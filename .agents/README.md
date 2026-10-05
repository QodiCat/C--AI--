# 工程入口与维护规则

这里承载当前工程事实；产品目标见 [产品入口](../docs/README.md)。详细源码部署文档继续作为人类交付资料保留在 [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md)，不复制第二份部署正文。

## 阅读路由
| 专题 | 阅读时机 |
| --- | --- |
| [architecture.md](architecture.md) | 修改模块、目录、调用链与边界 |
| [coding.md](coding.md) | 修改 Go/Dart 代码、配置与错误处理 |
| [testing.md](testing.md) | 编写验证、排查测试或提交前检查 |
| [api.md](api.md) | 修改请求、响应、认证或外部服务对接 |
| [database.md](database.md) | 修改模型、事务、迁移、兼容行为 |
| [security.md](security.md) | 处理权限、登录、凭据或图片地址 |
| [源码部署](../docs/DEPLOYMENT.md) | 运行、构建、服务器部署、备份 |
| [TODO.md](../TODO.md) | 每次任务开始读取，维护新增功能、进行中及已完成状态 |
| [需求变更](../docs/需求变更.md) | 业务变化、功能验收、未决事项 |

## 实际命令与前提
| 目录 | 用途 | 命令 | 状态 |
| --- | --- | --- | --- |
| server/ | 依赖 | `go mod download` | 配置存在；本次不更新依赖 |
| server/ | 开发 | `go run ./cmd/api` | 命令存在；需 PostgreSQL 与 server/.env，本次不启动 |
| server/ | 测试/检查 | `go test ./...`、`go vet ./...` | 本次结果见 testing.md |
| server/ | 构建 | `go build -o bin/api ./cmd/api` | 本次未构建生产二进制 |
| app/ | 依赖 | `flutter pub get` | pubspec 已存在，本次不更新依赖 |
| app/ | 开发 | `flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080` | 命令存在；需 app/.env，本次不启动 |
| app/ | 验证 | `flutter analyze --no-pub`、`flutter test --no-pub` | 本次结果见 testing.md |
| app/ | 构建 | `flutter build web --release`、`flutter build apk --release --no-pub` | Android release APK 已构建，服务器 IP/3000 安装测试包，详见 testing.md |

WSL 使用 Linux Flutter，不能调用 `/mnt/d/flutter` 的 Windows 脚本。当前环境 Linux SDK 位于 `$HOME/snap/flutter/common/flutter/bin`；Go Snap 包装器受限时可使用 `/snap/go/current/bin/go`。这些路径是当前环境事实，不是所有开发者的固定要求。
本机 WebSocket 被代理干扰时，仅对此次命令去掉大小写的 HTTP_PROXY、HTTPS_PROXY、ALL_PROXY，并设置 NO_PROXY/no_proxy 为 localhost,127.0.0.1,::1。不要输出代理 URL 中的凭据或自动改系统代理。
结构规范在仓库根运行 `python3 tools/check_structure.py`，检查入口、源码行数与现行文档链接。
默认 PostgreSQL 不随应用创建；用户、数据库和服务要事先准备。没有项目 CI 配置，不能声称 CI 已通过。

## 文档自维护（每次任务的完成条件）
开始任务读取根入口，按索引加载相关文档及目录规则，以当前代码、配置、验证结果和用户确认核对有效性。工作中发生需求、架构、目录、模块职责、接口、数据、配置、命令、测试或部署变化时，在同一任务主动更新受影响文档，不等待额外提醒。文档新增、迁移、删除或入口变化时修复根入口及中间索引；仅正文变化且索引准确时不制造入口改动。结束前核对文档、目标、实现和链接一致，并报告更新位置；无影响时说明已核对、无需更新。

| 触发变化 | 同步动作 |
| --- | --- |
| 用户确认需求新增、修改或取消 | 更新 docs/需求变更.md 的范围、验收及来源，重查 PRD、设计与 TODO.md；不将实施等同于客户验收 |
| 需求意见未确认或材料冲突 | 在 docs/需求变更.md 记录来源、待决项、影响及解除条件，保留已确认口径，继续不受影响工作 |
| 架构、技术栈、职责、目录变化 | 更新 architecture.md；阅读路径或全局规则变化时同步 AGENTS.md 和局部规则 |
| 接口、数据、迁移、配置或外部依赖变化 | 更新 api.md、database.md、coding.md 及验证前提；业务结果变化时同时核对需求 |
| 安装、开发、测试、构建或发布变化 | 更新本表、testing.md 与 docs/DEPLOYMENT.md，保留失败和未验证项 |
| 实现、验证或阻断状态变化 | 更新 TODO.md 及需求记录并附证据；实现、自测、部署、客户验收分开记录 |
| 文档新增、重命名、迁移、合并或删除 | 修复 AGENTS.md、中间索引及所有现行链接，移除重复权威入口 |

已确认变更直接同步；只确认尚未决定的业务取舍。代码说明现在如何，需求说明应当如何，不能改验收标准迁就缺陷。变更使证据失效时标为待复验，不沿用旧通过结论。每次修改 AGENTS.md 实际计数，超过 50 行先下沉专题。保留重要决定日期、来源、原因及替代关系；历史资料明确身份。所有文档、命令和提交不得包含真实密钥、令牌或客户敏感信息。

新增需求统一记录在 TODO.md，待做.md 仅为历史资料。每次开始任务读取 TODO.md；按用户当次任务范围挑选条目，实施后更新状态、日期、提交和验证依据，不自动执行未授权的全部列表。
