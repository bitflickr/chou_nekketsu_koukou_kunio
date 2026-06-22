# SP-M07：队伍与模式

| 属性 | 值 |
|------|------|
| 里程碑 | M7 |
| 优先级层级 | L4 🟣 完整游戏 |
| 前置依赖 | M4（比赛流程）、M5（AI 系统） |
| 后续解锁 | M11（打磨发布） |
| 可并行 | M8（UI 与美术）、M9（音频） |
| 预估工期 | 5 天 |
| 故事点数 | 6 |
| 关联风险 | RISK-04（存档系统）、RISK-13（Bean Ball 模式规则未定义） |

---

## 故事点列表

| ID | 标题 | 描述 | 依赖 | 估时 | 状态 |
|----|------|------|------|------|------|
| SP-M07.1 | 注册全部队伍数据 | 在 `team_data.gd` 中定义 8 支队伍 × 6 名角色 = 48 条角色数据（HP/ATK/DEF/SPD/JMP/必杀技/位置） | SP-M04.6 | 4h | ⬜ |
| SP-M07.2 | 世界杯模式流程 | 实现 7 场连续对战流程：印度→冰岛→中国→非洲→英国→美国→苏联，每场独立，难度递增 | SP-M07.1, SP-M05.7 | 6h | ⬜ |
| SP-M07.3 | VS 对战模式 | 实现选队画面（P1/P2 各选一队）→ 单场对战 → 结果展示 → 返回选队 | SP-M07.1 | 4h | ⬜ |
| SP-M07.4 | Bean Ball 模式 | 实现变体规则：取消外场，6 人全部在内场，被击中淘汰直接退出比赛（不转外场） | SP-M07.1, SP-M04.3 | 4h | ⬜ |
| SP-M07.5 | 世界杯通关画面 | 7 场全胜后显示通关画面/动画，展示玩家队伍和胜利信息 | SP-M07.2 | 3h | ⬜ |
| SP-M07.6 | 连续传球加速 | 内外场快速传球后投球速度 +20%，传球间隔 < 30 帧视为"连续传球" | SP-M02.7, SP-M04.2 | 3h | ⬜ |

---

## 验收标准

- [ ] 3 种模式均可完整游玩
- [ ] 8 支队伍全部可选，48 名角色数据正确
- [ ] 世界杯模式 7 场对战顺序正确
- [ ] 世界杯通关后有通关画面
- [ ] VS 模式选队→对战→结果流程完整
- [ ] Bean Ball 模式规则与标准模式区分明确
- [ ] 连续传球加速正确触发（+20%）

---

## 技术要点

- **team_data.gd 数据结构**：
  ```gdscript
  var teams: Array[TeamData] = []
  
  class TeamData:
    var id: int
    var name_jp: String
    var name_en: String
    var difficulty: int  # 1-4
    var members: Array[CharacterData]
  
  class CharacterData:
    var id: int
    var name_jp: String
    var position: String  # "IN" / "OUT"
    var is_captain: bool
    var hp: int
    var atk: int
    var def_val: int
    var spd: int
    var jmp: int
    var special_throw: String  # 必杀技 ID，"" 表示无
  ```

- **世界杯对战配置**：
  | 场次 | 对手 | AI 难度 | 场地 |
  |------|------|---------|------|
  | 1 | 印度 | Easy | 印度寺庙 |
  | 2 | 冰岛 | Easy+ | 冰原 |
  | 3 | 中国 | Normal | 长城 |
  | 4 | 非洲 | Normal+ | 草原 |
  | 5 | 英国 | Hard | 伦敦街道 |
  | 6 | 美国 | Hard+ | 自由女神 |
  | 7 | 苏联 | Expert | 红场 |

- **Bean Ball 模式差异**（关联 RISK-13）：
  - 无外场，所有 6 人在内场
  - 内场区域扩大（使用全场）
  - HP 归零 → 直接退出比赛
  - 胜负条件：对方全灭

---

## 变更日志

| 日期 | 变更 |
|------|------|
| 2026-06-22 | 初始创建 |
