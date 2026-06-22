extends Node
## 全局常量与数值定义（AutoLoad: Constants）
##
## 集中管理场地尺寸、物理参数、伤害公式常量、碰撞判定等全局数值。
## 数值来源：plans/master_plan/game_design_document.md 与 original_game_data.md。
## 所有数值在比赛逻辑中通过 `Constants.XXX` 全局访问。

# ---------------------------------------------------------------------------
# 渲染 / 分辨率（NES 原版基准）
# ---------------------------------------------------------------------------
const BASE_RESOLUTION := Vector2i(256, 240)
const TARGET_FPS := 60

# ---------------------------------------------------------------------------
# 场地尺寸（逻辑坐标，单位 px）—— GDD 3.2
# ---------------------------------------------------------------------------
const COURT_WIDTH := 256
const COURT_HEIGHT := 192
const INFIELD_WIDTH := 96          # 单侧内场宽度
const INFIELD_HEIGHT := 128        # 内场高度
const OUTFIELD_CHANNEL_WIDTH := 32 # 外场通道宽度
const COURT_CENTER_X := 128        # 中线 X 坐标

# ---------------------------------------------------------------------------
# 角色属性范围 —— GDD 4.1
# ---------------------------------------------------------------------------
const HP_MIN := 1
const HP_MAX := 64
const STAT_MIN := 1   # ATK / DEF / SPD / JMP 下限
const STAT_MAX := 16  # ATK / DEF / SPD / JMP 上限

# ---------------------------------------------------------------------------
# 角色移动 / 跳跃（M1）—— 单位换算为基于秒（move_and_slide 使用 px/秒）
# ---------------------------------------------------------------------------
const MOVE_SPEED_PER_SPD := 10.0    # 每点 SPD 对应的移动速度（px/秒）
const JUMP_VELOCITY_PER_JMP := 14.0 # 每点 JMP 对应的起跳垂直初速度（px/秒）
const JUMP_GRAVITY := 520.0         # 跳跃高度的重力加速度（px/秒^2）

# ---------------------------------------------------------------------------
# 球物理参数 —— original_game_data.md 4.3
# ---------------------------------------------------------------------------
const BALL_BASE_SPEED := 3.0        # 基础球速（px/帧）
const BALL_SPEED_PER_ATK := 0.25    # 每点 ATK 增加的球速
const BALL_GRAVITY := 0.25          # 抛物线重力加速度（px/帧^2）
const BALL_BOUNCE_DAMPING := 0.6    # 每次反弹的速度衰减系数
const BALL_MAX_BOUNCES := 3         # 反弹次数上限（之后转滚动）
const BALL_ROLL_FRICTION := 0.05    # 滚动摩擦衰减
const BALL_SPEED_DECAY := 0.5       # 飞行距离衰减系数（speed *= 1 - d/max*0.5）

# ---------------------------------------------------------------------------
# 伤害公式常量 —— original_game_data.md 4.1 / 4.2
# damage = ball_speed * (ATK / ATK_DIVISOR) * (DEF_DIVISOR / DEF)
# ---------------------------------------------------------------------------
const DAMAGE_ATK_DIVISOR := 8.0
const DAMAGE_DEF_DIVISOR := 8.0
const SPECIAL_MULTIPLIER_MIN := 1.5
const SPECIAL_MULTIPLIER_MAX := 3.0

# ---------------------------------------------------------------------------
# 接球 / 闪避 —— original_game_data.md 4.4 / GDD 7
# ---------------------------------------------------------------------------
const CATCH_BASE := 4.0             # 基础可接球速度阈值
const CATCH_PER_DEF := 0.5          # 每点 DEF 增加的阈值
const CATCH_WINDOW_NORMAL := 6      # 普通接球判定窗口（帧）
const CATCH_WINDOW_HARD := 3        # 困难必杀技窗口（帧）
const CATCH_WINDOW_EXTREME := 1     # 极难必杀技窗口（帧）

# ---------------------------------------------------------------------------
# 碰撞判定参数 —— original_game_data.md 6
# ---------------------------------------------------------------------------
const HITBOX_STAND := Vector2i(12, 16)  # 角色站立碰撞框
const HITBOX_JUMP := Vector2i(8, 8)     # 角色跳跃碰撞框
const HITBOX_BALL := Vector2i(6, 6)     # 球碰撞框
const CATCHBOX := Vector2i(16, 20)      # 接球判定框
const INVINCIBLE_FRAMES := 30           # 被击中后无敌帧
const GETUP_FRAMES := 45                # 倒地恢复帧
const KNOCKBACK_NORMAL := Vector2i(16, 32) # 普通击退距离范围
const KNOCKBACK_SPECIAL := Vector2i(32, 64) # 必杀技击退距离范围

# ---------------------------------------------------------------------------
# 队伍编号 —— original_game_data.md 1
# ---------------------------------------------------------------------------
enum Team { JAPAN, INDIA, ICELAND, CHINA, AFRICA, ENGLAND, USA, USSR }

# 世界杯对战顺序（玩家固定为 JAPAN）
const WORLD_CUP_ORDER := [
	Team.INDIA, Team.ICELAND, Team.CHINA, Team.AFRICA,
	Team.ENGLAND, Team.USA, Team.USSR,
]

const PLAYERS_PER_TEAM := 6
const INFIELD_PLAYERS := 3
const OUTFIELD_PLAYERS := 3

# ---------------------------------------------------------------------------
# AI 难度等级 —— GDD 9.2
# ---------------------------------------------------------------------------
enum AIDifficulty { EASY, NORMAL, HARD, EXPERT }


## 根据角色 ATK 计算投球初速度。
func ball_initial_speed(atk: int) -> float:
	return BALL_BASE_SPEED + float(atk) * BALL_SPEED_PER_ATK


## 计算普通投球伤害。
func calc_damage(ball_speed: float, atk: int, def: int) -> float:
	var safe_def: int = max(def, STAT_MIN)
	return ball_speed * (float(atk) / DAMAGE_ATK_DIVISOR) * (DAMAGE_DEF_DIVISOR / float(safe_def))


## 计算接球速度阈值。
func catch_threshold(def: int) -> float:
	return CATCH_BASE + float(def) * CATCH_PER_DEF
