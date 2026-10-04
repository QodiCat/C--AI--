# AI 衣橱 Agent 入口

## 项目
个人衣橱、图片识别与搭配管理。Go 1.23 + Gin / GORM，Flutter / Dart；依赖分别由 Go Modules 和 Flutter Pub 管理。

## 开始任务前
1. 阅读本文件与 [.agents/README.md](.agents/README.md)，按任务加载相关专题及局部规则。
2. 检查 Git 状态，保留用户改动，不修改无关代码或另一仓库。

## 常用命令
- 后端（server/）：`go mod download`、`go run ./cmd/api`、`go test ./...`、`go vet ./...`、`go build -o bin/api ./cmd/api`。
- 前端（app/）：`flutter pub get`、`flutter run -d web-server --web-port=8080`、`flutter analyze`、`flutter test`、`flutter build web --release`。
- 具体目录、依赖前提、WSL 与代理处理、验证状态见工程索引。

## 全局约束
- 修改最小化；源代码单文件不超过 500 行，超限按职责拆分；本入口不超过 50 行。
- 按业务领域组织目录；模块单一职责，先复用已有能力，不建立 utils/common 万能目录。
- 前后端配置分别为 app/.env 和 server/.env，示例同步维护；不硬编码部署 URL、端口或密钥，不提交真实凭据。
- 不以长期 Mock、静默降级、吞异常或默认成功掩盖失败；历史问题按专题登记并逐步处理。
- 行为修改同步有效测试；不删测试或绕过 CI 来消除失败，不顺带升级依赖。
- 产品目标与实现事实分别维护；冲突记录来源与差距，不擅自修改业务口径。
- 仅源码部署，不新增 Docker；真实服务启动遵循用户本次授权，不能把自测当作部署。

## 按任务阅读
| 任务 | 现行文档 |
| --- | --- |
| 所有任务：维护路由与命令 | [.agents/README.md](.agents/README.md) |
| 目录、模块、结构 | [.agents/architecture.md](.agents/architecture.md) |
| 编码与配置 | [.agents/coding.md](.agents/coding.md) |
| 验证 | [.agents/testing.md](.agents/testing.md) |
| 接口、数据 | [.agents/api.md](.agents/api.md)、[.agents/database.md](.agents/database.md) |
| 权限、敏感信息 | [.agents/security.md](.agents/security.md) |
| 运行、部署 | [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) |
| 需求、验收、未决事项 | [docs/README.md](docs/README.md) |

## 文档自维护
- 每次任务按当前代码、配置、验证和用户确认核对文档；需求、结构、接口、命令变化当次更新。
- 入口或文档位置变化同步修复索引；仅专题正文变化无需制造入口改动。
- 完成前核对文档、目标、链接与本入口物理行数；详细路由见工程索引。

## Git 与完成标准
- 独立任务经适用验证后创建本地 commit，仅提交本任务文件，沿用仓库提交风格。
- 不 push、强推、reset --hard 或改写历史，不绕过钩子，不覆盖或丢弃未知改动；用户明确授权时以其范围为准。
- 报告变更、实际验证与未验证原因、风险、文档更新位置和入口行数。
