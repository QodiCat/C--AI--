# 服务器部署

## 存储分工

- SQLite 保存用户、衣物元数据、搭配、穿搭记录和登录 Session。
- 阿里云 OSS 保存原图、抠图、头像和穿搭照片。Bucket 应设置为私有。
- 当前 OSS 接口已经约定用户隔离目录，但签名字段仍是占位值，上生产前必须接入阿里云 SDK 生成短期直传签名和临时读取 URL。

对象路径：`users/{userId}/{originals|cutouts|wear-logs|avatars}/...`。

## Docker 部署

服务器需要安装 Docker Engine 和 Compose 插件。复制 `.env.example` 为 `.env`，填写域名和服务密钥，然后执行：

```bash
docker compose up -d --build
docker compose logs -f
```

默认通过服务器 80 端口访问。SQLite 文件保存在 `api_data` Volume，更新容器不会丢失。

生产环境建议在云安全组中只开放 80/443，使用 Caddy、云负载均衡或宿主机 Nginx 终止 HTTPS，再转发到本项目 Web 容器。不要暴露 API 容器的 3000 端口。

## 环境变量

```dotenv
PUBLIC_ORIGIN=https://closet.example.com
WEB_PORT=80
AI_PROVIDER=mock
AI_API_BASE_URL=
AI_API_KEY=
ALIYUN_OSS_REGION=oss-cn-shanghai
ALIYUN_OSS_BUCKET=your-private-bucket
ALIYUN_OSS_ACCESS_KEY_ID=
ALIYUN_OSS_ACCESS_KEY_SECRET=
```

正式环境应通过云平台 Secret 管理 OSS 密钥，不要提交到 Git。建议为应用创建权限最小化的 RAM 用户，只允许访问指定 Bucket 和用户资源前缀。

## 数据库扩展

单机、小规模阶段可继续用 SQLite，并定时备份 Docker Volume。需要多实例、高并发或容灾时，应先把数据库驱动迁移为 PostgreSQL，再横向扩展 API；SQLite 不适合多个 API 容器同时写入。

## 发布前检查

1. 域名已启用 HTTPS，`PUBLIC_ORIGIN` 与实际域名一致。
2. OSS Bucket 为私有，直传签名和临时读取 URL 已真实实现。
3. 备份并验证恢复 SQLite Volume。
4. 修改或删除演示账号和演示数据。
5. 为注册和登录增加 IP/账号限流、邮箱验证与找回密码流程。
