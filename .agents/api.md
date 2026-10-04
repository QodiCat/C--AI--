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
