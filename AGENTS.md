# AGENTS.md — 上岗手册

> 给任何接手本系统的人/agent：10 分钟跑起来 + 规矩 + 坑 + 谁懂什么。
> 业务代码仓：`../data-exchange`（后端）、`../udp-portal`（前端）；本仓只有知识。

## 一、10 分钟跑起来

前置：Windows + 公司内网/VPN + JDK 8 + Maven + Node + pnpm/npm。

```powershell
# 1. 三个仓放同一父目录（如 D:\自助编程\实时配置自动化\）
#    data-exchange  +  udp-portal  +  dataexchange_portal_agent（本仓）

# 2. 恢复本地联调环境（mock 登录 + local profile，勿提交）
cd D:\自助编程\实时配置自动化\核心文档\本地联调
.\restore-local-dev.ps1 -Target both
#    然后填本机密钥：data-exchange/src/main/resources/application-local-testdb.properties

# 3. 启动（两个终端）
D:\自助编程\实时配置自动化\scripts\start-backend-testdb.ps1    # 后端 :8088
D:\自助编程\实时配置自动化\scripts\start-frontend-local-testdb.ps1  # 前端 :8080

# 4. 验证
curl "http://localhost:8088/data-exchange/portal/queue-status/snapshot?mode=now"
#    返回 {"status":...,"statusText":...,"data":{"queuedCount":...}} 即通
#    浏览器开 http://localhost:8080（mock 登录，默认 projectId=64）
```

启动失败/连不上库 → 读 `docs/DEV-ENVIRONMENT.md`「常见坑」。

## 二、规矩（违反=返工）

1. **接手任务先读**：本文件 → `specs/INDEX.md`（找相关迭代卡）→ 涉及接口必读 `docs/API-CONTRACT.md`
2. **无 spec 不开发**（agent 开发的迭代）：`specs/NNN-功能名/` 备好 需求/方案/测试 三层材料（合格标准见 `.cursor/rules/spec-flow.mdc`），经用户批准后写代码；实现完成 = 测试层的验收命令全部通过
3. **改接口同步契约**：业务仓提交 + 本仓 `docs/API-CONTRACT.md` 同迭代更新
4. **提交纪律**：作者李栋 `<lidong01@picc.com.cn>`；push 前必读 `.cursor/skills/picc-gitee-commit/SKILL.md`；Local*/mock/密钥/本地 properties 一律不推
5. **知识纪律**：宁可留白不可污染——推断带置信度，业务背景不知道就标「待补」，不编造

## 三、常见坑

| 坑 | 解法 |
|----|------|
| Windows 中文路径 | 工作区固定在 `D:\自助编程\实时配置自动化`，脚本已适配；新脚本先小范围验证 |
| 双仓分支要成对 | 功能分支两仓同名（如 `feature/queue-task-operations-sla1`），切换/合并成对操作 |
| 本地联调文件误提交 | push 前执行联调文档 §4 清理脚本（`核心文档/本地联调/README...`） |
| MySQL 副库连不上 | 需内网/VPN（`10.57.4.6:6033`），不通则任务列表为空 |
| 前端端口口径 | 实际 **8080**（vite.config.ts），旧材料写 8081 的以代码为准 |

## 四、谁懂什么（占位 · 待口述补充）

| 领域 | 懂的人 | 备注 |
|------|--------|------|
| 后端整体 / 审批流 | 待补 | DataLakeApproval 原始作者 fengsheng.su |
| 前端整体 | 待补 | — |
| 调度侧 / schedule_queue | 待补 | — |
| 运维实施 / 测试库申请 | 李冬（李栋） | 共享中心接口 |
| 入湖业务背景 | 待补 | 共享中心 |

> 维护：人员/分工变化时更新本表；口述后由 agent 整理回填。

## 五、仓内地图

| 你要找 | 去哪 |
|--------|------|
| 接口长什么样 | `docs/API-CONTRACT.md` |
| 系统全貌/画图汇报 | `docs/ARCHITECTURE.md` |
| 为什么这么设计 | `docs/DECISIONS.md` |
| 环境怎么搭 | `docs/DEV-ENVIRONMENT.md` |
| 规范执行版 | `.cursor/rules/*.mdc` + `docs/STANDARDS.md` |
| 某次迭代改了什么 | `specs/INDEX.md` → `specs/retro/` |
| 新功能开发流程 | `specs/NNN-功能名/` 三层 + `.cursor/rules/spec-flow.mdc` |
