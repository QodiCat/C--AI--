# AI衣橱

当前仓库已正式进入源码开发阶段，采用前后端分离结构：

- `server/`：Go + Gin 后端 API
- `app/`：Flutter 客户端

## 当前实现范围

已完成首轮工程骨架：

- 后端基础 API、模块化路由、本地 SQLite 数据库
- 衣橱列表接口
- AI 搭配与今日推荐接口
- 阿里云 OSS 上传签名接口占位
- Flutter 主壳、衣橱页、AI 搭配页、今日推荐页、个人中心页

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

当前采用 provider 设计：

- `MockProvider`
- `HTTPProvider`

`HTTPProvider` 中已明确预留真实外部 API 调用位置，后续只需要：

1. 补充请求地址、鉴权头和 schema
2. 解析供应商返回结构
3. 映射到项目内部的 `OutfitCandidate`

## 下一步建议

- 接入更完整的数据库迁移与仓储层
- 接入真实阿里云 OSS SDK
- 接入真实 AI 服务
- 完成衣物上传、识别任务、搭配保存、穿搭记录完整流程
