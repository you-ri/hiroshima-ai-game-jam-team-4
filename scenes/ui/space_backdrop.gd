extends Control
## タイトル背景。星・地球・接近する小惑星 Apophis を図形描画だけで組む。
##
## 画像アセットをまだ持たないので、すべて _draw() の手描きで作る。
## 乱数は固定シードなので、実行のたびに星の並びが変わることはない。
## 座標はすべて size（＝ビューポート基準サイズ）に対する比率で持つ。

## 星の数。増やしても見た目はあまり変わらず _draw のコストだけ上がる
const STAR_COUNT := 240
## 固定シード。Apophis が地球に最接近する 2029-04-13 から取った
const RNG_SEED := 20290413
## 流れ星の本数と、1 本が画面を横切るまでの秒数
const METEOR_COUNT := 5
const METEOR_CYCLE := 3.6
## 小惑星の輪郭を作る頂点数
const ROCK_VERTS := 13

const COLOR_STAR := Color(0.86, 0.91, 1.0)
const COLOR_EARTH_BODY := Color(0.04, 0.07, 0.13)
const COLOR_EARTH_LIMB := Color(0.29, 0.62, 0.92)
const COLOR_ROCK := Color(0.15, 0.13, 0.14)
const COLOR_ROCK_EDGE := Color(0.55, 0.42, 0.33)
const COLOR_HEAT := Color(1.0, 0.5, 0.16)

var _stars: Array[Dictionary] = []
var _meteors: Array[Dictionary] = []
var _rock: PackedVector2Array = PackedVector2Array()
var _craters: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	_build_stars(rng)
	_build_meteors(rng)
	_build_rock(rng)
	print("[backdrop] stars=%d meteors=%d rock_verts=%d" % [_stars.size(), _meteors.size(), _rock.size()])


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
	_draw_apophis(w, h)


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
