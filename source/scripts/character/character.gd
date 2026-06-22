class_name Character
extends CharacterBody2D
## 角色控制器（M1）。
##
## 实现 8 方向移动、伪 3D 跳跃、内场/外场区域约束，以及一个轻量状态机框架
## （Idle / Move / Jump 已实现，Hold / Throw / Catch / Hit / Down / Out 预留接口）。
## 关联风险：RISK-07（状态机设计）。
##
## 占位精灵：使用 _draw() 绘制彩色矩形 + 阴影 + 朝向指示，按队伍着色（SP-M01.5）。

signal state_changed(from: int, to: int)

## 角色状态。M1 仅激活前三个，其余为后续里程碑预留。
enum State { IDLE, MOVE, JUMP, HOLD, THROW, CATCH, HIT, DOWN, OUT }

## 允许的状态转换表（M1 框架版，后续里程碑扩展）。
const TRANSITIONS := {
	State.IDLE: [State.MOVE, State.JUMP, State.HOLD, State.HIT, State.OUT],
	State.MOVE: [State.IDLE, State.JUMP, State.HOLD, State.HIT, State.OUT],
	State.JUMP: [State.IDLE, State.MOVE, State.CATCH, State.HIT, State.OUT],
	State.HOLD: [State.IDLE, State.MOVE, State.JUMP, State.THROW, State.HIT, State.OUT],
	State.THROW: [State.IDLE, State.MOVE, State.HIT, State.OUT],
	State.CATCH: [State.IDLE, State.MOVE, State.HOLD, State.HIT, State.OUT],
	State.HIT: [State.IDLE, State.DOWN, State.OUT],
	State.DOWN: [State.IDLE, State.OUT],
	State.OUT: [State.IDLE],
}

const SPRITE_SIZE := Vector2(16, 24)

@export var player_controlled := false
@export var is_left_team := true
@export var is_infield := true
@export_range(1, 8) var team := 0  # Constants.Team
# 角色属性（默认中庸值，正式数据在 M7 接入 original_game_data.md）
@export_range(1, 64) var hp := 36
@export_range(1, 16) var atk := 8
@export_range(1, 16) var def := 8
@export_range(1, 16) var spd := 10
@export_range(1, 16) var jmp := 10

var state: int = State.IDLE
var facing := Vector2.DOWN
# 伪 3D 跳跃高度（z），仅影响视觉与碰撞框，不影响地面坐标
var height := 0.0
var height_vel := 0.0
# 区域约束矩形（由 Court 注入）。为空时回退到整个球场矩形。
var bounds_rects: Array[Rect2] = []

@onready var _collision: CollisionShape2D = $CollisionShape2D

# 队伍配色（占位）
const TEAM_COLORS := [
	Color("e23b3b"), Color("e2a13b"), Color("8ad6f0"), Color("e2e23b"),
	Color("d68a3b"), Color("3b6be2"), Color("ffffff"), Color("9b3be2"),
]


func _ready() -> void:
	add_to_group(&"characters")
	_apply_hitbox(false)


## 同队友（用于传球目标选择）。
func is_teammate(other: Character) -> bool:
	return other != self and other.is_left_team == is_left_team


func _physics_process(delta: float) -> void:
	var move_dir := Vector2.ZERO
	var jump_pressed := false
	if player_controlled:
		move_dir = GameInput.get_movement_vector_8()
		jump_pressed = GameInput.is_just_pressed(GameInput.JUMP)

	_update_jump(delta, jump_pressed)
	_update_locomotion(move_dir)

	velocity = move_dir * float(spd) * Constants.MOVE_SPEED_PER_SPD
	move_and_slide()
	_apply_region_constraint()
	queue_redraw()


# ---------------------------------------------------------------------------
# 移动 / 状态
# ---------------------------------------------------------------------------

func _update_locomotion(move_dir: Vector2) -> void:
	if move_dir != Vector2.ZERO:
		facing = move_dir
	# 跳跃中不改变地面状态机（保持 JUMP）
	if state == State.JUMP:
		return
	if move_dir != Vector2.ZERO:
		_set_state(State.MOVE)
	else:
		_set_state(State.IDLE)


func _update_jump(delta: float, jump_pressed: bool) -> void:
	if state != State.JUMP and jump_pressed and _can_jump():
		height_vel = float(jmp) * Constants.JUMP_VELOCITY_PER_JMP
		_set_state(State.JUMP)
		_apply_hitbox(true)
	if state == State.JUMP:
		height_vel -= Constants.JUMP_GRAVITY * delta
		height += height_vel * delta
		if height <= 0.0:
			height = 0.0
			height_vel = 0.0
			_apply_hitbox(false)
			# 落地后根据当前输入回到 Move/Idle
			var move_dir := Vector2.ZERO
			if player_controlled:
				move_dir = GameInput.get_movement_vector_8()
			state = State.IDLE  # 直接复位以允许立即转移
			_set_state(State.MOVE if move_dir != Vector2.ZERO else State.IDLE)


func _can_jump() -> bool:
	return state in [State.IDLE, State.MOVE]


## 切换状态（带转换校验）。非法转换被忽略并打印警告。
func _set_state(next: int) -> void:
	if next == state:
		return
	if not TRANSITIONS.get(state, []).has(next):
		push_warning("[Character] 非法状态转换 %s -> %s" % [State.keys()[state], State.keys()[next]])
		return
	var prev := state
	state = next
	state_changed.emit(prev, next)


# ---------------------------------------------------------------------------
# 碰撞框 / 区域约束
# ---------------------------------------------------------------------------

func _apply_hitbox(in_air: bool) -> void:
	if _collision == null:
		return
	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		return
	shape.size = Vector2(Constants.HITBOX_JUMP) if in_air else Vector2(Constants.HITBOX_STAND)


func _apply_region_constraint() -> void:
	var half := Vector2(Constants.HITBOX_STAND) * 0.5
	if bounds_rects.is_empty():
		global_position = CourtGeometry.clamp_to_rect(global_position, CourtGeometry.COURT_RECT, half)
	else:
		global_position = CourtGeometry.clamp_to_rects(global_position, bounds_rects, half)


# ---------------------------------------------------------------------------
# 占位渲染
# ---------------------------------------------------------------------------

func _draw() -> void:
	var color: Color = TEAM_COLORS[clampi(team, 0, TEAM_COLORS.size() - 1)]
	var body := Rect2(-SPRITE_SIZE * 0.5 - Vector2(0, height), SPRITE_SIZE)
	# 地面阴影（随跳跃高度缩小）
	var shadow_scale := clampf(1.0 - height / 64.0, 0.4, 1.0)
	draw_circle(Vector2(0, SPRITE_SIZE.y * 0.5), 6.0 * shadow_scale, Color(0, 0, 0, 0.35))
	# 身体
	draw_rect(body, color)
	draw_rect(body, Color(0, 0, 0, 0.6), false, 1.0)
	# 朝向指示
	var center := body.get_center()
	draw_line(center, center + facing * 8.0, Color(0, 0, 0, 0.8), 1.5)
