extends Node2D
class_name Explosion
## ロケット被弾時の爆発エフェクト（見た目のみ、Physics に触れない）。
## add_child した瞬間に一発バーストで再生され、終わったら自分で消える。
## フラッシュ（_draw）+ 火球・火花・煙（CPUParticles2D）の重ねがけ。
## GPUParticles2D ではなく CPUParticles2D を使う（ヘッドレス/dummy レンダラでも動く）。

## フラッシュの持続時間（秒）
const FLASH_TIME := 0.18
## 全エフェクトが終わって自壊するまでの時間（秒）
const CLEANUP_TIME := 2.0

@onready var _boom: AudioStreamPlayer = $Boom

var _flash_t := 0.0


func _ready() -> void:
	z_index = 10  # 障害物・機体より手前で光らせる

	# 火球: 大きめの塊がドッと広がる
	_add_burst(110, 100.0, 420.0, 4.0, 9.0, 0.8, [
		Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.5, 0.1, 0.9), Color(0.45, 0.1, 0.05, 0.0)])
	# 火花: 小さく速い粒が四方八方へ
	_add_burst(90, 320.0, 780.0, 1.2, 2.6, 0.55, [
		Color(1.0, 1.0, 0.85, 1.0), Color(1.0, 0.7, 0.2, 0.0)])
	# 煙: ゆっくり上へ流れて消える
	_add_burst(35, 30.0, 130.0, 8.0, 16.0, 1.4, [
		Color(0.35, 0.33, 0.3, 0.6), Color(0.2, 0.2, 0.2, 0.0)], Vector2(0.0, -70.0))

	await get_tree().create_timer(CLEANUP_TIME).timeout
	# 見た目より爆発音のほうが長い。鳴り終わるまで自壊を待つ（消すと音も切れる）
	if _boom.playing:
		await _boom.finished
	queue_free()


func _process(delta: float) -> void:
	if _flash_t <= FLASH_TIME:
		_flash_t += delta
		queue_redraw()


## 爆心のフラッシュ。白→透明へ一瞬で抜ける
func _draw() -> void:
	var t := _flash_t / FLASH_TIME
	if t < 1.0:
		draw_circle(Vector2.ZERO, 70.0 + 90.0 * t, Color(1.0, 0.95, 0.75, 0.85 * (1.0 - t)))


func _add_burst(amount: int, v_min: float, v_max: float, s_min: float, s_max: float,
		life: float, colors: Array, gravity := Vector2(0.0, 140.0)) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0  # 全粒を同時に放出（バースト）
	p.spread = 180.0       # 全方位
	p.gravity = gravity
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0

	var g := Gradient.new()
	var n := colors.size()
	var offsets := PackedFloat32Array()
	for i in n:
		offsets.append(float(i) / float(n - 1))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	p.color_ramp = g

	p.emitting = true
	add_child(p)
