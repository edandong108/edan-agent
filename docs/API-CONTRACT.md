# API 契约（唯一真相源）

> 数据交换中心前后端接口契约。集中一份，前后端两仓共用本仓。
> **改动纪律**：业务仓提交涉及接口变更的代码时，同迭代更新本文件（retro 生卡时校验）。
> 冷启动日期：2026-09-11 · 基线：后端 `dev_20260901_approval` / 前端 `develop-new`
> ⚠️ 本文件经两读一合生成，**待李冬 20 分钟校对**（见文末「校对记录」），校对前 B 级内容仅供参考。

## 使用约定

| 项 | 约定 |
|----|------|
| 门户前缀 | `/data-exchange/portal/**`（例外：`/alarm` 无前缀） |
| 前端通道 | `serverType`：server1=`/one-meta`、**server2=`/data-exchange`（本服务）**、server3=`/data-monitor-server`、server4=`/data-permission`；前端写 `/portal/xxx` + server2 ⇒ 完整路径 `/data-exchange/portal/xxx` |
| 统一返回体 | `ApiResponse { status, statusText, data }`；分页 `data: { list, total }` |
| 异常 | `CommonException` + `CommonExceptionCode`，由全局异常处理器转返回体 |

---

## C1 队列运维（QueueStatusController / QueueAnalysisController）

> 2026-09-10 SLA 迭代新增（后端 `00cd149` / 前端 `4f11ac5`），见 specs/retro/ 迭代卡。

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| GET `/portal/queue-status/snapshot?mode&t` | `QueueStatusSnapshot { snapshotTime, now, queuedCount, runningCount, zombieCount, queued[], running[], zombie[] }`，明细项含 `slaPriority`(0普通/1高优)、`submitTime`、`heartBeatenAt` | `api/queueStatus.ts` → 队列状态页（SLA 迭代新增） | 2026-09-10 新增 |
| GET/POST `/portal/queue-analysis/analyze` | 队列分析结果（积压/耗时维度） | `api/queueAnalysis.ts` → 队列分析页 | 2026-09-10 新增 |

## C2 任务管理（JobController / JobFlowConfigController）

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| POST `/portal/jobs`（create） | 新建任务 id | 任务管理-新建（views 内有硬编码调用） | 2026-09-11 冷启动 |
| PUT/POST `/portal/jobs/{id}`（update） | 影响行数/任务对象 | 任务管理-编辑 | 2026-09-11 冷启动 |
| DELETE `/portal/jobs/{id}` | — | 任务管理-删除 | 2026-09-11 冷启动 |
| GET/POST `/portal/jobs/table-mapping` | 表映射配置 | 任务管理-表映射 | 2026-09-11 冷启动 |
| GET/POST `/portal/jobs/{jobId}/flow-config` | flowable 流程配置 | 任务管理-流程配置 | 2026-09-11 冷启动 |
| POST `/portal/jobs/preflight` | 前置校验结果 | 任务管理-提交前校验 | 2026-09-11 冷启动 |
| GET/POST `/portal/jobs/suggest` | 建议参数 | 任务管理 | 2026-09-11 冷启动 |

> ⚠️ jobs 系列端点的方法动词（POST/PUT/GET）与完整路径后缀为扫描归并结果，逐一精确度待校对。

## C3 任务运维（TaskManagerInfoController）

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| POST `/portal/task_manager/fuzzyPage` | 分页 `{ list, total }` | 任务运维列表（双 Tab 壳页） | 2026-09-11 冷启动 |
| POST `/portal/task_manager/submit` | 提交结果 | 任务运维-提交 | 2026-09-11 冷启动 |
| POST `/portal/task_manager/batch` | 批量操作结果 | 任务运维-批量 | 2026-09-11 冷启动 |
| GET `/portal/task_manager/getTaskQueueStatus` | 任务队列状态 | 任务运维-队列状态列 | 2026-09-11 冷启动 |
| POST `/portal/task_manager/saveColumn` | — | 任务运维-列配置保存 | 2026-09-11 冷启动 |
| （其余启停/详情端点） | — | 任务运维页 | 2026-09-11 冷启动 |

## C4 源表台账（TableRegisterController，23 端点）

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| POST `/portal/table-register/page` 等查询系列 | 分页台账 | `api/tableRegister.ts` → views/dataExchange/dataResource | 2026-09-11 冷启动 |
| 登记/编辑/删除系列 | — | dataResource 页 | 2026-09-11 冷启动 |
| 文件上传系列 | 解析结果 | dataResource 页-批量导入 | 2026-09-11 冷启动 |
| ~~submitResult / getApprovalConfirmInfo~~ | — | **前端走旧审批路径，见「待澄清」P0-1** | — |

## C5 源表 Topic 台账（SourceTopicLedgerController，8 端点）

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| 分页/详情/增删改系列 | 分页 `{ list, total }` | `api/sourceTopicLedger.ts` → 源表 topic 台账页 | 2026-09-11 冷启动 |
| POST `/portal/source-topic-ledger/suggest-params` | 建议参数 | 台账页-参数联想 | 2026-09-11 冷启动 |

## C6 实时流（RealTimeStreamController，8 端点）

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| POST `/portal/real-time-stream/create` | 新流 id | `api/dataChange.ts` → liveStreamManagement | 2026-09-11 冷启动 |
| POST `/portal/real-time-stream/enable/{id}` | 影响行数 | dataChange.ts `enableStream` | 2026-09-11 冷启动 |
| POST `/portal/real-time-stream/stop/{id}` | 影响行数 | dataChange.ts `stopStream` | 2026-09-11 冷启动 |
| POST `/portal/real-time-stream/search` | 分页 `{ list, total }` | dataChange.ts `GET_STREAM_LIST` | 2026-09-11 冷启动 |
| GET `/portal/real-time-stream/log-type` | 日志格式枚举 | dataChange.ts `GET_STREAM_TYPE` | 2026-09-11 冷启动 |
| GET `/portal/real-time-stream/kafka-instance` | Kafka 实例列表 | dataChange.ts | 2026-09-11 冷启动 |
| GET `/portal/real-time-stream/yarn/application` | Yarn 应用状态 | liveStreamManagement 页 | 2026-09-11 冷启动 |
| GET `/portal/real-time-stream/custom-config` | 自定义配置 | liveStreamManagement 页（硬编码调用） | 2026-09-11 冷启动 |
| ~~update / delete/{id} / {id}~~ | — | **后端无此三端点，前端死封装，见「待澄清」P0-2** | — |

## C7 数据源与元数据（DatasourceInfoController / MetadataController）

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| `/portal/datasources` 增删改查系列（11 端点） | 数据源对象/分页 | `api/dataChange.ts` → sourceManagement | 2026-09-11 冷启动 |
| GET/POST `/portal/datasources/update/nacos` | Nacos 同步结果 | sourceManagement | 2026-09-11 冷启动 |
| GET/POST `/portal/datasources/net_check` | 网络连通性结果 | sourceManagement-连通测试 | 2026-09-11 冷启动 |
| GET `/portal/metadatas/...`（1 端点） | 元数据 | 元数据展示 | 2026-09-11 冷启动 |

## C8 数据探查（ExploreSource*，19 端点）

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| `/portal/explore-source/**`（模板发现等） | 探查任务/结果 | `api/dataChange.ts` 探查段 | 2026-09-11 冷启动 |
| GET `/portal/explore-source-template/{id}/result/column` | 表结构 | dataChange.ts `searchDataSourceTableStructure` | 2026-09-11 冷启动 |
| GET `/portal/explore-source-template/{id}/result/record` | 数据抽样 | dataChange.ts `searchDataSourceTablePreview` | 2026-09-11 冷启动 |
| GET `/portal/explore-source-template/{id}/instance/log?type=` | 失败日志 | dataChange.ts `getDataSourceTableLog` | 2026-09-11 冷启动 |
| POST `/portal/explore-source-custom/execute` | SQL 执行结果 | dataChange.ts `dataSourceExecute` | 2026-09-11 冷启动 |
| GET `/portal/explore-source-custom/task/status/{id}` | 执行状态 | dataChange.ts `taskStatus` | 2026-09-11 冷启动 |
| GET `/portal/explore-source-custom/{id}/instance/log` | 自定义 SQL 失败日志 | dataChange.ts `getDataSourceTableLog_SQL` | 2026-09-11 冷启动 |

## C9 入湖审批（DataLakeApprovalController）

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| POST `/portal/data-lake-approval/pre` | 预校验结果 | （前端未对接，见 P0-1） | 2026-09-11 冷启动 |
| POST `/portal/data-lake-approval/submit` | 提交结果 | （前端未对接，见 P0-1） | 2026-09-11 冷启动 |
| POST `/portal/data-lake-approval/my-approvals/metadata/update` | — | （前端旧路径下有同名语义端点） | 2026-09-11 冷启动 |

> 审批状态回调由 flowable 侧走内部接口 `/data-exchange/internal/data-lake-approval/callback/updateApprovalStatus`（DataLakeApprovalCallbackController）。

## C10 其他门户端点

| 方法+路径 | 返回 data 要点 | 前端消费方 | 变更记录 |
|-----------|---------------|-----------|---------|
| `/portal/task_log/**`（TaskLogController） | 任务日志 | 任务日志页 | 2026-09-11 冷启动 |
| `/portal/execution-history/**`（ExecutionHistoryController） | 执行历史分页 | execute_log 页（views 硬编码） | 2026-09-11 冷启动 |
| `/portal/data-check/**`（DataCheckController） | 校验结果 | 数据校验页 | 2026-09-11 冷启动 |
| `/portal/task/**`（InstantTaskController，即时任务） | 即时查询结果 | SQL 即时查询 | 2026-09-11 冷启动 |
| `/alarm/**`（AlarmDataController，3 端点，**无 portal 前缀**） | 告警数据 | 告警展示 | 2026-09-11 冷启动 |

## C11 执行端与内部接口（非前端消费）

| 方法+路径 | 消费方 | 说明 | 变更记录 |
|-----------|--------|------|---------|
| `/data-exchange/public-api/task/dispatch|heart-beaten|log|result`（PublicTaskController） | ETL 执行端（Python） | 任务下发/心跳/日志回传/结果回传 | 2026-09-11 冷启动 |
| `/data-exchange/public-api/datasources/**`（ExternalDatasourceInfoController） | 外部系统 | 数据源信息开放查询 | 2026-09-11 冷启动 |
| `/data-exchange/internal/table-register/**`、`/internal/datasources/**`、`/internal/data-lake-approval/callback/updateApprovalStatus` | 内部服务/flowable | 不暴露网关外 | 2026-09-11 冷启动 |
| `/zt/data-lake/data-sync/job-submission`（DataLakeJobController） | 中台 | 中台数据同步任务提交 | 2026-09-11 冷启动 |

## 通道边界（server1/3/4 不属本服务）

以下前端调用走 server1（/one-meta）或 server4（/data-permission），**不由 data-exchange 后端提供**，本契约不约束，仅登记防误判：

- `api/login.ts` 全部（login、user/info、menus、guanbi/token、list_with_perms → server1/server4）
- `api/udpPortal.ts`（introductions/notices/cas login → server4）
- `api/platformManagement.ts`、`api/projectManagement.ts`（项目管理/公司列表/项目资源 → server4）
- ChatAI 页（`/data-exchange-agent/` 通道，独立 AI 服务）

---

## 待澄清（知识债务）

> 两读一合发现的契约漂移，按优先级排列。**retro 生卡时复核本清单消化情况。**

### P0-1 入湖审批路径漂移（功能疑似不可用）

- 前端 `api/dataSecurity.ts` 全部 7 个接口（列表/详情/撤回/approve/reject/metadata update）、`api/tableRegister.ts` 的 `submitResult`/`getApprovalConfirmInfo`、views/DataReviewPage 内硬编码，均指向 **`/portal/table-ingestion-approvals/*`**
- 后端现仅有 **`/portal/data-lake-approval/{pre, submit, my-approvals/metadata/update}`** 三端点，无 `table-ingestion-approvals` Controller，无列表/详情/撤回/approve/reject
- 推断（置信度：中）：审批模块重构中，后端先行改版、前端未跟上；或旧 Controller 已删除而前端未切换
- **待确认**：审批链路当前在测试/生产环境是否可用？目标路径是 `data-lake-approval` 还是恢复 `table-ingestion-approvals`？

### P0-2 实时流 update/delete/view 后端缺失

- 前端 `api/dataChange.ts` 封装 `updateStream`（`/real-time-stream/update`）、`deleteStream`（`/real-time-stream/delete/{id}`）、`viewStream`（`/real-time-stream/{id}`），后端 RealTimeStreamController 无对应端点
- 页面侧 liveStreamManagement/index.vue 中 updateStream、deleteStream 的调用已被注释（686、782 行附近）
- 推断（置信度：中）：编辑/删除功能被有意下线（注释保留），封装未清理
- **待确认**：是功能下线（删封装）还是后端待补（补端点）？

### P1-1 探查状态查询与数据抽样同路径

- `api/dataChange.ts` 的 `searchDataSourceTableLog`（注释称"探源状态"）与 `searchDataSourceTablePreview`（"数据抽样预览"）同为 GET `/portal/explore-source-template/{id}/result/record`
- 推断（置信度：高）：复制粘贴未改路径，"探源状态"应另有端点
- **待确认**：探源状态查询的正确路径；当前页面该功能拿到的是抽样数据

### P1-2 refreshToken 调用了不存在的方法

- `hooks/useRefreshToken.ts` 调 `loginApi.refreshToken()`，但 `api/login.ts` 未定义该方法
- **待确认**：Token 刷新链路是否从未生效？依赖什么兜底（CAS 重登录）？

### P2 死封装与硬编码清单

- `dataChange.ts` 中 updateStream/deleteStream/viewStream 等未被页面使用（调用处已注释）
- views 内绕过 api 层的硬编码调用：taskManagement create/edit、execute_log、sourceManagement、DataReviewPage（`.post("/data-exchange/portal/table-ingestion-approvals/submitResult")`）、liveStreamManagement 的 custom-config
- 建议：api 层收口列入后续技术债迭代

---

## 校对记录

| 日期 | 校对人 | 范围 | 结论 |
|------|--------|------|------|
| 2026-09-11 | 待李冬 | 全文 | 待校对（重点：C2 方法动词、C9 审批现状、P0-1/P0-2 处置意见） |
