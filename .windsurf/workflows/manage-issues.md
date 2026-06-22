---
description: 强制规则：GitHub Issues 管理规范
---

# GitHub Issues 管理规范（强制）

**此规则为强制性规则，适用于所有 workflow 和所有对话。**

仓库地址：https://github.com/bitflickr/chou_nekketsu_koukou_kunio

## 0. Issue 的作用与范围（强制）

**GitHub Issues 仅用于管理「问题与缺陷」，不用于管理功能开发进度。**

- **属于 Issue 的范围**：
  - **Bug / 缺陷**：已有功能出现的错误、崩溃、行为不符合预期。
  - **风险 / 不确定性**：阻塞或威胁项目的开放问题、未决设计、外部依赖风险。
- **不属于 Issue 的范围（不要创建 Issue）**：
  - **功能需求 / 故事点 / 开发任务**：由 `plans/` 目录的路线图与故事点文档管理（`development_roadmap.md`、`plans/story_point/`），**不**登记为 Issue。
  - **资产制作、工程/CI 等计划内任务**：同样在 `plans/` 中跟踪，除非它们演变成「问题/风险」。

> 简言之：**计划要做什么 → 写进 `plans/`；出了什么问题 / 有什么风险 → 开 Issue。**

## 1. Issue 创建规则

仅以下情况**必须**创建对应类型的 GitHub Issue：

| 情况 | 使用模板 | 必打标签 |
|------|----------|----------|
| 发现 Bug / 缺陷 | `bug_report.md` | `type:bug` + `area:*` + `P*` |
| 识别新风险 / 不确定性 | `risk_item.md` | `type:risk` + `P*` |

> 功能/设计/资产/工程任务**不再创建 Issue**，改在 `plans/` 中跟踪。`type:feature`/`type:design`/`type:asset`/`type:infra` 标签仅在某个问题/风险需要标注其涉及领域时辅助使用。

## 2. Label 体系

### 类型标签（必选一个）
- `type:bug` — Bug
- `type:risk` — 风险项
- `type:feature` — 新功能
- `type:design` — 设计决策
- `type:asset` — 美术/音频资产
- `type:infra` — 工程/构建/CI

### 领域标签（按涉及领域选择）
- `area:character` — 角色系统
- `area:ball` — 球物理
- `area:match` — 比赛流程
- `area:ai` — AI 系统
- `area:ui` — UI/HUD
- `area:input` — 输入控制
- `area:audio` — 音频
- `area:mobile` — 移动端适配

### 优先级标签（必选一个）
- `P0:blocker` — 阻塞性，必须立即解决
- `P1:high` — 高优先级
- `P2:medium` — 中优先级
- `P3:low` — 低优先级

## 3. Milestone 关联

每个 Issue **必须**关联对应的 Milestone（除非影响全局无法归属单一里程碑）：

| Milestone | 对应阶段 |
|-----------|----------|
| M0: Project Setup | 项目搭建 |
| M1: Character Move | 角色移动 |
| M2: Ball Physics | 球物理 |
| M3: Catch and Damage | 接球与伤害 |
| M4: Match Flow | 比赛流程 |
| M5: AI System | AI 系统 |
| M6: Special Throws | 必杀技 |
| M7: Teams and Modes | 队伍与模式 |
| M8: UI and Art | UI 与美术 |
| M9: Audio | 音频 |
| M10: Mobile Adapt | 移动端适配 |
| M11: Polish Release | 打磨发布 |

## 4. Commit 关联规则

所有与 Issue 相关的 commit **必须**在 commit message 中引用 Issue 编号：

```
# 完全解决 Issue → 自动关闭
git commit -m "Fix ball collision detection. Fixes #3"

# 部分修复/进展 → 不关闭，仅关联
git commit -m "Add input manager base class. Ref #5"

# 多个 Issue
git commit -m "Refactor state machine. Fixes #7, Ref #6"
```

关键词（写在 commit message 中会自动关闭 Issue）：
- `Fixes #N` / `Fix #N`
- `Closes #N` / `Close #N`
- `Resolves #N` / `Resolve #N`

## 5. Issue 生命周期

```
创建 (Open) → 开发中 (分配 Assignee) → 提交代码 (Fixes #N) → 自动关闭 (Closed)
```

- 开始处理 Issue 时，**Assign** 给自己
- 解决后通过 commit message 自动关闭，或手动关闭并注明原因
- 不会解决的 Issue，关闭时打上说明（如 `wontfix`、`duplicate`）

## 6. 脚本工具

Token 配置文件：`scripts/.github-token`（已 gitignore）
批量操作脚本：`scripts/setup-github-issues.ps1`
数据文件：`scripts/github-issues-data.json`、`scripts/github-issues-list.json`
