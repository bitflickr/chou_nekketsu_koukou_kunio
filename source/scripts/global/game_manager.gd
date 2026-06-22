extends Node
## 比赛管理器（AutoLoad: GameManager）—— M4 比赛流程
##
## 状态机：PRE_MATCH → JUMP_BALL → IN_PROGRESS → MATCH_END
##
## 职责（SP-M04.1~.6）：
##   - 持有双方队伍引用，跟踪内场/外场名单
##   - 开球跳球决定首发球权（SP-M04.1）
##   - 持球权（possession）跟踪（SP-M04.2）
##   - 内场淘汰 → 转外场（SP-M04.3）
##   - 外场反杀 → 返回内场（SP-M04.4）
##   - 胜负判定与比赛流程时序（SP-M04.5/.6）
##
## 规则依据：GDD §8.6。Court 负责部署角色与球后调用 setup_match() / start_match()。

signal match_state_changed(from: int, to: int)
signal possession_changed(left_has_ball: bool)
signal infield_changed                  # 任一内场名单变化（HUD 刷新用）
signal match_ended(left_won: bool)

enum MatchState { PRE_MATCH, JUMP_BALL, IN_PROGRESS, MATCH_END }

var match_state: int = MatchState.PRE_MATCH
var left_team: Array[Character] = []     # 全部 6 名（左队 / 玩家方）
var right_team: Array[Character] = []    # 全部 6 名（右队 / 对手方）
var ball: Ball = null
var left_has_possession := true
var winner_is_left := false

var _left_infield_rect: Rect2
var _right_infield_rect: Rect2
var _left_outfield_rects: Array[Rect2] = []
var _right_outfield_rects: Array[Rect2] = []
var _connected: Array[Character] = []


## 部署完成后由 Court 调用，注册双方队伍与球，计算区域几何并连接信号。
func setup_match(left: Array[Character], right: Array[Character], match_ball: Ball) -> void:
	_disconnect_all()
	left_team = left.duplicate()
	right_team = right.duplicate()
	ball = match_ball

	_left_infield_rect = CourtGeometry.infield_rect(true)
	_right_infield_rect = CourtGeometry.infield_rect(false)
	_left_outfield_rects = CourtGeometry.outfield_rects(true)
	_right_outfield_rects = CourtGeometry.outfield_rects(false)

	for c in left_team + right_team:
		if is_instance_valid(c):
			c.down_finished.connect(_on_down_finished.bind(c))
			_connected.append(c)
	if is_instance_valid(ball):
		ball.picked_up.connect(_on_ball_picked_up)

	_set_state(MatchState.PRE_MATCH)


## 开始比赛：进入跳球 → 决定首发球权 → 进入比赛进行中（SP-M04.1/.6）。
func start_match() -> void:
	if left_team.is_empty() or right_team.is_empty():
		push_warning("[GameManager] start_match 前未部署队伍")
		return
	_set_state(MatchState.JUMP_BALL)
	_do_jump_ball()
	_set_state(MatchState.IN_PROGRESS)


# ---------------------------------------------------------------------------
# 开球跳球（SP-M04.1）
# ---------------------------------------------------------------------------

func _do_jump_ball() -> void:
	var lc := _jump_contestant(left_team)
	var rc := _jump_contestant(right_team)
	if lc == null or rc == null:
		return
	# 按 JMP 加权随机决定跳球胜者（GDD §8.6.1）
	var lj := maxi(lc.jmp, 1)
	var rj := maxi(rc.jmp, 1)
	var left_wins := randf() < float(lj) / float(lj + rj)
	var winner := lc if left_wins else rc
	if is_instance_valid(ball):
		ball.global_position = winner.global_position
		ball.hold_by(winner)
	_set_possession(left_wins)


## 选取一名参与跳球的内场球员（取最靠近中线者）。
func _jump_contestant(team: Array[Character]) -> Character:
	var best: Character = null
	var best_d := INF
	for c in team:
		if not is_instance_valid(c) or not c.is_infield:
			continue
		var d: float = absf(c.global_position.x - float(CourtGeometry.CENTER_X))
		if d < best_d:
			best_d = d
			best = c
	return best


# ---------------------------------------------------------------------------
# 持球权（SP-M04.2）
# ---------------------------------------------------------------------------

func _on_ball_picked_up(by: Node2D) -> void:
	if by is Character:
		_set_possession((by as Character).is_left_team)


func _set_possession(left_has_ball: bool) -> void:
	if left_has_possession == left_has_ball and match_state == MatchState.IN_PROGRESS:
		return
	left_has_possession = left_has_ball
	possession_changed.emit(left_has_ball)


# ---------------------------------------------------------------------------
# 内外场切换（SP-M04.3 / SP-M04.4）
# ---------------------------------------------------------------------------

func _on_down_finished(c: Character) -> void:
	if not is_instance_valid(c):
		return
	var attacker: Character = c.last_attacker
	# 被淘汰的内场球员 → 转己方外场（HP 重置为满）
	_move_to_outfield(c)
	# 外场反杀：若击杀者是对方外场球员，则其返回己方内场（HP 不恢复）
	if is_instance_valid(attacker) and not attacker.is_infield \
			and attacker.is_left_team != c.is_left_team:
		_return_to_infield(attacker)
	c.last_attacker = null
	infield_changed.emit()
	_check_win()


## 内场淘汰 → 转外场（GDD §8.6.4）。
func _move_to_outfield(c: Character) -> void:
	c.is_infield = false
	c.current_hp = c.hp  # 转外场 HP 重置为满，继续参战
	var rects := _left_outfield_rects if c.is_left_team else _right_outfield_rects
	c.bounds_rects = rects
	c.global_position = _outfield_spawn(rects, c.is_left_team)
	c.reset_after_transfer()


## 外场反杀 → 返回内场（GDD §8.6.5）。HP 不恢复；内场已满则保留外场。
func _return_to_infield(c: Character) -> void:
	if infield_count(c.is_left_team) >= Constants.INFIELD_PLAYERS:
		return
	c.is_infield = true
	var rect := _left_infield_rect if c.is_left_team else _right_infield_rect
	c.bounds_rects = [rect]
	c.global_position = rect.get_center()
	c.reset_after_transfer()


## 外场出生点：取远端通道中心（己方外场围绕对方半场）。
func _outfield_spawn(rects: Array[Rect2], _left_team: bool) -> Vector2:
	if rects.is_empty():
		return Vector2(CourtGeometry.CENTER_X, CourtGeometry.COURT_TOP + 8)
	# rects = [top_band, bottom_band, far_band]，优先放远端通道
	return rects[rects.size() - 1].get_center()


# ---------------------------------------------------------------------------
# 胜负判定（SP-M04.5）
# ---------------------------------------------------------------------------

## 统计某队当前内场存活人数。
func infield_count(left: bool) -> int:
	var team := left_team if left else right_team
	var n := 0
	for c in team:
		if is_instance_valid(c) and c.is_infield:
			n += 1
	return n


## 返回某队当前内场成员列表（HUD 用）。
func infield_members(left: bool) -> Array[Character]:
	var team := left_team if left else right_team
	var members: Array[Character] = []
	for c in team:
		if is_instance_valid(c) and c.is_infield:
			members.append(c)
	return members


func _check_win() -> void:
	if match_state != MatchState.IN_PROGRESS:
		return
	var left_in := infield_count(true)
	var right_in := infield_count(false)
	if left_in == 0:
		_end_match(false)
	elif right_in == 0:
		_end_match(true)


func _end_match(left_won: bool) -> void:
	winner_is_left = left_won
	_set_state(MatchState.MATCH_END)
	match_ended.emit(left_won)


# ---------------------------------------------------------------------------
# 状态机 / 清理
# ---------------------------------------------------------------------------

func _set_state(next: int) -> void:
	if next == match_state:
		return
	var prev := match_state
	match_state = next
	match_state_changed.emit(prev, next)


func is_in_progress() -> bool:
	return match_state == MatchState.IN_PROGRESS


func _disconnect_all() -> void:
	for c in _connected:
		if is_instance_valid(c) and c.down_finished.is_connected(_on_down_finished):
			c.down_finished.disconnect(_on_down_finished)
	_connected.clear()
	if is_instance_valid(ball) and ball.picked_up.is_connected(_on_ball_picked_up):
		ball.picked_up.disconnect(_on_ball_picked_up)
	left_team.clear()
	right_team.clear()
	ball = null
