# 热血高校躲避球 完整复刻计划

完整复刻 NES 版《熱血高校ドッジボール部》，使用 Godot 4 + GDScript，目标平台 Android/iOS。

---

## 一、项目结构

```
plans/
  game_design_document.md      # 完整游戏设计文档
  original_game_data.md        # 原版数据分析（角色属性、必杀技、伤害公式）
  development_roadmap.md       # 开发路线图与里程碑

source/
  project.godot                # Godot 4 项目配置
  scenes/
    main_menu.tscn             # 主菜单
    court.tscn                 # 球场场景
    character.tscn             # 角色场景
    ball.tscn                  # 球场景
    hud.tscn                   # HUD（血条、比分）
    result.tscn                # 结果画面
  scripts/
    global/
      game_manager.gd          # 全局比赛管理（回合、胜负、模式切换）
      team_data.gd             # 队伍/角色数据定义
      constants.gd             # 全局常量
    character/
      character_controller.gd  # 角色状态机（移动、投球、接球、被击中）
      character_stats.gd       # 角色属性
      ai_controller.gd         # AI 行为树
    ball/
      ball_physics.gd          # 球物理（轨迹、速度衰减、反弹）
      special_throws.gd        # 必杀技投球系统
    court/
      court_manager.gd         # 场地管理（内外场、边界）
      camera_controller.gd     # 摄像机跟踪
    ui/
      touch_controls.gd        # 触屏虚拟摇杆/按钮
      hud.gd                   # 血条与比分显示
      menu.gd                  # 菜单逻辑
  assets/
    sprites/                   # 角色精灵表、球场贴图
    audio/                     # BGM、音效
    fonts/                     # 像素字体
  export_presets.cfg           # Android/iOS 导出预设
```

---

## 二、plans 目录文档内容规划

### 1. `game_design_document.md`（GDD）

| 章节 | 内容 |
|------|------|
| 概述 | 游戏简介、目标平台、画面风格（NES 像素 256×240） |
| 游戏模式 | **世界杯模式**（单人，日本队依次挑战各国）、**VS对战模式**（本地双人）、**Bean Ball 模式** |
| 场地规则 | 球场分内场/外场区域；每队 3 内场 + 3 外场；内场球员 HP 归零后淘汰转外场 |
| 角色系统 | HP、攻击力、防御力、速度、跳跃力；每人 1 个必杀技 |
| 球的物理 | 投球力度/角度、抛物线轨迹、速度衰减曲线、地面反弹、传球 |
| 必杀技系统 | 助跑投球触发、各角色独特轨迹（旋转、闪电、分裂、加速等） |
| 接球与闪避 | 接球判定窗口、接球成功/失败条件、闪避动作、无敌帧 |
| 伤害系统 | 基础伤害 = 球速 × 攻击力 / 防御力、必杀技加成倍率 |
| AI 系统 | 移动决策、投球目标选择、接球/闪避判定、难度分级 |
| 触屏适配 | 虚拟摇杆 + A/B 按钮、投球方向滑动手势 |
| 视觉与音频 | 像素美术风格、动画帧数规格、BGM/SE 需求列表 |

### 2. `original_game_data.md`（原版数据分析）

| 章节 | 内容 |
|------|------|
| 队伍列表 | 日本、美国、英国、印度、冰岛、中国、非洲（肯尼亚）、苏联，共 8 支队伍 |
| 角色属性表 | 每队 6 名角色的 HP / ATK / DEF / SPD / JMP 数值（原版 ROM 数据） |
| 必杀技一览 | 每个角色的必杀技名称、触发条件、球运动轨迹描述、额外伤害倍率 |
| 世界杯对战顺序 | 各关卡对手顺序、难度递增规律 |
| 碰撞判定 | 原版判定框尺寸、接球窗口帧数 |
| 已知 Bug/特性 | 原版知名的 glitch 和特殊行为，决定是否复刻 |

### 3. `development_roadmap.md`（开发路线图）

| 里程碑 | 内容 | 预估 |
|--------|------|------|
| **M0：项目搭建** | Godot 项目初始化、目录结构、基础场景 | 1 天 |
| **M1：角色移动** | 8 方向移动、跳跃、占位精灵、触屏摇杆 | 3 天 |
| **M2：球物理** | 投掷、抛物线轨迹、传球、反弹 | 3 天 |
| **M3：接球与伤害** | 碰撞检测、HP 系统、被击中/击退动画 | 3 天 |
| **M4：比赛流程** | 发球权、内外场切换、淘汰、胜负判定 | 3 天 |
| **M5：AI 系统** | 基础 AI（移动、投球、接球决策） | 5 天 |
| **M6：必杀技** | 全角色特殊投球轨迹与动画 | 5 天 |
| **M7：队伍与模式** | 8 支队伍数据、世界杯模式流程、VS 模式 | 5 天 |
| **M8：UI 与美术** | 菜单、HUD、像素精灵、动画 | 7 天 |
| **M9：音频** | BGM、投球/击中/欢呼等音效 | 3 天 |
| **M10：移动端适配** | 触屏优化、Android/iOS 导出与测试 | 5 天 |
| **M11：打磨发布** | Bug 修复、平衡性调整、性能优化 | 5 天 |

---

## 三、Windsurf Workflow 规则

在 `d:\mywork\yaxuan\chou_nekketsu_koukou_kunio\.windsurf\workflows\` 下创建以下规则文件：

### 强制性规则（全局）
- **`plan-sync.md`** — **所有 plan 相关文档（含 Windsurf plans 目录中的计划文件）必须同步 copy 一份至 `d:\mywork\yaxuan\chou_nekketsu_koukou_kunio\plans\`**。这是强制性要求，适用于所有 workflow。

### 功能性规则
- `add-feature.md` — 新功能开发流程：先更新 GDD → 编写代码 → 更新路线图状态 → 同步 plans 目录
- `add-character.md` — 添加新角色/队伍：在 `original_game_data.md` 补充数据 → 在 `team_data.gd` 注册 → 创建精灵资源
- `fix-bug.md` — Bug 修复流程：记录问题 → 定位根因 → 最小修复 → 验证

---

## 四、当前执行步骤

### 步骤 A：创建 Windsurf Workflow 规则
在 `d:\mywork\yaxuan\chou_nekketsu_koukou_kunio\.windsurf\workflows\` 下创建：
1. **`plan-sync.md`** — 强制性规则：所有 plan 文档必须 copy 至项目 `plans/`
2. **`add-feature.md`** — 新功能开发流程
3. **`add-character.md`** — 添加角色/队伍流程
4. **`fix-bug.md`** — Bug 修复流程

### 步骤 B：创建 plan 文档（写入 `plans/`）
5. **`plans/game_design_document.md`** — 完整 GDD
6. **`plans/original_game_data.md`** — 原版数据分析
7. **`plans/development_roadmap.md`** — 开发路线图

### 步骤 C：同步（按 plan-sync 规则）
8. **将本计划文件同步至 `plans/`** — 遵守 plan-sync 强制规则

### 后续步骤（本次不执行）
9. 创建 Godot 4 项目骨架（`source/`）
10. 实现 M0~M1 原型
