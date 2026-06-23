class_name Character
extends CharacterBody2D
## 角色控制器（M1 + M3）。
##
## 实现 8 方向移动、伪 3D 跳跃、内场/外场区域约束，以及状态机框架。
## M3 新增：HP 系统、接球判定窗口（Catch）、被击中击退（Hit）、倒地恢复（Down）。
## 关联风险：RISK-07（状态机设计）。
##
## 占位精灵：使用 _draw() 绘制彩色矩形 + 阴影 + 朝向指示 + HP 条，按队伍着色（SP-M01.5）。

signal state_changed(from: int, to: int)
signal was_hit(damage: float)        # 被球击中（接球失败）
signal eliminated                    # HP 归零倒地瞬间（M4 用于即时反馈）
signal down_finished                 # 倒地动画结束、等待 GameManager 转外场（SP-M04.3）

## 角色状态。CROUCH 追加在末尾以保持既有枚举值不变。
enum State { IDLE, MOVE, JUMP, HOLD, THROW, CATCH, HIT, DOWN, OUT, CROUCH }

## 允许的状态转换表（M3 扩展版，含下蹲）。
const TRANSITIONS := {
	State.IDLE: [State.MOVE, State.JUMP, State.HOLD, State.CATCH, State.CROUCH, State.HIT, State.DOWN, State.OUT],
	State.MOVE: [State.IDLE, State.JUMP, State.HOLD, State.CATCH, State.CROUCH, State.HIT, State.DOWN, State.OUT],
	State.JUMP: [State.IDLE, State.MOVE, State.CATCH, State.HOLD, State.HIT, State.DOWN, State.OUT],
	State.HOLD: [State.IDLE, State.MOVE, State.JUMP, State.THROW, State.HIT, State.DOWN, State.OUT],
	State.THROW: [State.IDLE, State.MOVE, State.HIT, State.DOWN, State.OUT],
	State.CATCH: [State.IDLE, State.MOVE, State.HOLD, State.HIT, State.DOWN, State.OUT],
	State.CROUCH: [State.IDLE, State.MOVE, State.HIT, State.DOWN, State.OUT],
	State.HIT: [State.IDLE, State.MOVE, State.DOWN, State.OUT],
	State.DOWN: [State.IDLE, State.OUT],
	State.OUT: [State.IDLE],
}

const SPRITE_SIZE := Vector2(16, 24)

# 被击中 / 倒地相关常量
const HIT_KNOCKBACK_FRAMES := 18     # 击退滑动持续帧
const KNOCKBACK_DECAY := 0.82        # 每帧击退速度衰减
const KNOCKBACK_SPEED_FACTOR := 11.0 # 击退距离(px) → 初始击退速度(px/秒) 的换算系数
const GETUP_INVINCIBLE := 20         # 倒地起身后的短暂无敌帧
const CROUCH_HIT_HEIGHT := 7.0       # 下蹲时可被命中的高度上限（低于直线球高度）

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

# --- M3 战斗状态 ---
var current_hp := 0                  # 当前 HP（_ready 时初始化为 hp）
var invincible_timer := 0            # 剩余无敌帧
var catch_timer := 0                 # 接球判定窗口剩余帧（>0 表示正在尝试接球）
var hit_timer := 0                   # 被击中击退剩余帧
var down_timer := 0                  # 倒地剩余帧
var knockback_vel := Vector2.ZERO    # 击退速度（px/秒）
var last_attacker: Character = null  # 最近一次击中本角色的投球者（用于反杀判定 SP-M04.4）

# --- M5 AI 意图注入 ---
# player_controlled=false 时，由 AIController 每帧写入下列意图，复用角色既有状态机。
# ai_move 为期望移动向量（连续值）；ai_jump / ai_catch 为单帧边沿信号，被本帧消费后清零。
var ai_move := Vector2.ZERO
var ai_jump := false
var ai_catch := false
var ai_crouch := false

@onready var _collision: CollisionShape2D = $CollisionShape2D

# 队伍配色（占位）
const TEAM_COLORS := [
	Color("e23b3b"), Color("e2a13b"), Color("8ad6f0"), Color("e2e23b"),
	Color("d68a3b"), Color("3b6be2"), Color("ffffff"), Color("9b3be2"),
]


func _ready() -> void:
	add_to_group(&"characters")
	current_hp = hp
	_apply_hitbox(false)


## 同队友（用于传球目标选择）。
func is_teammate(other: Character) -> bool:
	return other != self and other.is_left_team == is_left_team


func _physics_process(delta: float) -> void:
	_tick_timers()

	# 受击 / 倒地状态独立处理：忽略玩家输入
	match state:
		State.HIT:
			_process_hit(delta)
			queue_redraw()
			return
		State.DOWN:
			_process_down(delta)
			queue_redraw()
			return

	var move_dir := Vector2.ZERO
	var jump_pressed := false
	var catch_pressed := false
	var crouch_held := false
	if player_controlled:
		move_dir = GameInput.get_movement_vector_8()
		jump_pressed = GameInput.is_just_pressed(GameInput.JUMP)
		catch_pressed = GameInput.is_just_pressed(GameInput.THROW)
		crouch_held = GameInput.is_pressed(GameInput.CROUCH)
	else:
		# AI 意图（由 AIController 注入）。边沿信号消费后立即清零，避免重复触发。
		move_dir = ai_move
		jump_pressed = ai_jump
		catch_pressed = ai_catch
		crouch_held = ai_crouch
		ai_jump = false
		ai_catch = false

	# 下蹲（しゃがむ）：仅地面、未持球时；期间不可移动/跳跃/接球，可躲直线球
	if _update_crouch(crouch_held):
		velocity = Vector2.ZERO
		move_and_slide()
		_apply_region_constraint()
		queue_redraw()
		return

	_update_jump(delta, jump_pressed)
	_update_catch(catch_pressed)
	_update_locomotion(move_dir)

	velocity = move_dir * float(spd) * Constants.MOVE_SPEED_PER_SPD
	move_and_slide()
	_apply_region_constraint()
	queue_redraw()


# ---------------------------------------------------------------------------
# 计时器 / 接球窗口（SP-M03.2）
# ---------------------------------------------------------------------------

func _tick_timers() -> void:
	if invincible_timer > 0:
		invincible_timer -= 1
	if catch_timer > 0:
		catch_timer -= 1
		# 窗口耗尽且仍处于 CATCH，退回 Idle/Move
		if catch_timer == 0 and state == State.CATCH:
			var moving := player_controlled and GameInput.get_movement_vector_8() != Vector2.ZERO
			state = State.IDLE  # 直接复位以允许立即转移
			_set_state(State.MOVE if moving else State.IDLE)


## 按下接球键（A）：仅在 Idle/Move 且未持球时开启接球判定窗口。
func _update_catch(catch_pressed: bool) -> void:
	if not catch_pressed:
		return
	if _is_holding_ball():
		return  # 持球时 A 键用于投球（由 Court 处理），不触发接球
	if state in [State.IDLE, State.MOVE]:
		catch_timer = Constants.CATCH_WINDOW_NORMAL
		_set_state(State.CATCH)


## 下蹲处理。返回 true 表示本帧处于下蹲（调用方应跳过移动/跳跃）。
func _update_crouch(crouch_held: bool) -> bool:
	if crouch_held and state != State.JUMP and not _is_holding_ball():
		if state == State.IDLE or state == State.MOVE:
			_set_state(State.CROUCH)
		return state == State.CROUCH
	if state == State.CROUCH:
		state = State.IDLE  # 直接复位以允许立即转移
		_set_state(State.IDLE)
	return false


## 本角色当前是否持有球。
func _is_holding_ball() -> bool:
	for node in get_tree().get_nodes_in_group(&"ball"):
		if node is Ball and node.holder == self:
			return true
	return false


# ---------------------------------------------------------------------------
# 移动 / 状态
# ---------------------------------------------------------------------------

func _update_locomotion(move_dir: Vector2) -> void:
	if move_dir != Vector2.ZERO:
		facing = move_dir
	# 跳跃 / 接球窗口期间不改变地面状态机（保持 JUMP / CATCH）
	if state == State.JUMP or state == State.CATCH:
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


## 强制切换状态（跳过转换校验）。用于被击中等"任意 → Hit/Down"的硬中断。
func _force_state(next: int) -> void:
	if next == state:
		return
	var prev := state
	state = next
	state_changed.emit(prev, next)


# ---------------------------------------------------------------------------
# M3：碰撞辅助 / 接球 / 受击 / 倒地
# ---------------------------------------------------------------------------

func is_jumping() -> bool:
	return state == State.JUMP or height > 0.0


func is_invincible() -> bool:
	return invincible_timer > 0


func is_catching() -> bool:
	return catch_timer > 0


func is_crouching() -> bool:
	return state == State.CROUCH


## 当前地面碰撞框尺寸（跳跃时缩小，SP-M03.1）。
func current_hitbox() -> Vector2:
	return Vector2(Constants.HITBOX_JUMP) if is_jumping() else Vector2(Constants.HITBOX_STAND)


## 球可命中的垂直高度上限。跳跃时更低；下蹲可降低（除非来球不可蹲躲，如跳投）。
func hit_height_ceiling(ignore_crouch := false) -> float:
	if is_jumping():
		return 8.0
	if state == State.CROUCH and not ignore_crouch:
		return CROUCH_HIT_HEIGHT
	return 16.0


## 判定本次接球是否成功（SP-M03.3）：
## 需面朝来球 + 球速不超过 1.5× 阈值；高速球（>阈值）判定窗口减半。
func can_catch(ball: Ball) -> bool:
	if not is_catching():
		return false
	var speed_pf := ball.ground_velocity.length() / 60.0  # px/秒 → px/帧
	var threshold := Constants.catch_threshold(def)
	# 超过 1.5× 阈值：无法接球
	if speed_pf > threshold * 1.5:
		return false
	# 高速球窗口减半
	var allowed := Constants.CATCH_WINDOW_NORMAL
	if speed_pf > threshold:
		allowed = Constants.CATCH_WINDOW_HARD
	var elapsed := Constants.CATCH_WINDOW_NORMAL - catch_timer
	if elapsed >= allowed:
		return false
	# 面朝来球：facing 与来球行进方向应大致相反
	var ball_dir := ball.ground_velocity.normalized()
	if facing.dot(ball_dir) > -0.2:
		return false
	return true


## 接球成功：持球并进入 Hold（SP-M03.3）。
func catch_ball(ball: Ball) -> void:
	catch_timer = 0
	_set_state(State.HOLD)
	ball.hold_by(self)


## 被球击中（接球失败或未尝试接球）：扣 HP + 击退 + 无敌帧（SP-M03.4 / SP-M03.5）。
func take_hit(damage: float, dir: Vector2, ball_speed_pps: float, attacker: Character = null) -> void:
	if is_invincible():
		return
	last_attacker = attacker
	current_hp = maxi(current_hp - int(ceilf(damage)), 0)
	was_hit.emit(damage)
	invincible_timer = Constants.INVINCIBLE_FRAMES
	catch_timer = 0
	# 跳跃中被击中：落地
	height = 0.0
	height_vel = 0.0
	_apply_hitbox(false)
	var dist := Constants.knockback_distance(ball_speed_pps)
	knockback_vel = dir.normalized() * dist * KNOCKBACK_SPEED_FACTOR
	hit_timer = HIT_KNOCKBACK_FRAMES
	_force_state(State.HIT)


func _process_hit(_delta: float) -> void:
	velocity = knockback_vel
	move_and_slide()
	_apply_region_constraint()
	knockback_vel *= KNOCKBACK_DECAY
	hit_timer -= 1
	if hit_timer <= 0:
		velocity = Vector2.ZERO
		knockback_vel = Vector2.ZERO
		if current_hp <= 0:
			down_timer = Constants.GETUP_FRAMES
			_force_state(State.DOWN)
			eliminated.emit()
		else:
			_force_state(State.IDLE)


func _process_down(_delta: float) -> void:
	velocity = Vector2.ZERO
	down_timer -= 1
	if down_timer <= 0:
		# 倒地结束：进入 OUT 等待 GameManager 处理内外场转移（SP-M04.3）。
		# 比赛场景下 GameManager 监听 down_finished 完成转外场/反杀。
		_force_state(State.OUT)
		down_finished.emit()


## 内外场转移后重置为可行动的 Idle 状态（由 GameManager 调用，SP-M04.3/.4）。
func reset_after_transfer() -> void:
	invincible_timer = GETUP_INVINCIBLE
	catch_timer = 0
	hit_timer = 0
	down_timer = 0
	knockback_vel = Vector2.ZERO
	velocity = Vector2.ZERO
	height = 0.0
	height_vel = 0.0
	_apply_hitbox(false)
	_force_state(State.IDLE)
	_apply_region_constraint()
	queue_redraw()


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

	# 倒地：绘制压扁的身体（SP-M03.6）
	if state == State.DOWN:
		var flat := Rect2(-SPRITE_SIZE.x * 0.5, SPRITE_SIZE.y * 0.5 - 6.0, SPRITE_SIZE.x, 6.0)
		draw_rect(flat, color.darkened(0.3))
		draw_rect(flat, Color(0, 0, 0, 0.6), false, 1.0)
		_draw_hp_bar()
		return

	# 下蹲：压低的身体（只覆盖下半身，表现可躲直线球）
	if state == State.CROUCH:
		var ch := SPRITE_SIZE.y * 0.55
		var crect := Rect2(-SPRITE_SIZE.x * 0.5, SPRITE_SIZE.y * 0.5 - ch, SPRITE_SIZE.x, ch)
		draw_circle(Vector2(0, SPRITE_SIZE.y * 0.5), 6.0, Color(0, 0, 0, 0.35))
		draw_rect(crect, color)
		draw_rect(crect, Color(0, 0, 0, 0.6), false, 1.0)
		var c := crect.get_center()
		draw_line(c, c + facing * 6.0, Color(0, 0, 0, 0.8), 1.5)
		_draw_hp_bar()
		return

	var body := Rect2(-SPRITE_SIZE * 0.5 - Vector2(0, height), SPRITE_SIZE)
	# 地面阴影（随跳跃高度缩小）
	var shadow_scale := clampf(1.0 - height / 64.0, 0.4, 1.0)
	draw_circle(Vector2(0, SPRITE_SIZE.y * 0.5), 6.0 * shadow_scale, Color(0, 0, 0, 0.35))

	# 无敌帧闪烁：每 4 帧切换显隐（SP-M03.5）
	var blink := is_invincible() and (invincible_timer / 4) % 2 == 0
	if not blink:
		# 接球窗口：青色高亮描边（SP-M03.2）
		if is_catching():
			draw_rect(body.grow(2.0), Color(0.2, 0.9, 1.0, 0.9), false, 1.5)
		draw_rect(body, color)
		draw_rect(body, Color(0, 0, 0, 0.6), false, 1.0)
		# 朝向指示
		var center := body.get_center()
		draw_line(center, center + facing * 8.0, Color(0, 0, 0, 0.8), 1.5)

	_draw_hp_bar()


## 头顶 HP 条（占位 HUD，SP-M03.4）。
func _draw_hp_bar() -> void:
	var w := SPRITE_SIZE.x
	var top := -SPRITE_SIZE.y * 0.5 - height - 5.0
	var ratio := clampf(float(current_hp) / float(maxi(hp, 1)), 0.0, 1.0)
	var bg := Rect2(-w * 0.5, top, w, 2.0)
	draw_rect(bg, Color(0, 0, 0, 0.6))
	var fill_col := Color(0.3, 0.9, 0.3)
	if ratio < 0.3:
		fill_col = Color(0.9, 0.25, 0.25)
	elif ratio < 0.6:
		fill_col = Color(0.95, 0.8, 0.2)
	draw_rect(Rect2(-w * 0.5, top, w * ratio, 2.0), fill_col)
