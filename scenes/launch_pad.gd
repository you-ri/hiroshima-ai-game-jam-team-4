extends Node2D
## スタート地点の発射台（純粋な見た目用。Physics に触れない）。
## 接地は scenes/main.gd の Ground コリジョンが担うため、ここはコリジョンを持たない。
## 地面の上面 = 世界 y=0、ロケットは x=0 に立つ前提で原点周りに描く。

## 背景(z=-10)・地面(z=-5) より手前、ロケット(z=0) より奥
const Z_INDEX := -3

## 夜景に合わせた鉄骨カラー
const PAD_COLOR := Color(0.2, 0.2, 0.24, 1)
const PAD_TOP_COLOR := Color(0.32, 0.32, 0.38, 1)
const TOWER_COLOR := Color(0.14, 0.15, 0.2, 1)
const FRAME_COLOR := Color(0.4, 0.42, 0.5, 1)
const LAMP_COLOR := Color(1.0, 0.3, 0.2, 1)

## 整備塔（ガントリー）の位置・寸法
const TOWER_LEFT := -104.0
const TOWER_WIDTH := 36.0
const TOWER_HEIGHT := 170.0


func _ready() -> void:
	z_index = Z_INDEX


func _draw() -> void:
	# 台座スラブ（地面からわずかに盛り上がる）
	draw_rect(Rect2(-110.0, -12.0, 220.0, 12.0), PAD_COLOR)
	draw_rect(Rect2(-110.0, -12.0, 220.0, 3.0), PAD_TOP_COLOR)

	# ロケット足元の固定クランプ（左右）
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * 44.0, -12.0),
			Vector2(side * 28.0, -12.0),
			Vector2(side * 30.0, -26.0),
			Vector2(side * 40.0, -26.0),
		]), PAD_TOP_COLOR)

	# 整備塔（左側のガントリー）
	var tower_right := TOWER_LEFT + TOWER_WIDTH
	draw_rect(Rect2(TOWER_LEFT, -TOWER_HEIGHT, TOWER_WIDTH, TOWER_HEIGHT - 12.0), TOWER_COLOR)
	# 縦フレーム
	draw_line(Vector2(TOWER_LEFT, -12.0), Vector2(TOWER_LEFT, -TOWER_HEIGHT), FRAME_COLOR, 3.0)
	draw_line(Vector2(tower_right, -12.0), Vector2(tower_right, -TOWER_HEIGHT), FRAME_COLOR, 3.0)
	# 横桟と筋交い（X 型）
	var y := -12.0
	var step := 34.0
	while y - step >= -TOWER_HEIGHT:
		var y2 := y - step
		draw_line(Vector2(TOWER_LEFT, y2), Vector2(tower_right, y2), FRAME_COLOR, 2.0)
		draw_line(Vector2(TOWER_LEFT, y), Vector2(tower_right, y2), FRAME_COLOR, 1.5)
		draw_line(Vector2(tower_right, y), Vector2(TOWER_LEFT, y2), FRAME_COLOR, 1.5)
		y = y2

	# ロケットへ伸びる支持アーム（機体側面 x=-18 付近まで）
	draw_rect(Rect2(tower_right, -64.0, 46.0, 8.0), FRAME_COLOR)

	# 塔頂の警告灯（マスト + ランプ + 淡いグロー）
	var lamp := Vector2(TOWER_LEFT + TOWER_WIDTH * 0.5, -TOWER_HEIGHT - 10.0)
	draw_line(Vector2(lamp.x, -TOWER_HEIGHT), lamp, FRAME_COLOR, 2.0)
	draw_circle(lamp, 8.0, Color(LAMP_COLOR.r, LAMP_COLOR.g, LAMP_COLOR.b, 0.25))
	draw_circle(lamp, 4.0, LAMP_COLOR)