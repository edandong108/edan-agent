---
name: picc-gitee-commit
description: >-
  人保科技数据平台向公司 Gitee（code.devops.piccnet）提交代码前的范围审查与规避清单。
  区分业务功能与本地联调改动，排除 Local* 配置、密钥与 personal 脚本。
  Use when the user asks to commit/push to Gitee, create a PR, amend author,
  or says 提交/推代码/公司仓库/规避本地配置.
disable-model-invocation: true
---

# 公司 Gitee 提交规避（PICC 数据交换）

## 适用仓库

| 仓库 | 远程 | 常见基线分支 |
|------|------|--------------|
| `data-exchange/` | `http://code.devops.piccnet/picc/picc__picc-data-platform/data-exchange.git` | `dev_20260901_approval` / `develop` |
| `udp-portal/` | `http://code.devops.piccnet/picc/picc__picc-data-platform/udp-portal.git` | `develop-new` |

前后端**各建 feature 分支、各提 PR**，禁止直接推主干。

---

## 核心原则

1. **只推业务功能代码**；凡是为「本机跑通 / local-testdb / 跳过权限」而加的改动，默认**不进公司分支**。
2. **密钥与真实连接串永不进仓**；可提交 `.example` 模板，真实 `application-local*.properties` 仅本地保留。
3. **提交前人工核对 `git status` + `git diff --cached`**，不要 `git add .` 一把梭。
4. **作者用本人公司账号**（如 `李栋 <lidong01@picc.com.cn>`）；推送后改作者需 `amend` + `--force-with-lease`。

---

## 禁止提交：后端本地联调（data-exchange）

### 整文件禁止（截图圈定 + 同类）

```
src/main/java/com/picc/udp/config/LocalDatasourceConfiguration.java
src/main/java/com/picc/udp/config/LocalDevAuthFilter.java
src/main/java/com/picc/udp/config/LocalWebConfig.java
src/main/java/com/picc/udp/util/LocalNacosUtil.java
```

### 禁止提交的「生产类文件上的本地补丁」

对以下文件的改动若仅为本地联调，**整段 revert 后再提交**（不要带着 `@Profile("!local")`、`skip-permission` 等进 PR）：

```
src/main/java/com/picc/udp/config/DatasourceConfig.java          # 增加 @Profile 排除 local
src/main/java/com/picc/udp/config/SecondaryDatasourceConfig.java
src/main/java/com/picc/udp/config/WebConfig.java
src/main/java/com/picc/udp/aop/PermissionAspect.java           # local.dev.skip-permission
src/main/java/com/picc/udp/service/impl/TaskManagerInfoServiceImpl.java  # 本地项目/跳过权限
```

### 配置与脚本禁止

```
src/main/resources/application-local.properties
src/main/resources/application-local-testdb.properties
src/main/resources/local-nacos-config.properties
nacos-jvm.local.args
maven-settings-local-repo.xml
META-INF/   # 与需求无关的本地自动配置
```

### 可选：仅模板可进仓（团队统一约定后再推）

```
application-local.properties.example
application-local-testdb.properties.example
nacos-jvm.local.args.example
```

若团队未约定「示例配置也走文档/内网 wiki」，则**一并视为本地材料，不推**。

### pom.xml 谨慎项

以下仅在为本地编译服务，**默认不随功能 PR 提交**，除非架构评审通过：

- `local-build` profile（hadoop 版本降级）
- 仅为 local 增加的 `postgresql` 依赖
- 个人 `repositories` / `distributionManagement` 调整

---

## 禁止提交：前端本地联调（udp-portal）

```
.env.development          # 若含 localhost:8088、个人代理地址
.env.local / .env.*.local
```

`vite.config.ts` 中仅为本机增加的 `VITE_DATA_EXCHANGE_PROXY` / `loadEnv` 代理逻辑：若改变团队默认 target，**应还原或拆成本地 override 文件（gitignore）** 再提交。

**可提交**：`src/api/*`、`src/views/**` 等业务页面与接口封装。

---

## 允许提交：业务功能（示例：任务运维）

**后端**

- `QueueStatus*` / `QueueAnalysis*`（Controller、Service、Impl、Mapper、DTO）
- `application.properties` 中**生产/Nacos 同名**的业务配置项（如 `etl.schedule.*`）

**前端**

- `taskOperations/`、`queueStatus/`、`queueAnalysis/` 及组件
- `api/queueStatus.ts`、`api/queueAnalysis.ts`

**不进代码仓但需 PR 说明**

- IAM 菜单（任务运维 component 路径）
- `核心文档/` 测试报告与方案（除非有独立文档仓）

---

## 提交流程（Agent 必做）

```
Task Progress:
- [ ] 1. 分别在 data-exchange、udp-portal 执行 git status / git diff
- [ ] 2. 对照「禁止提交」清单，unstage 或 restore 本地联调文件
- [ ] 3. 从当前基线分支 checkout -b feature/<需求简称>
- [ ] 4. 仅 git add 业务文件（显式路径，禁止 git add .）
- [ ] 5. git -c user.name="..." -c user.email="..." commit（勿改全局 git config）
- [ ] 6. git log -1 核对作者
- [ ] 7. git push -u origin feature/<分支>
- [ ] 8. PR 描述写明：功能范围、Nacos/IAM 配置、已知 SKIP 项
```

### 已误推本地文件时

1. 新 commit 删除误推文件，或 `git restore` + 重新提交纯净分支  
2. 勿在未确认前对共享分支 `force push`  
3. 若仅改作者：`git commit --amend --author="姓名 <email@picc.com.cn>"` + `git push --force-with-lease`

---

## PR 描述模板

```markdown
## 功能
- [简述业务变更]

## 本 PR 不包含（本地联调，未提交）
- LocalDatasourceConfiguration / LocalDevAuthFilter / LocalWebConfig 等
- application-local*.properties、skip-permission 相关改动

## 上线依赖
- [ ] Nacos 配置项：...
- [ ] IAM 菜单：...
- [ ] 前后端需同时合并

## 测试
- API 自动化 / 浏览器走查结论（可链到 `核心文档/<功能名>功能/测试/`，如 `核心文档/SLA功能/测试/`）
```

---

## 快速自检口诀

**秘、Local、Profile、Example 以外的 .env、错作者、直推主干、双仓不同步。**

---

## 参考

- 项目规范：`.cursor/rules/dev-standards-overview.mdc`
- 本地改作者脚本（仅本地执行）：`scripts/git-amend-author.ps1`
