extends Area2D
class_name Obstacle
## 障害物。下から飛んでくる岩と上から落ちてくる隕石（docs/Spec.txt）。
## - 重力の影響を受けず、velocity のまま等速直線運動する
## - カメラ外に出て 1.5 秒経つと自動消滅する
## - 岩と隕石が衝突すると両方消滅する
## Area2D なので物理的な押し合いはしない。プレイヤーへの当たり判定は
## Rocket の Hitbox(Area2D, mask=2) がこの layer=2 を検出して行う。

const OFFSCREEN_DESPAWN_TIME := 1.5
## カメラ外判定の余白。stretch=expand で実ビューが設計解像度より広い場合の保険
const VIEW_MARGIN := 80.0

const ROCK_COLOR := Color(0.5, 0.52, 0.58, 1)
const METEOR_COLOR := Color(0.92, 0.45, 0.18, 1)

var velocity := Vector2.ZERO
var is_meteor := false

var _offscreen_t := 0.0
var _spin := 0.0


## 生成直後（add_child の前）に呼ぶ。ツリー追加前でも動くよう @onready は使わない
func setup(meteor: bool, vel: Vector2) -> void:
	is_meteor = meteor
	velocity = vel

	var body := get_node("Body") as Polygon2D
	body.color = METEOR_COLOR if meteor else ROCK_COLOR

	# 見た目のバリエーション（大きさ・自転）。当たり判定の円も同じ倍率にする。
	# CircleShape2D の sub_resource はインスタンス間で共有されるため duplicate してから触る
	var s := randf_range(0.85, 1.3)
	body.scale = Vector2(s, s)
	var col := get_node("CollisionShape2D") as CollisionShape2D
	var shape: CircleShape2D = col.shape.duplicate()
	shape.radius *= s
	col.shape = shape
	_spin = randf_range(-2.5, 2.5)

	# 岩だけを判定側にして、隕石(layer=2)との重なりで両方消す（Spec: 岩が隕石と衝突すると消滅）
	if not meteor:
		collision_mask = 2
		monitoring = true


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	rotation += _spin * delta
	_update_despawn(delta)


## カメラ外に OFFSCREEN_DESPAWN_TIME 秒出続けたら消える（Spec: 画面/カメラ外 1.5 秒で自動消滅）
func _update_despawn(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var offset := (global_position - camera.global_position).abs()
	var outside := offset.x > Units.DESIGN_WIDTH * 0.5 + VIEW_MARGIN \
			or offset.y > Units.DESIGN_HEIGHT * 0.5 + VIEW_MARGIN
	if outside:
		_offscreen_t += delta
		if _offscreen_t >= OFFSCREEN_DESPAWN_TIME:
			queue_free()
	else:
		_offscreen_t = 0.0


func _on_area_entered(area: Area2D) -> void:
	var other := area as Obstacle
	if other != null and other.is_meteor != is_meteor:
		# queue_free は遅延実行なので物理コールバック中でも安全
		other.queue_free()
		queue_free()
