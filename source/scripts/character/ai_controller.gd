class_name AIController
extends Node2D
## AI 行为控制器（M5）。
##
## 驱动非玩家角色完成巡逻/站位/追球/拾球/投球/传球/接球闪避等行为。
## 通过向 Character 注入意图（ai_move / ai_jump / ai_catch / ai_crouch）复用既有角色
## 状态机；持球时直接调用 Ball.throw / Ball.pass_to。
##
## 行为状态：PATROL / CHASE / ATTACK / PASS / DEFEND / POSITION（见 GDD §9）。
## 难度参数：EASY / NORMAL / HARD / EXPERT（反应延迟、决策质量、必杀率、接球修正、站位精度）。

enum AIState { PATROL, CHASE, ATTACK, PASS, DEFEND, POSITION }

## 全局调试可视化开关（决策状态标签 + 目标连线），由 Court 按键切换。
static var debug_draw := false

## 触发威胁判定的来球半径（px）。
const THREAT_RADIUS := 72.0

## 难度参数表（索引 = Constants.AIDifficulty）。
##   reaction     反应延迟（帧）：越大越迟钝
##   quality      目标选择质量（0=随机，1=必选最优）
##   special_rate 必杀技（跳投）使用倾向（占位，M6 细化）
##   catch_corr   接球意愿阈值修正（提高则更敢接快球）
##   jitter       站位精度偏差（px）
const DIFFICULTY := [
	{"reaction": 20, "quality": 0.0, "special_rate": 0.10, "catch_corr": -0.30, "jitter": 24.0},
	{"reaction": 12, "quality": 0.70, "special_rate": 0.40, "catch_corr": 0.0, "jitter": 16.0},
	{"reaction": 6, "quality": 0.90, "special_rate": 0.70, "catch_corr": 0.20, "jitter": 8.0},
	{"reaction": 2, "quality": 1.0, "special_rate": 1.0, "catch_corr": 0.40, "jitter": 2.0},
]

const STATE_NAMES := ["PATROL", "CHASE", "ATTACK", "PASS", "DEFEND", "POSITION"]

var character: Character = null
var ball: Ball = null
var difficulty := 1                  # Constants.AIDifficulty.NORMAL
var ai_state: int = AIState.PATROL
var home_position := Vector2.ZERO

var _params: Dictionary = DIFFICULTY[1]
var _prev_state: int = -1

# 决策计时 / 反应
var _threat_timer := 0               # 当前来球已被跟踪的帧数
var _reacted := false                # 已对当前来球做出反应
var _defend_action := ""             # "catch" / "crouch" / "side"
var _side_dir := Vector2.ZERO        # 侧移闪避方向

# 持球
var _hold_timer := 0                 # 持球瞄准/出手计时
var _want_special := false           # 本次进攻是否尝试跳投
var _target: Character = null        # 当前投球目标


func setup(c: Character, b: Ball, diff: int) -> void:
	character = c
	ball = b
	set_difficulty(diff)
	home_position = c.global_position


func set_difficulty(diff: int) -> void:
	difficulty = clampi(diff, 0, DIFFICULTY.size() - 1)
	_params = DIFFICULTY[difficulty]


# ---------------------------------------------------------------------------
# 主循环
# ---------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if character == null or not is_instance_valid(character):
		queue_free()
		return
	global_position = character.global_position
	if debug_draw:
		queue_redraw()

	# 比赛未进行 / 角色处于硬中断状态：保持静止，交由角色自身处理
	if not GameManager.is_in_progress() \
			or character.state in [Character.State.HIT, Character.State.DOWN, Character.State.OUT] \
			or ball == null or not is_instance_valid(ball):
		_clear_intent()
		return

	_update_state()
	if ai_state != _prev_state:
		_on_enter_state(ai_state)
		_prev_state = ai_state
	_clear_intent()
	_execute_state()


func _clear_intent() -> void:
	if character == null:
		return
	character.ai_move = Vector2.ZERO
	character.ai_jump = false
	character.ai_catch = false
	character.ai_crouch = false


# ---------------------------------------------------------------------------
# 状态选择（优先级：持球 > 来球威胁 > 拾球 > 站位/巡逻）
# ---------------------------------------------------------------------------

func _update_state() -> void:
	if _holding():
		ai_state = AIState.PASS if _should_pass() else AIState.ATTACK
	elif _ball_is_threat():
		ai_state = AIState.DEFEND
	elif _should_chase():
		ai_state = AIState.CHASE
	elif _enemy_has_ball():
		ai_state = AIState.POSITION
	else:
		ai_state = AIState.PATROL


func _on_enter_state(s: int) -> void:
	match s:
		AIState.ATTACK:
			_hold_timer = 0
			_target = null
			_want_special = randf() < float(_params.special_rate)
		AIState.PASS:
			_hold_timer = 0
		AIState.DEFEND:
			_threat_timer = 0
			_reacted = false
			_defend_action = ""


func _execute_state() -> void:
	match ai_state:
		AIState.PATROL:
			_execute_patrol()
		AIState.POSITION:
			_execute_position()
		AIState.CHASE:
			_execute_chase()
		AIState.DEFEND:
			_execute_defend()
		AIState.ATTACK:
			_execute_attack()
		AIState.PASS:
			_execute_pass()


# ---------------------------------------------------------------------------
# 行为：巡逻 / 站位（SP-M05.2）
# ---------------------------------------------------------------------------

## 无球且球未被任何一方持有：守在出生站位附近，面向球。
func _execute_patrol() -> void:
	_move_toward(home_position, maxf(float(_params.jitter), 6.0))
	if character.ai_move == Vector2.ZERO:
		_face(ball.global_position)


## 对方持球时的防守站位：己方持球则前压，否则纵向跟随球以便拦截，面向球。
func _execute_position() -> void:
	var target := home_position
	if _team_has_ball():
		target.x += _attack_dir_x() * 24.0
	else:
		target.y = lerpf(home_position.y, ball.global_position.y, 0.4)
	var j: float = float(_params.jitter)
	target += Vector2(randf_range(-j, j), randf_range(-j, j))
	_move_toward(target, maxf(j, 4.0))
	if character.ai_move == Vector2.ZERO:
		_face(ball.global_position)


# ---------------------------------------------------------------------------
# 行为：追球 / 拾球（SP-M05.3）
# ---------------------------------------------------------------------------

## 移向松弛的球；进入拾球半径后由 Ball 自动拾取。
func _execute_chase() -> void:
	_move_toward(ball.global_position, 2.0)


# ---------------------------------------------------------------------------
# 行为：接球 / 闪避（SP-M05.5）
# ---------------------------------------------------------------------------

func _execute_defend() -> void:
	_face(ball.global_position)
	if not _reacted:
		_threat_timer += 1
		if _threat_timer < int(_params.reaction):
			return
		_reacted = true
		var speed_pf := ball.ground_velocity.length() / 60.0
		var eff := Constants.catch_threshold(character.def) * (1.0 + float(_params.catch_corr))
		if speed_pf <= eff:
			_defend_action = "catch"
		elif ball.duckable:
			_defend_action = "crouch"
		else:
			_defend_action = "side"
			var perp := ball.ground_velocity.normalized().orthogonal()
			var away := character.global_position - ball.global_position
			_side_dir = perp if away.dot(perp) >= 0.0 else -perp
	# 持续应用已决定的反应
	match _defend_action:
		"catch":
			character.ai_move = (ball.global_position - character.global_position).normalized()
			character.ai_catch = true
		"crouch":
			character.ai_crouch = true
		"side":
			character.ai_move = _side_dir


# ---------------------------------------------------------------------------
# 行为：投球（SP-M05.4） / 传球（SP-M05.6）
# ---------------------------------------------------------------------------

func _execute_attack() -> void:
	if not _valid_target(_target):
		_target = _choose_target()
	if _target == null:
		_execute_pass()  # 无可投目标 → 退化为传球
		return
	_face(_target.global_position)
	_hold_timer += 1
	# 必杀（跳投）倾向：先起跳，待离地后以 JUMP 类型出手。
	# 注意：持球时角色处于 IDLE/MOVE（拾球不切换至 HOLD），故以是否离地为判据。
	if _want_special and not character.is_jumping():
		character.ai_jump = true
	if _hold_timer >= int(_params.reaction) + 8:
		if _want_special and not character.is_jumping():
			return  # 等待离地后再投
		_throw_at(_target)


func _execute_pass() -> void:
	var mate := _best_pass_mate()
	if mate == null:
		# 无队友可传：若有敌方目标则改为投球
		var t := _choose_target()
		if t != null:
			_face(t.global_position)
			_hold_timer += 1
			if _hold_timer >= int(_params.reaction) + 8:
				_throw_at(t)
		return
	_face(mate.global_position)
	_hold_timer += 1
	if _hold_timer >= int(_params.reaction) + 4:
		ball.pass_to(mate.global_position)
		_hold_timer = 0


func _throw_at(t: Character) -> void:
	var dir := (t.global_position - character.global_position).normalized()
	character.facing = dir
	var type := Ball.ThrowType.JUMP if character.is_jumping() else Ball.ThrowType.STRAIGHT
	ball.throw(dir, character.atk, type, character.height)
	_hold_timer = 0


## 目标选择（SP-M05.4）：按难度质量决定取最优（HP 最低 → 最近）或随机。
func _choose_target() -> Character:
	var enemies := _enemy_infield()
	if enemies.is_empty():
		return null
	if randf() <= float(_params.quality):
		enemies.sort_custom(_cmp_target)
		return enemies[0]
	return enemies[randi() % enemies.size()]


func _cmp_target(a: Character, b: Character) -> bool:
	if a.current_hp != b.current_hp:
		return a.current_hp < b.current_hp
	var da := a.global_position.distance_squared_to(character.global_position)
	var db := b.global_position.distance_squared_to(character.global_position)
	return da < db


# ---------------------------------------------------------------------------
# 移动 / 朝向辅助
# ---------------------------------------------------------------------------

func _move_toward(target: Vector2, deadzone: float) -> void:
	var d := target - character.global_position
	if d.length() <= deadzone:
		character.ai_move = Vector2.ZERO
	else:
		character.ai_move = d.normalized()


func _face(world_pos: Vector2) -> void:
	var d := world_pos - character.global_position
	if d.length() > 0.01:
		character.facing = d.normalized()


## 己方进攻方向的 x 符号（左队向右，右队向左）。
func _attack_dir_x() -> float:
	return 1.0 if character.is_left_team else -1.0


# ---------------------------------------------------------------------------
# 查询辅助
# ---------------------------------------------------------------------------

func _holding() -> bool:
	return ball.holder == character


func _team_has_ball() -> bool:
	return ball.holder is Character and (ball.holder as Character).is_left_team == character.is_left_team


func _enemy_has_ball() -> bool:
	return ball.holder is Character and (ball.holder as Character).is_left_team != character.is_left_team


func _valid_target(t: Character) -> bool:
	return is_instance_valid(t) and t.is_infield \
			and t.state != Character.State.DOWN and t.state != Character.State.OUT


## 来球是否构成威胁：飞行中、有伤害、对方投出、朝我飞来且距离够近。
func _ball_is_threat() -> bool:
	if ball.state != Ball.State.FLYING or not ball.has_damage:
		return false
	if ball.thrower == null or ball.thrower.is_left_team == character.is_left_team:
		return false
	if character.is_invincible():
		return false
	var to_self := character.global_position - ball.global_position
	if to_self.length() > THREAT_RADIUS:
		return false
	var vel := ball.ground_velocity
	if vel.length() < 1.0:
		return false
	return vel.normalized().dot(to_self.normalized()) >= 0.5


## 仅由距离球最近的活动队友负责追球，避免全队抢球。
func _should_chase() -> bool:
	if ball.holder != null:
		return false
	if ball.state != Ball.State.IDLE and ball.state != Ball.State.ROLLING:
		return false
	return _nearest_teammate_to_ball() == character


func _enemy_infield() -> Array[Character]:
	var out: Array[Character] = []
	for n in character.get_tree().get_nodes_in_group(&"characters"):
		var c := n as Character
		if c == null or c.is_left_team == character.is_left_team or not c.is_infield:
			continue
		if c.state == Character.State.DOWN or c.state == Character.State.OUT:
			continue
		out.append(c)
	return out


func _nearest_teammate_to_ball() -> Character:
	var best: Character = null
	var best_d := INF
	for n in character.get_tree().get_nodes_in_group(&"characters"):
		var c := n as Character
		if c == null or c.is_left_team != character.is_left_team:
			continue
		if c.state in [Character.State.DOWN, Character.State.OUT, Character.State.HIT]:
			continue
		var d: float = c.global_position.distance_squared_to(ball.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


## 是否选择传球：无敌方内场可投，或自身在外场且有内场队友（按概率）。
func _should_pass() -> bool:
	if _enemy_infield().is_empty():
		return true
	if not character.is_infield and _best_pass_mate() != null:
		return randf() < 0.5
	return false


## 传球目标：最靠近敌方半场（进攻进度最大）的活动内场队友。
func _best_pass_mate() -> Character:
	var best: Character = null
	var best_prog := -INF
	for n in character.get_tree().get_nodes_in_group(&"characters"):
		var c := n as Character
		if c == null or c == character or c.is_left_team != character.is_left_team:
			continue
		if not c.is_infield or c.state == Character.State.DOWN or c.state == Character.State.OUT:
			continue
		var prog := c.global_position.x * _attack_dir_x()
		if prog > best_prog:
			best_prog = prog
			best = c
	return best


# ---------------------------------------------------------------------------
# 调试可视化（SP-M05.8）
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not debug_draw or character == null:
		return
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-16, -22), STATE_NAMES[ai_state],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1, 0.9))
	if _target != null and is_instance_valid(_target):
		draw_line(Vector2.ZERO, _target.global_position - character.global_position,
				Color(1, 0.3, 0.3, 0.7), 1.0)
