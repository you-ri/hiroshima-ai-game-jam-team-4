extends RigidBody2D
class_name Rocket
## ロケット本体。射撃なしの物理挙動。
## - 何も押さなければ重力で自然落下
## - W: 下向きに炎を出して推進（推力を得る）
## - A / D: 左右に回転（角速度を直接制御）
##
## 操作の取り込みはこのスクリプトが行い、クリア判定・リスポーンは
## シーン側（scenes/main.gd）が行う。

## 噴射推力（px/s^2、質量 1 換算）。プロジェクト重力（980 px/s^2）を
## 上回る値にしておくことで、真上向きなら連続噴射で上昇できる。
const THRUST_FORCE := 1600.0
## 旋回角速度（rad/s）。
const TURN_SPEED := 3.0

## false で入力を無視する（クリア後に設定される）
var controls_enabled := true

@onready var _flame: Polygon2D = $Flame
@onready var _flame_core: Polygon2D = $FlameCore

var _flicker := 0.0


func _ready() -> void:
	_set_flame(false)


func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		angular_velocity = 0.0
		_set_flame(false)
		return

	var thrust := Input.is_action_pressed("thrust")
	var turn := Input.get_axis("rotate_left", "rotate_right")

	angular_velocity = TURN_SPEED * turn

	if thrust:
		var forward := Vector2.UP.rotated(rotation)
		apply_central_force(forward * THRUST_FORCE)

	_set_flame(thrust)
	_flicker += _delta


func _process(_delta: float) -> void:
	if not _flame.visible:
		return
	# 炎の揺らぎ（見た目のみ。当たり判定には影響しない）
	var s := 1.0 + 0.15 * sin(_flicker * 5.0) + 0.08 * sin(_flicker * 11.0)
	_flame.scale = Vector2(s, s)
	_flame.rotation = 0.08 * sin(_flicker * 7.0)
	_flame_core.scale = Vector2(1.0 + 0.1 * sin(_flicker * 9.0), 1.0 + 0.1 * sin(_flicker * 9.0))


func _set_flame(on: bool) -> void:
	_flame.visible = on
	_flame_core.visible = on
	if not on:
		_flame.scale = Vector2.ONE
		_flame.rotation = 0.0
		_flame_core.scale = Vector2.ONE