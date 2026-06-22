# 熱血高校ドッジボール部 — AI 复刻版

> **100% AI-Driven Development** — 本项目从设计、编码、美术到测试，全程由 AI 完成。人类负责审核和决策。

使用 Godot 4 + GDScript 完整复刻 NES 版《熱血高校ドッジボール部》(1988, Technos Japan)，目标平台 Android / iOS。

## 游戏简介

经典的热血系列躲避球游戏。操控日本队，依次挑战 7 个国家队，每位球员都有独特的必杀技投球！

| 项目 | 说明 |
|------|------|
| 原版 | 熱血高校ドッジボール部 (FC/NES, 1988) |
| 引擎 | Godot 4 (GDScript) |
| 平台 | Android / iOS |
| 画风 | NES 像素风格 256×240 |
| 视角 | 俯视 45° 伪 3D |

### 游戏模式

- **世界杯模式** — 单人，操控日本队挑战 7 国
- **VS 对战** — 本地双人，自选队伍对战
- **Bean Ball** — 变体规则，无外场，淘汰制

### 核心特色

- 8 支队伍 × 6 名球员 = 48 名角色，各有独特属性
- 17 种必杀技投球（旋转球、闪电球、分裂球、消失球……）
- 接球/闪避系统，6 帧判定窗口
- 4 级 AI 难度（Easy → Expert）

## 项目特点：纯 AI 开发

本项目是一次**纯 AI 驱动游戏开发**的实验：

- **设计文档** — AI 撰写 GDD、数据表、开发路线图
- **风险管理** — AI 识别和跟踪 16 项风险（GitHub Issues）
- **代码实现** — AI 编写全部 GDScript 代码
- **美术资产** — AI 生成像素精灵、背景、UI
- **音频资产** — AI 生成 BGM 和音效
- **测试验证** — AI 协助测试和 Bug 修复
- **人类角色** — 审核决策、验收测试、最终发布

## 项目结构

```
chou_nekketsu_koukou_kunio/
├── source/                  # Godot 项目源码
│   ├── scenes/              # 场景文件 (.tscn)
│   ├── scripts/             # GDScript 脚本 (.gd)
│   └── assets/              # 美术、音频资源
├── plans/                   # 项目文档
│   ├── game_design_document.md    # 游戏设计文档
│   ├── original_game_data.md      # 原版数据
│   ├── development_roadmap.md     # 开发路线图
│   └── riskitem/                  # 风险跟踪
├── .github/
│   └── ISSUE_TEMPLATE/      # Issue 模板（Bug/Risk/Feature）
├── .windsurf/
│   └── workflows/           # AI 开发工作流规则
└── scripts/                 # 构建/运维脚本
```

## 开发路线图

共 12 个里程碑，预估总工期约 48 天：

| 里程碑 | 内容 | 工期 | 状态 |
|--------|------|------|------|
| M0 | 项目搭建 | 1d | ⬜ |
| M1 | 角色移动 | 3d | ⬜ |
| M2 | 球物理 | 3d | ⬜ |
| M3 | 接球与伤害 | 3d | ⬜ |
| M4 | 比赛流程 | 3d | ⬜ |
| M5 | AI 系统 | 5d | ⬜ |
| M6 | 必杀技 | 5d | ⬜ |
| M7 | 队伍与模式 | 5d | ⬜ |
| M8 | UI 与美术 | 7d | ⬜ |
| M9 | 音频 | 3d | ⬜ |
| M10 | 移动端适配 | 5d | ⬜ |
| M11 | 打磨发布 | 5d | ⬜ |

详细任务见 [`plans/development_roadmap.md`](plans/development_roadmap.md)

## 文档索引

| 文档 | 说明 |
|------|------|
| [游戏设计文档](plans/game_design_document.md) | 完整 GDD，涵盖所有游戏系统 |
| [原版数据](plans/original_game_data.md) | NES 原版角色属性、必杀技数据 |
| [开发路线图](plans/development_roadmap.md) | 里程碑、任务、进度跟踪 |
| [风险跟踪](plans/riskitem/riskitem.md) | 16 项已识别风险 |

## Issue 管理

项目使用 GitHub Issues 跟踪所有工作项：

- **Labels** — `type:*`（类型）+ `area:*`（领域）+ `P*`（优先级）
- **Milestones** — 对应 M0 ~ M11 里程碑
- **Templates** — Bug 报告 / 风险项 / 功能请求

查看：[Issues](https://github.com/bitflickr/chou_nekketsu_koukou_kunio/issues) · [Milestones](https://github.com/bitflickr/chou_nekketsu_koukou_kunio/milestones)

## 开发环境

- **Godot** 4.x
- **语言** GDScript
- **AI 工具** Windsurf (Cascade)
- **版本控制** Git + GitHub

## 许可证

[MIT License](LICENSE) — Copyright (c) 2026 Yaxuan

## 免责声明

本项目为致敬/学习性质的同人复刻作品。原版《熱血高校ドッジボール部》版权归 Technos Japan / Arc System Works 所有。本项目所有美术和音频资产均为 AI 原创生成，不包含原版素材。
