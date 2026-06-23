extends Node2D
## 球场根场景脚本 + M4 比赛流程集成场景。
##
## 层级结构：
##   - BackgroundLayer：球场背景与线条
##   - CharacterLayer：角色精灵
##   - BallLayer：球
##   - UILayer：HUD / 触屏控件（CanvasLayer，不随相机滚动）
##
## M4：部署双方完整队伍（各 3 内场 + 3 外场），交由 GameManager 驱动
## 开球跳球 → 比赛循环 → 内外场切换 → 胜负判定。玩家操控左队一名内场球员。
## 调试：按 T 切换敌方自动投球（便于验证玩家方受击与内外场转移）。

const CHARACTER_SCENE := preload("res://scenes/character.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/touch_controls.tscn")
const MATCH_HUD_SCRIPT := preload("res://scripts/ui/match_hud.gd")

@onready var background_layer: Node2D = $BackgroundLayer
@onready var character_layer: Node2D = $CharacterLayer
@onready var ball_layer: Node2D = $BallLayer
@onready var ui_layer: CanvasLayer = $UILayer

var _player: Character
var _ball: Ball
var _left_team: Array[Character] = []
var _right_team: Array[Character] = []

# --- M5：AI 控制器 ---
var _ai_controllers: Array[AIController] = []
var _ai_difficulty := Constants.AIDifficulty.NORMAL

# --- 调试：敌方自动投球（验证玩家方受击与内外场转移）。按 T 切换。---
const AUTO_THROW_INTERVAL := 2.5
var _auto_throw_on := false
var _auto_throw_t := 0.0
var _hint_label: Label


func _ready() -> void:
	print("[Court] ready — base resolution %s" % Constants.BASE_RESOLUTION)
	randomize()
	_spawn_teams()
	_spawn_ball()
	_spawn_ai()
	_spawn_ui()
	# 等待一帧确保所有角色 _ready 完成后再注册并开球
	GameManager.setup_match(_left_team, _right_team, _ball)
	GameManager.start_match.call_deferred()


# ---------------------------------------------------------------------------
# 队伍部署（SP-M04.6）
# ---------------------------------------------------------------------------

func _spawn_teams() -> void:
	_left_team = _spawn_team(true, Constants.Team.JAPAN, true)
	_right_team = _spawn_team(false, Constants.Team.INDIA, false)
	_player = _left_team[0]
	_player.player_controlled = true


## 部署单支队伍：3 名内场 + 3 名外场。返回全部 6 名角色（前 3 为内场）。
func _spawn_team(left: bool, team_id: int, _is_player_side: bool) -> Array[Character]:
	var members: Array[Character] = []
	var infield := CourtGeometry.infield_rect(left)
	var face := Vector2.RIGHT if left else Vector2.LEFT
	var center := infield.get_center()

	# 内场 3 名（纵向排布）
	for i in Constants.INFIELD_PLAYERS:
		var c := _make_character(left, team_id, true)
		c.bounds_rects = [infield]
		c.global_position = center + Vector2(0, -40 + i * 40)
		c.facing = face
		character_layer.add_child(c)
		members.append(c)

	# 外场 3 名（分布于对方半场外围三侧通道）
	var out_rects := CourtGeometry.outfield_rects(left)
	for i in Constants.OUTFIELD_PLAYERS:
		var c := _make_character(left, team_id, false)
		c.bounds_rects = out_rects
		c.global_position = out_rects[i % out_rects.size()].get_center()
		c.facing = face
		character_layer.add_child(c)
		members.append(c)

	return members


func _make_character(left: bool, team_id: int, infield: bool) -> Character:
	var c: Character = CHARACTER_SCENE.instantiate()
	c.is_left_team = left
	c.is_infield = infield
	c.team = team_id
	return c


func _spawn_ball() -> void:
	_ball = BALL_SCENE.instantiate()
	_ball.global_position = Vector2(CourtGeometry.CENTER_X, CourtGeometry.INFIELD_TOP + Constants.INFIELD_HEIGHT * 0.5)
	ball_layer.add_child(_ball)


# ---------------------------------------------------------------------------
# AI 控制器（SP-M05）
# ---------------------------------------------------------------------------

## 为所有非玩家角色挂载 AIController（含玩家方队友），构成完整可对战的比赛。
func _spawn_ai() -> void:
	for c in _left_team + _right_team:
		if c == _player:
			continue
		var ai := AIController.new()
		ai.name = "AI_%s_%d" % ["L" if c.is_left_team else "R", c.get_index()]
		ai.setup(c, _ball, _ai_difficulty)
		character_layer.add_child(ai)
		_ai_controllers.append(ai)


func _set_ai_difficulty(diff: int) -> void:
	_ai_difficulty = clampi(diff, 0, AIController.DIFFICULTY.size() - 1)
	for ai in _ai_controllers:
		if is_instance_valid(ai):
			ai.set_difficulty(_ai_difficulty)
	_update_hint()


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _spawn_ui() -> void:
	ui_layer.add_child(TOUCH_CONTROLS_SCENE.instantiate())
	var hud := Control.new()
	hud.set_script(MATCH_HUD_SCRIPT)
	ui_layer.add_child(hud)
	_spawn_reset_button()
	_spawn_hint_label()


func _spawn_hint_label() -> void:
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 7)
	_hint_label.position = Vector2(4, 30)
	ui_layer.add_child(_hint_label)
	_update_hint()


func _update_hint() -> void:
	if _hint_label != null:
		var diff_names := ["EASY", "NORMAL", "HARD", "EXPERT"]
		_hint_label.text = "AI: %s (1-4) | AI-DBG: %s (Y) | RESET (R)" % [
			diff_names[_ai_difficulty], "ON" if AIController.debug_draw else "OFF",
		]


func _spawn_reset_button() -> void:
	var btn := Button.new()
	btn.text = "RESET"
	btn.add_theme_font_size_override("font_size", 8)
	btn.position = Vector2(Constants.BASE_RESOLUTION.x - 44, 4)
	btn.size = Vector2(40, 14)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_reset)
	ui_layer.add_child(btn)


func _reset() -> void:
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_reset()
			KEY_T:
				_auto_throw_on = not _auto_throw_on
				_auto_throw_t = 0.0
				_update_hint()
			KEY_Y:
				AIController.debug_draw = not AIController.debug_draw
				_update_hint()
			KEY_1:
				_set_ai_difficulty(Constants.AIDifficulty.EASY)
			KEY_2:
				_set_ai_difficulty(Constants.AIDifficulty.NORMAL)
			KEY_3:
				_set_ai_difficulty(Constants.AIDifficulty.HARD)
			KEY_4:
				_set_ai_difficulty(Constants.AIDifficulty.EXPERT)


# ---------------------------------------------------------------------------
# 玩家操作 + 调试敌方投球
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not GameManager.is_in_progress():
		return
	if not is_instance_valid(_player) or not is_instance_valid(_ball):
		return
	# 玩家持球时响应投/传
	if _ball.state == Ball.State.HELD and _ball.holder == _player:
		if GameInput.is_just_pressed(GameInput.THROW):
			var t := Ball.ThrowType.JUMP if _player.is_jumping() else Ball.ThrowType.STRAIGHT
			_ball.throw(_player.facing, _player.atk, t, _player.height)
		elif GameInput.is_just_pressed(GameInput.PASS):
			var mate := _nearest_teammate(_player)
			if mate != null:
				_ball.pass_to(mate.global_position)

	if _auto_throw_on:
		_process_enemy_auto_throw(delta)


## 调试：周期性让一名右队球员拿球投向最近的左队内场球员。
func _process_enemy_auto_throw(delta: float) -> void:
	if _ball.state == Ball.State.HELD and _ball.holder is Character \
			and (_ball.holder as Character).is_left_team:
		return
	_auto_throw_t += delta
	if _auto_throw_t < AUTO_THROW_INTERVAL:
		return
	_auto_throw_t = 0.0
	var shooter := _pick_active(_right_team)
	if shooter == null:
		return
	var target := _nearest_infield_enemy(shooter)
	if target == null:
		return
	_ball.global_position = shooter.global_position
	_ball.hold_by(shooter)
	var dir := (target.global_position - shooter.global_position).normalized()
	shooter.facing = dir
	_ball.throw(dir, shooter.atk, Ball.ThrowType.STRAIGHT)


func _pick_active(team: Array[Character]) -> Character:
	for c in team:
		if is_instance_valid(c) and c.state != Character.State.DOWN \
				and c.state != Character.State.OUT and c.state != Character.State.HIT:
			return c
	return null


func _nearest_infield_enemy(from: Character) -> Character:
	var best: Character = null
	var best_d := INF
	for c in get_tree().get_nodes_in_group(&"characters"):
		if c is Character and c.is_left_team != from.is_left_team and c.is_infield:
			var d: float = from.global_position.distance_squared_to(c.global_position)
			if d < best_d:
				best_d = d
				best = c
	return best


func _nearest_teammate(from: Character) -> Character:
	var best: Character = null
	var best_d := INF
	for c in get_tree().get_nodes_in_group(&"characters"):
		if c is Character and from.is_teammate(c):
			var d: float = from.global_position.distance_squared_to(c.global_position)
			if d < best_d:
				best_d = d
				best = c
	return best
