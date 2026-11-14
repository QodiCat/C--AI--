# 接口契约与外部对接

权威路由由 server/internal/bootstrap/app.go 与 modules/*/routes.go、auth/password.go 定义，修改接口时同步请求模型、前端 repository 和相关测试。
响应通过 httpapi：成功 {success:true,data:...}；错误 {success:false,error:{code,message}}。前端使用 ApiClient；Bearer token 通过 AuthSession 管理。

| 领域 | 主要接口与约定 |
| --- | --- |
| 认证 | POST /auth/register/code、/auth/register、/auth/login、/auth/logout |
| 密码 | POST /auth/password/reset/code(email)、/reset(email,code,newPassword)、/change(currentPassword,newPassword，需登录) |
| 衣橱 | GET/POST /items，详情、编辑、状态修改及删除以 item/routes.go 为准 |
| 图片 | POST /uploads/images multipart file，最大 10 MB；归一化图最大 1900 像素、3 MB；GET /uploads/oss-url?objectUri=… 当前用户签名读取 |
| 识别 | POST /ai/item-recognition/tasks {imageUrls:[oss://…]}，1–9 张；GET /ai/tasks/:taskId，processing/success/failed；仅当前用户可查询 |
| 搭配 | GET/POST /outfits；GET/PATCH/DELETE /outfits/:outfitId、GET /outfits/:outfitId/items、PATCH /outfits/:outfitId/rating |
| AI/推荐 | 路由注册位于 recommendation/routes.go，生成结果的 itemIds 为数组；保存后的 Outfit.itemIds 当前为 JSON 字符串，前端兼容两种表示 |
| 记录/资料 | /wear-logs 与 /me 相关路由分别由 wearlog 与 profile 定义 |

私有 OSS 图片先上传，再执行 Qwen 识别和阿里云商品分割，结果保存回 OSS；无有效结果时任务失败。上海 OSS 走签名 URL，其他地域走 SDK 文件上传，HTTPS 连接。不要将失败错误中的原始 URL 或 SDK Data 返回用户。
注册验证码与重置验证码互相隔离；一次使用、10 分钟有效、60 秒发送间隔、5 次错误后失效；IP 配额共享。密码更新同时撤销会话。
搭配 POST 与 PATCH 使用 name、itemIds（数组）、scene、style、season、category；PATCH 当前为编辑页提交的完整可编辑快照，要求非空名称及至少一件本人衣物，不接受重复/他人单品。来源、评分和 AI 原因不随编辑重置。
GET /outfits 支持 source 与 category 精确筛选；category 显式空值表示未分类，未传则不按分类过滤。分类为最长 50 字符的自定义单分类，新增/编辑均可设置或清空。DELETE 仅删除当前用户的搭配；衣物和穿搭记录保留，历史记录可能显示已删除搭配。

## 2026-10-05 身体数据
GET /me 返回 height、weight、bust、hip、waist、shoulderWidth、thighCircumference、legLength、torsoLength。PATCH /me/body-measurements 接收数字对象，仅更新已传字段，0 清除，范围 0–300；长度 cm、体重 kg。拒绝空对象及未知字段，仅操作本人。基础资料 PATCH 未传 height/weight 时保留原值。

## 2026-10-05 今日 AI 搭配
移除 POST /ai/outfits/generate；保存 /ai/outfits/save 保留，旧 AI 搭配不删除。POST /ai/today-recommendation/generate 改为 {latitude:number,longitude:number,scene:string}；经登录认证后校验坐标范围，后端查天气再调用 AI。旧 weather/temperature 不能替代服务端查询；未传坐标返回 400，天气失败返回 502 WEATHER_UNAVAILABLE。返回 data:{candidates:[...],weather:{...}}；天气响应字段和校验已于 2026-11-08 被下述高德契约替代，需同步更新前后端。

## 2026-10-05 衣橱显示偏好
GET /me 新增 wardrobeDisplayPreferences，为 JSON 字符串，默认 {}；对象包含 categories、seasons 数组。PATCH /me/wardrobe-display 提交完整 {categories:[...],seasons:[...]}，两字段必传，空数组表示该维度不限制；categories 可选上装/下装/外套/裙装/鞋履/包袋/配饰，seasons 为春/夏/秋/冬，未知值/重复值/null 返回 400 INVALID_DISPLAY_PREFERENCES。仅更新当前用户的显示偏好；失败返回 500 DISPLAY_UPDATE_FAILED，成功返回当前 User。接口不限制 /items 或 AI 数据源，Flutter 在衣橱列表应用偏好。

## 2026-11-08 衣物编辑与备注
GET /items 与 GET /items/:itemId 的 Item 新增 notes 字符串。POST /items、PATCH /items/:itemId 接受 notes（最多 2000 Unicode 字符，多行）；创建省略为 ""，编辑省略或 null 保留原备注，显式 "" 清空。超限返回 400 INVALID_REQUEST；写入失败返回 500 ITEM_CREATE_FAILED/ITEM_UPDATE_FAILED。编辑沿用完整属性快照契约，名称/两级分类/管理状态/可穿状态必填，数组字段提交数组；前端不提交图片地址，后端保留原图、抠图和归属。详情读取与写入均按当前用户限制。

## 2026-11-08 高德天气契约（替代 Open-Meteo）
POST /ai/today-recommendation/generate 请求保持 {latitude,longitude,scene}，设备 GPS 坐标在后端先取三位小数，经 /v3/assistant/coordinate/convert（coordsys=gps）转换后取三位小数，经 /v3/geocode/regeo 解析 adcode，再调用 /v3/weather/weatherInfo 的 base/all。服务端只读取所需字段，兼容逆地理 city 等无关字段为空数组。
weather 返回 {latitude,longitude,date,time,timezone,source,city,adcode,weather,temperature,dayTemperature,nightTemperature,windDirection,windPower}；温度 °C，windPower 为原始风力等级字符串（如 ≤3），timezone 固定 Asia/Shanghai，source 为高德地图。date 为当地今天，time 为实况发布时间；不再返回 feelsLike/minimum/maximum/wind，不能把日夜预报当实测极值、风力当 km/h。前端与后端须同步更新，AI 按新字段获取天气，穿搭记录仍保存日期/天气/当前温度。
校验实况距现在不超过 3 小时、预报发布时间不超过 24 小时且包含今天的 cast；两者超前不超过 30 分钟。午夜允许前一天最新实况和包含今天的预报，date 仍取今天。温度须为有限有效数字，0 与负温度有效；缺少地区/必需字段、日期不符、HTTP/高德业务失败均拒绝且不调用 AI。缺少 AMAP_API_KEY 返回 503 WEATHER_NOT_CONFIGURED，其他天气失败返回 502 WEATHER_UNAVAILABLE（提示检查 Key、权限及额度）；不回传上游 URL、Key 或原始错误信息。
官方依据：[天气查询](https://lbs.amap.com/api/webservice/guide/api/weatherinfo)、[逆地理编码](https://lbs.amap.com/api/webservice/guide/api/georegeo)、[坐标转换](https://developer.amap.com/api/webservice/guide/api/convert)。

## 2026-11-14 单件衣物实测尺寸
Item 新增 measurements 数字对象（非 JSON 字符串），单位 cm。POST/PATCH /items 接受可选 measurements：创建省略/null 默认 {}，编辑省略/null 保留；传对象整体替换，{} 清空，删除单项需在完整对象中省略该键。仅允许有限数字，0 < 值 ≤ 500；未知键、字符串、null 单项及越界返回 400 INVALID_REQUEST。归属隔离、数据库失败契约沿用衣物接口。
上衣键：length（衣长）、shoulderWidth、chest、waist、hem、sleeveLength、centerBackSleeve、upperArm、armholeDepth、backWidth、cuff、collar、neckWidth、frontNeckDepth。裤子键：waist（共用）、hip、frontRise、backRise、thigh、outseam、inseam、knee、calf、legOpening。位置键：waistPosition（距肩颈点）、backWidthPosition（距后领中心）、hipPosition（距腰头）、kneePosition（距裆底）、calfPosition（距裤脚）。量法与用途由 Flutter garment_measurement.dart 目录提供。当前不以类别拒绝字段，切换分类不会自动删除已填写尺寸。
