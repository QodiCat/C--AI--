# AI 衣橱前端

复制 `.env.example` 为 `.env`，设置 `API_BASE_URL=http://localhost:3000`。前端 `.env` 会随客户端公开发布，只允许 API 地址，不要放服务端密钥。

```bash
flutter pub get
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

浏览器访问 `http://localhost:8080`。手机访问时将 `.env` 中 API 地址改为电脑局域网 IP，并在 `server/.env` 配置对应的 `CORS_ORIGIN`。

生产部署配置 `API_BASE_URL=/api`，执行 `flutter build web --release`，通过 Nginx 托管 `build/web/` 并代理 API。详细步骤见 [部署文档](../docs/DEPLOYMENT.md)。

今日 AI 搭配在生成时请求前台定位并由后端获取天气，无手动天气/温度字段。浏览器需 HTTPS 或 localhost；手机局域网 HTTP 不支持定位。生成平台目录后在仓库根运行 python3 tools/configure_location.py 配置原生定位权限；iOS 工程当前尚未生成。
