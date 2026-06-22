extends Control
## 比赛 HUD（占位）—— SP-M04.7
##
## 顶部显示双方各 3 名内场球员的 HP 条；某侧内场人数不足 3 时空槽变灰。
## 比赛结束时显示胜负横幅。数据来源：GameManager（AutoLoad）。

const BAR_W := 34.0
const BAR_H := 4.0
const BAR_GAP := 3.0
const MARGIN := 4.0
const ROW_Y := 14.0

var _banner: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 14)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(0, Constants.BASE_RESOLUTION.y * 0.5 - 8)
	_banner.size = Vector2(Constants.BASE_RESOLUTION.x, 16)
	_banner.visible = false
	add_child(_banner)
	GameManager.match_ended.connect(_on_match_ended)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_team(true, Vector2(MARGIN, ROW_Y))
	_draw_team(false, Vector2(size.x - MARGIN - BAR_W, ROW_Y))


## 绘制一侧 3 个内场 HP 槽（纵向排列）。left=true 左队（左上），否则右队（右上）。
func _draw_team(left: bool, origin: Vector2) -> void:
	var members := GameManager.infield_members(left)
	for i in Constants.INFIELD_PLAYERS:
		var top := origin + Vector2(0, float(i) * (BAR_H + BAR_GAP))
		var bg := Rect2(top, Vector2(BAR_W, BAR_H))
		draw_rect(bg, Color(0, 0, 0, 0.6))
		if i < members.size():
			var c: Character = members[i]
			var ratio := clampf(float(c.current_hp) / float(maxi(c.hp, 1)), 0.0, 1.0)
			var col: Color = Character.TEAM_COLORS[clampi(c.team, 0, Character.TEAM_COLORS.size() - 1)]
			draw_rect(Rect2(top, Vector2(BAR_W * ratio, BAR_H)), col)
		else:
			# 空槽（已淘汰转外场）：灰色
			draw_rect(bg.grow(-0.5), Color(0.25, 0.25, 0.25, 0.8))
		draw_rect(bg, Color(1, 1, 1, 0.4), false, 1.0)


func _on_match_ended(left_won: bool) -> void:
	_banner.text = "LEFT TEAM WINS!" if left_won else "RIGHT TEAM WINS!"
	_banner.visible = true
