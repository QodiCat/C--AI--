# 数据、事务与迁移

运行库 PostgreSQL，GORM 模型见 server/internal/models/models.go。users 保存邮箱、昵称、密码哈希及资料；sessions 保存登录会话；items 保存衣物字段与稳定 OSS 地址；outfits 保存组合、来源及评价；wear_logs 保存实际穿搭；ai_tasks 保存请求、状态、结果及错误。
服务启动 AutoMigrate 建表/调整结构，不创建 PostgreSQL 用户和数据库，不自动迁移旧 SQLite 数据。重大字段迁移先记录兼容/回滚方案，禁止把 AutoMigrate 等同于无风险生产迁移。

## 当前兼容行为
- Outfit.itemIds 是 JSON 字符串，AI candidate.itemIds 是数组；当前展示助手兼容二者，不静默改变现行 API。
- 注册用户与创建会话使用同一事务；密码更新与删除所有旧会话同一事务。
- 历史 NULL 密码哈希账号通过邮箱验证码重置，更新条件使用 COALESCE 比较与影响行数检查；不能自动赋默认密码或绕过邮箱验证。
- 默认不注入演示数据；生产环境禁止 SEED_DEMO_DATA 和 mock AI。
- 修改、查询业务数据均必须限制当前 user_id，公共认证流程按邮箱归一化进行。

真实数据库验证需按任务授权；数据清理与破坏性迁移不得作为排错捷径。备份命令及源码部署前提参见 [部署说明](../docs/DEPLOYMENT.md)。
