# 测试与验证

后端在 server/ 执行 go test ./... 和 go vet ./...；SQLite 临时数据库用于自动化业务验证，不调用收费云服务。PostgreSQL 集成测试需要显式 TEST_POSTGRES_DSN，使用可创建临时 schema 的测试库，不使用真实客户数据或默认开发连接代替。
前端在 app/ 执行 flutter analyze --no-pub 和 flutter test --no-pub；前提是依赖已安装。新环境先执行 flutter pub get。测试中的模拟 HTTP 与图片不代表真实云端验收。
格式：Go 使用 gofmt；Dart 使用 dart format。结构检查统计维护的 .go/.dart 文件不超过 500 行，所有 AGENTS.md 不超过 50 行，检查现行文档相对链接及 git diff --check。

## 2026-10-04 本次整理验证
- Go 全套 `go test ./...` 通过；`go vet ./...` 通过。首次沙箱测试因 httptest 监听本机端口被禁止而失败，允许本机测试端口后复验通过。
- Flutter `flutter analyze --no-pub` 无问题，`flutter test --no-pub` 12 项通过。
- 根目录 `python3 tools/check_structure.py` 通过：入口 44 行、维护源码均≤500行、现行文档链接有效；`git diff --check` 通过。
- 不启动前后端、不修改远端数据库/OSS、不发送邮件、不调用收费 AI。
- 本次不执行生产构建或部署；不宣称移动端真机或客户验收通过。
- CI 尚未建立；历史测试结果不能替代改动后的复验。

## 2026-10-04 搭配管理验证
- 后端全套 go test ./...、go vet ./... 通过；新增测试覆盖编辑分类、重复/跨用户衣物、跨用户改删、删除失败与历史保留。
- 前端 flutter analyze --no-pub 无问题，flutter test --no-pub 14 项通过；覆盖分类筛选、确认/取消删除、编辑回填与衣物替换。
- 结构检查与 git diff --check 通过，AGENTS.md 仍为 44 行。未运行真实数据库迁移、启动服务、生产构建或客户验收。

## 2026-10-05 身体数据验证
- Go 全套 go test ./...、go vet ./... 通过；新增本人保存/清空、非法/null 输入、用户隔离和基础资料不丢失身高体重测试。
- Flutter analyze --no-pub 无问题；flutter test --no-pub 15 项通过，新增回填、输入校验、清空请求、保存失败保留输入测试。
- 初次工具因缓存只读失败，经审批使用 SDK 缓存复验；页面测试调整焦点与滚动等待后通过。结构检查和 diff --check 通过，根 AGENTS.md 实测 45 行。
- 未启动真实服务、迁移 PostgreSQL、构建生产包、调用收费 AI 或进行真机/客户验收。

## 2026-10-05 今日 AI 搭配验证
- Go 全套 go test ./...、go vet ./... 通过；覆盖坐标校验、零坐标、鉴权/用户衣物隔离、手填天气不能覆盖服务端结果、天气失败阻断 AI、旧生成路由 404、天气代码/缺失/null/非法/过期数据、HTTP 错误、取消及配置覆盖。核心端到端流改为自动天气今日生成，保留保存与穿搭记录回归。
- Flutter analyze --no-pub 无问题；flutter test --no-pub 18 项通过，覆盖只保留场景输入、获取设备坐标、天气展示、失败重试、当地日期/天气一致的记录；flutter build web --release --no-pub 通过。
- 使用公开示例坐标验证 Open-Meteo 真实接口连通与字段格式；无用户定位数据或收费 AI 调用。Android 前台粗略定位清单已由 tools/configure_location.py 配置；iOS 工程未生成。
- 结构与 git diff --check 通过，AGENTS.md 实测 45 行。未启动真实服务、部署、迁移数据库、构建 Android/iOS 或验证真机 GPS/浏览器权限/客户验收。

## 2026-10-05 衣橱显示设置验证
- Go 全套 go test ./...、go vet ./... 通过；新增默认显示全部、旧用户迁移保留数据、多选保存/读取、非法/重复/null 选项、鉴权与用户隔离、写入失败回滚、恢复全部验证。
- Flutter analyze --no-pub 无问题，flutter test --no-pub 22 项通过；新增类型与多季节组合匹配、四季/历史标签、设置保存与实际列表/分类入口过滤、重进持久化、失败保留选择、恢复全部、加载失败重试验证。
- 初次分析发现新增代码括号风格问题，修正后复验通过。结构检查与 git diff --check 通过，AGENTS.md 实测 45 行，维护源码均不超过 500 行。
- 未启动真实服务、执行真实 PostgreSQL 迁移、生产构建、部署或真机/客户验收。

## 2026-10-05 Android 安装包构建验证
- Flutter doctor 确认 Android SDK 36、Java 17 和许可证就绪，flutter build apk --release --no-pub 成功，原产物 53,609,447 字节；交付副本 app/build/installers/ai-closet-0.1.0-usb-test.apk。
- apksigner verify --verbose 通过（v2，单签名）；aapt 核验包名 com.example.ai_closet_app、0.1.0/1、minSdk 24、targetSdk 36、三种 ABI、INTERNET/ACCESS_COARSE_LOCATION 权限。使用本地已有测试签名。
- 解包确认只包含公开 API_BASE_URL=http://localhost:3000；适用于 adb reverse 的 USB 本机测试。独立联网地址待用户提供，未声称手机业务可独立连通。
- 无源码行为更改，沿用上一任务已通过的 Go test/vet、Flutter analyze 与 22 项测试；本次新增 APK 编译/签名/包内容检查。未启动真实后端、部署、安装到手机或执行真机验收。结构检查与 diff --check 通过，AGENTS.md 45 行。

## 2026-10-05 指定服务器 APK 复验
- 用户提供 115.25.46.153，沿用后端现有 3000 端口更新公开客户端配置；flutter build apk --release --no-pub 成功，交付 app/build/installers/ai-closet-0.1.0-server.apk（53,609,451 字节）。
- apksigner verify --verbose 通过（v2）；解包断言只包含 API_BASE_URL=http://115.25.46.153:3000。无源码行为变更，无依赖升级；已有 USB 测试副本保留。
- 只读健康探测失败：直接 :3000/health 连接错误，/api/health 返回 404。未声称线上服务可用；未登录服务器、部署、启动后端、修改数据库或真机安装。
- 结构检查和 diff --check 通过，AGENTS.md 实测 45 行。
