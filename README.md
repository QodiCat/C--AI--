# AI衣橱

当前仓库已正式进入源码开发阶段，采用前后端分离结构：

- `server/`：Go + Gin 后端 API
- `app/`：Flutter 客户端

## 当前实现范围

MVP 业务闭环已实现：

- 登录、退出、个人资料、风格偏好、隐私授权和账号注销
- 邮箱密码注册、bcrypt 密码哈希、持久化登录态与多用户数据隔离
- 衣橱录入、搜索、分类筛选、状态维护、归档与软删除
- 真实 Qwen-VL 图片结构化识别、阿里云商品分割、透明 PNG 转存 OSS 与任务状态查询
- 手动/AI 搭配保存、列表、详情、评分、反馈和局部换单品
- 今日推荐、最近可穿单品过滤、AI 任务状态记录
- “今天穿了这套”、穿搭记录维护及按日期/月查询
- Flutter 衣橱、AI 造型师、今日推荐、搭配记录和个人中心交互
- Go 核心业务流程测试与 Flutter 组件测试

## 后端运行

1. 进入 `server/`
2. 准备环境变量：参考 `server/.env.example`，配置 PostgreSQL 的 `DATABASE_URL`、阿里云 OSS/商品分割和 DashScope API Key
3. 安装依赖：`go mod tidy`
4. 启动服务：`go run ./cmd/api`

默认地址：`http://localhost:3000`

运行环境使用 PostgreSQL，启动时自动创建/更新表。SQLite 仅用于自动化测试；旧 SQLite 文件不会自动迁移。默认不注入演示账号或示例衣物。

## SMTP 邮件配置

后端启动时读取 `server/.env`（不存在时读取根目录 `.env`），已导出的环境变量优先。
设置 `SMTP_SERVER`、`SMTP_PORT=465`、`SMTP_USERNAME`、`SMTP_PASSWORD` 和 `FROM_EMAIL`。
Docker Compose 通过根目录 `.env` 注入同名变量。真实凭据只保存在被 Git 忽略的本地环境文件中。

在 `server/` 目录验证 TLS 连接和 SMTP 登录：

```bash
go run ./cmd/mailcheck
```

向指定收件人发送测试邮件：

```bash
go run ./cmd/mailcheck -to recipient@example.com
```

邮件发送模块使用隐式 TLS、证书验证和连接超时。注册时需先发送邮箱验证码，再提交邮箱、密码和验证码。验证码 10 分钟有效，60 秒后可重发，连续错误 5 次后失效，同一来源每小时最多发送 10 次。验证码仅保存在后端内存中，服务重启后需重新获取。密码找回尚未接入。

接口：`POST /auth/register/code`（`email`）；`POST /auth/register`（`email`、`password`、`nickname`、`code`）。

## 前端运行

1. 进入 `app/`
2. 执行 `flutter pub get`
3. 运行：`flutter run`

当前前端默认请求：`http://localhost:3000`

请使用邮箱验证码注册真实账号。测试夹具仅在自动化测试中使用演示账号。手机浏览器和 Android 本机测试步骤见 [DEPLOYMENT.md](DEPLOYMENT.md)。

## 服务器部署

Docker Compose 部署、HTTPS、数据库和对象存储配置见 [DEPLOYMENT.md](DEPLOYMENT.md)。

## 外部服务接入说明

### 阿里云 OSS 与抠图

手机相机/相册通过 `POST /uploads/images` 上传，后端验证图片并缩放压缩后存入私有上海 OSS。`POST /ai/item-recognition/tasks` 运行 Qwen-VL 识别与阿里云 `SegmentCommodity` 抠图，`GET /ai/tasks/:id` 查询结果。抠图结果立即转存 OSS；确认页展示真实结果，保存后从数据库读取衣橱。

`GET /uploads/oss-url` 生成当前用户对象的临时读取链接。原有 `POST /uploads/oss-signature` 仍可供直传客户端使用。

### 通义千问

默认 `AI_PROVIDER=qwen`。配置 `DASHSCOPE_API_KEY`、`QWEN_BASE_URL`、`QWEN_VISION_MODEL`（默认 `qwen3-vl-plus`）和 `QWEN_TEXT_MODEL`（默认 `qwen-plus`）。阿里云 AccessKey 不能替代 DashScope API Key。

图像提取名称、分类、颜色、图案、品牌、材质、版型、季节、风格、场景和待确认字段；搭配模型只能使用当前用户的可穿单品 ID。服务缺少配置或调用失败时返回真实错误，不回退到模拟内容。

`MockProvider` 仅用于显式启用的开发/自动化测试，生产环境禁止使用。部署和完整配置见 [DEPLOYMENT.md](DEPLOYMENT.md)。
