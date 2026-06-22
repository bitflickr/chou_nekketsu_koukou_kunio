# SP-M01：角色移动

| 属性 | 值 |
|------|------|
| 里程碑 | M1 |
| 优先级层级 | L1 🟠 核心基础 |
| 前置依赖 | M0（项目搭建） |
| 后续解锁 | M3（接球与伤害） |
| 可并行 | M2（球物理） |
| 预估工期 | 3 天 |
| 故事点数 | 7 |
| 关联风险 | RISK-05（统一输入管理层）、RISK-07（角色状态机设计） |

---

## 故事点列表

| ID | 标题 | 描述 | 依赖 | 估时 | 状态 |
|----|------|------|------|------|------|
| SP-M01.1 | 创建角色场景 | 创建 `character.tscn`，使用 CharacterBody2D 节点，包含 CollisionShape2D（站立 12×16px）、AnimatedSprite2D、状态机节点 | SP-M00.5 | 2h | ✅ |
| SP-M01.2 | 实现 8 方向移动 | 响应输入实现 8 方向移动，速度由 SPD 属性决定：`velocity = direction * (SPD * SPEED_MULTIPLIER)` | SP-M01.1 | 3h | ✅ |
| SP-M01.3 | 实现跳跃系统 | 实现起跳→滞空→落地三阶段，跳跃高度由 JMP 属性决定，跳跃中碰撞框缩小至 8×8px | SP-M01.2 | 3h | ✅ |
| SP-M01.4 | 角色状态机框架 | 实现基础状态机：Idle / Move / Jump 三个状态及转换规则，预留 Hold / Throw / Catch / Hit / Down / Out 接口 | SP-M01.1 | 4h | ✅ |
| SP-M01.5 | 占位精灵测试 | 使用彩色矩形作为占位精灵，不同队伍不同颜色，验证视觉表现 | SP-M01.2 | 1h | ✅ |
| SP-M01.6 | 触屏虚拟摇杆 | 实现左侧虚拟摇杆（触摸起点为中心，半径 48px，8 方向输入），含统一输入管理器支持键盘/触屏切换 | SP-M01.2 | 4h | ✅ |
| SP-M01.7 | 内场/外场区域约束 | 实现区域约束系统：内场球员限制在己方半场矩形内，外场球员限制在对方半场外围通道内 | SP-M01.2, SP-M00.4 | 3h | ✅ |

---

## 验收标准

- [x] 角色可通过虚拟摇杆在场地内 8 方向移动（`touch_controls.gd`，桌面鼠标模拟触摸，待窗口验收）
- [x] 跳跃表现完整（起跳/滞空/落地，伪 3D 高度 + 阴影缩放）
- [x] 角色不可移动超出内场/外场边界（`court_geometry.gd` 区域钳制，headless 测试验证）
- [x] 键盘（WASD + Space）可在开发模式下控制角色（`GameInput` 运行时注册 InputMap）
- [x] 状态机正确切换，无卡死（转换表校验 + 非法转换警告）
- [x] 移动速度与 SPD 属性值成正比（`velocity = dir * spd * MOVE_SPEED_PER_SPD`）

> 备注：headless 逻辑回归（`tests/test_l1.tscn`）全部通过；摇杆/跳跃/移动的手感需在 Godot 4.7 窗口运行中人工验收。

---

## 技术要点

- **状态机设计**（关联 RISK-07）：
  ```
  Idle ←→ Move（输入方向非零切换到 Move，归零回 Idle）
  Idle/Move → Jump（按跳跃键）
  Jump → Idle/Move（落地后根据输入决定）
  ```

- **输入管理**（关联 RISK-05）：
  - 创建 `input_manager.gd`（AutoLoad）
  - 抽象 `get_movement_vector()` 和 `is_action_pressed(action)` 接口
  - 触屏/键盘/手柄作为不同的输入 Provider

- **区域约束参数**（来自 GDD）：
  - 内场宽度（单侧）：96px
  - 内场高度：128px
  - 外场通道宽度：32px
  - 球场总宽度：256px / 总高度：192px

---

## 变更日志

| 日期 | 变更 |
|------|------|
| 2026-06-22 | 初始创建 |
| 2026-06-23 | M1 全部 7 个故事点实现完成（character/input_manager/court_geometry/touch_controls）|
