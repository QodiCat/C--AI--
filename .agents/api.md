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
| 搭配 | GET/POST /outfits；GET/DELETE /outfits/:outfitId、GET /outfits/:outfitId/items、PATCH /outfits/:outfitId/rating |
| AI/推荐 | 路由注册位于 recommendation/routes.go，生成结果的 itemIds 为数组；保存后的 Outfit.itemIds 当前为 JSON 字符串，前端兼容两种表示 |
| 记录/资料 | /wear-logs 与 /me 相关路由分别由 wearlog 与 profile 定义 |

私有 OSS 图片先上传，再执行 Qwen 识别和阿里云商品分割，结果保存回 OSS；无有效结果时任务失败。上海 OSS 走签名 URL，其他地域走 SDK 文件上传，HTTPS 连接。不要将失败错误中的原始 URL 或 SDK Data 返回用户。
注册验证码与重置验证码互相隔离；一次使用、10 分钟有效、60 秒发送间隔、5 次错误后失效；IP 配额共享。密码更新同时撤销会话。
现有删除、评分接口并不表示搭配编辑/分类 UI 已交付，见需求未决事项。
