# dataexchange_portal_agent

数据交换中心的 **AI 知识中转站**：业务代码在 `data-exchange`（后端）与 `udp-portal`（前端）两仓，本仓沉淀让「下一个接手的人/agent」能 10 分钟上岗的知识——接口契约、架构图、决策史、迭代卡。

维护到公司 Gitee，与两业务仓并列（建议同组 `picc__picc-data-platform`）。

## 三层结构导读

```
dataexchange_portal_agent/
├── AGENTS.md          上岗手册：跑起来 / 规矩 / 坑 / 谁懂什么（先读这个）
├── docs/              稳定知识层
│   ├── API-CONTRACT.md    接口契约（唯一真相源，C 编号）
│   ├── ARCHITECTURE.md    架构全景（Mermaid + 联动时序图）
│   ├── DECISIONS.md       决策史（ADR）
│   ├── DEV-ENVIRONMENT.md 环境真相（端口/数据源/Nacos/坑）
│   └── STANDARDS.md       规范导读（权威来源/差异点/对齐日期）
├── specs/             迭代知识层
│   ├── INDEX.md           规格索引（每卡一行+质量级别）
│   ├── _templates/        retro-card.md（迭代卡模板）
│   ├── 需求/ 方案/ 测试/  功能材料三层（扁平，按【功能名】命名聚拢；评审一页纸即需求）
│   └── retro/             迭代卡（交付后收口，所有迭代都有）+ .anchor.txt（双仓锚点）
└── .cursor/           agent 执行层（clone 即生效）
    ├── rules/             spec-flow + 前后端规范 + **三角色（designer/builder/reviewer）**
    └── skills/picc-gitee-commit/  提交纪律
```

## 与其他资产的分工

| 资产 | 位置 | 去向 |
|------|------|------|
| **agent 可读知识层** | 本仓 | Gitee，随仓分发 |
| 对人汇报材料层 | `核心文档/`（工作区外层） | 本地留存，不入仓 |
| 业务代码 | `data-exchange/`、`udp-portal/` | Gitee 业务仓（本仓零侵入，不加任何文件） |

## 日常节奏

- **agent 开发新迭代**（三角色串行，显式 `@designer`/`@builder`/`@reviewer` 激活）：
  1. designer 备 `specs/需求·方案/` 三层材料（按【功能名】命名，合格标准见 `.cursor/rules/spec-flow.mdc`）→ 你批准
  2. builder 按方案实现 + 验收命令全通过
  3. reviewer 出分级建议清单 → 你拍板改
  4. 交付后验收结论回填对应 retro 卡
- **每周五（或说"生成迭代卡"）**：对双仓 `git log <锚点>..HEAD` 生成 retro 迭代卡 → 更新 `specs/INDEX.md` → 更新 `.anchor.txt` → 输出知识债务清单
- **接口变更**：业务仓提交 + 本仓 `docs/API-CONTRACT.md` 同迭代更新
- **规范更新**：`相关规范/*.doc` 变 → 同步 `.cursor/rules/*.mdc` → `docs/STANDARDS.md` 记对齐日期

## 快速开始

读 [AGENTS.md](AGENTS.md)。
