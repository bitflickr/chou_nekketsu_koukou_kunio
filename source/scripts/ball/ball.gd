class_name Ball
extends Area2D
## 球物理（M2）。伪 3D：地面坐标 (x,y) + 高度 z。
##
## 状态：Held → Flying → Rolling → Idle，以及被拾取/接住的回路。
## 实现投球抛物线、球速距离衰减、地面反弹（3 次后滚动）、滚动到静止、
## 自动拾球与传球。关联风险：RISK-01（数值来源）。
##
## 占位渲染：_draw() 绘制球与地面阴影（阴影位置/大小随高度变化）。

signal state_changed(from: int, to: int)
signal picked_up(by: Node2D)

enum State { HELD, FLYING, ROLLING, IDLE }

# 物理常量（px、px/秒）。由 original_game_data.md 的每帧数值换算而来。
const GRAVITY_PPS2 := 640.0       # 高度方向重力
const THROW_VZ := 120.0           # 投球起跳垂直初速度（形成抛物线）
const PASS_SPEED_PPS := 90.0      # 传球地面速度（较慢、无伤害）
const PASS_VZ := 40.0             # 传球轻微抛物
const MAX_RANGE := 256.0          # 用于球速距离衰减的最大射程
const PICKUP_RADIUS := 12.0       # 自动拾球半径
const ROLL_DECEL_PPS2 := 160.0    # 滚动线性减速
const STOP_SPEED := 6.0           # 低于此速度视为静止
const HELD_OFFSET := 8.0          # 持球时相对持球者朝向的偏移

var state: int = State.IDLE
var height := 0.0                 # z 高度
var height_vel := 0.0
var ground_velocity := Vector2.ZERO  # px/秒
var initial_speed := 0.0          # 本次投球初速度（用于衰减）
var travelled := 0.0              # 已飞行地面距离
var bounce_count := 0
var has_damage := true            # 投球有伤害；传球无伤害（M3 使用）
var catchable := false            # 低速球更易接住（M3 使用）

var holder: Node2D = null

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group(&"ball")


func _physics_process(delta: float) -> void:
	match state:
		State.HELD:
			_process_held()
		State.FLYING:
			_process_flying(delta)
		State.ROLLING:
			_process_rolling(delta)
		State.IDLE:
			_try_pickup()
	queue_redraw()


# ---------------------------------------------------------------------------
# 状态处理
# ---------------------------------------------------------------------------

func _process_held() -> void:
	if not is_instance_valid(holder):
		_set_state(State.IDLE)
		holder = null
		return
	var facing: Vector2 = holder.get("facing") if holder.get("facing") != null else Vector2.DOWN
	global_position = holder.global_position + facing * HELD_OFFSET
	height = 8.0


func _process_flying(delta: float) -> void:
	# 距离衰减：speed = initial * (1 - travelled/MAX_RANGE * BALL_SPEED_DECAY)
	var dir := ground_velocity.normalized()
	var factor := clampf(1.0 - travelled / MAX_RANGE * Constants.BALL_SPEED_DECAY, 0.2, 1.0)
	var speed := initial_speed * factor
	ground_velocity = dir * speed
	catchable = speed <= Constants.CATCH_BASE * 60.0

	var step := ground_velocity * delta
	global_position += step
	travelled += step.length()
	_bounce_walls()

	# 高度抛物线
	height_vel -= GRAVITY_PPS2 * delta
	height += height_vel * delta
	if height <= 0.0:
		_on_ground_contact()


func _on_ground_contact() -> void:
	height = 0.0
	if bounce_count < Constants.BALL_MAX_BOUNCES:
		bounce_count += 1
		height_vel = absf(height_vel) * Constants.BALL_BOUNCE_DAMPING
		# 反弹时地面速度也衰减
		ground_velocity *= Constants.BALL_BOUNCE_DAMPING
		initial_speed *= Constants.BALL_BOUNCE_DAMPING
		travelled = 0.0
	else:
		height_vel = 0.0
		_set_state(State.ROLLING)


func _process_rolling(delta: float) -> void:
	height = 0.0
	var speed := ground_velocity.length()
	speed = maxf(speed - ROLL_DECEL_PPS2 * delta, 0.0)
	if speed <= STOP_SPEED:
		ground_velocity = Vector2.ZERO
		_set_state(State.IDLE)
		return
	ground_velocity = ground_velocity.normalized() * speed
	global_position += ground_velocity * delta
	_bounce_walls()
	_try_pickup()


## 球碰到球场边界时反弹（带衰减），避免飞出界外消失。
func _bounce_walls() -> void:
	var r := CourtGeometry.COURT_RECT
	var p := global_position
	var damp := Constants.BALL_BOUNCE_DAMPING
	if p.x < r.position.x:
		p.x = r.position.x
		ground_velocity.x = absf(ground_velocity.x) * damp
	elif p.x > r.end.x:
		p.x = r.end.x
		ground_velocity.x = -absf(ground_velocity.x) * damp
	if p.y < r.position.y:
		p.y = r.position.y
		ground_velocity.y = absf(ground_velocity.y) * damp
	elif p.y > r.end.y:
		p.y = r.end.y
		ground_velocity.y = -absf(ground_velocity.y) * damp
	global_position = p


func _try_pickup() -> void:
	for c in get_tree().get_nodes_in_group(&"characters"):
		if c is Node2D and global_position.distance_to(c.global_position) <= PICKUP_RADIUS:
			hold_by(c)
			return


# ---------------------------------------------------------------------------
# 公共接口
# ---------------------------------------------------------------------------

## 被角色拾取/持有。
func hold_by(character: Node2D) -> void:
	holder = character
	ground_velocity = Vector2.ZERO
	height_vel = 0.0
	bounce_count = 0
	_set_state(State.HELD)
	picked_up.emit(character)


## 投球：方向单位向量 + 投球者攻击力。
func throw(direction: Vector2, atk: int) -> void:
	holder = null
	has_damage = true
	bounce_count = 0
	travelled = 0.0
	initial_speed = Constants.ball_initial_speed(atk) * 60.0  # px/帧 → px/秒
	ground_velocity = direction.normalized() * initial_speed
	height_vel = THROW_VZ
	_set_state(State.FLYING)


## 传球：飞向目标位置，低速、无伤害。
func pass_to(target_pos: Vector2) -> void:
	holder = null
	has_damage = false
	bounce_count = 0
	travelled = 0.0
	initial_speed = PASS_SPEED_PPS
	ground_velocity = (target_pos - global_position).normalized() * PASS_SPEED_PPS
	height_vel = PASS_VZ
	_set_state(State.FLYING)


# ---------------------------------------------------------------------------
# 内部
# ---------------------------------------------------------------------------

func _set_state(next: int) -> void:
	if next == state:
		return
	var prev := state
	state = next
	state_changed.emit(prev, next)


func _draw() -> void:
	# 地面阴影（随高度上升而变小、变淡）
	var shadow_scale := clampf(1.0 - height / 48.0, 0.4, 1.0)
	draw_circle(Vector2.ZERO, 3.5 * shadow_scale, Color(0, 0, 0, 0.3))
	# 球本体（按高度向上偏移）
	var ball_pos := Vector2(0, -height)
	draw_circle(ball_pos, 3.0, Color(1.0, 0.95, 0.6))
	draw_arc(ball_pos, 3.0, 0, TAU, 12, Color(0.2, 0.15, 0.0), 0.8)
