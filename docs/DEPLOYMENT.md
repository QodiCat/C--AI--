# 真实服务部署与手机测试

## 服务配置

PostgreSQL 保存用户、衣物、识别任务、搭配、反馈、穿搭记录和登录 Session；私有 OSS 保存原图与透明 PNG 抠图。Qwen-VL 提取结构化信息，阿里云 `SegmentCommodity` 分割商品主体，Qwen 文本模型生成搭配。正式环境不创建演示账号或示例衣物，不允许 `AI_PROVIDER=mock`。

后端配置放在 `server/.env`，参考 `server/.env.example`，保留已有密钥和 SMTP 配置。前端配置单独放在 `app/.env`，参考 `app/.env.example`，仅填写公开的 `API_BASE_URL`。至少填写：

- `DATABASE_URL`：已安装并运行的 PostgreSQL 连接地址；留空时使用 `POSTGRES_HOST`、`POSTGRES_PORT`、`POSTGRES_USER`、`POSTGRES_PASSWORD`、`POSTGRES_DB` 和 `POSTGRES_SSLMODE`（仍兼容 `PG*` 配置）。
- `CORS_ORIGIN`：允许的前端来源，多个来源用逗号分隔。
- `ALIYUN_ACCESS_KEY_ID` / `ALIYUN_ACCESS_KEY_SECRET`：允许目标 OSS Bucket 上传和读取的 RAM 凭据。
- `ALIYUN_VIAPI_ACCESS_KEY_ID` / `ALIYUN_VIAPI_ACCESS_KEY_SECRET`：允许调用视觉智能商品分割的 RAM 凭据。
- `ALIYUN_OSS_BUCKET`：实际地域的私有 Bucket，北京填写 `ALIYUN_OSS_REGION=oss-cn-beijing`。
- `DASHSCOPE_API_KEY`：百炼模型调用凭据，与阿里云 AccessKey 不同。模型和 API Key 的地域应与 `QWEN_BASE_URL` 一致。
- `SMTP_SERVER` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `FROM_EMAIL`：注册验证码邮件。

OSS 与视觉平台使用独立的变量，必须分别配置，不会相互回退。Bucket 权限至少允许原图写入、原图读取、抠图写入与抠图读取。阿里云需开通商品分割服务，并授予相应调用权限。

密钥只保存在被 Git 忽略的环境文件或服务器 Secret 中，不能放入 `app/.env`；前端 `.env` 会打包到客户端并公开可读。曾粘贴到聊天中的密钥应先轮换。

## 源码运行与部署

先自行安装 PostgreSQL，创建 `server/.env` 对应的数据库和用户，并确保后端能够连接。服务启动会自动创建业务表，不会创建 PostgreSQL 用户或数据库。

本地运行，在项目根目录打开两个终端：

```bash
# 终端一
cd server
go mod download
go run ./cmd/api
```

```bash
# 终端二，app/.env 中 API_BASE_URL=http://localhost:3000
cd app
flutter pub get
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

浏览器访问 `http://localhost:8080`。修改 `server/.env` 后重启后端；修改 `app/.env` 后重新运行或构建前端。

生产环境从源码构建：

```bash
cd server
go build -o bin/api ./cmd/api
# 从 server/ 目录运行，使用 server/.env
./bin/api
```

长期运行时使用 systemd 等进程管理器，将工作目录设置为 `server/` 的绝对路径。设置 `APP_ENV=production`、正确的数据库 TLS 参数和前端来源。

前端生产配置设为 `app/.env` 中 `API_BASE_URL=/api`，然后构建：

```bash
cd app
flutter pub get
flutter build web --release
```

将 `app/build/web/` 内容部署到 `/var/www/ai-closet/`，使用 `app/deploy/nginx.conf` 作为 Nginx 配置模板，将 `/api/` 代理到本机 `127.0.0.1:3000`。按服务器实际情况修改域名和静态文件路径，并配置 HTTPS。模板上传限制为 `11m`，代理超时为 `180s`。后端端口只允许本机或可信网络访问。

## 图片处理

1. 点击拍照或相册，上传至受登录保护的 `POST /uploads/images`。
2. 后端验证真实图片格式，将 JPEG、PNG、WebP 缩放为最长边 1900 像素、3 MB 以下的 JPEG，再保存到当前用户的 OSS 原图目录。输入最多 10 MB，不接受 HEIC；手机相册需转换为 JPEG。
3. `POST /ai/item-recognition/tasks` 创建任务，返回 `processing`；客户端查询 `GET /ai/tasks/:id`。
4. Qwen-VL 提取名称、一级/二级分类、主/次颜色、图案、品牌、材质、版型、季节、风格、场景、置信度和待确认字段。无法确认的品牌/材质留空，不编造尺码和价格。
5. 非上海 OSS 原图通过官方 SDK 文件上传方式调用商品分割，上海 OSS 可直接使用签名链接。阿里云商品分割返回裁边后的透明 PNG；后端立即下载并保存到自己的私有 OSS。官方结果链接仅有效 30 分钟，不能直接作为衣橱永久图片。
6. 确认页展示抠图及识别字段，用户确认后保存到 PostgreSQL。任一步骤失败，任务记为 `failed`，不会用原图或示例数据假装成功。

相册一次最多选择 9 张图片，最多同时上传和解析两张，每张图片单独显示结果、确认保存和失败重试。请每张照片拍摄一件衣物或一双鞋的完整主体。存在多个不同单品的照片会被拒绝。后台单实例最多并行处理两项任务；重启后未完成任务标为失败，需重新提交。当前实现适用于单 API 实例，多实例需增加共享任务队列和任务租约。

OSS 读取 URL 仅对当前用户签发，五分钟有效。数据库保存稳定的 `oss://` 地址，不保存会过期的签名链接。前端重新加载页面时获取新的签名链接。

## 手机本机测试

原生 Android：设置 `app/.env` 中 `API_BASE_URL=http://127.0.0.1:3000`，手机通过 USB 连接电脑，执行：

```bash
adb reverse tcp:3000 tcp:3000
cd app
flutter pub get
flutter run -d DEVICE_ID
```

使用手机浏览器时，`localhost` 指手机，不能用它访问电脑。假设电脑局域网 IP 为 `192.168.1.10`，设置 `app/.env` 中 `API_BASE_URL=http://192.168.1.10:3000`：

```bash
# 终端一（已配置 server/.env 内的 PostgreSQL、云服务和 SMTP）
cd server
CORS_ORIGIN=http://192.168.1.10:8080 go run ./cmd/api

# 终端二
cd app
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

手机和电脑连接同一网络，手机打开 `http://192.168.1.10:8080`。若电脑防火墙拦截，应允许局域网访问 8080 和 3000。手机浏览器的拍照入口使用 capture，是否直接打开相机取决于浏览器；不支持时可先拍照再从相册选取。正式手机浏览器测试建议使用部署后的 HTTPS 网站。

本仓库当前具有 Android、Web 和 Linux 工程，没有 iOS 工程。要构建 iPhone 原生应用需在 macOS 补齐 iOS 工程，并配置相机及相册用途声明。

## 验证和备份

```bash
cd server
go test ./...
# TEST_POSTGRES_DSN 指向可创建临时 schema 的测试数据库
TEST_POSTGRES_DSN='host=127.0.0.1 port=5432 user=... password=... dbname=... sslmode=disable' \
  go test ./internal/infrastructure/database -run TestPostgres -v

cd ../app
flutter analyze
flutter test
flutter build web --release
```

自动化测试不调用收费云服务。上线验收应使用已配置的真实凭据：注册真实用户，拍摄一件上衣和一双鞋，验证抠图、结构化信息、刷新后的衣橱和跨账号隔离，再生成搭配并保存今日穿搭。

使用 PostgreSQL 客户端备份（替换为实际连接信息）：

```bash
pg_dump -h 127.0.0.1 -p 5432 -U ai_closet -d ai_closet -W > ai_closet_backup.sql
```

原有 SQLite 文件不会自动迁入 PostgreSQL，也不会被删除。默认连接到新的空数据库；如需迁移已有真实数据，应先备份并单独执行迁移，避免混入演示记录。

官方参考：[商品分割](https://help.aliyun.com/en/viapi/developer-reference/api-i8iw3k)、[Qwen 兼容接口](https://help.aliyun.com/en/model-studio/qwen-api-via-openai-chat-completions)、[结构化输出](https://help.aliyun.com/en/model-studio/qwen-structured-output)、[手机浏览器拍照限制](https://pub.dev/packages/image_picker_for_web)。

## 今日 AI 搭配的定位与天气
后端新增 WEATHER_BASE_URL，默认 https://api.open-meteo.com/v1/forecast，模板见 server/.env.example；需要可访问天气接口及系统时区数据库。Open-Meteo 公共接口用于个人非商业使用；商业部署需使用相应订阅接口配置，不能把公共免费额度当作商业服务保证。参考 [天气接口与使用条款](https://open-meteo.com/en/docs)。
Web 定位需要 HTTPS 或 localhost；通过局域网 HTTP IP 打开的手机浏览器不能验证定位，应改用 HTTPS。Nginx 模板仍需按实际域名配置 TLS。定位失败不会改用个人资料城市或默认天气。
平台目录由 Flutter 本地生成且不提交。新环境执行 flutter create --platforms=android,web,linux . 后，在项目根执行 python3 tools/configure_location.py，配置 Android 前台粗略定位权限；现有本地 Android 清单已配置，不增加后台定位。iOS 工程仍未建立；在 macOS 生成后运行同一脚本配置 NSLocationWhenInUseUsageDescription 和 geolocator_apple 的 BYPASS_PERMISSION_LOCATION_ALWAYS=1，再进行真机验收。参考 [定位插件权限说明](https://pub.dev/packages/geolocator)。
验收时允许定位，确认坐标、天气、当地日期显示正确；再测试拒绝权限、关闭定位、天气网络失败与重试，最后保存今日穿搭，核对天气及日期。
