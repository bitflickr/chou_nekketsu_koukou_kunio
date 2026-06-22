extends Node
## L1（M1/M2）核心逻辑 headless 回归测试。
##
## 运行：godot --path source --headless res://tests/test_l1.tscn
## （以场景方式运行以保证 AutoLoad Constants/GameInput 可用）
## 由于 headless 无法注入玩家输入，本测试直接驱动物理与区域约束逻辑。

const FRAME := 1.0 / 60.0

var _failures := 0


func _ready() -> void:
	print("=== L1 headless tests ===")
	_test_region_clamp()
	_test_ball_throw_to_roll_to_idle()
	_test_ball_stays_in_bounds()
	_test_ball_pickup()
	_test_pass_no_damage()
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


func _step_ball(ball: Ball, frames: int) -> void:
	for i in frames:
		ball._physics_process(FRAME)


func _test_region_clamp() -> void:
	print("- region clamp")
	var infield := CourtGeometry.infield_rect(true)
	var half := Vector2(Constants.HITBOX_STAND) * 0.5
	var outside := Vector2(-100, -100)
	var clamped := CourtGeometry.clamp_to_rect(outside, infield, half)
	_check(infield.grow(-1).has_point(clamped) or infield.has_point(clamped),
		"位置被钳制进内场矩形")
	_check(clamped.x >= infield.position.x + half.x - 0.01, "左边界约束生效")


func _test_ball_throw_to_roll_to_idle() -> void:
	print("- ball throw -> bounce -> roll -> idle")
	var ball: Ball = preload("res://scenes/ball.tscn").instantiate()
	add_child(ball)
	ball.global_position = Vector2(40, 120)
	ball.throw(Vector2.RIGHT, 8)
	_check(ball.state == Ball.State.FLYING, "投球后进入 FLYING")
	var saw_air := false
	for i in 600:
		ball._physics_process(FRAME)
		if ball.height > 0.5:
			saw_air = true
		if ball.state == Ball.State.IDLE:
			break
	_check(saw_air, "飞行过程中出现抛物线高度")
	_check(ball.bounce_count == Constants.BALL_MAX_BOUNCES, "反弹达到上限 %d 次" % Constants.BALL_MAX_BOUNCES)
	_check(ball.state == Ball.State.IDLE, "最终停止为 IDLE")
	_check(ball.ground_velocity.length() < 0.01, "静止时速度归零")
	ball.queue_free()


func _test_ball_stays_in_bounds() -> void:
	print("- ball stays within court bounds")
	var ball: Ball = preload("res://scenes/ball.tscn").instantiate()
	add_child(ball)
	var court := CourtGeometry.COURT_RECT
	ball.global_position = Vector2(court.end.x - 8, 120)
	ball.throw(Vector2.RIGHT, 16)  # 朝右墙投出
	var max_x := -INF
	var min_x := INF
	for i in 600:
		ball._physics_process(FRAME)
		max_x = maxf(max_x, ball.global_position.x)
		min_x = minf(min_x, ball.global_position.x)
		if ball.state == Ball.State.IDLE:
			break
	_check(max_x <= court.end.x + 0.01, "球未飞出右边界 (max_x=%.1f <= %.1f)" % [max_x, court.end.x])
	_check(min_x >= court.position.x - 0.01, "球未飞出左边界")
	_check(court.grow(1).has_point(ball.global_position), "球最终停留在球场内")
	ball.queue_free()


func _test_ball_pickup() -> void:
	print("- ball pickup")
	var ball: Ball = preload("res://scenes/ball.tscn").instantiate()
	var character: Character = preload("res://scenes/character.tscn").instantiate()
	add_child(character)
	add_child(ball)
	character.global_position = Vector2(100, 100)
	ball.global_position = Vector2(104, 100)  # 在拾球半径内
	ball._physics_process(FRAME)
	_check(ball.state == Ball.State.HELD, "靠近时被拾取为 HELD")
	_check(ball.holder == character, "持球者为该角色")
	ball.queue_free()
	character.queue_free()


func _test_pass_no_damage() -> void:
	print("- pass has no damage")
	var ball: Ball = preload("res://scenes/ball.tscn").instantiate()
	add_child(ball)
	ball.global_position = Vector2(60, 120)
	ball.pass_to(Vector2(120, 120))
	_check(ball.state == Ball.State.FLYING, "传球后进入 FLYING")
	_check(ball.has_damage == false, "传球无伤害标记")
	_check(ball.initial_speed < Constants.ball_initial_speed(8) * 60.0, "传球速度低于普通投球")
	ball.queue_free()
