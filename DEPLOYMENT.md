# 真实服务部署与手机测试

## 服务配置

PostgreSQL 保存用户、衣物、识别任务、搭配、反馈、穿搭记录和登录 Session；私有 OSS 保存原图与透明 PNG 抠图。Qwen-VL 提取结构化信息，阿里云 `SegmentCommodity` 分割商品主体，Qwen 文本模型生成搭配。正式环境不创建演示账号或示例衣物，不允许 `AI_PROVIDER=mock`。

复制根目录 `.env.example` 的配置项到现有 `.env`，保留已有 SMTP 配置。至少填写：

- `POSTGRES_PASSWORD`：内置 PostgreSQL 的密码。
- `PUBLIC_ORIGIN`：实际 HTTPS 网站地址。
- `ALIYUN_ACCESS_KEY_ID` / `ALIYUN_ACCESS_KEY_SECRET`：轮换后、允许调用视觉智能商品分割的 RAM 凭据。
- `ALIYUN_OSS_BUCKET`：实际地域的私有 Bucket，北京填写 `ALIYUN_OSS_REGION=oss-cn-beijing`。
- `DASHSCOPE_API_KEY`：百炼模型调用凭据，与阿里云 AccessKey 不同。模型和 API Key 的地域应与 `QWEN_BASE_URL` 一致。
- `SMTP_SERVER` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `FROM_EMAIL`：注册验证码邮件。

可使用单独的 `ALIYUN_OSS_ACCESS_KEY_ID` / `ALIYUN_OSS_ACCESS_KEY_SECRET`，留空则后端复用视觉智能平台凭据。Bucket 权限至少允许原图写入、原图读取、抠图写入与抠图读取。阿里云需开通商品分割服务，并授予相应调用权限。

密钥只保存在被 Git 忽略的环境文件或服务器 Secret 中，不能放入 Flutter 的 `--dart-define`。曾粘贴到聊天中的密钥应先轮换。

## Docker Compose

```bash
docker compose config --quiet
docker compose up -d --build
docker compose logs -f api
```

默认启动 `postgres`、`api`、`web`。PostgreSQL 使用 `postgres_data` Volume，API 等待数据库健康检查后启动并自动创建/更新表。数据库与 API 不对公网映射端口，只有 Web 端口开放。

需要使用服务器已有的 PostgreSQL 时，填写 `DATABASE_URL`；该值优先于 Compose 内置连接。内置服务仍会启动，如不需要可使用单独的 Compose override 移除。服务器数据库应使用正确的 TLS 配置；内置容器网络默认使用 `sslmode=disable`。在更改数据库配置前备份数据；不要运行 `docker compose down -v`，该命令会删除数据库 Volume。

用 HTTPS 反向代理转发至 Web 容器的 80 端口。Web 容器将 `/api/` 转发至后端，Flutter 生产构建使用 `API_BASE_URL=/api`。若外层还有 Nginx，应将上传大小设为至少 `11m`，API 代理超时设为至少 `180s`。

## 图片处理

1. 点击拍照或相册，上传至受登录保护的 `POST /uploads/images`。
2. 后端验证真实图片格式，将 JPEG、PNG、WebP 缩放为最长边 1900 像素、3 MB 以下的 JPEG，再保存到当前用户的 OSS 原图目录。输入最多 10 MB，不接受 HEIC；手机相册需转换为 JPEG。
3. `POST /ai/item-recognition/tasks` 创建任务，返回 `processing`；客户端查询 `GET /ai/tasks/:id`。
4. Qwen-VL 提取名称、一级/二级分类、主/次颜色、图案、品牌、材质、版型、季节、风格、场景、置信度和待确认字段。无法确认的品牌/材质留空，不编造尺码和价格。
5. 非上海 OSS 原图通过官方 SDK 文件上传方式调用商品分割，上海 OSS 可直接使用签名链接。阿里云商品分割返回裁边后的透明 PNG；后端立即下载并保存到自己的私有 OSS。官方结果链接仅有效 30 分钟，不能直接作为衣橱永久图片。
6. 确认页展示抠图及识别字段，用户确认后保存到 PostgreSQL。任一步骤失败，任务记为 `failed`，不会用原图或示例数据假装成功。

目前一次手机操作处理一张图片。请每张照片拍摄一件衣物或一双鞋的完整主体。存在多个不同单品的照片会被拒绝。后台单实例最多并行处理两项任务；重启后未完成任务标为失败，需重新提交。当前实现适用于单 API 实例，多实例需增加共享任务队列和任务租约。

OSS 读取 URL 仅对当前用户签发，五分钟有效。数据库保存稳定的 `oss://` 地址，不保存会过期的签名链接。前端重新加载页面时获取新的签名链接。

## 手机本机测试

原生 Android：手机通过 USB 连接电脑，执行：

```bash
adb reverse tcp:3000 tcp:3000
cd app
flutter pub get
flutter run -d DEVICE_ID --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

使用手机浏览器时，`localhost` 指手机，不能用它访问电脑。假设电脑局域网 IP 为 `192.168.1.10`：

```bash
# 终端一（已配置 server/.env 内的 PostgreSQL、云服务和 SMTP）
cd server
CORS_ORIGIN=http://192.168.1.10:8080 go run ./cmd/api

# 终端二
cd app
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 \
  --dart-define=API_BASE_URL=http://192.168.1.10:3000
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
flutter build web --release --dart-define=API_BASE_URL=/api
```

自动化测试不调用收费云服务。上线验收应使用已配置的真实凭据：注册真实用户，拍摄一件上衣和一双鞋，验证抠图、结构化信息、刷新后的衣橱和跨账号隔离，再生成搭配并保存今日穿搭。

内置 PostgreSQL 备份：

```bash
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > ai_closet_backup.sql
```

原有 SQLite 文件不会自动迁入 PostgreSQL，也不会被删除。默认连接到新的空数据库；如需迁移已有真实数据，应先备份并单独执行迁移，避免混入演示记录。

官方参考：[商品分割](https://help.aliyun.com/en/viapi/developer-reference/api-i8iw3k)、[Qwen 兼容接口](https://help.aliyun.com/en/model-studio/qwen-api-via-openai-chat-completions)、[结构化输出](https://help.aliyun.com/en/model-studio/qwen-structured-output)、[手机浏览器拍照限制](https://pub.dev/packages/image_picker_for_web)。
