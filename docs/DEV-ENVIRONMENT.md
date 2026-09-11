# 环境真相（DEV-ENVIRONMENT）

> 冷启动：2026-09-11。本文件只写「跑起来必须知道的事实」，详细联调手册见 `核心文档/本地联调/README-本地开发说明（勿提交仓库）.md`（本地留存，不入仓）。

## 端口与启动

| 项 | 值 | 出处 |
|----|-----|------|
| 后端端口 | **8088**（profile=`local-testdb`） | `scripts/start-backend-testdb.ps1` |
| 前端端口 | **8080** | `udp-portal/vite.config.ts`（注意：方案讨论稿曾写 8081，以代码为准） |
| 前端代理 | `/data-exchange` → `http://localhost:8088` | `.env.development.local` |
| 浏览器入口 | `http://localhost:8080` | — |

```powershell
# 终端 1：后端
D:\自助编程\实时配置自动化\scripts\start-backend-testdb.ps1
# 终端 2：前端（mock 登录）
D:\自助编程\实时配置自动化\scripts\start-frontend-local-testdb.ps1
```

## 两种联调模式

| 对比项 | 模式 A：公司测试环境 | 模式 B：本机 + 测试库 |
|--------|---------------------|----------------------|
| 登录 | IAM / 4A | mock（`VITE_USE_LOCAL_MOCK=true`，`mock/portal-local.ts`） |
| 菜单 | data-permission 下发 | mock 目录下发 |
| 后端 | 测试环境已部署实例 | 本机 8088（local-testdb profile） |
| 适用 | 验收、提测、评审 | 功能开发、接口调试 |
| 是否进 MR | 是（干净分支） | **否** |

模式 B 一键恢复：`核心文档/本地联调/restore-local-dev.ps1 -Target both`；push 前按联调文档 §4 恢复干净工作区。

## 数据层本地替代

| 库 | 本地联调做法 | 注意 |
|----|-------------|------|
| Gauss 主库 | 连公司测试 Gauss（账号密码填 `application-local-testdb.properties`，勿提交） | 台账表需先执行 `核心文档/sql/gauss-test-v22-source_topic_ledger.sql` |
| MySQL 副库 | 连公司测试 MySQL `10.57.4.6:6033` | **需内网/VPN**，否则任务列表为空 |

模板：`核心文档/本地联调/templates/.../application-local-testdb.properties.example`。

## Nacos / 中间件

- 生产数据源、业务开关、cron 全在 Nacos；代码仓只放默认值
- 本地启动用 `local-nacos-config.properties` 覆盖（恢复脚本生成，勿提交）
- udp-flowable Feign 调用需 `udp_flowable.app.access.token`（Nacos key，见 AppConfig.java）

## 常见坑（Windows）

| 坑 | 表现 | 解法 |
|----|------|------|
| 中文路径 | 个别构建脚本/依赖解析失败 | 保持工作区路径 `D:\自助编程\实时配置自动化` 不动，脚本已适配；新增脚本先在小路径验证 |
| 双仓分支成对 | 前端合了后端没合 → 页面 404/报错 | 功能分支同名成对切换（如 `feature/queue-task-operations-sla1` 两仓同名） |
| 本地联调文件误提交 | MR 混入 Local*/mock/skip-permission | push 前执行联调文档 §4 清理；遵守 `.cursor/skills/picc-gitee-commit` |
| 默认项目 | 登录后看不到数据 | mock 默认 `projectId=64`（测试库任务较多） |

## 测试库申请入口

测试环境 Gauss/MySQL 账号、IAM 菜单配置、建表执行，按 `核心文档/公司环境联调清单-实时流参数功能.html` 流程走（共享中心/平台组接口人）。
