extends Control
## 触屏控件（SP-M01.6）：左侧虚拟摇杆 + 右侧 A/B 动作按钮。
##
## 摇杆：在屏幕左半区按下即以触点为中心，拖动产生方向向量（半径 48px），
## 释放回中。向量写入 GameInput.set_touch_vector，支持 8 方向输入。
## 动作按钮写入 GameInput.set_touch_action。
##
## 桌面端通过 project.godot 的 emulate_touch_from_mouse 也可用鼠标测试。

const JOY_RADIUS := 48.0
const BTN_RADIUS := 20.0

# A = 投球/传球/接球；B = 跳跃/闪避（SP-M03.7）
const COLOR_A := Color(0.9, 0.3, 0.3, 0.35)
const COLOR_A_DOWN := Color(1.0, 0.5, 0.5, 0.7)
const COLOR_B := Color(0.3, 0.5, 0.9, 0.35)
const COLOR_B_DOWN := Color(0.5, 0.7, 1.0, 0.7)

var _joy_index := -1          # 控制摇杆的触点 index（-1 = 无）
var _joy_base := Vector2.ZERO
var _joy_knob := Vector2.ZERO
# 按钮触点：index -> action
var _button_touches := {}

@onready var _btn_a_pos := Vector2.ZERO  # 投球（右下）
@onready var _btn_b_pos := Vector2.ZERO  # 跳跃（右上）


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_buttons()
	get_viewport().size_changed.connect(_layout_buttons)


func _layout_buttons() -> void:
	var s := get_viewport_rect().size
	_btn_a_pos = Vector2(s.x - 28, s.y - 28)
	_btn_b_pos = Vector2(s.x - 66, s.y - 46)
	queue_redraw()


## 指定动作按钮当前是否被按下（用于绘制按压反馈）。
func _is_action_down(action: StringName) -> bool:
	return action in _button_touches.values()


func _gui_input(event: InputEvent) -> void:
	_handle_event(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle_event(event)


func _handle_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)


func _on_press(index: int, pos: Vector2) -> void:
	# 优先判断是否按在动作按钮上
	if pos.distance_to(_btn_a_pos) <= BTN_RADIUS:
		_button_touches[index] = GameInput.THROW
		GameInput.set_touch_action(GameInput.THROW, true)
		return
	if pos.distance_to(_btn_b_pos) <= BTN_RADIUS:
		_button_touches[index] = GameInput.JUMP
		GameInput.set_touch_action(GameInput.JUMP, true)
		return
	# 左半屏 → 摇杆
	if _joy_index == -1 and pos.x < get_viewport_rect().size.x * 0.5:
		_joy_index = index
		_joy_base = pos
		_joy_knob = pos
		_update_joy_vector()
		queue_redraw()


func _on_drag(index: int, pos: Vector2) -> void:
	if index == _joy_index:
		_joy_knob = pos
		_update_joy_vector()
		queue_redraw()


func _on_release(index: int) -> void:
	if _button_touches.has(index):
		GameInput.set_touch_action(_button_touches[index], false)
		_button_touches.erase(index)
		return
	if index == _joy_index:
		_joy_index = -1
		GameInput.set_touch_vector(Vector2.ZERO)
		queue_redraw()


func _update_joy_vector() -> void:
	var offset := (_joy_knob - _joy_base).limit_length(JOY_RADIUS)
	_joy_knob = _joy_base + offset
	GameInput.set_touch_vector(offset / JOY_RADIUS)


func _draw() -> void:
	# 动作按钮（带标签与按压反馈，SP-M03.7）
	var a_down := _is_action_down(GameInput.THROW)
	var b_down := _is_action_down(GameInput.JUMP)
	_draw_button(_btn_b_pos, "B", COLOR_B_DOWN if b_down else COLOR_B)
	_draw_button(_btn_a_pos, "A", COLOR_A_DOWN if a_down else COLOR_A)
	# 摇杆
	if _joy_index != -1:
		draw_circle(_joy_base, JOY_RADIUS, Color(1, 1, 1, 0.12))
		draw_circle(_joy_knob, 12.0, Color(1, 1, 1, 0.5))


func _draw_button(center: Vector2, label: String, fill: Color) -> void:
	draw_circle(center, BTN_RADIUS, fill)
	draw_arc(center, BTN_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.5), 1.0)
	var font := ThemeDB.fallback_font
	var fsize := 12
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	draw_string(font, center + Vector2(-tw * 0.5, fsize * 0.4), label, \
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1, 0.85))
