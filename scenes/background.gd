extends Node2D
## ステージ背景: 暗黒空間 + 星空 + グリッド + 画面区切り線 + 壁 + ゴールライン。
## 純粋な見た目用（Physics に触れない）。stage 範囲は scenes/main.gd が setup() で与える。
## カメラが常にプレイヤー中心（クランプなし）のため、壁の外・ゴールの上まで描いておく。

## カメラが壁の外／ゴールの上を映しても空白にならないための余白
const MARGIN_X := 720.0
const MARGIN_Y := 800.0
const STAR_COUNT := 260
## 全員の環境・毎回の起動で同じ星空になるよう固定シード
const STAR_SEED := 20260811

var _top_y := 0.0
var _bottom_y := 0.0
var _half_width := 640.0
var _screen_sep := 720.0
var _grid_step := 64.0


func setup(top_y: float, bottom_y: float, half_width: float, screen_sep: float) -> void:
	_top_y = top_y
	_bottom_y = bottom_y
	_half_width = half_width
	_screen_sep = screen_sep
	queue_redraw()


func _draw() -> void:
	var left := -_half_width - MARGIN_X
	var right := _half_width + MARGIN_X
	var top := _top_y - MARGIN_Y
	var bottom := _bottom_y + MARGIN_Y

	# 外周（壁の外）はより暗く、ステージ内はわずかに明るく
	draw_rect(Rect2(left, top, right - left, bottom - top), Color(0.015, 0.02, 0.035, 1))
	draw_rect(Rect2(-_half_width, _top_y, _half_width * 2.0, _bottom_y - _top_y),
			Color(0.03, 0.04, 0.06, 1))

	# 星空（固定シードで決定的に配置）
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for _i in STAR_COUNT:
		var p := Vector2(rng.randf_range(left, right), rng.randf_range(top, bottom))
		var radius := rng.randf_range(0.6, 2.0)
		var alpha := rng.randf_range(0.2, 0.85)
		draw_circle(p, radius, Color(0.85, 0.9, 1.0, alpha))

	# グリッド（ステージ内のみ、うっすら）
	var x := -_half_width
	while x <= _half_width:
		draw_line(Vector2(x, _top_y), Vector2(x, _bottom_y), Color(0.08, 0.1, 0.14, 1), 1.0)
		x += _grid_step
	var y := _top_y
	while y <= _bottom_y:
		draw_line(Vector2(-_half_width, y), Vector2(_half_width, y), Color(0.08, 0.1, 0.14, 1), 1.0)
		y += _grid_step

	# 左右の壁（コリジョンは main.gd 側。ここは見た目だけ）
	for side: float in [-1.0, 1.0]:
		var x0 := side * _half_width
		var x1 := side * (_half_width + 24.0)
		draw_rect(Rect2(minf(x0, x1), _top_y - 200.0, absf(x1 - x0), _bottom_y - _top_y + 200.0),
				Color(0.28, 0.26, 0.33, 1))

	# 画面区切り（最上部のゴールラインと重ならないよう +1 画面分から）
	var sep := _top_y + _screen_sep
	while sep < _bottom_y:
		draw_line(Vector2(-_half_width, sep), Vector2(_half_width, sep), Color(0.85, 0.5, 0.15, 0.5), 2.0)
		sep += _screen_sep

	# ゴールライン（最上部）
	draw_line(Vector2(-_half_width, _top_y), Vector2(_half_width, _top_y), Color(0.2, 0.9, 0.6, 0.9), 3.0)
