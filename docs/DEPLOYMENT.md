# 服务器部署与 Android 发布

首次照着操作可从文末的[服务器与正式 Android 安装包教程](#2026-11-14-从当前代码到服务器与正式-android-安装包)开始，包含备份、发布签名、构建、安装和更新。

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

## 2026-11-08 衣物编辑与备注更新
本次需要同时更新后端与 Flutter 客户端。后端新增 items.notes（非空、默认空字符串），启动时 AutoMigrate；先备份 PostgreSQL，再更新并重启后端。真实 PostgreSQL 迁移尚未验证，不将 SQLite 自动化通过视为生产迁移通过。随后重启开发前端，或重新构建 Web/APK；只刷新旧前端资源不会加载新页面。旧客户端省略 notes 时保留已保存备注。

## 2026-11-08 高德天气配置
天气服务已由 Open-Meteo 改为高德地图。先在[高德开放平台](https://lbs.amap.com/api/webservice/gettingstarted)创建 Web 服务类型 Key，确认具有坐标转换、逆地理编码和天气查询所需服务权限与可用额度，再在实际运行后端的 server/.env 中添加（不要覆盖已有其他配置）：

```dotenv
AMAP_API_KEY=替换为高德Web服务Key
AMAP_BASE_URL=https://restapi.amap.com
```

WEATHER_BASE_URL 已停用，可删除旧项。Key 不写入 app/.env 或 Git，也无需贴在聊天中。生产 AMAP_BASE_URL 保持默认 HTTPS；如启用高德服务端 IP 白名单，填写运行后端的出口 IP。每次生成天气通常调用四次高德服务（坐标转换、逆地理编码、实况、预报），额度需覆盖这几项服务。
更新后端并重启，使配置加载；同时重新启动开发前端或构建/更新 Web、APK。天气响应和页面由体感/风速改为日夜预报及风力等级，因此不能只更新后端继续使用旧页面。本次无数据库结构变更。推荐接口缺少 Key 返回明确配置提示，权限/额度/上游失败阻止 AI；其他业务不因天气配置缺失而无法启动。
本地未配置高德 Key，未执行真实高德调用或服务器部署；真实连通性需在已配置 Key 的环境点击“获取天气并生成今日搭配”验证。自动化测试只用本机 HTTP 夹具，不代表高德实际 SLA 或网络稳定性。


## 2026-11-11 高德 Key 最小诊断

在后端所在机器的项目根目录运行（仅需 Python 3 标准库，无需启动后端或数据库）：

```bash
python3 tools/check_amap.py
# 指定实际部署配置文件
python3 tools/check_amap.py --env-file /path/to/server/.env
```

默认读取仓库 server/.env，已导出环境变量优先（包括空值），与后端一致。默认北京公开示例坐标；可用 `--longitude`、`--latitude` 指定 GPS 点。脚本发起最多四次真实高德请求，会使用接口额度，不修改任何配置。只向官方 HTTPS 地址发送 Key，拒绝重定向，不打印 Key、URL、原始响应或精确位置。

分别检查坐标转换、逆地理编码、实况和预报；定位失败仍以北京示例行政区单独测试天气权限。退出码：0 全部通过，1 接口/数据失败，2 配置错误。10001 表示 Key 不正确或过期；10002 检查服务权限/路径；10009 检查是否为 Web 服务 Key；10005 检查后端出口 IP 白名单；10003/10004 检查日额度/频率。含义依据[高德官方错误码文档](https://lbs.amap.com/api/webservice/guide/tools/info/)。网络失败不能据此判断 Key 无效。

全部通过仅证明本次接口调用成功，不验证应用内天气日期/时效校验或整条链路 20 秒时限。若仅本机通过而服务器失败，应在服务器使用实际配置复测；运行中的后端可能仍加载旧环境变量。

## 2026-11-14 从当前代码到服务器与正式 Android 安装包

本文是操作教程，不代表已经执行部署或打包。命令按 Linux/WSL Bash 编写；本机项目根目录为 `/home/qodicat/C--AI--`，服务器沿用本页记录的 `qodi@115.25.46.153`。如果目标已改变，先替换目标配置。流程是：确认服务配置与备份 → 更新后端 → 检查公网健康接口 → 配置 Android 地址和签名 → 构建安装 → 手机验收。

服务器运行 Go API，PostgreSQL 保存账号与衣物数据，OSS 保存图片；APK 是访问 API 的手机客户端。APK 安装后不需要电脑持续运行，但服务器和数据库需要持续在线。无需在服务器安装 Flutter，也不必部署 Web 前端才能使用 Android 客户端。

### A. 本机工具与服务器前提

本机准备 Python 3.8+、OpenSSH 的 ssh/scp、Linux Flutter、Android SDK 和 JDK。当前本机 Flutter 路径可在终端配置：

```bash
export PATH="$HOME/snap/flutter/common/flutter/bin:$PATH"
cd /home/qodicat/C--AI--
flutter doctor -v
```

按 doctor 输出补齐 Android toolchain；若提示许可证未接受，执行 `flutter doctor --android-licenses`。在 WSL 不要调用 Windows 的 Flutter 脚本；密钥与 SDK 路径也必须是当前构建环境可读取的路径。

检查 SSH 非交互命令能找到服务端工具：

```bash
ssh qodi@115.25.46.153 'go version'
ssh qodi@115.25.46.153 'python3 --version'
```

服务端需要 Go 能构建 `server/go.mod` 要求的 1.23.0 或兼容工具链，能下载 Go Modules，并能访问数据库、百炼、OSS、视觉分割、SMTP 和高德所需服务。没有数据库时先请管理员准备 PostgreSQL 数据库和应用账号；AutoMigrate 只负责表结构，不会创建数据库/账号。目标现有账号没有管理员权限，不在其会话中假设可运行 sudo 安装服务。

新服务器首次部署，先在本机创建运行目录并传配置模板：

```bash
ssh qodi@115.25.46.153 'mkdir -p "$HOME/ai-closet/server"'
scp server/.env.example qodi@115.25.46.153:ai-closet/server/.env.example
```

然后在服务器上执行（已有 `.env` 时只编辑，不覆盖）：

```bash
cd "$HOME/ai-closet/server"
# 仅首次、没有 .env 时复制模板
cp -n .env.example .env
chmod 600 .env
nano .env
```

按服务器实际环境填写数据库、Qwen/百炼、OSS、视觉分割、SMTP 和高德 Web 服务 Key；`PORT=3000` 要与 deploy/backend.json 的 api_port 一致，关闭演示数据，使用真实提供方。数据库远程连接的 SSL 设置按数据库服务要求填写，不直接照抄本机模板。已有服务器通常只需核对和补充配置。不要把后端凭据放进 app/.env，不要 `source .env` 当 shell 脚本执行或把完整配置贴到聊天中。

### B. 备份数据库并更新后端

这轮衣物实测尺寸增加了 `items.measurements` 列；若服务器较旧还会涉及 `items.notes` 等此前新增字段。因此要先做数据库备份，再运行更新脚本。标签统计本身不需要迁移。

在服务器上，下面以本机 PostgreSQL、账号/库名均为 ai_closet 举例；主机、端口、账号、库名应按实际配置替换，密码在终端提示时输入，不写在命令行里：

```bash
umask 077
mkdir -p "$HOME/backups/ai-closet"
backup_file="$HOME/backups/ai-closet/before-update-$(date +%Y%m%d-%H%M%S).dump"
pg_dump -h 127.0.0.1 -p 5432 -U ai_closet -d ai_closet -W -Fc -f "$backup_file"
pg_restore --list "$backup_file" > /dev/null
```

只有 pg_dump 成功且备份可读才继续；客户端版本需兼容服务器，远程数据库应使用其要求的 SSL 配置。`pg_restore --list` 只检查目录可读，不等于恢复演练。无 pg_dump 或备份权限时让数据库管理员提供可恢复备份；备份另存安全位置，程序备份不能替代数据库备份。参考 [PostgreSQL pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html)。

回到本机项目根目录，先准备目标配置，已有配置时不要覆盖：

```bash
cd /home/qodicat/C--AI--
# 仅首次：已有 backend.json 则跳过
cp -n deploy/backend.example.json deploy/backend.json
```

确认 deploy/backend.json：

```json
{
  "ssh_target": "qodi@115.25.46.153",
  "ssh_port": 22,
  "remote_directory": "ai-closet",
  "api_port": 3000
}
```

依次执行，第一条失败时先修正，不继续第二条：

```bash
python3 tools/update_backend.py --dry-run
python3 tools/update_backend.py
```

第二条真正上传当前本机 server 源码、在服务器编译、替换程序并重启，启动会执行 AutoMigrate。脚本保留服务器配置和数据，不需要先把代码 push 到 Git；也不会上传 app 或自动生成 APK。看见 `Update successful` 后检查服务。失败恢复行为及日志位置见本页“失败处理与数据库”，不要反复启动未知端口上的程序。

```bash
ssh qodi@115.25.46.153 'curl --noproxy "*" --max-time 10 --fail http://127.0.0.1:3000/health'
```

成功响应包含 `success: true` 和 `data.status: "ok"`。它证明进程健康，不等于图片、邮件、AI 等业务都正常。

### C. 确认手机能访问的 API 地址

现有 IP/HTTP 地址仅用于安装联通测试：`http://115.25.46.153:3000`。从手机浏览器打开它的 `/health`；服务器本机成功而手机失败时，检查云安全组、主机防火墙、端口及路由，需要管理员配合。生产网络应通过 HTTPS 提供服务，数据库端口无需向手机开放。

正式使用时准备域名与有效证书，例如把自有 API 域名解析到服务器，让管理员配置 HTTPS 反向代理至 `http://127.0.0.1:3000`，同时支持至少 10 MB 图片上传。域名示例 `api.your-domain.example` 不是可直接访问的真实服务，要换成自己的域名。只有手机浏览器成功打开 `https://实际域名/health` 后，才把这个 HTTPS 根地址打进正式 APK。此项目路由直接为 `/items`、`/auth` 等，反代时不要无故加上 `/api` 前缀。

现有更新脚本只托管普通后台进程，不能保证崩溃自动重启或服务器重启后自启。长期运行请管理员提供进程托管，并同步调整部署脚本，不让 systemd 与当前脚本同时争抢同一进程/端口。

### D. 配置 Android 工程与客户端地址

在本机 app 目录：

```bash
cd /home/qodicat/C--AI--/app
flutter pub get
```

仅在 `app/android` 不存在时生成平台，已有工程不要重新生成覆盖签名和权限配置：

```bash
flutter create --platforms=android .
```

在本机项目根目录执行定位权限配置：

```bash
cd /home/qodicat/C--AI--
python3 tools/configure_location.py
```

核对 `app/android/app/src/main/AndroidManifest.xml` 的 `<manifest>` 内有：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

脚本只补定位权限，不保证 INTERNET 已配置。正式 HTTPS 包不需要允许明文 HTTP；当前本机测试工程有 `android:usesCleartextTraffic="true"`，正式发布可移除此测试配置。仅在做 HTTP 联通测试时保留对应设置，并检查是否有覆盖它的 Network Security Config。参见 [Android 网络安全配置](https://developer.android.com/privacy-and-security/security-config)。

编辑本机 `app/.env`，只放公开地址（下面示例域名需替换）：

```dotenv
API_BASE_URL=https://api.your-domain.example
```

HTTP 联通测试可暂用当前 IP/3000 地址；不要使用 localhost、127.0.0.1 或只有开发浏览器能用的相对路径，它们在手机里无法代表这台服务器。`.env` 会作为资源打进 APK，改地址后必须重新构建并安装，不能只改文件而继续用旧 APK。

### E. 首次正式签名：只做一次并备份

本次检查到本机 `app/android/app/build.gradle.kts` 的 release 仍使用 `signingConfigs.getByName("debug")`。release 构建模式不代表已经使用正式签名；固定发布密钥用于以后持续更新。

如果已有发布密钥，继续使用它，不要重新生成。否则在本机生成（密码按提示输入）：

```bash
mkdir -p "$HOME/.android"
keytool -genkeypair -v -keystore "$HOME/.android/ai-closet-release.jks" \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias ai-closet
```

在 `app/android/key.properties` 写入以下配置；将占位符换成本机真实值，storeFile 使用绝对路径，不用 `~`：

```properties
storePassword=REPLACE_WITH_STORE_PASSWORD
keyPassword=REPLACE_WITH_KEY_PASSWORD
keyAlias=ai-closet
storeFile=/home/REPLACE_WITH_LOCAL_USER/.android/ai-closet-release.jks
```

限制该文件读取权限，备份密钥及密码到安全位置，不把它们提交 Git。当前整个 app/android 目录被忽略；如果以后改变平台目录管理方式，仍须单独排除 key.properties 和密钥文件。

```bash
chmod 600 app/android/key.properties
```

此 chmod 命令在项目根运行。编辑 `app/android/app/build.gradle.kts`：

1. 文件最上方、`plugins` 之前添加 import：

```kotlin
import java.util.Properties
```

2. 在 `plugins { ... }` 之后、`android { ... }` 之前添加读取逻辑：

```kotlin
val releaseKeys = Properties().apply {
    rootProject.file("key.properties").inputStream().use { load(it) }
}
```

3. 在现有 `android { ... }` 内、`buildTypes` 之前添加：

```kotlin
signingConfigs {
    create("release") {
        storeFile = file(releaseKeys.getProperty("storeFile"))
        storePassword = releaseKeys.getProperty("storePassword")
        keyAlias = releaseKeys.getProperty("keyAlias")
        keyPassword = releaseKeys.getProperty("keyPassword")
    }
}
```

4. 将现有 `buildTypes.release` 里的 debug 签名那一行替换为：

```kotlin
signingConfig = signingConfigs.getByName("release")
```

保留其余现有 Gradle 配置，不追加第二个 android/buildTypes/release 块。以上方案缺少 key.properties 时会直接失败，而不会回退 debug 签名；因此本机以后构建也需要保存该文件。步骤依据 [Flutter Android 发布](https://docs.flutter.dev/deployment/android) 与 [Android 应用签名](https://developer.android.com/studio/publish/app-signing)。

本机现有包名为 `com.example.ai_closet_app`。个人安装可先沿用；若要改为自己正式的 applicationId，应在首次发布前确定，并同步 Android namespace、MainActivity 包声明和目录。包名或签名变化无法直接覆盖原安装包。已装 debug 签名版的手机，切到新发布签名后需先确认数据已保存到账号，再卸载测试版、安装新版并重新登录；卸载会移除本机数据。正式发布后持续沿用包名和发布密钥，递增版本号。

### F. 构建、检查并安装 APK

编辑 `app/pubspec.yaml`，本轮可把 `version: 0.1.0+1` 改成 `version: 0.2.0+2`；若已经发布过更高版本，以已发布最高值为准继续递增 `+` 后的构建号。

在本机 app 目录依次运行：

```bash
cd /home/qodicat/C--AI--/app
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub
```

任何一步失败先修正，不继续发包。首次调整签名若遇到缓存问题，可先 `flutter clean`，再重新 `flutter pub get` 和上述检查/构建；普通更新不必每次 clean。

通用 APK 的完整路径：

```text
/home/qodicat/C--AI--/app/build/app/outputs/flutter-apk/app-release.apk
```

把这个 APK 传到手机，用系统文件管理器打开，按系统提示允许该来源安装。也可启用 USB 调试，在有权限访问手机的电脑上执行：

```bash
adb devices
adb install -r app/build/app/outputs/flutter-apk/app-release.apk
```

adb install 命令在项目根运行；WSL 未连接 USB 手机时可在 Windows 上用 adb 并使用 Windows 可访问的 APK 路径。`-r` 仍要求签名/包名兼容，不能解决签名冲突。

在 Android SDK build-tools 目录找到 apksigner，可执行以下只读校验，路径以本机实际目录为准：

```bash
apksigner verify --verbose --print-certs app/build/app/outputs/flutter-apk/app-release.apk
```

该命令假定 apksigner 已加入 PATH，且在项目根运行。核对签名证书指纹与自己的发布密钥一致；仅看到验证通过，不能证明用了正确发布密钥。

需要更小的分架构 APK 时，在 app 目录使用 `flutter build apk --release --split-per-abi --no-pub`，按手机 ABI 选择产物；先用通用 APK 更易安装。准备上架 Google Play 时使用 `flutter build appbundle --release --no-pub`，产物是 `app/build/outputs/bundle/release/app-release.aab`，不是直接点击安装的 APK。商店交付步骤另按商店流程处理。

### G. 手机验收与后续更新

手机断开开发电脑或切换移动网络后，检查：注册/登录、衣橱列表、拍照/相册上传、识别/图片加载、编辑保存、衣物尺寸、标签统计、定位授权与今日搭配。用同一账号重进确认数据保留。健康接口成功但部分业务失败时，按具体业务检查对应服务凭据、权限和网络，不能认为重新打包即可修复后端配置问题。

| 后续变化 | 操作 |
| --- | --- |
| 仅兼容的后端改动 | 数据结构有变时先备份，再运行后端更新脚本 |
| Flutter 页面、标签统计、客户端逻辑改动 | 递增构建号，重新打 APK 并安装 |
| API_BASE_URL 改动 | 修改 app/.env，重新打 APK 并安装 |
| 双端或接口不兼容改动 | 按兼容性安排更新顺序；本轮先更新后端，再更新 APK |
| 服务器 .env 配置改动 | 重启后端使配置生效；不把密钥打进 APK |

常见故障：
- 手机显示网络错误：先用手机浏览器检查实际 API 地址的 /health，再看地址、证书、端口和安全组；不是浏览器客户端时无需用 CORS 解决手机网络不通。
- 新 APK 安装冲突：核对包名、签名和构建号；debug 切正式签名不能覆盖安装，不要为解决冲突盲目删除账号或服务器数据。
- 更新成功但没有尺寸/统计入口：确认手机实际安装的是此次新构建的 APK，而不是 build/installers 下以前的历史副本。
- 服务器更新后退出：检查服务日志、数据库连接和迁移权限；脚本失败时不保证旧服务已自动恢复运行。

本次教程核对了源码、更新脚本、配置模板和当前本机生成的 Android 工程，并查阅官方发布/签名文档；未实际连接服务器、备份数据库、签发证书、创建发布密钥、修改私密配置或构建/安装新包。
