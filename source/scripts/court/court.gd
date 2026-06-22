extends Node2D
## 球场根场景脚本。
##
## M0 阶段仅建立基础层级结构：
##   - BackgroundLayer：球场背景
##   - CharacterLayer：角色精灵
##   - BallLayer：球
##   - UILayer：HUD / 触屏控件（CanvasLayer，不随相机滚动）
## 后续里程碑在此基础上挂载角色、球与 UI。

@onready var background_layer: Node2D = $BackgroundLayer
@onready var character_layer: Node2D = $CharacterLayer
@onready var ball_layer: Node2D = $BallLayer
@onready var ui_layer: CanvasLayer = $UILayer


func _ready() -> void:
	print("[Court] ready — base resolution %s" % Constants.BASE_RESOLUTION)
