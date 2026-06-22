class_name CourtGeometry
extends RefCounted
## 球场几何与区域约束工具（静态）。
##
## 在 256×240 视口中，球场逻辑区域 256×192 垂直居中（上下各留 24px）。
## 提供内场 / 外场区域矩形与位置钳制，供角色移动约束（SP-M01.7）使用。
##
## 数值来源：GDD 3.2（内场单侧 96×128、外场通道 32、球场 256×192）。

const VIEWPORT := Vector2i(256, 240)
const COURT_TOP := 24          # 球场在视口中的垂直偏移
const COURT_RECT := Rect2(0, COURT_TOP, 256, 192)
const CENTER_X := 128

const INFIELD_W := 96
const INFIELD_H := 128
const OUTFIELD_CHANNEL := 32

# 内场垂直居中：(192 - 128) / 2 = 32 → y ∈ [24+32, 24+32+128] = [56, 184]
const INFIELD_TOP := COURT_TOP + 32  # 56
const INFIELD_BOTTOM := INFIELD_TOP + INFIELD_H  # 184


## 内场矩形。left=true 为左半场（A 队），false 为右半场（B 队）。
static func infield_rect(left: bool) -> Rect2:
	if left:
		return Rect2(CENTER_X - INFIELD_W, INFIELD_TOP, INFIELD_W, INFIELD_H)
	return Rect2(CENTER_X, INFIELD_TOP, INFIELD_W, INFIELD_H)


## 外场通道带（围绕对方半场的上、下、远三侧）。
## left_team=true 表示己方为左队，则外场分布在右半场外围。
static func outfield_rects(left_team: bool) -> Array[Rect2]:
	var half_left: float
	var half_right: float
	if left_team:
		half_left = CENTER_X
		half_right = COURT_RECT.end.x
	else:
		half_left = COURT_RECT.position.x
		half_right = CENTER_X
	var top_band := Rect2(half_left, COURT_TOP, half_right - half_left, INFIELD_TOP - COURT_TOP)
	var bottom_band := Rect2(half_left, INFIELD_BOTTOM, half_right - half_left, COURT_RECT.end.y - INFIELD_BOTTOM)
	var far_band: Rect2
	if left_team:
		# 远端为右侧垂直通道
		far_band = Rect2(half_right - OUTFIELD_CHANNEL, COURT_TOP, OUTFIELD_CHANNEL, COURT_RECT.size.y)
	else:
		far_band = Rect2(half_left, COURT_TOP, OUTFIELD_CHANNEL, COURT_RECT.size.y)
	return [top_band, bottom_band, far_band]


## 将位置钳制到单个矩形内（考虑半尺寸的碰撞框 padding）。
static func clamp_to_rect(pos: Vector2, rect: Rect2, half_extents := Vector2.ZERO) -> Vector2:
	var min_p := rect.position + half_extents
	var max_p := rect.end - half_extents
	return Vector2(
		clampf(pos.x, min_p.x, maxf(min_p.x, max_p.x)),
		clampf(pos.y, min_p.y, maxf(min_p.y, max_p.y)),
	)


## 将位置钳制到多个矩形的并集（选取钳制后距离最近的矩形）。
static func clamp_to_rects(pos: Vector2, rects: Array[Rect2], half_extents := Vector2.ZERO) -> Vector2:
	if rects.is_empty():
		return pos
	var best := clamp_to_rect(pos, rects[0], half_extents)
	var best_d := pos.distance_squared_to(best)
	for i in range(1, rects.size()):
		var c := clamp_to_rect(pos, rects[i], half_extents)
		var d := pos.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = c
	return best
