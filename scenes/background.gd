extends Node2D
## ステージ背景:暗い矩形 + グリッド + 画面区切り線 + ゴールライン。
## 純粋な見た目用（Physics に触れない）。stage 範囲は scenes/main.gd が setup() で与える。

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
	var width := _half_width * 2.0
	var height := _bottom_y - _top_y
	draw_rect(Rect2(-_half_width, _top_y, width, height), Color(0.03, 0.04, 0.06, 1))

	var x := -_half_width
	while x <= _half_width:
		draw_line(Vector2(x, _top_y), Vector2(x, _bottom_y), Color(0.1, 0.12, 0.16, 1), 1.0)
		x += _grid_step

	var y := _top_y
	while y <= _bottom_y:
		draw_line(Vector2(-_half_width, y), Vector2(_half_width, y), Color(0.1, 0.12, 0.16, 1), 1.0)
		y += _grid_step

	# 画面区切り（最上部のゴールラインと重ならないよう +1 画面分から）
	var sep := _top_y + _screen_sep
	while sep < _bottom_y:
		draw_line(Vector2(-_half_width, sep), Vector2(_half_width, sep), Color(0.85, 0.5, 0.15, 0.8), 2.0)
		sep += _screen_sep

	# ゴールライン（最上部）
	draw_line(Vector2(-_half_width, _top_y), Vector2(_half_width, _top_y), Color(0.2, 0.9, 0.6, 0.9), 3.0)