# AI衣橱

当前仓库已正式进入源码开发阶段，采用前后端分离结构：

- `server/`：Go + Gin 后端 API
- `app/`：Flutter 客户端

## 当前实现范围

MVP 业务闭环已实现：

- 登录、退出、个人资料、风格偏好、隐私授权和账号注销
- 衣橱录入、搜索、分类筛选、状态维护、归档与软删除
- 图片识别任务创建和结果查询（本地开发使用结构化模拟结果）
- 手动/AI 搭配保存、列表、详情、评分、反馈和局部换单品
- 今日推荐、最近可穿单品过滤、AI 任务状态记录
- “今天穿了这套”、穿搭记录维护及按日期/月查询
- Flutter 衣橱、AI 造型师、今日推荐、搭配记录和个人中心交互
- Go 核心业务流程测试与 Flutter 组件测试

## 后端运行

1. 进入 `server/`
2. 准备环境变量：参考 `.env.example`
3. 安装依赖：`go mod tidy`
4. 启动服务：`go run ./cmd/api`

默认地址：`http://localhost:3000`

本地数据库默认路径：`server/data/ai_closet.db`

## 前端运行

1. 进入 `app/`
2. 执行 `flutter pub get`
3. 运行：`flutter run`

当前前端默认请求：`http://localhost:3000`

## 外部服务接入说明

### 阿里云 OSS

当前接口：

- `POST /uploads/oss-signature`

已预留阿里云 OSS 直传签名协议位置，但还没有接入真实 OSS SDK 与签名算法。

### 第三方 AI

采用 provider 设计：

- `MockProvider`
- `HTTPProvider`

本地默认使用 `MockProvider`，配置 `AI_PROVIDER`、`AI_API_BASE_URL` 和
`AI_API_KEY` 后切换至 `HTTPProvider`。供应商接口需要符合项目内部的
`OutfitCandidate` 数据合同。

未配置真实 AI 或 OSS 密钥时，应用仍可通过本地模拟能力完整演示业务流程；
生产发布前需配置实际供应商凭证和图片域名。
