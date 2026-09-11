# 离线作业队列状态查询 — 上线配置与联调对账

> 配套文档：`离线作业队列状态查询-评审一页纸.html`、`离线作业队列状态查询-技术实施方案.html`
> 适用范围：本期仅前端 + 后端代码实现，**不加 mock 数据**，待测试环境数据库连通后直接用真实数据联调。

---

## 一、IAM 菜单配置（手动，不在代码内）

在【数据交换】分组下新增 **1 个菜单**，**排在分组最后面**。页面内通过顶部 Tab 切换「队列状态 / 队列分析」，只配一次菜单即可。

| 菜单名称 | 路由地址（component） | 图标（参考） | 权限字符 |
|---|---|---|---|
| 任务运维 | `/dataExchange/taskOperations/index` | `ToolOutlined` 或 `DashboardOutlined` | **不配**（只读查询，能进数据交换分组即可见） |

> **实现说明（相对评审稿变更）**：评审稿为「队列状态」「队列分析」两个独立菜单；开发中合并为 `taskOperations` 壳页面 + 双 Tab，减少 IAM 配置量。子页面路径仍保留：
> - `queueStatus/index.vue`（Tab：队列状态）
> - `queueAnalysis/index.vue`（Tab：队列分析）
>
> 前端路由通过 `import.meta.glob` 自动扫描 `src/views/dataExchange/**/index.vue`，**无需改 `routes.ts`**。IAM 只登记壳页面 `taskOperations` 即可。

---

## 二、后端配置项

以下参数已写入 `application.properties` 作为本地默认值，**生产环境从 Nacos 读取**（与 `entry.py` 侧同 key，保持一致）：

| 配置 key | 默认值 | 含义 |
|---|---|---|
| `etl.schedule.max_wait_seconds` | `3600` | 单进程最长等待秒数；排队回看窗口 = 2 × 该值 |
| `etl.schedule.queue_status_exec_lookback` | `86400` | 执行回看窗口（秒），须 ≥ 最长作业执行时长 |
| `etl.schedule.heartbeat_interval_seconds` | `30` | 心跳间隔；僵尸阈值 = 该值 × 20（=600s） |

SLA 基线：前端默认 30 分钟，可通过分析页筛选框临时调整；**后续可扩展为按表配置**（基于历史数据单独设置）。

---

## 三、DB 通后联调对账

测试环境数据库连通后，按以下步骤联调（**不依赖 mock**）：

### 1. 后端接口直连验证

- `GET /data-exchange/portal/queue-status/snapshot?mode=now`
  - 校验 `snapshotTime` 为数据库 `NOW()`
  - 校验 `queued/running/zombie` 三集合互斥（同一 jobId 不应同时出现在多个集合）
- `GET /data-exchange/portal/queue-status/snapshot?mode=history&t=2026-09-08 14:30:00`
  - 校验 `t` 不晚于 `NOW()`，否则返回 `INVALID_PARAM_ERROR`
- `GET /data-exchange/portal/queue-analysis/analyze?day=2026-09-08&priority=all&slice=5min&baseline=30`
  - 校验 `sliceSeries` 长度 = 288（5min）或 24（1hour）
  - 校验 `hourly` 长度 = 24

### 2. 用 PDF 7.6 输出示例对账三态

参照《离线作业SLA保障方案——第一阶段+V2》7.6 节示例数据，核对：
- 排队中：`submit_time <= T` 且 `finished_at` 为空或 > T 的记录数
- 执行中：经队列提交且实例区间覆盖 T（已结束看 `actual_duration`，未结束看心跳）
- 僵尸：`actual_duration=0` 且心跳停摆 > 阈值

### 3. 前端页面联调

入口：**任务运维** → Tab「队列状态」/「队列分析」。

- **队列状态 Tab**：当前态 10s 自动刷新（默认关）；历史态精度到分钟；统计卡数字与明细表行数一致；范围说明文案在筛选栏右侧（快照时间前）；各指标/列头有 ⓘ 口径提示
- **队列分析 Tab**：4 张趋势图（`SliceChart` 组件，time 轴 + 整数 Y 轴）；KPI 卡与表头均有口径提示；TopN 按等待时长降序、每页 10 条；按小时聚合 24 行（计数类累加、峰值类取 max）
- **Tab 滚动**：长页面在 Tab 内容区内滚动，不撑破外层布局
- **无 mock**：直连测试库真实数据，不启用 `vite-plugin-mock`

### 4. 测试用例对账

核心用例（见 `核心文档/SLA功能/测试/离线作业队列状态查询-测试用例.md`）：
- TC-010 / TC-011：当前态/历史态三态快照正确性
- TC-020：5 分钟切片聚合指标口径

---

## 四、相对评审稿的实现变更（摘要）

| 项 | 评审稿 | 最终实现 |
|---|---|---|
| 菜单 | 2 个（队列状态 + 队列分析） | **1 个「任务运维」+ 双 Tab** |
| 权限码 | queue-status:view / queue-analysis:view | **不配**（IAM 菜单级控制） |
| 前端 mock | — | **明确不做**，连测试库 |
| 图表联动 / 参考线 | 图①点选联动、30min/K 参考线 | **一期未做**（4 图独立随筛选刷新） |
| 指标说明 | 页面顶部文案 | **全部指标 ⓘ 悬浮提示**（卡/列头/图表标题） |
| 组件化 | 单文件页面 | **StatCard / KpiCard / SliceChart** 抽取复用 |
| 表格布局 | — | 百分比列宽铺满；jobId、湖表名居中 |

## 五、已知待优化（代码审查，非阻塞上线）

1. **历史快照时长**：`snapshotTime` 当前返回 DB `NOW()`，历史模式下等待/执行时长应按查询时刻 `t` 计算（前后端需对齐）。
2. **优先级筛选**：分析页选「高优/普通」时，执行并发/完成/僵尸侧实例集合未同步按优先级过滤。
3. **`SimpleDateFormat` 静态字段**：`QueueAnalysisServiceImpl` 建议改为 `java.time`（并发安全）。
4. **`done` 计数**：依赖 `job_instance.actual_duration > 0`，快速失败实例可能漏计。

## 六、回滚

- 前端：移除 IAM 中「任务运维」菜单即可隐藏入口
- 后端：两个 Controller 为独立新增，删菜单后接口不被调用；彻底回滚可删除 `Queue*` 系列 dto/dao/service/api 文件
