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
