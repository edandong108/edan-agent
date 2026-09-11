# 规范导读（STANDARDS）

> 冷启动：2026-09-11 · 对齐日期以本文件为准。

## 权威来源与执行层分工

| 层 | 位置 | 说明 |
|----|------|------|
| 权威来源 | `相关规范/前端规范.doc`、`相关规范/后端规范.doc`（工作区外层，Word 原文） | 团队评审发布的正式规范，变更走团队评审 |
| 执行层 | 本仓 `.cursor/rules/*.mdc`（clone 即生效） | 从 doc 提炼的 agent 可执行版；**doc 变 → mdc 同步 → 更新本文件对齐日期** |

**不复制 Word 原文进仓**：避免双份漂移。mdc 与 doc 冲突时以 doc 为准，并修正 mdc。

## 三个 mdc 的分工

| 文件 | 适用 | 内容 |
|------|------|------|
| `dev-standards-overview.mdc` | 全局 | 项目结构总览、前后端仓边界、本文件指向 |
| `frontend-standards.mdc` | udp-portal | Vue3 + TS + Vite 规范（目录/hooks/组件/命名） |
| `backend-standards.mdc` | data-exchange | Java 8 + Spring Boot 2.7 + MyBatis 规范（分层/异常/日志） |

## mdc 与 doc 的已知差异点（以项目现有代码为准）

| 差异项 | doc 表述 | 项目实际（以此为准） |
|--------|---------|---------------------|
| 前端 UI 库 | Element Plus | **Ant Design Vue**（TS/Vue3/目录/hooks 等规范同样适用） |
| 后端控制器包 | `controller/` | **`api/`** |
| 统一返回体 | `code` / `msg` | **`status` / `statusText`**（ApiResponse） |
| 异常体系 | 通用异常 | `CommonException` + `CommonExceptionCode` |

## 规范更新流程

1. 团队评审更新 doc（权威来源）
2. 同步修订本仓 mdc（执行层），在本文件「对齐记录」追加一行
3. 工作区 `.cursor/rules/` 同名副本同步（同源双份）

## 对齐记录

| 日期 | doc 版本/变动 | mdc 动作 | 操作人 |
|------|--------------|---------|--------|
| 2026-09-11 | 现行版 | 冷启动复制入仓 | 李栋 |
