extends Node
## 统一输入管理层（AutoLoad: GameInput）—— 关联 RISK-05
##
## 抽象输入来源（键盘 / 触屏虚拟摇杆 / 后续手柄），向上层提供统一接口：
##   - get_movement_vector()    原始移动向量（-1..1）
##   - get_movement_vector_8()  吸附到 8 方向的单位向量
##   - is_pressed / just_pressed / just_released
##
## 动作在运行时通过 InputMap 注册，避免 project.godot 中手写事件资源，
## 同时保证 headless 环境下动作可用。
##
## 注意：AutoLoad 命名为 GameInput，不可命名为 Input（会遮蔽 Godot 内置单例）。

# 动作名常量（对外统一引用）
const MOVE_LEFT := &"kn_move_left"
const MOVE_RIGHT := &"kn_move_right"
const MOVE_UP := &"kn_move_up"
const MOVE_DOWN := &"kn_move_down"
const JUMP := &"kn_jump"      # B 按钮：跳跃 / 闪避
const THROW := &"kn_throw"    # A 按钮：投球 / 接球
const PASS := &"kn_pass"      # 传球
const CROUCH := &"kn_crouch"  # C 按钮：下蹲 / 闪避（按住生效）

# 8 方向单位向量表
const DIR_8 := [
	Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
]

# 触屏来源状态（由虚拟摇杆 / 触屏按钮写入）
var _touch_vector := Vector2.ZERO

var _keyboard_bindings := {
	MOVE_LEFT: [KEY_A, KEY_LEFT],
	MOVE_RIGHT: [KEY_D, KEY_RIGHT],
	MOVE_UP: [KEY_W, KEY_UP],
	MOVE_DOWN: [KEY_S, KEY_DOWN],
	JUMP: [KEY_SPACE, KEY_K],
	THROW: [KEY_J, KEY_ENTER],
	PASS: [KEY_L],
	CROUCH: [KEY_SHIFT, KEY_C],
}


func _ready() -> void:
	_ensure_actions()


## 在 InputMap 中注册所有游戏动作（若尚未存在）。
func _ensure_actions() -> void:
	for action in _keyboard_bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in _keyboard_bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------------------
# 移动向量
# ---------------------------------------------------------------------------

## 原始移动向量，幅度被限制在单位圆内。触屏优先于键盘。
func get_movement_vector() -> Vector2:
	if _touch_vector != Vector2.ZERO:
		return _touch_vector.limit_length(1.0)
	var v := Vector2(
		Input.get_action_strength(MOVE_RIGHT) - Input.get_action_strength(MOVE_LEFT),
		Input.get_action_strength(MOVE_DOWN) - Input.get_action_strength(MOVE_UP),
	)
	return v.limit_length(1.0)


## 吸附到最近的 8 方向单位向量（无输入时返回零向量）。
func get_movement_vector_8() -> Vector2:
	var v := get_movement_vector()
	if v.length() < 0.2:
		return Vector2.ZERO
	var angle := v.angle()
	var idx: int = int(round(angle / (PI / 4.0))) % 8
	if idx < 0:
		idx += 8
	return DIR_8[idx].normalized()


# ---------------------------------------------------------------------------
# 动作查询（合并键盘与触屏来源）
# ---------------------------------------------------------------------------

func is_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)


func is_just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)


func is_just_released(action: StringName) -> bool:
	return Input.is_action_just_released(action)


# ---------------------------------------------------------------------------
# 触屏来源接口（由 UI 层调用）
# ---------------------------------------------------------------------------

func set_touch_vector(v: Vector2) -> void:
	_touch_vector = v


## 触屏按钮写入动作状态。通过 Input.action_press/release 注入，
## 使 is_just_pressed / is_just_released 对触屏来源同样生效（M3 接球/投球需要边沿）。
func set_touch_action(action: StringName, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	if pressed:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
	else:
		if Input.is_action_pressed(action):
			Input.action_release(action)
