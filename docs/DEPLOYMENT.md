# 后端运行与一键更新

当前部署按用户确认：服务器 115.25.46.153、SSH 账号 qodi、Ubuntu 24.04、无管理员权限；运行目录 /home/qodi/ai-closet/server，API 端口 3000。用户已确认服务器本机和手机健康检查成功；此记录不替代后续更新检查。

## 本机一条命令更新

本机需 Python 3.8+、ssh、scp；服务器需 Python 3.8+、Go（允许 GOTOOLCHAIN=auto 下载项目要求工具链）、curl 可用于手动检查。服务器已有可用数据库及配置好的 ~/ai-closet/server/.env。

首次在本机项目根目录配置目标：

```bash
cp deploy/backend.example.json deploy/backend.json
```

示例已填写 qodi@115.25.46.153、SSH 22、remote_directory=ai-closet、api_port=3000；其他机器修改 deploy/backend.json。该文件本地忽略，不存密码。remote_directory 为 SSH 用户家目录内的相对路径。

先预检，再更新：

```bash
python3 tools/update_backend.py --dry-run
python3 tools/update_backend.py
```

第二条命令会真正连接服务器、编译和重启服务。输入 SSH 密码或使用已有 SSH 密钥；不关闭主机密钥校验。临时复用 SSH 连接减少重复认证。

流程：
- 仅打包 server/go.mod、go.sum、cmd 和 internal 源码，排除 .env、运行数据、日志和二进制。
- 上传到 ~/ai-closet/releases/<唯一编号>，解包到新的 source 目录，服务器执行 Go Modules 下载与编译；没有旧源码残留。编译失败保留当前服务。
- 保存旧程序为该版本目录的 previous-api，仅停止同一账号、运行目录和程序路径匹配的 API 进程。不停止未知端口进程；更新锁阻止同时重启。
- 替换 ~/ai-closet/server/bin/api，以独立会话在原 server 目录启动，日志追加到 logs/api.log；保留 .env、data 和 logs。
- 绕过 HTTP 代理查询本机 /health，同时检查新进程仍在运行。成功记录 api.pid 并输出备份/源码目录。

发布目录保留用于检查和备份，不自动清理；定期按实际磁盘空间保留需要的版本。更新仍有短暂重启中断，不宣称无中断。

## 失败处理与数据库

新增配置项需先在服务器 .env 补充；脚本不覆盖也不输出凭据。后端启动 AutoMigrate 会建表/改表，因此涉及模型或迁移变化时先备份 PostgreSQL，或请数据库管理员备份。程序备份不是数据库备份。

新程序健康检查失败时，脚本停止新进程、在存在备份时恢复旧二进制，并明确返回失败；不会自动启动旧版本或回滚数据库。先检查服务器 logs/api.log 中错误并确认数据库兼容，再决定恢复启动。该保守行为避免错误地承诺数据库迁移可自动回退。

```bash
ssh qodi@115.25.46.153
cd "$HOME/ai-closet/server"
tail -n 50 logs/api.log
ss -ltnp 'sport = :3000'
```

确认端口没有服务、数据库兼容且配置已修复后才重新启动：

```bash
nohup ./bin/api >> logs/api.log 2>&1 < /dev/null &
curl --noproxy '*' --max-time 10 --fail http://127.0.0.1:3000/health
```

日志可能含业务信息，分享前遮住凭据和个人信息。脚本不自动打印服务日志。

## 后台运行边界

更新后进程脱离 SSH 会话，等效于当前 nohup 使用方式；不提供崩溃自动重启或服务器开机启动。长期托管需管理员提供 systemd，或允许用户 systemd 并开启 linger。若改用 systemd，应相应改造脚本的服务管理流程，不同时使用两种管理方式。

数据库配置在 server/.env，模板见 server/.env.example；仅真实 PostgreSQL 用于服务，不用 SQLite 替代。必须配置实际百炼、OSS、视觉分割和邮件凭据，不使用 mock 或演示种子。

## 安卓更新

仅接口兼容的后端修改可直接使用上述命令。客户端 UI/逻辑或不兼容接口变化还需更新 APK；递增 app/pubspec.yaml 版本号，并沿用同一包名/签名。

```bash
cd app
flutter build apk --release --no-pub
```

APK 位于 app/build/app/outputs/flutter-apk/app-release.apk。当前客户端服务器地址为 http://115.25.46.153:3000；HTTP 为安装测试配置，正式公网服务应配置 HTTPS 并按新绝对接口地址重建 APK。Android 生成平台后在仓库根运行 python3 tools/configure_location.py，检查 INTERNET 与前台定位权限。

## 本次验证范围

本机预检与脚本自动化测试验证打包排除、独立源码、非法路径、编译失败保持旧程序、未知端口保护、成功备份、健康检查失败处理及真实本地进程身份/停止。未连接服务器更新、未迁移远端数据库；真实部署结果以执行脚本后的输出与手机验收为准。
