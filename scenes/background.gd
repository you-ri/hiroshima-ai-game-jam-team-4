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

## 雲海（ステージ中腹。登っている実感を出すための通過目標）。
## 上空のアポフィスを覆い隠す「幕」の役割もあるため、帯を厚く・濃くしてある。
## 抜けた先で初めてアポフィスが見えるのが演出の肝（main.gd の常時微振動もここが起点）。
## 高度は m 単位で持ち、px へは Units で変換する（Spec の 3000m ＝ 6 画面と揃える）
const CLOUD_LAYERS: Array[Dictionary] = [
	# 奥ほど高く・暗く・小さい。手前ほど低く・明るく・大きい
	{"altitude_m": 1300.0, "radius": Vector2(34.0, 64.0), "step": Vector2(40.0, 78.0),
			"spread": 24.0, "color": Color(0.26, 0.3, 0.44, 0.5)},
	{"altitude_m": 1240.0, "radius": Vector2(42.0, 80.0), "step": Vector2(44.0, 86.0),
			"spread": 28.0, "color": Color(0.32, 0.36, 0.5, 0.62)},
	{"altitude_m": 1180.0, "radius": Vector2(50.0, 92.0), "step": Vector2(48.0, 92.0),
			"spread": 32.0, "color": Color(0.38, 0.42, 0.56, 0.72)},
	{"altitude_m": 1110.0, "radius": Vector2(58.0, 106.0), "step": Vector2(56.0, 104.0),
			"spread": 36.0, "color": Color(0.46, 0.5, 0.64, 0.8)},
	{"altitude_m": 1040.0, "radius": Vector2(66.0, 120.0), "step": Vector2(64.0, 118.0),
			"spread": 40.0, "color": Color(0.54, 0.58, 0.72, 0.86)},
	{"altitude_m": 970.0, "radius": Vector2(72.0, 132.0), "step": Vector2(72.0, 132.0),
			"spread": 44.0, "color": Color(0.62, 0.66, 0.8, 0.9)},
]
## 雲海全体をぼんやり照らす帯（月明かりが雲に反射している感じ）
const CLOUD_GLOW_COLOR := Color(0.35, 0.4, 0.58, 0.05)

## 巨大隕石アポフィス（雲海の向こう側に浮かぶ背景オブジェクト。移動しない）。
## 下端を雲海の帯に沈めて手前の雲に隠させることで「雲より遠くにある」遠近感を出す。
## 当たり判定は無い（純粋な見た目）
const APOPHIS_ALTITUDE_M := 1550.0
const APOPHIS_CENTER_X := 140.0
const APOPHIS_RADIUS := 460.0
const APOPHIS_ROCK_COLOR := Color(0.11, 0.09, 0.1, 1)
const APOPHIS_LIT_COLOR := Color(0.24, 0.17, 0.15, 1)
const APOPHIS_CRATER_COLOR := Color(0.07, 0.055, 0.07, 1)
## 不吉さを出す赤いハロー（大気越しに照り返している感じ）
const APOPHIS_GLOW_COLOR := Color(0.9, 0.25, 0.1, 1)

## 大気圏の上端（＝ゴール。ステージ最上部 _top_y）。ここを抜けると main.gd が自動上昇に入る。
## 軌道から見た大気光（airglow）のような、淡く発光する帯として絵的に描く
const AIRGLOW_COLOR := Color(0.45, 0.9, 0.8, 1)
## 大気光が界面の下に溜まる帯の厚さと分割数（多いほど滑らかなグラデーション）
const AIRGLOW_HEIGHT := 170.0
const AIRGLOW_BANDS := 14
## 境界の下に敷く大気のかすみ。下（地上側）ほど濃く、境界に近づくほど薄れて宇宙になる
const ATMO_HAZE_COLOR := Color(0.22, 0.55, 0.95, 1)
const ATMO_HAZE_HEIGHT := 1100.0
const ATMO_HAZE_BANDS := 10
const ATMO_HAZE_MAX_ALPHA := 0.1

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

	# アポフィス（雲海より奥＝先に描く。下から登る間は雲海が幕になって見えない）
	_draw_apophis(rng)

	# 雲海（ステージ中腹。夜景より手前・壁より奥）
	_draw_cloud_sea(rng, left, right)

	# 大気のかすみ（境界の下側。ここから上が宇宙だと分かるように薄れていく）
	_draw_atmosphere_haze(left, right)

	# 左右の壁（コリジョンは main.gd 側。ここは見た目だけ）
	for side: float in [-1.0, 1.0]:
		var x0 := side * _half_width
		var x1 := side * (_half_width + 24.0)
		draw_rect(Rect2(minf(x0, x1), _top_y - 200.0, absf(x1 - x0), _bottom_y - _top_y + 200.0),
				Color(0.28, 0.26, 0.33, 1))

	# 画面区切り（最上部の大気圏界面と重ならないよう +1 画面分から）
	var sep := _top_y + _screen_sep
	while sep < _bottom_y:
		draw_line(Vector2(-_half_width, sep), Vector2(_half_width, sep), Color(0.85, 0.5, 0.15, 0.5), 2.0)
		sep += _screen_sep

	# 大気圏界面（ゴール。壁より手前に描いて一番目立たせる）
	_draw_atmosphere_edge()


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


## 雲海の上空に浮かぶ巨大隕石アポフィス。背景の一部なので動かない。
## 街明かりの照り返し（下面の赤）＋月明かり（上面の微光）＋クレーターで立体感を出す
func _draw_apophis(rng: RandomNumberGenerator) -> void:
	var center := Vector2(APOPHIS_CENTER_X, -Units.m_to_px(APOPHIS_ALTITUDE_M))

	# 赤いハロー（外ほど薄い 3 重円）
	for i in 3:
		var t := float(i) / 3.0
		draw_circle(center, APOPHIS_RADIUS * (1.35 - t * 0.11),
				Color(APOPHIS_GLOW_COLOR.r, APOPHIS_GLOW_COLOR.g, APOPHIS_GLOW_COLOR.b,
						0.03 + t * 0.02))

	# 岩体。ベース → 下側の照り返し → 本体の順に重ねて球っぽく見せる
	draw_circle(center, APOPHIS_RADIUS, APOPHIS_LIT_COLOR)
	draw_circle(center + Vector2(-APOPHIS_RADIUS * 0.08, -APOPHIS_RADIUS * 0.1),
			APOPHIS_RADIUS * 0.94, APOPHIS_ROCK_COLOR)

	# クレーター（本体の内側に収まる範囲だけ。固定シード rng で決定的に配置）
	for _i in 26:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(0.0, APOPHIS_RADIUS * 0.78)
		var r := rng.randf_range(14.0, 64.0)
		var p := center + Vector2(cos(a), sin(a)) * d
		draw_circle(p, r, APOPHIS_CRATER_COLOR)
		# 縁の照り返し（下側だけ細く明るく）
		draw_arc(p, r, TAU * 0.1, TAU * 0.4, 10,
				Color(0.3, 0.2, 0.17, 0.5), 2.0)

	# 下弦の赤いリムライト（地上の火災・街明かりの照り返し）
	draw_arc(center, APOPHIS_RADIUS * 0.99, TAU * 0.08, TAU * 0.42, 40,
			Color(APOPHIS_GLOW_COLOR.r, APOPHIS_GLOW_COLOR.g, APOPHIS_GLOW_COLOR.b, 0.5), 5.0)

	# 大気越しのかすみ（空の色を薄く被せて彩度とコントラストを落とし、遠くに見せる）
	draw_circle(center, APOPHIS_RADIUS * 1.02, Color(0.05, 0.07, 0.12, 0.28))


## 境界（_top_y）の下に敷く大気の層。下ほど濃く、境界に近づくほど薄くして
## 「ここから上には空気が無い」と見て分かるようにする
func _draw_atmosphere_haze(left: float, right: float) -> void:
	var band := ATMO_HAZE_HEIGHT / float(ATMO_HAZE_BANDS)
	for i in ATMO_HAZE_BANDS:
		var alpha := ATMO_HAZE_MAX_ALPHA * float(i + 1) / float(ATMO_HAZE_BANDS)
		var color := Color(ATMO_HAZE_COLOR.r, ATMO_HAZE_COLOR.g, ATMO_HAZE_COLOR.b, alpha)
		draw_rect(Rect2(left, _top_y + band * i, right - left, band), color)


## 大気圏の上端。軌道写真で見える大気光（airglow）のイメージで、
## 界面のすぐ下に淡い光が溜まり、その上はすっと宇宙の黒に抜ける。
## 文字や記号は置かず、絵として「ここで空気が終わる」と分からせる。
## 越えた後の挙動（自動上昇 → 画面外でクリア）は scenes/main.gd 側。
func _draw_atmosphere_edge() -> void:
	var x0 := -_half_width
	var x1 := _half_width

	# 界面の下に溜まる大気光。界面側が最も明るく、下へ二乗で減衰させる
	var band := AIRGLOW_HEIGHT / float(AIRGLOW_BANDS)
	for i in AIRGLOW_BANDS:
		var t := float(i) / float(AIRGLOW_BANDS)
		# 界面付近は緑がかった大気光、下に行くほど大気のかすみの青に馴染ませる
		var color := AIRGLOW_COLOR.lerp(ATMO_HAZE_COLOR, t)
		color.a = 0.22 * (1.0 - t) * (1.0 - t)
		draw_rect(Rect2(x0, _top_y + band * i, x1 - x0, band + 1.0), color)

	# 界面そのものは細い光の芯。にじみ（幅広・低アルファ）を重ねてぼんやり光らせる
	for width_alpha in [[22.0, 0.05], [10.0, 0.1], [4.0, 0.22]]:
		var c := Color(AIRGLOW_COLOR.r, AIRGLOW_COLOR.g, AIRGLOW_COLOR.b, width_alpha[1])
		draw_line(Vector2(x0, _top_y), Vector2(x1, _top_y), c, width_alpha[0])


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
