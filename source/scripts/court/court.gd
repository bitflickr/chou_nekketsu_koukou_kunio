extends Node2D
## 球场根场景脚本 + M1/M2 集成测试场景。
##
## 层级结构：
##   - BackgroundLayer：球场背景与线条
##   - CharacterLayer：角色精灵
##   - BallLayer：球
##   - UILayer：HUD / 触屏控件（CanvasLayer，不随相机滚动）
##
## M1/M2/M3 测试内容：生成 1 名玩家角色 + 2 名同队友 + 3 名敌队角色 + 1 个球，
## 演示移动/跳跃/拾球/投球/传球，以及投球命中敌方扣 HP、接球与击退。

const CHARACTER_SCENE := preload("res://scenes/character.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/touch_controls.tscn")

@onready var background_layer: Node2D = $BackgroundLayer
@onready var character_layer: Node2D = $CharacterLayer
@onready var ball_layer: Node2D = $BallLayer
@onready var ui_layer: CanvasLayer = $UILayer

var _player: Character
var _ball: Ball


func _ready() -> void:
	print("[Court] ready — base resolution %s" % Constants.BASE_RESOLUTION)
	_spawn_characters()
	_spawn_ball()
	_spawn_touch_controls()


func _spawn_characters() -> void:
	var infield := CourtGeometry.infield_rect(true)
	# 玩家角色
	_player = CHARACTER_SCENE.instantiate()
	_player.player_controlled = true
	_player.is_left_team = true
	_player.team = Constants.Team.JAPAN
	_player.bounds_rects = [infield]
	_player.global_position = infield.get_center()
	character_layer.add_child(_player)

	# 两名同队友（无 AI，便于演示传球）
	for i in 2:
		var mate: Character = CHARACTER_SCENE.instantiate()
		mate.is_left_team = true
		mate.team = Constants.Team.JAPAN
		mate.bounds_rects = [infield]
		mate.global_position = infield.get_center() + Vector2(0, -32 + i * 64)
		character_layer.add_child(mate)

	# 敌队三名（右半场，无 AI，供 M3 投球命中/接球测试）
	var enemy_infield := CourtGeometry.infield_rect(false)
	for i in 3:
		var foe: Character = CHARACTER_SCENE.instantiate()
		foe.is_left_team = false
		foe.team = Constants.Team.INDIA
		foe.bounds_rects = [enemy_infield]
		foe.global_position = enemy_infield.get_center() + Vector2(0, -48 + i * 48)
		character_layer.add_child(foe)
		foe.facing = Vector2.LEFT  # 面朝中线，便于观察朝向


func _spawn_ball() -> void:
	_ball = BALL_SCENE.instantiate()
	_ball.global_position = _player.global_position + Vector2(16, 0)
	ball_layer.add_child(_ball)


func _spawn_touch_controls() -> void:
	ui_layer.add_child(TOUCH_CONTROLS_SCENE.instantiate())
	_spawn_reset_button()


## 仅测试用：右上角重置按钮（也可按 R 键），重新加载场景。
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
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_R:
		_reset()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_ball):
		return
	# 仅当球被玩家持有时响应投/传
	if _ball.state == Ball.State.HELD and _ball.holder == _player:
		if GameInput.is_just_pressed(GameInput.THROW):
			_ball.throw(_player.facing, _player.atk)
		elif GameInput.is_just_pressed(GameInput.PASS):
			var mate := _nearest_teammate(_player)
			if mate != null:
				_ball.pass_to(mate.global_position)


func _nearest_teammate(from: Character) -> Character:
	var best: Character = null
	var best_d := INF
	for c in get_tree().get_nodes_in_group(&"characters"):
		if c is Character and from.is_teammate(c):
			var d := from.global_position.distance_squared_to(c.global_position)
			if d < best_d:
				best_d = d
				best = c
	return best
