extends Node
## L3 / M4（比赛流程）核心逻辑 headless 回归测试。
##
## 运行：godot --path source --headless res://tests/test_l3.tscn
## 直接构造双方队伍并驱动 GameManager 的开球、内外场转移、反杀与胜负逻辑。
## headless 无玩家输入，故通过直接施加致命伤害 + 驱动角色物理帧来触发淘汰流程。

const FRAME := 1.0 / 60.0
const CHAR_SCENE := preload("res://scenes/character.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")

var _failures := 0


func _ready() -> void:
	print("=== L3 / M4 headless tests ===")
	_test_jump_ball_possession()
	_test_infield_to_outfield()
	_test_outfield_reverse_kill()
	_test_win_condition()
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


## 对 victim 施加致命伤害并驱动其物理帧直到完成倒地→转移流程。
func _eliminate(victim: Character, attacker: Character) -> void:
	victim.invincible_timer = 0
	victim.current_hp = 1
	victim.take_hit(999.0, Vector2.RIGHT, 240.0, attacker)
	for i in 200:
		victim._physics_process(FRAME)
		if victim.state == Character.State.IDLE and not victim.is_infield:
			return  # 已完成转外场


func _teardown(left: Array, right: Array, ball: Ball) -> void:
	for c in left + right:
		c.queue_free()
	ball.queue_free()


# ---------------------------------------------------------------------------
# 测试用例
# ---------------------------------------------------------------------------

func _test_jump_ball_possession() -> void:
	print("- jump ball assigns possession (SP-M04.1/.2)")
	var m := _new_match()
	var left: Array = m[0]
	var right: Array = m[1]
	var ball: Ball = m[2]
	_check(GameManager.match_state == GameManager.MatchState.IN_PROGRESS, "开球后进入 IN_PROGRESS")
	_check(ball.holder is Character, "跳球胜者持球")
	if ball.holder is Character:
		var holder := ball.holder as Character
		_check(GameManager.left_has_possession == holder.is_left_team, "持球权与持球者阵营一致")
		_check(holder.is_infield, "跳球者为内场球员")
	_teardown(left, right, ball)


func _test_infield_to_outfield() -> void:
	print("- infield elimination -> outfield (SP-M04.3)")
	var m := _new_match()
	var left: Array = m[0]
	var right: Array = m[1]
	var ball: Ball = m[2]
	var victim: Character = right[0]
	var attacker: Character = left[0]
	_eliminate(victim, attacker)
	_check(not victim.is_infield, "被淘汰内场球员转为外场")
	_check(victim.current_hp == victim.hp, "转外场后 HP 重置为满")
	_check(GameManager.infield_count(false) == 2, "右队内场剩余 2 人")
	# 外场区域约束：victim 位置应落在右队外场矩形内
	var in_outfield := false
	for r in CourtGeometry.outfield_rects(false):
		if r.grow(8).has_point(victim.global_position):
			in_outfield = true
	_check(in_outfield, "转外场后位置位于外场通道")
	_teardown(left, right, ball)


func _test_outfield_reverse_kill() -> void:
	print("- outfield reverse-kill returns to infield (SP-M04.4)")
	var m := _new_match()
	var left: Array = m[0]
	var right: Array = m[1]
	var ball: Ball = m[2]
	# 先让左队一名内场被淘汰，腾出内场空位（GDD §8.6.5 需有空位才能返回）
	_eliminate(left[0], right[0])
	_check(GameManager.infield_count(true) == 2, "前置：左队内场被淘汰 1 人，余 2")
	# 左队外场球员反杀对方内场 → 返回内场填补空位
	var out_attacker: Character = left[3]
	_check(not out_attacker.is_infield, "前置：反杀者为外场球员")
	out_attacker.current_hp = out_attacker.hp - 5  # 反杀后应保留此 HP（不恢复）
	var hp_before := out_attacker.current_hp
	_eliminate(right[1], out_attacker)
	_check(out_attacker.is_infield, "外场反杀者返回内场")
	_check(out_attacker.current_hp == hp_before, "返回内场 HP 不恢复")
	_check(GameManager.infield_count(true) == 3, "左队内场回补至 3 人")
	_teardown(left, right, ball)


func _test_win_condition() -> void:
	print("- clearing enemy infield wins match (SP-M04.5)")
	var m := _new_match()
	var left: Array = m[0]
	var right: Array = m[1]
	var ball: Ball = m[2]
	var attacker: Character = left[0]
	var won_left := [false]
	GameManager.match_ended.connect(func(lw: bool) -> void: won_left[0] = lw, CONNECT_ONE_SHOT)
	for i in Constants.INFIELD_PLAYERS:
		_eliminate(right[i], attacker)
	_check(GameManager.infield_count(false) == 0, "右队内场清空")
	_check(GameManager.match_state == GameManager.MatchState.MATCH_END, "比赛进入 MATCH_END")
	_check(won_left[0], "左队获胜（match_ended 信号）")
	_teardown(left, right, ball)
