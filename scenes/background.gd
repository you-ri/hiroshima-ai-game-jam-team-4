extends Node2D
## ステージ背景: 暗黒空間 + 星空 + 地上の夜景（山・街明かり）+ 隕石群の落下と着弾爆発 +
## 各所の火災 + 雲海 + アポフィス + グリッド + 画面区切り線 + 壁 + 大気圏界面（ゴール）。
## 純粋な見た目用（Physics に触れない）。stage 範囲は scenes/main.gd が setup() で与える。
## カメラが常にプレイヤー中心（クランプなし）のため、壁の外・ゴールの上まで描いておく。
## 隕石・火災のアニメーションのため毎フレーム全体を再描画する（全て手続き描画なので軽い）。

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

## 落下する無数の小さな隕石（アポフィスの破片の先触れ）。地面に着弾すると爆発する。
## ゲームプレイの障害物（actors/obstacle）とは無関係の、当たり判定を持たない演出
const SHOWER_SEED := 99942
const SHOWER_COUNT := 90
const SHOWER_SPEED := Vector2(420.0, 820.0)  # px/s
## 落下方向の x 成分（全体をやや左流れに揃えると「同じ空から降っている」感が出る）
const SHOWER_DRIFT := Vector2(0.06, 0.3)
const SHOWER_LENGTH := Vector2(26.0, 64.0)
const SHOWER_COLOR := Color(1.0, 0.62, 0.3, 1)
## 着弾爆発の長さ（秒）と半径の範囲
const SHOWER_EXPLOSION_TIME := 0.7
const SHOWER_EXPLOSION_RADIUS := Vector2(26.0, 72.0)
## 低空では流星を間引く。地上では 1/4、この高度（雲海の下端）で全数になる
const SHOWER_MIN_FRACTION := 0.25
const SHOWER_FULL_ALTITUDE_M := 950.0
## 雲海の中の高度を飛ぶ旅客機（一度きりの演出）。カメラが TRIGGER 高度を超えると
## 右から現れ、数秒飛んだところで被弾して爆発し、火を噴きながら墜落する。当たり判定なし。
## 暗い空が背景だと機体が見えないため、明るい雲海（970〜1300m）を背にして飛ばす
const PLANE_TRIGGER_ALTITUDE_M := 1000.0
const PLANE_ALTITUDE_M := 1150.0
## 出現から爆発までの飛行時間（秒）と速度（px/s）
const PLANE_FLY_TIME := 2.6
const PLANE_SPEED := 470.0
const PLANE_EXPLOSION_TIME := 0.6
## 墜落中も進行方向へ流れる割合と、落下の加速度（px/s²）
const PLANE_FALL_DRIFT := 0.35
const PLANE_FALL_ACCEL := 880.0
const PLANE_GROUND_EXPLOSION_TIME := 0.8
const PLANE_BODY_COLOR := Color(0.16, 0.17, 0.22, 1)
## 機体の表示倍率（遠景でも見えるよう少し大きめに描く）
const PLANE_SCALE := 1.35

## 雲海の上で、左右からアポフィスへ撃ち込まれ続ける弾道ミサイル（人類の抵抗）。
## 表面で爆発するがアポフィスはびくともしない。ループする環境演出で当たり判定なし
const MISSILE_SEED := 573
const MISSILE_COUNT := 7
## 発射から着弾までの時間（秒）の範囲と、着弾爆発の長さ・半径
const MISSILE_FLIGHT_TIME := Vector2(2.0, 3.2)
const MISSILE_EXPLOSION_TIME := 0.55
const MISSILE_EXPLOSION_RADIUS := Vector2(26.0, 48.0)
## 次弾までの休止（秒）の範囲（全弾同時発射にならないよう周期をずらす）
const MISSILE_PAUSE := Vector2(0.4, 1.6)

## 大気圏の近くで、他国のロケットも同じように脱出を試みている演出（一度きり）。
## カメラが TRIGGER 高度を超えると視界の下から 10 機が登ってくるが、
## 7 秒ほどの間に隕石に撃ち抜かれて全機墜ちる（＝生きて抜けるのはプレイヤーだけ）
const ESCAPE_TRIGGER_ALTITUDE_M := 2300.0
## 各機のパラメータ: offset = 開始時のカメラ中央からの相対位置（+y は画面下）、
## speed = 上昇速度（px/s）、doom = 撃墜される時刻（秒）、scale = 遠近感の倍率
## （scale が小さい＝遠い機ほど遅く見えるよう speed も下げる）
const ESCAPE_ROCKETS: Array[Dictionary] = [
	{"offset": Vector2(-600.0, 420.0), "speed": 150.0, "doom": 1.8, "scale": 0.45},
	{"offset": Vector2(-430.0, 380.0), "speed": 190.0, "doom": 2.4, "scale": 0.62},
	{"offset": Vector2(-260.0, 560.0), "speed": 210.0, "doom": 3.0, "scale": 0.70},
	{"offset": Vector2(-90.0, 340.0), "speed": 165.0, "doom": 3.4, "scale": 0.50},
	{"offset": Vector2(150.0, 520.0), "speed": 230.0, "doom": 3.9, "scale": 0.78},
	{"offset": Vector2(320.0, 660.0), "speed": 245.0, "doom": 4.4, "scale": 0.85},
	{"offset": Vector2(430.0, 300.0), "speed": 165.0, "doom": 5.0, "scale": 0.52},
	{"offset": Vector2(590.0, 480.0), "speed": 175.0, "doom": 5.5, "scale": 0.58},
	{"offset": Vector2(-520.0, 700.0), "speed": 200.0, "doom": 6.1, "scale": 0.66},
	{"offset": Vector2(40.0, 780.0), "speed": 255.0, "doom": 6.8, "scale": 0.88},
]
const ESCAPE_EXPLOSION_TIME := 0.5
## 撃墜後、残骸が燃えながら落ちて消えるまでの時間（秒）
const ESCAPE_DEBRIS_TIME := 1.8
const ESCAPE_BODY_COLOR := Color(0.72, 0.75, 0.84, 1)

## スタート地点の発射台へ、助けを求めて走り寄ってくる群衆（純粋な演出）。
## 接触判定は持たず、時間経過で一人ずつ順々に焼かれていく
## （降り注ぐ流星に世界が焼かれていく画）。残機・スコア等のゲームプレイには一切影響しない
const CROWD_SEED := 4444
const CROWD_COUNT := 100
## 出現位置と、集まって立ち止まる位置（発射台の縁）の x 距離範囲
const CROWD_SPAWN_X := Vector2(170.0, 640.0)
const CROWD_STOP_X := Vector2(112.0, 240.0)
const CROWD_SPEED := Vector2(30.0, 85.0)
## 発火が始まる時刻（秒。開始直後から）と、全員に行き渡るまでの幅（秒）
const CROWD_BURN_START := 0.0
const CROWD_BURN_SPAN := 10.0
## 燃え尽きるまでの時間（秒）。その後は黒い塊になって残る
const CROWD_BURN_TIME := 1.1
const CROWD_SKIN_COLOR := Color(0.85, 0.7, 0.55, 1)

## 大気圏外に浮かぶ宇宙人の攻撃戦艦の艦隊（オチ: 流星は実はこの艦隊の爆撃だった）。
## 大気圏界面の上の宇宙空間にずらりと並び、下へ向けて爆弾を落とし続けている。
## ゴールに近づく・大気圏を突破すると初めて視界に入る。当たり判定なしの純粋な演出
const ARMADA_SEED := 51
const ARMADA_COUNT := 10
## 界面（_top_y）からの高さの範囲（手前の列）。奥の列はさらに上に小さく置く
const ARMADA_OFFSET_Y := Vector2(150.0, 380.0)
const ARMADA_HULL_COLOR := Color(0.13, 0.11, 0.18, 1)
const ARMADA_EDGE_COLOR := Color(0.3, 0.26, 0.4, 1)
## 妖しい発光（宇宙人らしく緑）と、爆弾の色
const ARMADA_LIGHT_COLOR := Color(0.35, 1.0, 0.5, 1)
const ARMADA_BOMB_COLOR := Color(1.0, 0.55, 0.2, 1)
## 爆弾の投下間隔（秒）の範囲と、投下から消えるまでの落下距離（px）
const ARMADA_BOMB_INTERVAL := Vector2(1.2, 2.6)
const ARMADA_BOMB_FALL := 620.0

## 街・山のあちこちで燃える火災（ちらつく光の点。世紀末感の主役）
const FIRE_SEED := 20290413
const FIRE_COUNT := 34
const FIRE_COLOR := Color(1.0, 0.45, 0.12, 1)
const FIRE_CORE_COLOR := Color(1.0, 0.85, 0.45, 1)
## 地平線全体を赤く染める「世界が燃えている」光
const FIRE_HORIZON_COLOR := Color(0.85, 0.18, 0.05, 1)

var _top_y := 0.0
var _bottom_y := 0.0
var _half_width := 640.0
var _screen_sep := 720.0
var _grid_step := 64.0
## アニメーション用の経過時間（隕石の落下位相・火災のちらつきに使う）
var _t := 0.0
## 旅客機の演出。カメラが所定高度を超えたら開始し、以後 _plane_t を進める
var _plane_started := false
var _plane_t := 0.0
## 被弾させる x 座標。開始時のカメラ中央を記録し、プレイヤーの目の前で爆発させる
var _plane_boom_x := 0.0
## 他国ロケットの脱出演出。開始時のカメラ中央を基準に相対配置する
var _escape_started := false
var _escape_t := 0.0
var _escape_origin := Vector2.ZERO
## 群衆。1 人 1 Dictionary（x=現在位置, stop=目標位置, state: 0=走る 1=燃焼中 2=焼死体）
var _crowd: Array[Dictionary] = []
## 流星群の各弾のパラメータ（固定シードから setup() で一度だけ生成）
var _shower_cache: Array[Dictionary] = []


func _ready() -> void:
	# main.tscn のツリー順では Rocket より後ろ（＝手前）に来るため、必ず奥に描く
	z_index = -10
	_init_crowd()


## 群衆を発射台の左右に散らして生成する（固定シードで決定的）
func _init_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = CROWD_SEED
	for i in CROWD_COUNT:
		var side := -1.0 if i % 2 == 0 else 1.0
		_crowd.append({
			"x": side * rng.randf_range(CROWD_SPAWN_X.x, CROWD_SPAWN_X.y),
			"stop": side * rng.randf_range(CROWD_STOP_X.x, CROWD_STOP_X.y),
			"speed": rng.randf_range(CROWD_SPEED.x, CROWD_SPEED.y),
			"ph": rng.randf_range(0.0, TAU),
			"h": rng.randf_range(14.0, 20.0),
			"shirt": Color(rng.randf_range(0.25, 0.55), rng.randf_range(0.2, 0.45),
					rng.randf_range(0.2, 0.5), 1.0),
			"state": 0,
			"burn": 0.0,
			# この時刻（_t）になったら発火する。全員バラバラで順々に燃えていく
			"doom": CROWD_BURN_START + rng.randf_range(0.0, CROWD_BURN_SPAN),
		})


func _process(delta: float) -> void:
	_t += delta
	var camera := get_viewport().get_camera_2d()

	if _plane_started:
		_plane_t += delta
	elif camera != null \
			and camera.global_position.y <= -Units.m_to_px(PLANE_TRIGGER_ALTITUDE_M):
		# プレイヤー（＝カメラ）が雲海の少し下まで登ってきたら旅客機の演出を始める
		_plane_started = true
		# 画面の真ん中あたりで被弾するよう、この時点のカメラ中央 x を狙い点にする
		_plane_boom_x = camera.global_position.x

	if _escape_started:
		_escape_t += delta
	elif camera != null \
			and camera.global_position.y <= -Units.m_to_px(ESCAPE_TRIGGER_ALTITUDE_M):
		# 大気圏が近づいたら、他国のロケットも脱出を試みる演出を始める
		_escape_started = true
		_escape_origin = camera.global_position

	_update_crowd(delta)
	queue_redraw()


## 群衆の移動と発火。接触判定は持たず、各自の doom 時刻が来たら順々に燃えていく
func _update_crowd(delta: float) -> void:
	for p in _crowd:
		match p["state"]:
			0:
				# 発射台の縁へ走り寄る
				var dx: float = p["stop"] - p["x"]
				if absf(dx) > 2.0:
					p["x"] += signf(dx) * (p["speed"] as float) * delta
				if _t >= (p["doom"] as float):
					p["state"] = 1
			1:
				p["burn"] = (p["burn"] as float) + delta
				if p["burn"] >= CROWD_BURN_TIME:
					p["state"] = 2


func setup(top_y: float, bottom_y: float, half_width: float, screen_sep: float) -> void:
	_top_y = top_y
	_bottom_y = bottom_y
	_half_width = half_width
	_screen_sep = screen_sep
	_build_shower_cache()
	queue_redraw()


## 流星群のパラメータを固定シードで生成する。ステージ範囲に依存するため setup() で呼ぶ
func _build_shower_cache() -> void:
	_shower_cache.clear()
	var left := -_half_width - MARGIN_X
	var right := _half_width + MARGIN_X
	var top := _top_y - MARGIN_Y
	var rng := RandomNumberGenerator.new()
	rng.seed = SHOWER_SEED
	for i in SHOWER_COUNT:
		var start := Vector2(rng.randf_range(left, right), rng.randf_range(top, -250.0))
		var speed := rng.randf_range(SHOWER_SPEED.x, SHOWER_SPEED.y)
		var dir := Vector2(-rng.randf_range(SHOWER_DRIFT.x, SHOWER_DRIFT.y), 1.0).normalized()
		# 開始位置から地面（y=0）までの落下時間 + 爆発時間で 1 周期
		var fall_time := (0.0 - start.y) / dir.y / speed
		var cycle := fall_time + SHOWER_EXPLOSION_TIME
		_shower_cache.append({
			"start": start,
			"speed": speed,
			"dir": dir,
			"length": rng.randf_range(SHOWER_LENGTH.x, SHOWER_LENGTH.y),
			"alpha": rng.randf_range(0.25, 0.6),
			"boom_r": rng.randf_range(SHOWER_EXPLOSION_RADIUS.x, SHOWER_EXPLOSION_RADIUS.y),
			"fall_time": fall_time,
			"cycle": cycle,
			"phase_off": rng.randf_range(0.0, cycle),
			"impact": start + dir * speed * fall_time + Vector2(0.0, -4.0),
		})


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

	# 各所の火災（山・ビルの上に乗せてちらつかせる）
	_draw_fires(left, right)

	# 発射台へ集まる群衆（地面の上。夜景・火災より手前）
	_draw_crowd()

	# アポフィス（雲海より奥＝先に描く。下から登る間は雲海が幕になって見えない）
	_draw_apophis(rng)

	# アポフィスへ撃ち込まれる弾道ミサイル（アポフィスの手前）
	_draw_missiles()

	# 落下する隕石群（山・街・アポフィスより手前、雲海より奥）
	_draw_meteor_shower()

	# 他国ロケットの脱出と撃墜（大気圏の近く。遠景なので小さく描く）
	_draw_escape_rockets()

	# 大気圏外の攻撃戦艦の艦隊（流星の正体。界面の上の宇宙空間に並ぶ）
	_draw_armada()

	# 雲海（ステージ中腹。夜景より手前・壁より奥）
	_draw_cloud_sea(rng, left, right)

	# 旅客機の被弾・墜落（明るい雲海を背にシルエットが見えるよう、雲より手前に描く）
	_draw_plane()

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


## いま有効な流星の数。低空では 1/4 に間引き、雲海へ近づくほど増やして全数にする。
## キャッシュの並びは空間的にランダムなので、先頭 n 個を取れば自然に散る
func _shower_active_count() -> int:
	var camera := get_viewport().get_camera_2d()
	var altitude := 0.0
	if camera != null:
		altitude = maxf(Units.px_to_m(-camera.global_position.y), 0.0)
	var fraction := lerpf(SHOWER_MIN_FRACTION, 1.0,
			clampf(altitude / SHOWER_FULL_ALTITUDE_M, 0.0, 1.0))
	return int(ceil(_shower_cache.size() * fraction))


## 落下する無数の小さな隕石。各隕石は「空から落ちる → 地面（y=0）で爆発 → 再落下」を
## 独自の周期でループする。パラメータは _shower_cache（固定シード）、位相だけ _t で進める
func _draw_meteor_shower() -> void:
	for i in _shower_active_count():
		var m := _shower_cache[i]
		var phase := fposmod(_t + (m["phase_off"] as float), m["cycle"] as float)
		if phase < (m["fall_time"] as float):
			# 落下中: 尾を引く光の筋（先端ほど明るい 2 重線）
			var dir: Vector2 = m["dir"]
			var length: float = m["length"]
			var alpha: float = m["alpha"]
			var pos: Vector2 = (m["start"] as Vector2) + dir * (m["speed"] as float) * phase
			draw_line(pos - dir * length, pos,
					Color(SHOWER_COLOR.r, SHOWER_COLOR.g, SHOWER_COLOR.b, alpha * 0.4), 1.5)
			draw_line(pos - dir * length * 0.35, pos,
					Color(1.0, 0.85, 0.55, alpha), 2.5)
		else:
			# 着弾: 広がって消える爆発
			var e := (phase - (m["fall_time"] as float)) / SHOWER_EXPLOSION_TIME
			_draw_explosion(m["impact"], e, m["boom_r"])


## 広がって消える爆発（グロー → 芯 → 衝撃波の輪）。e は進行度 0〜1
func _draw_explosion(center: Vector2, e: float, radius: float) -> void:
	var grow := 1.0 - (1.0 - e) * (1.0 - e)
	draw_circle(center, radius * grow, Color(1.0, 0.45, 0.12, 0.4 * (1.0 - e)))
	draw_circle(center, radius * grow * 0.5, Color(1.0, 0.85, 0.5, 0.7 * (1.0 - e)))
	draw_arc(center, radius * (0.4 + grow * 1.6), 0.0, TAU, 28,
			Color(1.0, 0.7, 0.4, 0.5 * (1.0 - e)), 2.0)


## 左右の画面外からアポフィスへ向かう弾道ミサイル。2 次ベジェで緩い弧を描いて飛び、
## 表面で爆発して消える（アポフィスは無傷のまま＝人類の攻撃が通じない絵）。
## 各弾のパラメータは固定シードで決定的、位相だけ _t で進める
func _draw_missiles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MISSILE_SEED
	var apo := Vector2(APOPHIS_CENTER_X, -Units.m_to_px(APOPHIS_ALTITUDE_M))
	for i in MISSILE_COUNT:
		var side := -1.0 if i % 2 == 0 else 1.0
		# 発射点は雲海の高さの画面外。撃った側の面（左弾なら左面）に当てる
		var from := Vector2(side * (_half_width + 80.0),
				-Units.m_to_px(rng.randf_range(1100.0, 1350.0)))
		var hit_angle := (PI if side < 0.0 else 0.0) + rng.randf_range(-0.5, 0.5)
		var to := apo + Vector2(cos(hit_angle), sin(hit_angle)) * APOPHIS_RADIUS * 0.98
		# 中間制御点を外側・上方に置いて弾道らしい弧にする
		var mid := (from + to) * 0.5 \
				+ Vector2(side * rng.randf_range(60.0, 160.0), -rng.randf_range(120.0, 260.0))
		var flight := rng.randf_range(MISSILE_FLIGHT_TIME.x, MISSILE_FLIGHT_TIME.y)
		var boom_r := rng.randf_range(MISSILE_EXPLOSION_RADIUS.x, MISSILE_EXPLOSION_RADIUS.y)
		var cycle := flight + MISSILE_EXPLOSION_TIME \
				+ rng.randf_range(MISSILE_PAUSE.x, MISSILE_PAUSE.y)
		var phase := fposmod(_t + rng.randf_range(0.0, cycle), cycle)

		if phase < flight:
			var u := phase / flight
			var pos := from.lerp(mid, u).lerp(mid.lerp(to, u), u)
			var tangent := (mid - from).lerp(to - mid, u).normalized()
			# 排気炎（2 つ）と煙（2 つ）の尾
			for j in 4:
				var color := Color(1.0, 0.6, 0.2, 0.55 - j * 0.12) if j < 2 \
						else Color(0.5, 0.5, 0.55, 0.3 - (j - 2) * 0.1)
				draw_circle(pos - tangent * (9.0 + j * 12.0), 3.0 + j * 1.5, color)
			# 弾体と先端の光点
			draw_line(pos - tangent * 8.0, pos + tangent * 4.0,
					Color(0.85, 0.88, 0.95, 0.9), 3.0)
			draw_circle(pos + tangent * 4.0, 2.0, Color(1.0, 0.95, 0.8, 0.95))
		elif phase < flight + MISSILE_EXPLOSION_TIME:
			# 着弾。爆発だけしてアポフィスは無傷（描き換えない）
			_draw_explosion(to, (phase - flight) / MISSILE_EXPLOSION_TIME, boom_r)


## 群衆の描画。走る（腕を振り上げて助けを求める）→ 燃える → 黒い塊が残る。
## 足元は地面（y=0）。1 人あたり数プリミティブの棒人間で、火はちらつかせる
func _draw_crowd() -> void:
	for p in _crowd:
		var x: float = p["x"]
		var h: float = p["h"]
		var ph: float = p["ph"]
		match p["state"]:
			0:
				var running := absf((p["stop"] as float) - x) > 2.0
				# 走っている間は上下に弾む
				var bob := absf(sin(_t * 9.0 + ph)) * (2.2 if running else 0.8)
				var hip := Vector2(x, -h * 0.45 - bob)
				var neck := Vector2(x, -h * 0.85 - bob)
				var shirt: Color = p["shirt"]
				# 脚（走行中は交互に開く）
				var swing := sin(_t * 11.0 + ph) * (4.0 if running else 1.0)
				draw_line(hip, Vector2(x + swing, 0.0), shirt, 1.6)
				draw_line(hip, Vector2(x - swing, 0.0), shirt, 1.6)
				# 胴体と頭
				draw_line(hip, neck, shirt, 2.2)
				draw_circle(Vector2(x, -h * 0.92 - bob), h * 0.14, CROWD_SKIN_COLOR)
				# 両腕を振り上げて左右に振る（助けを求める仕草）
				var wave := sin(_t * 6.0 + ph) * 2.5
				draw_line(neck, Vector2(x - h * 0.22 + wave, -h - 3.0 - bob),
						CROWD_SKIN_COLOR, 1.4)
				draw_line(neck, Vector2(x + h * 0.22 + wave, -h - 3.0 - bob),
						CROWD_SKIN_COLOR, 1.4)
			1:
				# 燃焼中: 人影が黒ずみ、炎に包まれる
				var e: float = clampf((p["burn"] as float) / CROWD_BURN_TIME, 0.0, 1.0)
				var dark := Color(0.3, 0.2, 0.15, 1).lerp(Color(0.05, 0.04, 0.04, 1), e)
				draw_line(Vector2(x, 0.0), Vector2(x, -h * (1.0 - e * 0.5)), dark, 2.6)
				for j in 3:
					var flick := 0.7 + 0.3 * sin(_t * 21.0 + ph + j * 2.3)
					draw_circle(Vector2(x + sin(_t * 13.0 + j) * 2.0, -h * (0.25 + j * 0.3)),
							(3.5 - j * 0.7) * flick, Color(1.0, 0.55, 0.15, 0.8 - e * 0.4))
				draw_circle(Vector2(x, -h - 6.0), 3.0, Color(0.3, 0.28, 0.26, 0.3))
			2:
				# 焼け跡（黒い塊とかすかな残り火）
				draw_circle(Vector2(x, -3.0), 4.5, Color(0.07, 0.06, 0.06, 1))
				var ember := 0.5 + 0.5 * sin(_t * 5.0 + ph)
				draw_circle(Vector2(x + 1.5, -4.5), 1.2,
						Color(1.0, 0.4, 0.1, 0.35 * ember))


## 大気圏外の宇宙空間に浮かぶ攻撃戦艦の艦隊。ゆっくり上下に揺れながら、
## 下（地球）へ向けて爆弾を落とし続ける。落ちた爆弾が大気圏に入って流星になる、
## というオチをゴール到達時に見せる。手前の列は大きく、奥の列は小さく暗く描く
func _draw_armada() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ARMADA_SEED
	for i in ARMADA_COUNT:
		var far := i % 3 == 2  # 3 隻に 1 隻は奥の列
		var ship_scale := rng.randf_range(0.5, 0.65) if far else rng.randf_range(0.9, 1.15)
		var x := rng.randf_range(-_half_width - 200.0, _half_width + 200.0)
		var base_y := _top_y - rng.randf_range(ARMADA_OFFSET_Y.x, ARMADA_OFFSET_Y.y) \
				- (180.0 if far else 0.0)
		var bob_ph := rng.randf_range(0.0, TAU)
		var pos := Vector2(x, base_y + sin(_t * 0.7 + bob_ph) * 5.0)
		var dim := 0.55 if far else 1.0

		# 投下される爆弾（船体より奥に描く）。界面をくぐって大気に入り、消える
		var interval := rng.randf_range(ARMADA_BOMB_INTERVAL.x, ARMADA_BOMB_INTERVAL.y)
		var bomb_phase := fposmod(_t + rng.randf_range(0.0, interval), interval) / interval
		var bomb_y := pos.y + 26.0 + ARMADA_BOMB_FALL * bomb_phase * ship_scale
		var bomb_fade := (1.0 - bomb_phase) * dim
		draw_line(Vector2(pos.x, bomb_y - 26.0), Vector2(pos.x, bomb_y),
				Color(ARMADA_BOMB_COLOR.r, ARMADA_BOMB_COLOR.g, ARMADA_BOMB_COLOR.b,
						0.4 * bomb_fade), 2.0)
		draw_circle(Vector2(pos.x, bomb_y), 3.2 * ship_scale,
				Color(1.0, 0.8, 0.45, 0.9 * bomb_fade))

		_draw_armada_ship(pos, ship_scale, dim, i)


## 攻撃戦艦 1 隻。横長の艦体 + 上部艦橋 + 緑の発光列 + 下面の投下口の妖しい光
func _draw_armada_ship(pos: Vector2, ship_scale: float, dim: float, i: int) -> void:
	draw_set_transform(pos, 0.0, Vector2(ship_scale, ship_scale))

	# 艦体（横長の六角形シルエット）
	var hull := Color(ARMADA_HULL_COLOR.r, ARMADA_HULL_COLOR.g, ARMADA_HULL_COLOR.b, dim)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-78.0, 0.0), Vector2(-46.0, -14.0), Vector2(52.0, -14.0),
		Vector2(78.0, 0.0), Vector2(52.0, 14.0), Vector2(-46.0, 14.0),
	]), hull)
	# 上部艦橋と縁のハイライト
	var edge := Color(ARMADA_EDGE_COLOR.r, ARMADA_EDGE_COLOR.g, ARMADA_EDGE_COLOR.b, dim)
	draw_rect(Rect2(-14.0, -26.0, 34.0, 14.0), edge)
	draw_line(Vector2(-78.0, 0.0), Vector2(-46.0, -14.0), edge, 2.0)
	draw_line(Vector2(-46.0, -14.0), Vector2(52.0, -14.0), edge, 2.0)

	# 舷側の発光列（緑。順に明滅して生き物っぽく）
	for j in 6:
		draw_circle(Vector2(-52.0 + j * 20.0, 0.0), 2.6,
				Color(ARMADA_LIGHT_COLOR.r, ARMADA_LIGHT_COLOR.g, ARMADA_LIGHT_COLOR.b,
						(0.5 + 0.5 * sin(_t * 3.0 + j - i)) * dim))
	# 下面の投下口（爆弾が出てくる場所の妖しい光）
	var pulse := 0.6 + 0.4 * sin(_t * 2.2 + i * 1.4)
	draw_circle(Vector2(0.0, 16.0), 10.0,
			Color(ARMADA_BOMB_COLOR.r, ARMADA_BOMB_COLOR.g, ARMADA_BOMB_COLOR.b,
					0.25 * pulse * dim))
	draw_circle(Vector2(0.0, 15.0), 4.5, Color(1.0, 0.75, 0.4, 0.7 * pulse * dim))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 他国のロケット 10 機が視界の下から炎を噴いて登ってくるが、順に隕石に撃ち抜かれて
## 全機墜ちる演出。上昇 → 直前に隕石の光条が刺さる → 爆発 → 燃える残骸が落ちて消える
func _draw_escape_rockets() -> void:
	if not _escape_started:
		return
	for i in ESCAPE_ROCKETS.size():
		var data := ESCAPE_ROCKETS[i]
		var offset: Vector2 = data["offset"]
		var speed: float = data["speed"]
		var doom: float = data["doom"]
		var rocket_scale: float = data["scale"]
		var base := _escape_origin + offset

		if _escape_t < doom:
			# 上昇中
			_draw_escape_rocket_body(base + Vector2(0.0, -speed * _escape_t),
					rocket_scale, i)
			# 撃墜の 0.3 秒前から、隕石の光条が上から刺さってくる
			var lead := _escape_t - (doom - 0.3)
			if lead > 0.0:
				var doom_pos := base + Vector2(0.0, -speed * doom)
				# 光条の向きは機ごとに左右へ振る（同じ角度が 10 本並ぶと嘘くさい）
				var from := Vector2(320.0 * (1.0 if i % 2 == 0 else -1.0), -480.0)
				var head := doom_pos + from * (1.0 - lead / 0.3)
				var dir := -from.normalized()
				draw_line(head - dir * 70.0, head, Color(1.0, 0.7, 0.35, 0.8), 2.5)
			continue

		var doom_pos := base + Vector2(0.0, -speed * doom)
		var td := _escape_t - doom
		if td < ESCAPE_EXPLOSION_TIME:
			_draw_explosion(doom_pos, td / ESCAPE_EXPLOSION_TIME, 70.0 * rocket_scale + 20.0)
		if td < ESCAPE_DEBRIS_TIME:
			# 燃える残骸が弧を描いて落ち、薄れて消える
			var fade := 1.0 - td / ESCAPE_DEBRIS_TIME
			var pos := doom_pos + Vector2(60.0 * td * (1.0 if i % 2 == 0 else -1.0),
					0.5 * PLANE_FALL_ACCEL * td * td)
			draw_circle(pos, 9.0 * rocket_scale + 2.0,
					Color(1.0, 0.55, 0.2, 0.7 * fade))
			for j in 3:
				draw_circle(pos + Vector2(0.0, -14.0 - j * 14.0), 4.0 + j * 2.5,
						Color(0.45, 0.42, 0.4, 0.25 * fade))


## 遠景の脱出ロケット 1 機。プレイヤー機と同じ「上向き + 噴射炎」の記号で描き、
## 倍率で遠近感を出す。i は炎のちらつき位相をずらすためのインデックス
func _draw_escape_rocket_body(pos: Vector2, rocket_scale: float, i: int) -> void:
	draw_set_transform(pos, 0.0, Vector2(rocket_scale, rocket_scale))

	# 噴射炎（ちらつき）と煙の尾
	var flick := 0.75 + 0.25 * sin(_t * 23.0 + i * 2.7)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7.0, 20.0), Vector2(7.0, 20.0), Vector2(0.0, 20.0 + 34.0 * flick),
	]), Color(1.0, 0.6, 0.2, 0.85))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.5, 20.0), Vector2(3.5, 20.0), Vector2(0.0, 20.0 + 20.0 * flick),
	]), Color(1.0, 0.9, 0.55, 0.9))
	for j in 4:
		draw_circle(Vector2(sin(_t * 3.0 + j * 1.8) * 4.0, 46.0 + j * 22.0),
				6.0 + j * 3.0, Color(0.55, 0.55, 0.6, 0.22 - j * 0.045))

	# 機体（カプセル型 + ノーズコーン + フィン）
	draw_rect(Rect2(-9.0, -12.0, 18.0, 32.0), ESCAPE_BODY_COLOR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9.0, -12.0), Vector2(9.0, -12.0), Vector2(0.0, -30.0),
	]), Color(0.85, 0.4, 0.3, 1))
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * 9.0, 20.0), Vector2(side * 9.0, 6.0), Vector2(side * 17.0, 20.0),
		]), Color(0.5, 0.53, 0.62, 1))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 旅客機の演出。飛行（2〜3 秒）→ 空中爆発 → 火を噴いて墜落 → 地面で爆発 →
## 墜落地点が燃え続ける、を _plane_t だけで手続き的に描く（状態変数を増やさない）
func _draw_plane() -> void:
	if not _plane_started:
		return
	var cruise_y := -Units.m_to_px(PLANE_ALTITUDE_M)
	# 爆発地点（開始時のカメラ中央）から逆算して、画面右外から入ってくる開始位置を決める
	var start_x := _plane_boom_x + PLANE_SPEED * PLANE_FLY_TIME

	# 飛行中（左向きに巡航。機体は _draw_plane_body）
	if _plane_t < PLANE_FLY_TIME:
		_draw_plane_body(Vector2(start_x - PLANE_SPEED * _plane_t, cruise_y), _plane_t)
		return

	var boom := Vector2(_plane_boom_x, cruise_y)
	var tf := _plane_t - PLANE_FLY_TIME
	# 被弾点から地面（y=0）までの落下時間
	var fall_time := sqrt(2.0 * (0.0 - cruise_y) / PLANE_FALL_ACCEL)

	if tf < fall_time:
		# 火を噴きながら墜落する残骸（炎 3 つ + 煙 3 つの尾を引く）
		var pos := boom + Vector2(-PLANE_SPEED * PLANE_FALL_DRIFT * tf,
				0.5 * PLANE_FALL_ACCEL * tf * tf)
		var back := -Vector2(-PLANE_SPEED * PLANE_FALL_DRIFT,
				PLANE_FALL_ACCEL * tf).normalized()
		for i in 6:
			var flick := 0.7 + 0.3 * sin(_t * 17.0 + i * 2.1)
			var color := Color(1.0, 0.5, 0.15, 0.5 * flick) if i < 3 \
					else Color(0.4, 0.38, 0.36, 0.3)
			draw_circle(pos + back * (8.0 + i * 16.0), 5.0 + i * 2.5, color)
		# 回転しながら落ちる機体の破片
		draw_set_transform(pos, tf * 7.0, Vector2.ONE)
		draw_rect(Rect2(-16.0, -4.0, 32.0, 8.0), PLANE_BODY_COLOR)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 空中爆発（墜落の始まりと重ねて描く）
	if tf < PLANE_EXPLOSION_TIME:
		_draw_explosion(boom, tf / PLANE_EXPLOSION_TIME, 90.0)

	# 地面に到達: 着地爆発 → 以後は墜落地点が燃え続ける（煙の柱つき）
	if tf >= fall_time:
		var crash := Vector2(boom.x - PLANE_SPEED * PLANE_FALL_DRIFT * fall_time, -8.0)
		var tg := tf - fall_time
		if tg < PLANE_GROUND_EXPLOSION_TIME:
			_draw_explosion(crash, tg / PLANE_GROUND_EXPLOSION_TIME, 120.0)
		var flick := 0.72 + 0.28 * sin(_t * 7.0)
		draw_circle(crash, 40.0, Color(1.0, 0.45, 0.12, 0.1 * flick))
		draw_circle(crash, 18.0, Color(1.0, 0.45, 0.12, 0.7 * flick))
		draw_circle(crash + Vector2(0.0, -8.0), 8.0, Color(1.0, 0.85, 0.45, 0.85 * flick))
		for i in 5:
			draw_circle(crash + Vector2(sin(_t * 0.9 + i) * 8.0 + i * 4.0,
					-30.0 - i * 26.0), 10.0 + i * 4.0,
					Color(0.25, 0.23, 0.22, 0.16 - i * 0.02))


## 左向きに巡航する旅客機のシルエット。夜なので暗い機体を窓明かりと航法灯で見せる。
## 座標は機体ローカルで書き、PLANE_SCALE の transform でまとめて拡大する
func _draw_plane_body(pos: Vector2, t: float) -> void:
	draw_set_transform(pos, 0.0, Vector2(PLANE_SCALE, PLANE_SCALE))

	# 飛行機雲（後方へ薄く途切れながら伸びる）
	for i in 5:
		var d := 34.0 + i * 26.0
		draw_line(Vector2(d, 2.0), Vector2(d + 20.0, 2.0),
				Color(0.75, 0.8, 0.88, 0.14 - i * 0.022), 3.0)

	# 胴体（左が機首）と尾翼・主翼
	draw_line(Vector2(-26.0, 0.0), Vector2(24.0, 0.0), PLANE_BODY_COLOR, 6.0)
	draw_circle(Vector2(-26.0, 0.0), 3.0, PLANE_BODY_COLOR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.0, 0.0), Vector2(16.0, 13.0), Vector2(6.0, 0.0),
	]), PLANE_BODY_COLOR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(18.0, 0.0), Vector2(28.0, -13.0), Vector2(26.0, 0.0),
	]), PLANE_BODY_COLOR)

	# 窓明かりの列
	for i in 6:
		draw_circle(Vector2(-19.0 + i * 7.0, -1.5), 1.2, Color(1.0, 0.9, 0.6, 0.8))

	# 航法灯（翼端の赤 + 尾部の白ストロボ。実機っぽく別周期で点滅）
	if fmod(t, 1.0) < 0.55:
		draw_circle(Vector2(16.0, 13.0), 2.2, Color(1.0, 0.2, 0.15, 0.95))
	if fmod(t, 0.9) < 0.12:
		draw_circle(Vector2(28.0, -13.0), 2.6, Color(1.0, 1.0, 1.0, 0.95))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 山・ビルのあちこちで燃える火災。ちらつく光の点 + 地平線を赤く染める帯。
## 位置・大きさは固定シードで決定的、明滅だけ _t で揺らす
func _draw_fires(left: float, right: float) -> void:
	# 地平線全体の赤い照り返し（矩形を重ねた擬似グラデーション。街明かりの紫の上に赤を足す）
	for i in 4:
		var h := 240.0 - i * 52.0
		draw_rect(Rect2(left, -h, right - left, h),
				Color(FIRE_HORIZON_COLOR.r, FIRE_HORIZON_COLOR.g, FIRE_HORIZON_COLOR.b, 0.035))

	var rng := RandomNumberGenerator.new()
	rng.seed = FIRE_SEED
	for _i in FIRE_COUNT:
		var pos := Vector2(rng.randf_range(left, right), -rng.randf_range(6.0, 220.0))
		var size := rng.randf_range(6.0, 18.0)
		var freq := rng.randf_range(5.0, 10.0)
		var ph := rng.randf_range(0.0, TAU)
		# ちらつき（大きさと明るさを別位相で揺らすと火っぽくなる）
		var flicker := 0.72 + 0.28 * sin(_t * freq + ph)
		var s := size * (0.85 + 0.15 * sin(_t * freq * 1.7 + ph * 2.0))

		draw_circle(pos, s * 3.4, Color(FIRE_COLOR.r, FIRE_COLOR.g, FIRE_COLOR.b,
				0.07 * flicker))
		draw_circle(pos, s * 1.7, Color(FIRE_COLOR.r, FIRE_COLOR.g, FIRE_COLOR.b,
				0.16 * flicker))
		draw_circle(pos, s, Color(FIRE_COLOR.r, FIRE_COLOR.g, FIRE_COLOR.b,
				0.8 * flicker))
		# 芯は少し上に（炎の形の示唆）
		draw_circle(pos + Vector2(0.0, -s * 0.35), s * 0.45,
				Color(FIRE_CORE_COLOR.r, FIRE_CORE_COLOR.g, FIRE_CORE_COLOR.b, 0.9 * flicker))


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
