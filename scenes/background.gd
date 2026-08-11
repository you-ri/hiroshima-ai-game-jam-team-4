extends Node2D
## ステージ背景: 暗黒空間 + 星空 + 地上の夜景（山・街明かり）+ 雲海 + グリッド + 画面区切り線 + 壁 + 大気圏界面（ゴール）。
## 純粋な見た目用（Physics に触れない）。stage 範囲は scenes/main.gd が setup() で与える。
## カメラが常にプレイヤー中心（クランプなし）のため、壁の外・ゴールの上まで描いておく。

## カメラが壁の外／ゴールの上を映しても空白にならないための余白
const MARGIN_X := 720.0
const MARGIN_Y := 800.0
const STAR_COUNT := 260
## 全員の環境・毎回の起動で同じ星空になるよう固定シード
const STAR_SEED := 20260811

## 地上の夜景（地面 y=0 から上に生える。高く登ると自然に画面外へ流れる）
const FAR_MOUNTAIN_COLOR := Color(0.07, 0.09, 0.16, 1)
const NEAR_MOUNTAIN_COLOR := Color(0.04, 0.05, 0.1, 1)
const BUILDING_COLOR := Color(0.055, 0.065, 0.12, 1)
const WINDOW_COLOR := Color(1.0, 0.8, 0.45, 0.8)
const CITY_GLOW_COLOR := Color(0.45, 0.3, 0.45, 0.05)

## 雲海（ステージ中腹。登っている実感を出すための通過目標）
## 高度は m 単位で持ち、px へは Units で変換する（Spec の 3000m ＝ 6 画面と揃える）
const CLOUD_LAYERS: Array[Dictionary] = [
	# 奥ほど高く・暗く・小さい。手前ほど低く・明るく・大きい
	{"altitude_m": 1180.0, "radius": Vector2(38.0, 72.0), "step": Vector2(48.0, 96.0),
			"spread": 26.0, "color": Color(0.32, 0.36, 0.5, 0.32)},
	{"altitude_m": 1100.0, "radius": Vector2(52.0, 98.0), "step": Vector2(64.0, 124.0),
			"spread": 34.0, "color": Color(0.46, 0.5, 0.64, 0.4)},
	{"altitude_m": 1020.0, "radius": Vector2(64.0, 124.0), "step": Vector2(78.0, 150.0),
			"spread": 42.0, "color": Color(0.62, 0.66, 0.8, 0.46)},
]
## 雲海全体をぼんやり照らす帯（月明かりが雲に反射している感じ）
const CLOUD_GLOW_COLOR := Color(0.35, 0.4, 0.58, 0.05)

var _top_y := 0.0
var _bottom_y := 0.0
var _half_width := 640.0
var _screen_sep := 720.0
var _grid_step := 64.0


func _ready() -> void:
	# main.tscn のツリー順では Rocket より後ろ（＝手前）に来るため、必ず奥に描く
	z_index = -10


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

	# 地上の夜景（遠景の山 → 街明かり → 近景の山の順で奥から重ねる）
	_draw_night_scenery(rng, left, right)

	# 雲海（ステージ中腹。夜景より手前・壁より奥）
	_draw_cloud_sea(rng, left, right)

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


## 地面（y=0）から生える夜景。地平線の街明かりの淡い光 → 遠景の山 →
## 遠くの街並み（窓明かり）→ 近景の山。すべて固定シードの rng で決定的に配置する
func _draw_night_scenery(rng: RandomNumberGenerator, left: float, right: float) -> void:
	# 地平線のうっすらした光（街明かりが空に滲む感じ。矩形を重ねた擬似グラデーション）
	for i in 4:
		var h := 200.0 - i * 45.0
		draw_rect(Rect2(left, -h, right - left, h), CITY_GLOW_COLOR)

	# 遠景の山（高め・青紫）
	_draw_ridge(rng, left, right, 140.0, 300.0, 90.0, 200.0, FAR_MOUNTAIN_COLOR)

	# 遠くの街並み（山あいの窓明かり）
	_draw_city(rng, left, right)

	# 近景の山（低め・より暗い）
	_draw_ridge(rng, left, right, 40.0, 150.0, 120.0, 260.0, NEAR_MOUNTAIN_COLOR)


## ステージ中腹の雲海。奥（高く暗い）から手前（低く明るい）へ 3 層重ねる。
## 円を横に並べてもこもこさせるだけの見た目用で、当たり判定は持たない
func _draw_cloud_sea(rng: RandomNumberGenerator, left: float, right: float) -> void:
	# 層全体に薄く広がる光。雲の帯がある高度をぼんやり明るく見せる
	var glow_top := -Units.m_to_px(CLOUD_LAYERS[0]["altitude_m"] as float) - 120.0
	var glow_bottom := -Units.m_to_px(CLOUD_LAYERS[-1]["altitude_m"] as float) + 120.0
	for i in 3:
		var inset := i * 60.0
		draw_rect(Rect2(left, glow_top + inset, right - left,
				(glow_bottom - glow_top) - inset * 2.0), CLOUD_GLOW_COLOR)

	for layer in CLOUD_LAYERS:
		var base_y := -Units.m_to_px(layer["altitude_m"] as float)
		var radius: Vector2 = layer["radius"]
		var step: Vector2 = layer["step"]
		var spread: float = layer["spread"]
		var color: Color = layer["color"]
		# 端が切れて見えないよう、描画範囲の外側から始めて外側まで並べる
		var x := left - radius.y
		while x < right + radius.y:
			var r := rng.randf_range(radius.x, radius.y)
			draw_circle(Vector2(x, base_y + rng.randf_range(-spread, spread)), r, color)
			x += rng.randf_range(step.x, step.y)


## 稜線をランダムに折りながら left→right へ走らせ、地面より下（+60）で閉じる
func _draw_ridge(rng: RandomNumberGenerator, left: float, right: float,
		min_h: float, max_h: float, seg_min: float, seg_max: float, color: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(left, 60.0))
	pts.append(Vector2(left, -rng.randf_range(min_h, max_h)))
	var x := left
	while x < right:
		x = minf(x + rng.randf_range(seg_min, seg_max), right)
		pts.append(Vector2(x, -rng.randf_range(min_h, max_h)))
	pts.append(Vector2(right, 60.0))
	draw_polygon(pts, PackedColorArray([color]))


## 地平線上のビル群。窓はランダムに点灯（夜景）
func _draw_city(rng: RandomNumberGenerator, left: float, right: float) -> void:
	var x := left
	while x < right:
		var w := rng.randf_range(12.0, 28.0)
		var h := rng.randf_range(30.0, 110.0)
		draw_rect(Rect2(x, -h, w, h + 60.0), BUILDING_COLOR)

		var wy := -h + 5.0
		while wy < -10.0:
			var wx := x + 3.0
			while wx < x + w - 4.0:
				if rng.randf() < 0.35:
					draw_rect(Rect2(wx, wy, 2.5, 3.5), WINDOW_COLOR)
				wx += 6.0
			wy += 8.0
		x += w + rng.randf_range(3.0, 18.0)
