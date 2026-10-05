# 编码与配置约定

## 组织与复用
源代码文件不超过 500 物理行；按模型、领域、页面及适配职责拆分，不靠 part 文件、巨型单行或删测试绕过。文档、锁文件和外部生成产物不套用代码行数限制，AGENTS.md 单独遵守 50 行上限。
Go 保持现有 cmd/internal/modules/infrastructure 分层，使用 gofmt；Dart 按 features/<领域>/data/models/presentation 分层，使用 dart format 和 flutter analyze。不新增万能 utils/common，不为本次整理升级包或改技术栈。
复用 ApiClient、AuthSession、WardrobeRepository、OutfitCatalog 和 httpapi 响应，不从展示页面导入领域模型。文件拆分同步更新生产及测试导入，不保留失效重导出。
普通业务配置集中 config/AppConfig；固定协议端点及测试夹具是明确例外，新增可变部署地址不可散落页面。

## 配置职责
- app/.env：仅 API_BASE_URL，作为客户端资源发布，不能包含任何密钥；模板 app/.env.example。
- server/.env：后端私密配置，模板 server/.env.example，已导出环境变量优先；从 server/ 或项目根启动加载同一文件。
- 数据库：DATABASE_URL 优先；否则 POSTGRES_HOST/PORT/USER/PASSWORD/DB/SSLMODE，兼容 PG* 回退，新增更改要更新配置测试与部署说明。
- OSS：ALIYUN_ACCESS_KEY_ID/SECRET；视觉分割：ALIYUN_VIAPI_ACCESS_KEY_ID/SECRET，两者独立，不互相回退。
- Qwen：DASHSCOPE_API_KEY 与 QWEN_*；邮件：SMTP_*、FROM_EMAIL；其他后端字段以 config.go 和示例为准。
- API 来源由 CORS_ORIGIN 配置，浏览器直读 OSS 还需 Bucket 对应 GET/HEAD 跨域规则；配置命令 --apply 是真实外部变更，应按任务授权执行。
不要在文档、日志、CLI 或 Git 里打印环境值、签名地址或密码哈希。

## 错误与测试
所有查询、更新和网络错误应检查并返回可行动提示；日志仅保留安全错误码、类型与请求 ID。涉及多表写入使用事务并验证影响行数，不吞异常或假装成功。
现有 MockProvider 仅显式测试/开发使用，生产禁止；不得用模拟图片或 AI 结果替代真实失败。
行为变化必须覆盖成功、失败和必要隔离测试；纯拆分沿用回归测试证明行为未变。
[代码风格原始参考](../docs/优秀代码风格.md)保留一般原则与历史示例；具体项目规则以本文件为现行位置。

天气配置新增 server/.env 的 WEATHER_BASE_URL，默认 Open-Meteo forecast 固定协议端点；示例同步，客户端无天气凭据。新增 geolocator 14.1.1 及平台依赖，保留既有依赖版本。生成平台后执行 tools/configure_location.py 配置原生定位权限；不提交本地生成的平台工程。
