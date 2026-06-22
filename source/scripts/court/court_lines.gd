extends Node2D
## 球场线条占位渲染：球场外框、中线、左右内场区域。
## 仅用于 M1/M2 测试期的可视参考，正式背景在 M8 接入美术资产。

func _draw() -> void:
	var court := CourtGeometry.COURT_RECT
	# 场地底色
	draw_rect(court, Color(0.18, 0.34, 0.22))
	# 外框
	draw_rect(court, Color(1, 1, 1, 0.8), false, 1.0)
	# 中线
	draw_line(Vector2(CourtGeometry.CENTER_X, court.position.y),
		Vector2(CourtGeometry.CENTER_X, court.end.y), Color(1, 1, 1, 0.8), 1.0)
	# 左右内场
	draw_rect(CourtGeometry.infield_rect(true), Color(1, 1, 1, 0.5), false, 1.0)
	draw_rect(CourtGeometry.infield_rect(false), Color(1, 1, 1, 0.5), false, 1.0)
