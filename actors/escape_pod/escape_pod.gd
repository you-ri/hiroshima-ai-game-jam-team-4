extends Area2D
class_name EscapePod
## 収集アイテム「脱出ポッド」。docs/Spec.txt の Item セクション。
## 落下速度 10 m/s（一定）で降りながら、左右に等速で往復（振り子）する。
## 金色は 10% 判定で生成され、取得すると 5 秒間の無敵＋障害物破壊になる。
## collision_layer=4。拾う側（Rocket/ItemCatch）が mask=4 で検出する。
## 障害物(layer=2)とは判定が噛み合わないので、誤って自機ヒットにならない。

const FALL_SPEED_MPS := 10.0
const SWING_SPEED_MIN_MPS := 10.0
const SWING_SPEED_MAX_MPS := 30.0
const SWING_AMPLITUDE_PX := 60.0
const OFFSCREEN_DESPAWN_TIME := 1.5
const VIEW_MARGIN := 80.0

const POD_COLOR := Color(0.55, 0.78, 0.9, 1)
const GOLD_COLOR := Color(1.0, 0.82, 0.25, 1)

var is_golden := false

var _fall_speed_px := 0.0
var _swing_speed_px := 0.0
var _swing_dir := 1.0
var _base_x := 0.0
var _sway_t := 0.0
var _offscreen_t := 0.0


## 生成直後（add_child の前）に呼ぶ。@onready は使わず _ready で位置を確定する
func setup(golden: bool) -> void:
	is_golden = golden
	_fall_speed_px = Units.m_to_px(FALL_SPEED_MPS)
	_swing_speed_px = Units.m_to_px(randf_range(SWING_SPEED_MIN_MPS, SWING_SPEED_MAX_MPS))
	if randf() < 0.5:
		_swing_dir = -1.0
	var body: Polygon2D = get_node("Body")
	body.color = GOLD_COLOR if golden else POD_COLOR
	get_node("Glow").visible = golden


func _ready() -> void:
	_base_x = global_position.x


func _physics_process(delta: float) -> void:
	global_position.y += _fall_speed_px * delta
	_swing(delta)
	_sway_t += delta
	rotation = 0.35 * sin(_sway_t * 2.4)
	_update_despawn(delta)


## 等速の左右往復（振幅 SWING_AMPLITUDE_PX で折り返す）
func _swing(delta: float) -> void:
	var next := global_position.x + _swing_speed_px * _swing_dir * delta
	if absf(next - _base_x) > SWING_AMPLITUDE_PX:
		_swing_dir *= -1.0
		next = clampf(next, _base_x - SWING_AMPLITUDE_PX, _base_x + SWING_AMPLITUDE_PX)
	global_position.x = next


## カメラ外に 1.5 秒出続けたら消える（障害物と同じ扱い）
func _update_despawn(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var offset := (global_position - camera.global_position).abs()
	if offset.x > Units.DESIGN_WIDTH * 0.5 + VIEW_MARGIN \
			or offset.y > Units.DESIGN_HEIGHT * 0.5 + VIEW_MARGIN:
		_offscreen_t += delta
		if _offscreen_t >= OFFSCREEN_DESPAWN_TIME:
			queue_free()
	else:
		_offscreen_t = 0.0


## 取得された。スコア加算は持ち主（copy_main）が行い、ここは消えるだけ
func collect() -> void:
	queue_free()
