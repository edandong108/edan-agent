# 架构全景（数据交换中心）

> 冷启动：2026-09-11 · 图源迁移自 `核心文档/技术介绍/数据交换中心-架构图与功能模块图.md`（同源维护，改图两边同步）。
> 高清汇报版见 FigJam：https://www.figma.com/board/1ivxnU32PajFyG0cANjmEB
> 前后端分两个仓（udp-portal / data-exchange），但对外是同一个系统，图按「系统」组织。

## 1. 系统架构图（集成视角）

```mermaid
flowchart TB
    subgraph AUTH["用户与认证"]
        U["业务 / 运维用户"]
        IAM["集团 IAM · 4A 统一认证"]
    end

    subgraph FE["前端 udp-portal（Vue3 + AntD Vue + Vite）"]
        PORTAL["数据交换中心门户<br/>菜单由 IAM 动态下发 · token + project-id"]
    end

    subgraph BE["后端 data-exchange（Java 8 + Spring Boot 2.7 + MyBatis）"]
        API["REST API 层<br/>portal 门户 / internal 内部 / public-api 执行端"]
        SVC["业务服务层（23 个 Service）"]
        SCH["定时调度<br/>@Scheduled + DB 分布式锁"]
        MQC["Kafka 消费者<br/>应用/负责人主数据同步"]
    end

    subgraph DB["数据层（双数据源）"]
        GAUSS[("GaussDB 主库 udp_etl<br/>表登记 · 探查 · 实时流 · 台账 · 告警")]
        MYSQL[("MySQL 副库 udp_etl<br/>Job · 实例 · 调度队列 schedule_queue")]
    end

    subgraph MW["中间件"]
        NACOS["Nacos 配置中心<br/>数据源连接 · 业务开关 · cron"]
        CONSUL["Consul 服务注册"]
    end

    subgraph BIG["大数据平台"]
        YARN["Yarn / Flink<br/>实时流作业状态与 Kill"]
        HDFS["HDFS<br/>探查结果文件（Kerberos）"]
        KAFKA["Kafka<br/>架构管理平台事件"]
    end

    subgraph EXT["外围系统"]
        ONEMETA["one-meta 元数据（Feign）"]
        FLOW["udp-flowable 入湖审批流（Feign）"]
        UDIAM["udp-iam 权限（Feign）"]
        ALARM["告警 / 邮件（HTTP）"]
        DATABLAU["数语 Datablau（HTTP）"]
    end

    EXEC["ETL 执行端（Python entry.py）<br/>拉取任务 · 心跳 · 结果回写"]

    U --> IAM --> PORTAL
    PORTAL -->|HTTPS · /data-exchange| API
    API --> SVC
    SVC --> GAUSS
    SVC --> MYSQL
    SVC --> NACOS
    SCH --> GAUSS
    SCH --> MYSQL
    MQC --> KAFKA
    SVC --> YARN
    SVC --> HDFS
    SVC --> ONEMETA
    SVC --> FLOW
    SVC --> UDIAM
    SVC --> ALARM
    SVC --> DATABLAU
    EXEC -->|public-api 派发/心跳/回写| API
    EXEC --> MYSQL
    BE -. 服务注册 .-> CONSUL
```

要点：双数据源分工见 DECISIONS.md#D1；执行端经 `public-api` 解耦；审批外链（DataReviewPage）走白名单 token。

## 2. 功能模块图（业务能力视角）

```mermaid
flowchart LR
    subgraph CENTER["数据交换中心"]
        subgraph M1["接入与配置"]
            A1["数据源管理"]
            A2["源探查<br/>模板 / 自定义 SQL"]
            A3["数据资源 · 表注册"]
            A4["实时流配置"]
            A5["源表-Topic 台账"]
        end
        subgraph M2["任务编排"]
            B1["入湖任务管理"]
            B2["出湖任务管理"]
            B3["执行历史"]
        end
        subgraph M3["运维观测"]
            C1["任务运维<br/>队列状态 + 队列分析"]
            C2["执行日志"]
            C3["服务性能监控"]
        end
        subgraph M4["数据安全"]
            D1["入湖审批"]
            D2["权限审批 / 审计<br/>（在建）"]
        end
        subgraph M5["平台管理"]
            E1["用户 / 角色 / 菜单"]
            E2["项目统筹"]
        end
        M1 --> M2 --> M3
        M4 -. 审批嵌入入湖流程 .-> M2
    end
```

业务域 ↔ 代码映射（答疑用）：

| 业务域 | 前端 views | 后端 API | 主要数据表 |
|--------|-----------|---------|-----------|
| 数据源管理 | `dataExchange/sourceManagement` | `/portal/datasources` | `datasource_info`（副库） |
| 源探查 | `dataExchange/explorationManagement` | `/portal/explore-source*` | `explore_source*`（主库）+ HDFS |
| 表注册/数据资源 | `dataExchange/dataResource` | `/portal/table-register` | `table_register`（主库） |
| 实时流 | `dataExchange/liveStreamManagement` | `/portal/real-time-stream` | `real_time_stream`（主库）+ Yarn/Kafka |
| 源表-Topic 台账 | `dataExchange/sourceTopicLedger` | `/portal/source-topic-ledger` | `source_topic_ledger`（主库） |
| 出入湖任务 | `dataExchange/taskManagement/*` | `/portal/jobs`、`/portal/task_manager` | `job` / `job_instance`（副库） |
| 任务运维（SLA） | `dataExchange/taskOperations` | `/portal/queue-status`、`/portal/queue-analysis` | `schedule_queue` / `job_instance`（副库） |
| 执行日志/历史 | `dataExchange/execute_log`、`taskExecuteHistory` | `/portal/execution-history`、`/portal/task_log` | `job_instance_log`（副库） |
| 入湖审批 | `dataSecurity/LakeEntryApproval` | `/portal/data-lake-approval` + flowable 回调 | 审批流（udp-flowable） |
| 平台管理 | `platformManagement/*` | `/data-permission`（独立服务） | — |

## 3. 前后端映射图（仓 → 部署）

```mermaid
flowchart LR
    subgraph REPO["代码仓（公司 Gitee）"]
        R1["udp-portal<br/>Vue3 前端仓"]
        R2["data-exchange<br/>Java 后端仓"]
    end

    subgraph DEPLOY["部署单元"]
        D1["静态资源服务<br/>udp-portal dist"]
        D2["JVM 服务 :8088<br/>data-exchange"]
    end

    R1 -->|vite build| D1
    R2 -->|maven package| D2

    D1 -->|"/data-exchange"| D2
    D1 -->|"/one-meta"| S1["one-meta 元数据服务"]
    D1 -->|"/data-permission"| S2["权限 / 门户服务"]
    D1 -->|"/data-monitor-server"| S3["监控服务"]
```

要点：前端 `serverType` 四路分流（仅 `/data-exchange` 到本系统后端）；菜单由 IAM 下发 + 前端 `import.meta.glob` 映射 `views/**/index.vue`（DECISIONS.md#D2）；两仓独立发版，功能上线通常要求前后端同分支成对合并。

## 4. 联动时序图：队列状态查询（SLA 迭代新增）

```mermaid
sequenceDiagram
    participant P as 队列状态页<br/>taskOperations
    participant F as queueStatusApi<br/>(server2)
    participant C as QueueStatusController
    participant S as QueueStatusService
    participant M as QueueStatusMapper<br/>(dao/secondary)
    participant DB as MySQL 副库<br/>schedule_queue + job_instance + job

    P->>F: snapshot({ mode, t? })
    F->>C: GET /data-exchange/portal/queue-status/snapshot
    C->>S: snapshot(mode, t)
    S->>M: 按时刻 T 查询
    M->>DB: SELECT ... FROM schedule_queue sq<br/>区间 [submit_time, finished_at) 覆盖 T
    DB-->>M: 队列记录（queued/running/zombie）
    M-->>S: 明细列表
    S-->>C: QueueStatusSnapshot<br/>(snapshotTime/now/三态计数+明细)
    C-->>F: ApiResponse { status, statusText, data }
    F-->>P: 快照渲染（slaPriority 0普通/1高优）
```

## 5. 联动时序图：入湖申请提交（含 flowable 审批）

```mermaid
sequenceDiagram
    participant P as 数据资源页<br/>dataResource
    participant F as 前端 api 层
    participant C as DataLakeApprovalController
    participant S as DataLakeApprovalServiceImpl
    participant FL as udp-flowable<br/>(Feign: UdpFlowableService)
    participant CB as 内部回调<br/>/internal/.../callback

    P->>F: 勾选登记表 → 发起入湖
    F->>C: POST /portal/data-lake-approval/pre (registerIds)
    C->>S: pre(registerIds)
    S->>FL: getApprovalNodes()（app-token header）
    FL-->>S: 审批节点组 ApprovalNodeGroupDto
    S-->>P: 确认信息（审批人/节点）
    P->>C: POST /portal/data-lake-approval/submit
    C->>S: submit(DataLakeApplyRequest)
    S->>FL: submit(FlowSubmitRequest)
    FL-->>S: instanceId（流程实例）
    S-->>P: 提交成功（进入审批中）
    Note over FL,CB: 审批人操作后
    FL->>CB: POST /internal/data-lake-approval/callback/updateApprovalStatus
    CB->>S: 更新审批状态
```

> ⚠️ 本图是**目标链路**。前端现状仍调旧路径 `/portal/table-ingestion-approvals/*`，后端无此端点——见 API-CONTRACT.md「待澄清」P0-1，处置结论出来前审批链路以本图为准做对照。
