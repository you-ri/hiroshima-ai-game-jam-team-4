extends RigidBody2D
class_name Rocket
## ロケット本体（射撃なし）。
## 仕様（docs/Spec.txt）に合わせた挙動:
## - W を連打: 押すたびに炎が出て前方（機首方向）へ推進力を得る。押しっぱなしは無効
## - 何も押さなければ重力で自然落下
## - A / D: 推力の向き＝機体の向きを左右に回転
##
## 被弾判定は子の Hitbox(Area2D) が障害物(Area2D)と重なったとき `hit` を発火する。
## 当たった後の処理（残機・リスポーン）はシーン側（scenes/main.gd）が行う。

signal hit

## 旋回角速度（rad/s）。
const TURN_SPEED := 3.0
## 連打 1 回で得る推進力（速度変化 px/s）。質量 1、重力 980 に対して 連打 6 回/s で
## 約 820 px/s の上昇を得る（6 * 300 - 980）。
const THRUST_IMPULSE := 300.0
## 炎が出ている時間（秒）。1 連打ごとにこの時間だけ炎が見える。
const FLAME_TIME := 0.15

## false で入力を無視する（クリア・ゲームオーバー後に設定される）
var controls_enabled := true
## 被弾後の無敵。true の間は Hitbox を無効化し点滅する（シーン側が制御）
var invulnerable := false

@onready var _flame: Polygon2D = $Flame
@onready var _flame_core: Polygon2D = $FlameCore
@onready var _hitbox: Area2D = $Hitbox

var _flame_timer := 0.0
var _flicker := 0.0
var _blink_t := 0.0


func _ready() -> void:
	add_to_group("player")
	_hitbox.area_entered.connect(_on_hitbox_area_entered)
	_set_flame(false)


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		angular_velocity = 0.0
		_set_flame(false)
		return

	angular_velocity = TURN_SPEED * Input.get_axis("rotate_left", "rotate_right")

	if Input.is_action_just_pressed("thrust"):
		var forward := Vector2.UP.rotated(rotation)
		apply_central_impulse(forward * THRUST_IMPULSE)
		_flame_timer = FLAME_TIME

	_flicker += delta


func _process(delta: float) -> void:
	if _flame_timer > 0.0:
		_flame_timer -= delta
	_set_flame(_flame_timer > 0.0)

	if _flame.visible:
		# 炎の揺らぎ（見た目のみ。当たり判定には影響しない）
		var s := 1.0 + 0.15 * sin(_flicker * 5.0) + 0.08 * sin(_flicker * 11.0)
		_flame.scale = Vector2(s, s)
		_flame.rotation = 0.08 * sin(_flicker * 7.0)
		_flame_core.scale = Vector2(1.0 + 0.1 * sin(_flicker * 9.0), 1.0 + 0.1 * sin(_flicker * 9.0))

	if invulnerable:
		_blink_t += delta
		modulate.a = 0.35 + 0.65 * absf(sin(_blink_t * 10.0))


func set_invulnerable(on: bool) -> void:
	invulnerable = on
	_hitbox.set_deferred("monitoring", not on)
	if not on:
		modulate.a = 1.0
		_blink_t = 0.0


func _set_flame(on: bool) -> void:
	_flame.visible = on
	_flame_core.visible = on
	if not on:
		_flame.scale = Vector2.ONE
		_flame.rotation = 0.0
		_flame_core.scale = Vector2.ONE


func _on_hitbox_area_entered(_area: Area2D) -> void:
	if not invulnerable and controls_enabled:
		emit_signal("hit")