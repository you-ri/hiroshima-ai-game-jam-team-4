extends "res://scenes/main.gd"
## scenes/copy_main.tscn 用。docs/Spec.txt の Item / Point セクションを実装する。
## 本体（main.gd）は変更せず、ここにスコア・アイテム・無敵破壊を足す。
##
## スコア（Spec の Point セクション）:
## - タイム: クリアが速いほど高得点、最高 10,000 点。100 秒で 0 になる線形逓減
## - 残機  : 残った残機 1 につき 3,000 点（クリア時のみ）
## - アイテム: 脱出ポッド 1 個につき 1,000 点
## - 特殊  : 無敵中に岩・隕石を破壊するたび 500 点
##
## アイテム（Spec の Item セクション）:
## - 5 秒ごとにプレイヤー上空 300m のランダムな X 位置に 1 個生成。10% 判定で金色
## - 金色を取ると 5 秒間無敵になり、接触した岩・隕石を破壊できる
## - 破壊判定は Rocket.destroy_on_contact → obstacle_destroyed シグナルで受け取る
##
## 速度は本編と差し替え: 岩 100〜130 m/s、隕石 30〜70 m/s（_spawn_obstacle を上書き）
##
## 決着時はスコアを確定して ScoreBoard に保存し、余韻の間だけ内訳を出してから
## 本体（main.gd）と同じく結果画面（game_clear / game_over）へ遷移する。

const ESCAPE_POD_SCENE: PackedScene = preload("res://actors/escape_pod/escape_pod.tscn")

const ITEM_SPAWN_INTERVAL := 5.0
const ITEM_SPAWN_HIGH_M := 300.0
const GOLDEN_CHANCE := 0.10
const POWER_INVULN_TIME := 5.0

const SCORE_TIME_MAX := 10000
const SCORE_TIME_PER_SEC := 100.0
const SCORE_LIFE := 3000
const SCORE_ITEM := 1000
const SCORE_SPECIAL := 500

#const ROCK_SPEED_MIN_MPS := 120.0
#const ROCK_SPEED_MAX_MPS := 130.0
#const METEOR_SPEED_MIN_MPS := 30.0
#const METEOR_SPEED_MAX_MPS := 70.0

const AURA_COLOR := Color(1.0, 0.85, 0.4, 1.0)

@onready var _score_label: Label = $UI/Score
@onready var _breakdown_label: Label = $UI/Breakdown
@onready var _aura: Polygon2D = $Rocket/Aura
@onready var _item_catch: Area2D = $Rocket/ItemCatch

var _score_total := 0
var _score_time := 0
var _score_lives := 0
var _score_items := 0
var _score_special := 0
var _pod_count := 0
var _special_count := 0

var _play_elapsed := 0.0
var _item_spawn_timer := 0.0
var _power_invuln_timer := 0.0

var _items: Node2D


func _ready() -> void:
	super()
	_items = Node2D.new()
	_items.name = "Items"
	add_child(_items)

	_item_catch.area_entered.connect(_on_item_caught)
	_rocket.obstacle_destroyed.connect(_on_obstacle_destroyed)
	_update_score_label()


func _physics_process(delta: float) -> void:
	super(delta)
	if _cleared or _game_over or _escaping:
		return

	_play_elapsed += delta

	_item_spawn_timer -= delta
	if _item_spawn_timer <= 0.0:
		_item_spawn_timer = ITEM_SPAWN_INTERVAL
		_spawn_escape_pod()

	if _power_invuln_timer > 0.0:
		_power_invuln_timer -= delta
		if _power_invuln_timer <= 0.0:
			_end_power_invuln()


## スコアを確定して ScoreBoard に保存し、余韻の間だけ内訳を見せてから
## 本体と同じ遷移（RESULT_DELAY 後に結果画面へ）を行う
func _go_to_result(path: String) -> void:
	_finalize_score()
	_show_breakdown()
	super(path)


## Spec: 5 秒ごとにプレイヤー上空 300m のランダムな X 位置に 1 個。10% 判定で金色
func _spawn_escape_pod() -> void:
	var pod: EscapePod = ESCAPE_POD_SCENE.instantiate()
	pod.setup(randf() < GOLDEN_CHANCE)
	_items.add_child(pod)
	pod.global_position = Vector2(
			randf_range(-HALF_STAGE_WIDTH + 60.0, HALF_STAGE_WIDTH - 60.0),
			_rocket.global_position.y - Units.m_to_px(ITEM_SPAWN_HIGH_M))


## 本編の生成ロジックを流用し、速度だけ差し替える（岩 100-130 / 隕石 30-70 m/s）
func _spawn_obstacle(meteor: bool) -> void:
	var obstacle: Obstacle = OBSTACLE_SCENE.instantiate()

	var x := _random_away_from(_rocket.global_position.x)
	var py := _rocket.global_position.y

	if meteor:
		var speed := Units.m_to_px(randf_range(METEOR_SPEED_MIN_MPS, METEOR_SPEED_MAX_MPS))
		obstacle.setup(true, Vector2(0.0, speed))
	else:
		var speed := Units.m_to_px(randf_range(ROCK_SPEED_MIN_MPS, ROCK_SPEED_MAX_MPS))
		var angle := deg_to_rad(randf_range(0.0, 180.0))
		obstacle.setup(false, Vector2(cos(angle), -sin(angle)) * speed)

	_obstacles.add_child(obstacle)
	obstacle.global_position = Vector2(x, py - SPAWN_OFFSET if meteor else py + SPAWN_OFFSET)


func _on_item_caught(area: Area2D) -> void:
	var pod := area as EscapePod
	if pod == null:
		return
	if _cleared or _game_over or _escaping or not _rocket.controls_enabled:
		return

	_score_items += SCORE_ITEM
	_pod_count += 1
	_update_score_label()
	if pod.is_golden:
		_start_power_invuln()
	else:
		_show_message("脱出ポッド +%d 点" % SCORE_ITEM, 1.2)
	pod.collect()


## 金色ポッド取得。5 秒間無敵になり岩・隕石を破壊できる
func _start_power_invuln() -> void:
	_power_invuln_timer = POWER_INVULN_TIME
	_rocket.destroy_on_contact = true
	_rocket.modulate = AURA_COLOR
	_aura.visible = true
	_show_message("金色ポッド！ 無敵 %d 秒。岩を破壊できる！" % int(POWER_INVULN_TIME))


func _end_power_invuln() -> void:
	_power_invuln_timer = 0.0
	_rocket.destroy_on_contact = false
	_rocket.modulate = Color.WHITE
	_aura.visible = false


## 無敵中の岩・隕石破壊。1 回 = 特殊アクション 500 点
func _on_obstacle_destroyed(area: Area2D) -> void:
	if not (area is Obstacle):
		return
	if _power_invuln_timer <= 0.0:
		return
	_score_special += SCORE_SPECIAL
	_special_count += 1
	_update_score_label()
	_spawn_explosion(area.global_position)
	area.queue_free()


func _finalize_score() -> void:
	var time_score := 0
	if _cleared:
		time_score = clampi(int(SCORE_TIME_MAX - _play_elapsed * SCORE_TIME_PER_SEC),
				0, SCORE_TIME_MAX)
	var lives_score := _lives * SCORE_LIFE if _cleared else 0
	_score_time = time_score
	_score_lives = lives_score
	_score_total = _score_time + _score_lives + _score_items + _score_special
	_score_label.text = "SCORE %d" % _score_total
	ScoreBoard.store(_score_total, _score_time, _score_lives,
			_score_items, _score_special, _cleared)
	print("[copy_main] FINAL total=%d time=%d lives=%d items=%d special=%d cleared=%s" % [
			_score_total, _score_time, _score_lives, _score_items, _score_special, _cleared])


## 結果画面へ切り替わるまでの余韻の間、スコア内訳を中央に出す
func _show_breakdown() -> void:
	_breakdown_label.text = ("クリア！ タイム %.1f 秒\n" % _play_elapsed if _cleared else "失敗…\n") \
			+ "タイム  %d 点\n" % _score_time \
			+ "残機    %d 点\n" % _score_lives \
			+ "アイテム %d 点\n" % _score_items \
			+ "特殊アクション %d 点\n" % _score_special \
			+ "合計    %d 点" % _score_total
	_breakdown_label.visible = true


func _update_score_label() -> void:
	_score_label.text = "SCORE %d" % (_score_items + _score_special)
