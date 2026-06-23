extends Node
## L5 / M5（AI 系统）核心逻辑 headless 回归测试。
##
## 运行：godot --path source --headless res://tests/test_l5.tscn
## 直接构造比赛 + AIController，逐帧驱动 AI 与角色物理，验证目标选择、投球出手、
## 接球/闪避决策与难度参数差异。
##
## headless 无渲染：AIController._draw 不触发；逻辑均可在 _physics_process 中跑通。

const FRAME := 1.0 / 60.0
const CHAR_SCENE := preload("res://scenes/character.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const AI_SCRIPT := preload("res://scripts/character/ai_controller.gd")

var _failures := 0


func _ready() -> void:
	print("=== L5 / M5 headless tests ===")
	_test_difficulty_params()
	_test_target_selection_quality()
	_test_attack_throws_ball()
	_test_defend_catches_slow_ball()
	_test_defend_dodges_fast_ball()
	if _failures == 0:
		print("ALL TESTS PASSED")
		get_tree().quit(0)
	else:
		print("TESTS FAILED: %d" % _failures)
		get_tree().quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] " + msg)
	else:
		_failures += 1
		print("  [FAIL] " + msg)


# ---------------------------------------------------------------------------
# 测试夹具
# ---------------------------------------------------------------------------

func _make_team(left: bool, team_id: int) -> Array[Character]:
	var team: Array[Character] = []
	var infield := CourtGeometry.infield_rect(left)
	var out_rects := CourtGeometry.outfield_rects(left)
	for i in Constants.INFIELD_PLAYERS:
		var c := _make_char(left, team_id, true)
		c.bounds_rects = [infield]
		c.global_position = infield.get_center() + Vector2(0, -40 + i * 40)
		add_child(c)
		team.append(c)
	for i in Constants.OUTFIELD_PLAYERS:
		var c := _make_char(left, team_id, false)
		c.bounds_rects = out_rects
		c.global_position = out_rects[i % out_rects.size()].get_center()
		add_child(c)
		team.append(c)
	return team


func _make_char(left: bool, team_id: int, infield: bool) -> Character:
	var c: Character = CHAR_SCENE.instantiate()
	c.is_left_team = left
	c.is_infield = infield
	c.team = team_id
	return c


func _new_match() -> Array:
	var left := _make_team(true, Constants.Team.JAPAN)
	var right := _make_team(false, Constants.Team.INDIA)
	var ball: Ball = BALL_SCENE.instantiate()
	add_child(ball)
	GameManager.setup_match(left, right, ball)
	GameManager.start_match()
	return [left, right, ball]


func _make_ai(c: Character, ball: Ball, diff: int) -> AIController:
	var ai: AIController = AI_SCRIPT.new()
	ai.setup(c, ball, diff)
	add_child(ai)
	return ai


## 逐帧驱动一名 AI 与其角色（AI 先写意图，角色随后消费）。
func _step(ai: AIController, c: Character, frames: int) -> void:
	for i in frames:
		ai._physics_process(FRAME)
		c._physics_process(FRAME)


func _teardown(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()


# ---------------------------------------------------------------------------
# 测试用例
# ---------------------------------------------------------------------------

func _test_difficulty_params() -> void:
	print("- difficulty params escalate (SP-M05.7)")
	var p := AIController.DIFFICULTY
	_check(p.size() == 4, "四级难度参数齐备")
	_check(p[0].reaction > p[3].reaction, "反应延迟：EASY > EXPERT")
	_check(p[0].quality < p[3].quality, "决策质量：EASY < EXPERT")
	_check(p[0].jitter > p[3].jitter, "站位精度：EASY 偏差更大")
	_check(p[0].catch_corr < p[3].catch_corr, "接球修正：EASY < EXPERT")


func _test_target_selection_quality() -> void:
	print("- expert AI targets lowest-HP enemy (SP-M05.4)")
	var m := _new_match()
	var left: Array = m[0]
	var right: Array = m[1]
	var ball: Ball = m[2]
	# 右队 AI 选择左队（敌方）内场目标：令 left[1] HP 最低
	left[0].current_hp = 30
	left[1].current_hp = 5
	left[2].current_hp = 30
	var ai := _make_ai(right[0], ball, Constants.AIDifficulty.EXPERT)
	var t := ai._choose_target()
	_check(t == left[1], "EXPERT 必选 HP 最低的内场敌人")
	_teardown(left + right + [ball, ai])


func _test_attack_throws_ball() -> void:
	print("- holding AI throws at enemy (SP-M05.4)")
	var m := _new_match()
	var left: Array = m[0]
	var right: Array = m[1]
	var ball: Ball = m[2]
	var shooter: Character = right[0]
	# 强制 shooter 持球（拾球不切换至 HOLD：角色持球时仍处于 IDLE/MOVE）
	ball.global_position = shooter.global_position
	ball.hold_by(shooter)
	_check(ball.holder == shooter, "shooter 成为持球者")
	var ai := _make_ai(shooter, ball, Constants.AIDifficulty.EXPERT)
	var threw := false
	for i in 60:
		ai._physics_process(FRAME)
		shooter._physics_process(FRAME)
		ball._physics_process(FRAME)
		if ball.state == Ball.State.FLYING:
			threw = true
			break
	_check(threw, "AI 在瞄准延迟后投出球")
	_check(ball.thrower == shooter, "投球者为该 AI 角色")
	_teardown(left + right + [ball, ai])


func _test_defend_catches_slow_ball() -> void:
	print("- AI catches slow incoming ball (SP-M05.5)")
	var m := _new_match()
	var left: Array = m[0]
	var right: Array = m[1]
	var ball: Ball = m[2]
	var defender: Character = left[0]
	var attacker: Character = right[0]
	defender.global_position = Vector2(100, 120)
	# 慢速来球（低于接球阈值），从右侧朝左飞向 defender
	ball.holder = null  # 清除跳球分配的持球者
	ball.thrower = attacker
	ball.has_damage = true
	ball.duckable = true
	ball.state = Ball.State.FLYING
	ball.global_position = defender.global_position + Vector2(40, 0)
	ball.ground_velocity = Vector2(-Constants.CATCH_BASE * 30.0, 0)  # 远低于阈值
	var ai := _make_ai(defender, ball, Constants.AIDifficulty.EXPERT)
	var reacted_catch := false
	for i in 30:
		ai._physics_process(FRAME)
		defender._physics_process(FRAME)
		if ai._defend_action == "catch":
			reacted_catch = true
			break
	_check(ai.ai_state == AIController.AIState.DEFEND, "进入 DEFEND 状态")
	_check(reacted_catch, "对慢速球选择接球")
	_teardown(left + right + [ball, ai])


func _test_defend_dodges_fast_ball() -> void:
	print("- AI dodges fast incoming ball (SP-M05.5)")
	var m := _new_match()
	var left: Array = m[0]
	var right: Array = m[1]
	var ball: Ball = m[2]
	var defender: Character = left[0]
	var attacker: Character = right[0]
	defender.global_position = Vector2(100, 120)
	# 高速直线球（远超阈值），可下蹲躲
	ball.holder = null  # 清除跳球分配的持球者
	ball.thrower = attacker
	ball.has_damage = true
	ball.duckable = true
	ball.state = Ball.State.FLYING
	ball.global_position = defender.global_position + Vector2(40, 0)
	ball.ground_velocity = Vector2(-Constants.CATCH_BASE * 60.0 * 4.0, 0)
	var ai := _make_ai(defender, ball, Constants.AIDifficulty.EXPERT)
	var dodged := false
	for i in 30:
		ai._physics_process(FRAME)
		defender._physics_process(FRAME)
		if ai._defend_action == "crouch" or ai._defend_action == "side":
			dodged = true
			break
	_check(dodged, "对高速球选择闪避（下蹲/侧移）")
	_teardown(left + right + [ball, ai])
