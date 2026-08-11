extends Area2D
class_name Obstacle
## 障害物。下から登ってくる岩と上から落ちてくる隕石。
## Area2D なので物理的な押し合いはしない。速度 velocity に沿って移動し、
## プレイヤー（group "player"）から離れすぎたら自ら消える。
## 当たり判定は Rocket の Hitbox との Area 重なりで行われる。

const DESPAWN_DISTANCE := 900.0

var velocity := Vector2.ZERO


func _physics_process(delta: float) -> void:
	global_position += velocity * delta

	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null and (global_position - player.global_position).length() > DESPAWN_DISTANCE:
		queue_free()


func set_body_color(c: Color) -> void:
	# ツリー追加前（_ready 前）にも呼べるよう @onready ではなく get_node を使う
	(get_node("Body") as Polygon2D).color = c