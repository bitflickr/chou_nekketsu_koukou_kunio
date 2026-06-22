# SP-M03：接球与伤害

| 属性 | 值 |
|------|------|
| 里程碑 | M3 |
| 优先级层级 | L2 🟡 核心玩法 |
| 前置依赖 | M1（角色移动）、M2（球物理） |
| 后续解锁 | M4（比赛流程）、M5（AI 系统）、M6（必杀技） |
| 可并行 | 无（整合里程碑） |
| 预估工期 | 3 天 |
| 故事点数 | 7 |
| 关联风险 | RISK-01（数据来源）、RISK-07（状态机设计） |

---

## 故事点列表

| ID | 标题 | 描述 | 依赖 | 估时 | 状态 |
|----|------|------|------|------|------|
| SP-M03.1 | 球-角色碰撞检测 | 实现 Flying 状态球与角色碰撞框（站立 12×16px / 跳跃 8×8px）的碰撞检测，区分敌我阵营 | SP-M01.1, SP-M02.2 | 3h | ✅ |
| SP-M03.2 | 接球判定窗口 | 实现接球检测框（16×20px，略大于角色框），在球到达前 6 帧（100ms）内按接球键触发判定 | SP-M03.1 | 3h | ✅ |
| SP-M03.3 | 接球成功/失败逻辑 | 接球成功条件：面朝球 + 判定窗口内按键 + 球速≤接球阈值。成功→球变 Held；失败→受伤害 | SP-M03.2 | 3h | ✅ |
| SP-M03.4 | HP 系统与伤害计算 | 实现 HP 属性系统，伤害公式：`damage = ball_speed × ATK_thrower / DEF_target`，HP 归零触发淘汰 | SP-M03.1 | 2h | ✅ |
| SP-M03.5 | 被击中状态 | 实现 Hit 状态：播放击退动画，击退距离与球速成正比（普通 16~32px），30 帧无敌时间 | SP-M03.4, SP-M01.4 | 3h | ✅ |
| SP-M03.6 | 倒地与恢复 | 实现 Down 状态：被击倒后 45 帧倒地，恢复后有短暂无敌帧，过渡回 Idle | SP-M03.5 | 2h | ✅ |
| SP-M03.7 | 触屏 A/B 按钮 | 实现右侧 A 按钮（投球/传球/接球）、B 按钮（跳跃/闪避），64×64px，支持半透明度 | SP-M01.6 | 3h | ✅ |

---

## 验收标准

- [x] 投球可命中对方角色并扣 HP
- [x] 在正确时机按接球键可成功接住球
- [x] 接球失败时受到正确伤害
- [x] 被击中后角色有明显击退和无敌帧表现
- [x] HP 归零时角色有倒地反馈
- [x] A/B 按钮响应灵敏，不与摇杆冲突
- [x] 球速超过阈值时接球窗口减半或无法接球

> 验收说明：以上为代码层交付（headless 解析/运行无错误）。最终视觉手感验收由用户在 Godot 4.7 编辑器/运行实例中人工确认。

---

## 技术要点

- **伤害公式**（来自 original_game_data.md）：
  ```
  damage = ball_speed × ATK_thrower / DEF_target
  special_damage = damage × special_multiplier (1.5~3.0)
  ```

- **接球速度阈值**：
  ```
  catch_threshold = 4.0 + (DEF_target × 0.5)
  ball_speed > threshold → 判定窗口减半（3帧）
  ball_speed > threshold × 1.5 → 无法接球
  ```

- **状态转换扩展**：
  ```
  Any → Hit（被球击中）
  Hit → Down（击退结束）
  Down → Idle（恢复帧结束）
  Idle/Move → Catch（按接球键且球接近）
  Catch → Hold（接球成功）
  Catch → Hit（接球失败）
  ```

- **碰撞判定参数**：
  | 参数 | 值 |
  |------|------|
  | 角色碰撞框（站立） | 12×16 px |
  | 角色碰撞框（跳跃） | 8×8 px |
  | 球碰撞框 | 6×6 px |
  | 接球判定框 | 16×20 px |
  | 接球窗口 | 6 帧 (100ms) |
  | 无敌帧 | 30 帧 (500ms) |
  | 倒地恢复帧 | 45 帧 (750ms) |

---

## 变更日志

| 日期 | 变更 |
|------|------|
| 2026-06-22 | 初始创建 |
| 2026-06-23 | M3（L2）实现完成，7 个故事点全部交付。新增：球-角色碰撞/敌我区分（ball.gd）、接球窗口与成功/失败判定、HP 与伤害计算、Hit 击退+无敌帧、Down 倒地恢复（character.gd）、触屏 A/B 按钮强化（touch_controls.gd）、触屏动作边沿修复（input_manager.gd）、敌队测试环境（court.gd）。 |

---

## 实现备注（M3）

- **代码落点**：`source/scripts/character/character.gd`（Catch/Hit/Down 状态机 + HP）、`source/scripts/ball/ball.gd`（`thrower` 跟踪 + `_check_character_contact` / `_resolve_contact`）、`source/scripts/global/constants.gd`（`knockback_distance`）、`source/scripts/ui/touch_controls.gd`（A/B 标签与按压反馈）、`source/scripts/global/input_manager.gd`（`Input.action_press/release` 注入触屏边沿）、`source/scripts/court/court.gd`（敌队三人测试环境）。
- **接球阈值**：`catch_threshold(def)=4.0+0.5×DEF`（px/帧）；速度>阈值窗口减半（3帧），速度>1.5×阈值无法接球；接球需 `facing` 与来球方向夹角大致相反。
- **击退**：`knockback_distance` 将来球地面速度线性映射到 16~32px，换算为初速后按 0.82/帧衰减，持续 18 帧；30 帧无敌；倒地 45 帧。
- **M3 测试取舍**：HP 归零进入 Down 并在 45 帧后恢复满血（便于回归测试）；正式「淘汰出内场」逻辑在 M4 接管（已预留 `eliminated` 信号）。
