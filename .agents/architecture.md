# 当前架构与目录

依据 server/internal/bootstrap/app.go、app/lib/features/、依赖清单及用户确认，更新于 2026-10-04。

## 目录职责
- server/cmd/：API 与邮件、OSS 诊断命令入口。
- server/internal/config/：环境加载与配置映射；bootstrap/ 负责数据库、路由和服务装配。
- server/internal/modules/：auth、profile、item、outfit、wearlog、ai、recommendation、imageprocess、oss 按业务领域隔离。
- server/internal/infrastructure/：PostgreSQL/测试 SQLite、邮件和 Qwen 适配；models/ 为 GORM 数据模型，httpapi/ 为响应契约。
- app/lib/core/：网络、登录会话、公开配置和基础主题；features/ 按认证、衣橱、搭配、推荐、记录和个人资料组织。
- app/lib/features/wardrobe/models/：衣物展示模型；presentation/ 的列表、上传处理、识别确认、详情和批量处理分别独立。
- app/lib/features/outfits/：我的搭配列表/分类筛选、独立新增/编辑组合页面与所有单品图片展示。今日 AI 搭配为唯一推荐入口，原双页签在 2026-10-05 被替代。
- .agents/：现行工程规则；docs/：产品资料、源码部署、人类交付和明确标注的历史方案；UI设计图/：原始视觉资料。

## 核心边界
Flutter 通过 API 操作当前用户数据；后端负责鉴权、数据库、AI、OSS 凭据与签名。图片原图与抠图存私有 OSS，数据库存 oss:// 稳定地址；前端按需获取短期签名读取 URL。
注册用户与会话、密码更新与撤销全部会话使用事务。验证码仅在单进程内存，服务重启后无效。
识别由异步任务处理，单后端最多两项任务；前端批量最多 9 张、同时两张，每张一件单品。单张多件拆分仍是产品目标与当前实现的差距。
运行数据库为 PostgreSQL；SQLite 只用于测试。源码部署，不恢复 Docker。

## 已知边界与技术债
- 内存验证码、内存任务槽位不适合多实例；当前不宣称支持分布式部署。
- 部分早期路由仍未检查每个 GORM 写入错误，ApiClient 的 UI 错误呈现与领域层可继续分离；本次结构整理不扩展业务行为。
- 历史技术文档保留 SQLite 方案等设计，不是当前架构。其独有设计信息不删除，也不当作已实现事实。

个人资料新增独立身体数据编辑页面及 /me/body-measurements 接口，复用 User 与 ProfileRepository；围度暂不参与 AI 推荐。

## 2026-10-05 今日 AI 搭配
导航不再包含 AI/今日双页签；我的搭配 AI 按钮也进入 TodayRecommendationPage。移除 ai_stylist 前端领域与通用 AI 生成流，只保留今日生成与共享保存。weather 领域负责 Open-Meteo HTTP 查询和天气契约，recommendation 装配天气与 AI。Flutter 使用 Geolocator 前台获取设备坐标；后台不获取定位，不以资料城市代替。

## 2026-10-05 衣橱显示设置
wardrobe 领域新增 WardrobeDisplayPreferences 模型、WardrobeDisplayRepository 与独立设置页，复用 ApiClient；个人中心和衣橱均进入该设置页。服务端 profile 持久化账号偏好，衣橱加载时读取本人设置和衣物，类型/季节筛选及分类按钮统一应用偏好。仅控制列表显示，组合编辑、已保存搭配、AI 不受影响。
