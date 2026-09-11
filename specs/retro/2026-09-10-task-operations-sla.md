# 迭代卡 #001 · 任务运维：队列状态 + 队列分析（SLA 第一阶段）

- 日期：2026-09-10 / 提交人：李栋 / 分支：`feature/queue-task-operations-sla1` → 前端 `develop-new`、后端 `dev_20260901_approval`
- 涉及仓库：双端（后端 `00cd149` / 前端 `4f11ac5`，同分支名成对）
- 材料全集：[specs/001-任务运维SLA/](../001-任务运维SLA/)（需求整理 + 评审一页纸/技术方案/原型 + 测试用例/报告/自动化脚本）
- 生成方式：retro（diff 冷启动）· 质量级别：★★（C/B 满，A 部分已由回填材料解答）

## 改了什么 [C·自动]

**接口变更**（新增 2 端点，已登记 API-CONTRACT.md C1）：

- GET `/data-exchange/portal/queue-status/snapshot?mode&t`：队列状态快照，返回 `QueueStatusSnapshotDto { snapshotTime, now, queuedCount, runningCount, zombieCount, queued[], running[], zombie[] }`，明细含 `slaPriority`（0 普通/1 高优）、`submitTime`、`heartBeatenAt`
- `/data-exchange/portal/queue-analysis/analyze`：队列分析，返回 KPI/小时分布/切片/TopN 等（`QueueKpiDto`、`QueueHourlyDto`、`QueueSliceDto`、`QueueTopNDto`、`QueueAnalysisInstanceDto`）

**表变更**：无（只读查询；数据源为副库既有 `schedule_queue` + `job_instance` + `job`）

**后端实现**（18 文件，+1165/-1）：

- `api/QueueStatusController.java`、`api/QueueAnalysisController.java`（各 37 行，薄控制器）
- `dao/secondary/mapper/QueueStatusMapper.java`（109 行，注解 SQL，区间覆盖判定：排队中 = `schedule_queue` 区间 `[submit_time, finished_at)` 覆盖时刻 T）
- `dao/secondary/mapper/QueueAnalysisMapper.java`（65 行，按天加载含 lookback 缓冲）
- `service/impl/QueueStatusServiceImpl.java`（131 行）、`service/impl/QueueAnalysisServiceImpl.java`（419 行，Java 侧按天加载 + 288 片聚合）
- DTO × 9 + `application.properties` 新增 3 个配置项：`etl.schedule.max_wait_seconds=3600`、`etl.schedule.queue_status_exec_lookback=86400`、`etl.schedule.heartbeat_interval_seconds=30`（与 ETL 执行端 entry.py 侧 Nacos key 同名，本地默认值，生产从 Nacos 读取）

**前端变更**（8 文件，+844）：

- `api/queueStatus.ts`（30 行）、`api/queueAnalysis.ts`（75 行），均走 server2
- `views/dataExchange/queueStatus/`：index.vue（246）+ components/StatCard.vue（56）
- `views/dataExchange/queueAnalysis/`：index.vue（241）+ components/KpiCard.vue（43）+ SliceChart.vue（106）
- `views/dataExchange/taskOperations/index.vue`（47 行）：双 Tab 壳页，承载上述两页（对应 DECISIONS.md#D3）

**影响范围**：纯新增，不改动既有接口与页面；菜单需 IAM 侧配置（路由名映射 `taskOperations`）。

## 为什么 [B·推断]

- 队列运维长期靠登库查 `schedule_queue`，入湖任务排队/僵死无可观测手段 → 门户内建队列看板（置信度：高，依据功能形态与"SLA 第一阶段"命名）
- 拆快照（当前/历史时刻）+ 分析（按天聚合）两接口：前者轻量高频轮询，后者重计算按需触发（置信度：中，依据实现结构）
- 分析用"按天加载 + Java 侧 288 片聚合"而非 SQL 聚合：跨时段区间覆盖统计用 SQL 表达复杂，Java 侧可控且副库只读无写入压力（置信度：中，待确认是否有数据量上限隐患）
- 3 个配置项与执行端 Nacos key 同名：门户展示口径需与调度实际参数一致（如心跳间隔判僵死）（置信度：高，依据 commit message 原文）

## 风险与测试建议 [C·自动] + 验收回填

**建议验证**：

```powershell
curl "http://localhost:8088/data-exchange/portal/queue-status/snapshot?mode=now"
curl "http://localhost:8088/data-exchange/portal/queue-status/snapshot?mode=history&t=<epoch_ms>"
# analyze 与历史时刻查询需副库有数据（内网/VPN）
```

**边界风险**：历史时刻 T 久远的快照依赖 `finished_at` 完整性；分析接口按天加载，单日队列记录量级大时 419 行聚合逻辑需关注内存；`zombie` 判定依赖心跳间隔配置与执行端实际上报节奏一致。

**验收结论（回填，2026-09-11）**：接口自动化 **19/19 通过**（snapshot/analyze 正例 + 边界 + 异常参数）；UI 走查通过（队列状态三态计数与明细、分析页 KPI/切片图/TopN 渲染正常，双 Tab 切换正常）。测试脚本：`scripts/verify-task-list-apis.ps1` 系列。

## 业务背景 [A·待补]

（待李冬口述；材料回填后两问已有书面答案）

1. SLA 第一阶段的"SLA"具体口径是什么——是先做可观测、后续再告警/考核？整体分几阶段？
   - 材料已答部分（需求整理）：一期只读观察、基线固定 30min（高优 100% / 普通 ≥95%），原始方案为每表按历史数据设基线；**后续阶段划分仍待口述**
2. ~~高优任务（slaPriority=1）的标记来源~~ ✅ 材料已答：字段来自底层表改造（`schedule_queue.sla_priority`），一期仅展示不参与排序，排队恒按 FIFO
3. 队列分析的使用者是谁（运维自己 / 向业务方汇报）？有无固定查看节奏（日报/周报）？
4. ~~上线后是否需要配套 IAM 菜单与权限点申请~~ ✅ 材料已答：只配 IAM 菜单，不配权限码（只读，能进数据交换即可）
