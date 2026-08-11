extends Control
## タイトル／ゲームオーバーの共通背景。星・地球・接近する小惑星 Apophis を図形描画だけで組む。
##
## 画像アセットをまだ持たないので、すべて _draw() の手描きで作る。
## 乱数は固定シードなので、実行のたびに星の並びが変わることはない。
## 座標はすべて size（＝ビューポート基準サイズ）に対する比率で持つ。
##
## `earth_destroyed` を立てると地球だけが砕けた姿に変わる。星・星雲・小惑星は
## 同じシードから作るので位置が完全に一致し、タイトルと同じレイアウトのまま
## 地球の状態だけが変わって見える。

## 地球を破壊された状態で描くか。タイトル画面は false、ゲームオーバー／クリア画面は true。
@export var earth_destroyed := false
## 脱出したロケットを大きく描くか。ゲームクリア画面だけ true。
@export var show_rocket := false
## 接近中の小惑星 Apophis を描くか。決着後の画面（地球が砕けたあと）では
## すでに衝突済みなので false にする。
## 描画を止めるだけで生成（_build_rock）は必ず通す。飛ばすと乱数の消費がずれて
## 星の配置がタイトルと変わってしまう。
@export var show_asteroid := true

## 星の数。増やしても見た目はあまり変わらず _draw のコストだけ上がる
const STAR_COUNT := 240
## 固定シード。Apophis が地球に最接近する 2029-04-13 から取った
const RNG_SEED := 20290413
## 流れ星の本数と、1 本が画面を横切るまでの秒数
const METEOR_COUNT := 5
const METEOR_CYCLE := 3.6
## 小惑星の輪郭を作る頂点数
const ROCK_VERTS := 13
## 破壊された地球の亀裂の本数と、飛び散る破片の数
const FISSURE_COUNT := 8
const CHUNK_COUNT := 10

const COLOR_STAR := Color(0.86, 0.91, 1.0)
const COLOR_EARTH_BODY := Color(0.04, 0.07, 0.13)
const COLOR_EARTH_LIMB := Color(0.29, 0.62, 0.92)
const COLOR_ROCK := Color(0.15, 0.13, 0.14)
const COLOR_ROCK_EDGE := Color(0.55, 0.42, 0.33)
const COLOR_HEAT := Color(1.0, 0.5, 0.16)
const COLOR_EARTH_DEAD := Color(0.06, 0.045, 0.05)
const COLOR_MAGMA := Color(1.0, 0.36, 0.10)

# ロケットの形と色は本編の actors/rocket/rocket.tscn からそのまま持ってきている。
# 向こうを描き変えたらここも合わせること（別物に見えると「脱出した機体」に見えない）。
const ROCKET_BODY_COLOR := Color(0.72, 0.76, 0.82)
const ROCKET_NOSE_COLOR := Color(0.9, 0.25, 0.2)
const ROCKET_FLAME_COLOR := Color(1, 0.55, 0.1, 0.9)
const ROCKET_CORE_COLOR := Color(1, 0.9, 0.5)
## 炎ポリゴンが機体に付く位置（ローカル y）。ここを軸に伸縮させないと根元に隙間が空く
const ROCKET_NOZZLE_Y := 46.0

## 機体の輪郭そのもの（actors/rocket/rocket.tscn の Body と同一）。凹形状なので塗りには使わず、
## 縁取りの線と、本編と一致しているかの検証にだけ使う。
var _rocket_body := PackedVector2Array([
	Vector2(0, -56), Vector2(18, -30), Vector2(18, -8), Vector2(30, 20), Vector2(18, 20),
	Vector2(18, 38), Vector2(0, 44), Vector2(-18, 38), Vector2(-18, 20), Vector2(-30, 20),
	Vector2(-18, -8), Vector2(-18, -30)])
# 塗りは上の輪郭を「胴体＋左右のフィン」の凸な 3 つに分けて描く。
# 凹んだままだと三角形分割の解が一意に決まらず、輪郭からはみ出して太った形になる（実測で確認）。
# この 3 つの和は _rocket_body と完全に一致する。
var _rocket_hull := PackedVector2Array([
	Vector2(0, -56), Vector2(18, -30), Vector2(18, 38), Vector2(0, 44),
	Vector2(-18, 38), Vector2(-18, -30)])
var _rocket_fin_right := PackedVector2Array([
	Vector2(18, -8), Vector2(30, 20), Vector2(18, 20)])
var _rocket_fin_left := PackedVector2Array([
	Vector2(-18, -8), Vector2(-30, 20), Vector2(-18, 20)])
var _rocket_nose := PackedVector2Array([
	Vector2(0, -56), Vector2(12, -32), Vector2(0, -18), Vector2(-12, -32)])
var _rocket_flame := PackedVector2Array([
	Vector2(0, 46), Vector2(12, 62), Vector2(0, 118), Vector2(-12, 62)])
var _rocket_core := PackedVector2Array([
	Vector2(0, 46), Vector2(7, 58), Vector2(0, 86), Vector2(-7, 58)])

var _stars: Array[Dictionary] = []
var _meteors: Array[Dictionary] = []
var _rock: PackedVector2Array = PackedVector2Array()
var _craters: Array[Dictionary] = []
var _fissures: Array[PackedVector2Array] = []
var _chunks: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	# 生成順を変えると乱数の消費がずれて星の配置まで変わる。末尾に足すこと
	_build_stars(rng)
	_build_meteors(rng)
	_build_rock(rng)
	_build_debris(rng)
	print("[backdrop] stars=%d meteors=%d rock_verts=%d destroyed=%s fissures=%d chunks=%d" % [
		_stars.size(), _meteors.size(), _rock.size(), earth_destroyed, _fissures.size(), _chunks.size()])


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	_draw_nebula(w, h)
	_draw_stars(w, h)
	_draw_earth(w, h)
	_draw_meteors(w, h)
	if show_asteroid:
		_draw_apophis(w, h)
	if show_rocket:
		_draw_rocket(w, h)


# --- 生成 ---------------------------------------------------------------

func _build_stars(rng: RandomNumberGenerator) -> void:
	for i in STAR_COUNT:
		_stars.append({
			"u": rng.randf(),
			"v": rng.randf_range(0.0, 0.92),
			"radius": rng.randf_range(0.6, 2.1),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.4, 2.2),
			"alpha": rng.randf_range(0.25, 1.0),
		})


func _build_meteors(rng: RandomNumberGenerator) -> void:
	for i in METEOR_COUNT:
		# 画面右上から左下へ流す。地球が左下にあるので「落ちてくる」向きになる
		var angle := deg_to_rad(rng.randf_range(148.0, 166.0))
		_meteors.append({
			"start": Vector2(rng.randf_range(0.55, 1.25), rng.randf_range(-0.15, 0.45)),
			"dir": Vector2(cos(angle), -sin(angle)).normalized(),
			"travel": rng.randf_range(0.55, 0.95),
			"tail": rng.randf_range(0.08, 0.18),
			"offset": float(i) / float(METEOR_COUNT) + rng.randf_range(0.0, 0.12),
			"width": rng.randf_range(1.4, 2.8),
		})


func _build_rock(rng: RandomNumberGenerator) -> void:
	var verts := PackedVector2Array()
	for i in ROCK_VERTS:
		var a := TAU * float(i) / float(ROCK_VERTS)
		var r := rng.randf_range(0.74, 1.0)
		verts.append(Vector2(cos(a), sin(a)) * r)
	_rock = verts
	for i in 4:
		_craters.append({
			"pos": Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)),
			"radius": rng.randf_range(0.1, 0.22),
		})


## 破壊された地球用の亀裂と破片。earth_destroyed が false でも作る
## （生成しないと乱数の消費が変わり、星の配置がタイトルとずれる）
func _build_debris(rng: RandomNumberGenerator) -> void:
	for i in FISSURE_COUNT:
		# 中心付近から縁へ向かってギザギザに伸びる線。半径 1.0 を地球の縁とする
		var base := rng.randf_range(0.0, TAU)
		var pts := PackedVector2Array()
		for s in 7:
			var t := float(s) / 6.0
			var a := base + rng.randf_range(-0.16, 0.16)
			pts.append(Vector2(cos(a), sin(a)) * lerpf(0.06, 1.0, t))
		_fissures.append(pts)
	for i in CHUNK_COUNT:
		var angle := rng.randf_range(0.0, TAU)
		var verts := rng.randi_range(3, 5)
		# 大きいと宇宙に浮いた板に見え、遠いと画面中央の文字に重なる。縁の近くに小さく散らす
		var scale := rng.randf_range(0.022, 0.062)
		var poly := PackedVector2Array()
		for k in verts:
			var a := TAU * float(k) / float(verts)
			poly.append(Vector2(cos(a), sin(a)) * scale * rng.randf_range(0.55, 1.0))
		_chunks.append({
			"poly": poly,
			"angle": angle,
			"dist": rng.randf_range(1.02, 1.22),
			"spin": rng.randf_range(-0.7, 0.7),
			"bob": rng.randf_range(0.012, 0.05),
			"phase": rng.randf_range(0.0, TAU),
		})


# --- 描画 ---------------------------------------------------------------

func _draw_nebula(w: float, h: float) -> void:
	# 大きく薄い円を重ねて星雲のムラを作る
	var blobs := [
		[Vector2(0.74, 0.22), 0.42, Color(0.30, 0.12, 0.34, 0.055)],
		[Vector2(0.22, 0.58), 0.50, Color(0.10, 0.20, 0.42, 0.055)],
		[Vector2(0.52, 0.05), 0.34, Color(0.35, 0.18, 0.12, 0.040)],
	]
	for blob in blobs:
		var center: Vector2 = blob[0] * Vector2(w, h)
		var radius: float = float(blob[1]) * h
		var col: Color = blob[2]
		for i in 5:
			var t := float(i) / 5.0
			draw_circle(center, radius * (1.0 - t * 0.6), Color(col.r, col.g, col.b, col.a))


func _draw_stars(w: float, h: float) -> void:
	for s in _stars:
		var twinkle: float = 0.55 + 0.45 * sin(_time * float(s["speed"]) + float(s["phase"]))
		var col := COLOR_STAR
		col.a = float(s["alpha"]) * twinkle
		var pos := Vector2(float(s["u"]) * w, float(s["v"]) * h)
		var r: float = float(s["radius"])
		draw_circle(pos, r, col)
		if r > 1.7:
			# 明るい星だけ十字のにじみを足す
			var flare := r * 3.2
			var faint := Color(col.r, col.g, col.b, col.a * 0.35)
			draw_line(pos - Vector2(flare, 0), pos + Vector2(flare, 0), faint, 1.0)
			draw_line(pos - Vector2(0, flare), pos + Vector2(0, flare), faint, 1.0)


func _draw_earth(w: float, h: float) -> void:
	var center := Vector2(w * 0.14, h * 1.22)
	var radius := h * 0.66
	if earth_destroyed:
		_draw_earth_destroyed(center, radius, h)
		return
	# 大気の輝き。外側へ薄くなる輪を細かく重ねて、縞に見えないようにする
	for i in 22:
		var t := float(i) / 22.0
		var col := COLOR_EARTH_LIMB
		col.a = 0.05 * (1.0 - t)
		draw_arc(center, radius + t * h * 0.10, 0.0, TAU, 96, col, 4.0, true)
	draw_circle(center, radius, COLOR_EARTH_BODY)
	# 大陸に見えるムラ。中心からの距離＋半径が radius を超えると宇宙側へはみ出すので、
	# |offset| + patch <= 0.88 に収めて必ず地球の内側に入るようにする
	var patches := [
		[Vector2(0.28, -0.58), 0.17],
		[Vector2(0.60, -0.34), 0.13],
		[Vector2(-0.12, -0.70), 0.14],
		[Vector2(0.12, -0.26), 0.15],
	]
	for p in patches:
		var offset: Vector2 = p[0]
		draw_circle(center + offset * radius, float(p[1]) * radius, Color(0.07, 0.13, 0.12, 0.8))
	# 太陽に照らされた縁（右上側）。角度は画面座標なので y は下向き
	draw_arc(center, radius - 2.0, -2.35, 0.25, 128, COLOR_EARTH_LIMB, 5.0, true)
	draw_arc(center, radius - 9.0, -2.10, 0.05, 128, Color(0.45, 0.78, 1.0, 0.45), 2.5, true)


## 砕けた地球。位置と半径は健在なときと同じで、状態だけが違う
func _draw_earth_destroyed(center: Vector2, radius: float, h: float) -> void:
	# 脈打つ余熱。青い大気の代わりに赤熱した輪を出す
	var pulse: float = 0.85 + 0.15 * sin(_time * 1.6)
	for i in 22:
		var t := float(i) / 22.0
		var col := COLOR_MAGMA
		col.a = 0.055 * (1.0 - t) * pulse
		draw_arc(center, radius + t * h * 0.13, 0.0, TAU, 96, col, 4.0, true)
	draw_circle(center, radius, COLOR_EARTH_DEAD)

	# 亀裂。太く暗い線の上に細く明るい線を重ねて、光っている溝に見せる
	for f in _fissures:
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for v in f:
			outer.append(center + v * radius)
			inner.append(center + v * radius)
		draw_polyline(outer, Color(0.5, 0.15, 0.04, 0.55), 9.0, true)
		draw_polyline(inner, Color(COLOR_MAGMA.r, COLOR_MAGMA.g, COLOR_MAGMA.b, 0.9 * pulse), 3.0, true)

	# Apophis が当たった跡。小惑星が来る右上側に開いた穴。
	# 少ない枚数を濃く重ねると同心円の縞（的のような輪）になるので、薄く細かく重ねる
	var impact := center + Vector2(0.62, -0.58).normalized() * radius * 0.66
	var core := radius * 0.10
	for i in 20:
		var t := float(i) / 20.0
		var col := COLOR_MAGMA
		col.a = 0.035 * (1.0 - t) * pulse
		draw_circle(impact, core * (1.0 + t * 3.0), col)
	draw_circle(impact, core * 0.55, Color(1.0, 0.72, 0.32, 0.9 * pulse))

	# 死んだ星の縁。健在なときの青い大気の位置に、鈍い残光だけを残す
	draw_arc(center, radius - 2.0, -2.35, 0.25, 128, Color(0.52, 0.20, 0.11, 0.5), 3.0, true)

	# 飛び散った破片。ゆっくり外へ漂わせる
	for c in _chunks:
		var angle: float = float(c["angle"])
		var dist: float = float(c["dist"]) + float(c["bob"]) * sin(_time * 0.5 + float(c["phase"]))
		var at := center + Vector2(cos(angle), sin(angle)) * radius * dist
		var spin := _time * float(c["spin"])
		var poly := PackedVector2Array()
		for v in PackedVector2Array(c["poly"]):
			poly.append(at + v.rotated(spin) * radius)
		draw_colored_polygon(poly, COLOR_ROCK)
		var outline := poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, Color(0.62, 0.30, 0.16, 0.8), 1.5, true)


## 脱出したロケット。砕けた地球（左下）に背を向け、右上へ昇っていく姿。
## 画面右下の空いている領域に置く（中央の文字と右下のクレジットを避ける位置）。
func _draw_rocket(w: float, h: float) -> void:
	var at := Vector2(w * 0.79, h * 0.60)
	# 本編のポリゴンは全長 100 単位。画面高さに対する比率で拡大する
	var s := h * 0.0042
	# 傾けすぎると大きく映したときに機体だと分かりにくい。右上へ昇る程度に留める
	var rot := deg_to_rad(16.0)
	var flicker: float = 0.80 + 0.14 * sin(_time * 12.0) + 0.06 * sin(_time * 27.0)
	var back := Vector2(0, 1).rotated(rot)

	# 噴射の余韻。地球の方向へ長く尾を引かせる
	for i in 14:
		var t := float(i) / 14.0
		var col := COLOR_HEAT
		col.a = 0.05 * (1.0 - t)
		draw_circle(at + back * s * (70.0 + t * 460.0), s * (28.0 - t * 14.0), col)

	# 機体は底が 1 点に尖っているため、炎をそのまま繋ぐと離れて見える。
	# 根元を機体側へ少し潜り込ませてから描く（機体を後で上に重ねるので継ぎ目は出ない）
	var flame_at := at + (Vector2(0, -10) * s).rotated(rot)
	draw_colored_polygon(_place(_flicker_flame(_rocket_flame, flicker), flame_at, s, rot), ROCKET_FLAME_COLOR)
	draw_colored_polygon(_place(_flicker_flame(_rocket_core, flicker), flame_at, s, rot), ROCKET_CORE_COLOR)

	# 胴体とフィンを別々に塗る（どれも凸なので分割は一意に決まる）
	draw_colored_polygon(_place(_rocket_hull, at, s, rot), ROCKET_BODY_COLOR)
	draw_colored_polygon(_place(_rocket_fin_right, at, s, rot), ROCKET_BODY_COLOR)
	draw_colored_polygon(_place(_rocket_fin_left, at, s, rot), ROCKET_BODY_COLOR)
	draw_colored_polygon(_place(_rocket_nose, at, s, rot), ROCKET_NOSE_COLOR)

	# 操縦席の窓。本編の機体（豆粒サイズ）には無いが、大きく映すと単色の板に見えて
	# ロケットだと分からないため、この画面用の描き込みとして足している
	var window_at := at + (Vector2(0, -20) * s).rotated(rot)
	draw_circle(window_at, s * 9.5, Color(0.16, 0.20, 0.26))
	draw_circle(window_at, s * 7.5, Color(0.45, 0.74, 0.95))
	draw_circle(window_at + (Vector2(-2.5, -2.5) * s).rotated(rot), s * 2.6, Color(0.85, 0.95, 1.0, 0.8))

	# 単色の板に見えないよう、輪郭にだけ光を乗せる。線は凹形状でも問題ない
	var rim := _place(_rocket_body, at, s, rot)
	rim.append(rim[0])
	draw_polyline(rim, Color(0.97, 0.99, 1.0, 0.55), 2.5, true)


## 炎を根元（ノズル）を軸に伸縮させる。全体に係数を掛けると機体との間に隙間が空く
func _flicker_flame(src: PackedVector2Array, flicker: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in src:
		out.append(Vector2(v.x, ROCKET_NOZZLE_Y + (v.y - ROCKET_NOZZLE_Y) * flicker))
	return out


func _place(src: PackedVector2Array, at: Vector2, s: float, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in src:
		out.append(at + (v * s).rotated(rot))
	return out


func _draw_meteors(w: float, h: float) -> void:
	var diag := Vector2(w, h).length()
	for m in _meteors:
		var t := fmod(_time / METEOR_CYCLE + float(m["offset"]), 1.0)
		if t > 0.6:
			continue  # 残りは次が流れるまでの間
		var progress := t / 0.6
		var fade: float = sin(progress * PI)
		var dir: Vector2 = m["dir"]
		var head: Vector2 = Vector2(m["start"]) * Vector2(w, h) + dir * (progress * float(m["travel"]) * diag)
		var tail_len: float = float(m["tail"]) * diag
		# 尾を 3 分割して先端ほど明るくする
		for i in 3:
			var a := float(i) / 3.0
			var b := float(i + 1) / 3.0
			var col := COLOR_HEAT.lerp(Color(1, 1, 1), 1.0 - a)
			col.a = fade * (1.0 - a) * 0.8
			draw_line(head - dir * tail_len * b, head - dir * tail_len * a, col, float(m["width"]) * (1.0 - a * 0.6))
		draw_circle(head, float(m["width"]) * 1.1, Color(1, 1, 1, fade))


func _draw_apophis(w: float, h: float) -> void:
	var drift := Vector2(sin(_time * 0.31) * 7.0, cos(_time * 0.23) * 9.0)
	var center := Vector2(w * 0.79, h * 0.27) + drift
	var radius := h * 0.062
	var spin := _time * 0.17
	# 進行方向は左下（地球側）なので、熱の尾は右上へ伸びる。
	# 円を並べると数珠つなぎに見えるため、先細りの四角形を重ねて作る
	var dir := Vector2(1.0, -0.62).normalized()
	var perp := Vector2(-dir.y, dir.x)
	draw_circle(center, radius * 1.6, Color(COLOR_HEAT.r, COLOR_HEAT.g, COLOR_HEAT.b, 0.10))
	for i in 5:
		var t := float(i) / 5.0
		var half := radius * (1.15 - t * 0.32)
		var length := radius * (4.4 - t * 1.5)
		var col := COLOR_HEAT
		col.a = 0.07 + t * 0.045
		draw_colored_polygon(PackedVector2Array([
			center + perp * half,
			center + dir * length + perp * half * 0.12,
			center + dir * length - perp * half * 0.12,
			center - perp * half,
		]), col)
	var points := PackedVector2Array()
	for v in _rock:
		points.append(center + v.rotated(spin) * radius)
	draw_colored_polygon(points, COLOR_ROCK)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, COLOR_ROCK_EDGE, 2.0, true)
	for c in _craters:
		draw_circle(center + Vector2(c["pos"]).rotated(spin) * radius, float(c["radius"]) * radius, Color(0.09, 0.08, 0.09))
	# 照らされている縁を上書きしてハイライトにする
	var lit := PackedVector2Array()
	for i in range(points.size() / 2 + 1):
		lit.append(points[i])
	draw_polyline(lit, Color(0.78, 0.55, 0.38, 0.7), 2.0, true)
