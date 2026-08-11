extends Node2D
## 縦スクロール・クライマー「アポフィス」（射撃なし）。
## 仕様（docs/Spec.txt）:
## - スタートは 0m。地面の上に立つ。ゴールは 3000m（= 6 画面分。1m = 1.44px、scripts/units.gd）
## - カメラは常にプレイヤーを中心に映す
## - W 連打で推進（A/D で旋回、無操作は自然落下）
## - 残機制 3。障害物に 3 回当たると失敗
## - 岩: 画面下方から 0.5s ごと、方向 0〜180 度・速度 100〜150 m/s のランダム
## - 隕石: 高度 1000m 到達後、画面上方から 0.7s ごと、速度 20〜50 m/s で落下
##
## 当たり判定は Rocket の Hitbox(Area2D) と障害物(Area2D) の重なりで行う。
## 障害物は物理的な押し合いをせず、RigidBody の挙動を汚さない。

const DESIGN_WIDTH := Units.DESIGN_WIDTH
const DESIGN_HEIGHT := Units.DESIGN_HEIGHT
const HALF_STAGE_WIDTH := DESIGN_WIDTH * 0.5
## 地面の上面 = 世界 y=0。ロケット中心（半径 30）が接地する高さ
const GROUND_Y := 0.0
const GROUND_CENTER_Y := GROUND_Y - 30.0
const WALL_THICKNESS := 24.0

const START_LIVES := 3
const INVULN_TIME := 2.0

## Spec: ゴールは 3000m
const GOAL_ALTITUDE_M := 3000.0
## Spec: 隕石はプレイヤーが高度 1000m に到達してから生成される
const METEOR_UNLOCK_ALTITUDE_M := 1000.0

## 結果画面（クリア／ゲームオーバー）の遷移先
const GAME_CLEAR_SCENE_PATH := "res://scenes/ui/game_clear.tscn"
const GAME_OVER_SCENE_PATH := "res://scenes/ui/game_over.tscn"
## 決着してから結果画面へ切り替わるまでの余韻（秒）。
## 0 にすると何が起きたか分からないまま画面が変わる
const RESULT_DELAY := 1.8

## Spec: 岩は 0.5s ごと、速度 100〜150 m/s のランダム
const ROCK_INTERVAL := 0.5
const ROCK_SPEED_MIN_MPS := 100.0
const ROCK_SPEED_MAX_MPS := 150.0
## Spec: 隕石は 0.7s ごと、速度 20〜50 m/s のランダム
const METEOR_INTERVAL := 0.7
const METEOR_SPEED_MIN_MPS := 20.0
const METEOR_SPEED_MAX_MPS := 50.0
## カメラの半高さ（DESIGN_HEIGHT/2）より外側にスポーンさせるための余裕
const SPAWN_OFFSET := 430.0

const OBSTACLE_SCENE: PackedScene = preload("res://actors/obstacle/obstacle.tscn")

@onready var _rocket: Rocket = $Rocket
@onready var _camera: Camera2D = $Camera2D
@onready var _background: Node2D = $Background
@onready var _altitude_label: Label = $UI/Altitude
@onready var _lives_label: Label = $UI/Lives
@onready var _message_label: Label = $UI/Message
@onready var _alt_bar: Control = $UI/AltitudeBar
@onready var _alt_fill: ColorRect = $UI/AltitudeBar/Fill

var world_height := 0.0
var goal_y := 0.0

var _lives := START_LIVES
var _cleared := false
var _game_over := false
var _meteor_unlocked := false
var _invuln_timer := 0.0
var _spawn_timer_rock := 0.0
var _spawn_timer_meteor := 0.0
var _message_timer := 0.0
var _obstacles: Node2D


func _ready() -> void:
	world_height = Units.m_to_px(GOAL_ALTITUDE_M)
	goal_y = GROUND_CENTER_Y - world_height

	_obstacles = Node2D.new()
	_obstacles.name = "Obstacles"
	add_child(_obstacles)

	_build_walls()
	_build_ground()
	_background.setup(goal_y, GROUND_Y, HALF_STAGE_WIDTH, DESIGN_HEIGHT)

	_alt_bar.position = Vector2(DESIGN_WIDTH - 56.0, 40.0)
	_alt_bar.size = Vector2(32.0, DESIGN_HEIGHT - 80.0)

	_rocket.hit.connect(_on_rocket_hit)
	_update_lives_label()
	print("[main] ready goal=%.0fm (%.0fpx) goal_y=%.0f lives=%d" % [
			GOAL_ALTITUDE_M, world_height, goal_y, _lives])


func _physics_process(delta: float) -> void:
	if _cleared or _game_over:
		return

	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			_rocket.set_invulnerable(false)

	var altitude := _altitude_m()

	if altitude >= GOAL_ALTITUDE_M:
		_cleared = true
		_rocket.controls_enabled = false
		_rocket.freeze = true
		_show_message("クリア！")
		print("[main] CLEARED at %.0fm" % altitude)
		_go_to_result(GAME_CLEAR_SCENE_PATH)
		return

	# Spec: 隕石は高度 1000m 到達後に生成開始（一度解禁されたら降りても止まらない）
	if not _meteor_unlocked and altitude >= METEOR_UNLOCK_ALTITUDE_M:
		_meteor_unlocked = true
		_show_message("警告！ 上から隕石が来る", 2.0)
		print("[main] meteor unlocked at %.0fm" % altitude)

	_spawn_timer_rock -= delta
	if _spawn_timer_rock <= 0.0:
		_spawn_timer_rock = ROCK_INTERVAL
		_spawn_obstacle(false)
	if _meteor_unlocked:
		_spawn_timer_meteor -= delta
		if _spawn_timer_meteor <= 0.0:
			_spawn_timer_meteor = METEOR_INTERVAL
			_spawn_obstacle(true)


func _process(delta: float) -> void:
	# Spec: カメラは常にプレイヤーを中心に映す（クランプなし）
	_camera.global_position = _rocket.global_position
	_update_hud()

	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false


## 高度（m）。地面に接地した状態が 0m
func _altitude_m() -> float:
	return maxf(Units.px_to_m(GROUND_CENTER_Y - _rocket.global_position.y), 0.0)


func _on_rocket_hit() -> void:
	if _cleared or _game_over:
		return
	_lives -= 1
	_update_lives_label()
	print("[main] HIT lives=%d" % _lives)
	if _lives <= 0:
		_game_over = true
		_rocket.controls_enabled = false
		# area_entered のフラッシュ中は body mode を変えられないため deferred にする
		_rocket.set_deferred("freeze", true)
		_show_message("失敗…残機なし")
		print("[main] GAME OVER")
		_go_to_result(GAME_OVER_SCENE_PATH)
		return
	# リスポーンもフラッシュ中に走るので deferred で実行する
	_respawn_to_start.call_deferred()
	_rocket.set_invulnerable(true)
	_invuln_timer = INVULN_TIME
	_show_message("スタートへ戻った")


## 結果画面へ切り替える。余韻を挟んでから遷移する。
## 呼び出し元は _cleared / _game_over を立ててから呼ぶので、二重に走ることはない。
func _go_to_result(path: String) -> void:
	await get_tree().create_timer(RESULT_DELAY).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(path)


func _respawn_to_start() -> void:
	_rocket.freeze = true
	_rocket.rotation = 0.0
	_rocket.linear_velocity = Vector2.ZERO
	_rocket.angular_velocity = 0.0
	_rocket.global_position = Vector2(0.0, GROUND_CENTER_Y)
	_rocket.freeze = false


func _spawn_obstacle(meteor: bool) -> void:
	var obstacle: Obstacle = OBSTACLE_SCENE.instantiate()

	var x := _random_away_from(_rocket.global_position.x)
	var py := _rocket.global_position.y

	if meteor:
		# Spec: 画面上方の任意の位置から、20〜50 m/s で落下
		var speed := Units.m_to_px(randf_range(METEOR_SPEED_MIN_MPS, METEOR_SPEED_MAX_MPS))
		obstacle.setup(true, Vector2(0.0, speed))
	else:
		# Spec: 画面下方の任意の位置から、方向 0〜180 度・速度 100〜150 m/s のランダム
		var speed := Units.m_to_px(randf_range(ROCK_SPEED_MIN_MPS, ROCK_SPEED_MAX_MPS))
		var angle := deg_to_rad(randf_range(0.0, 180.0))
		obstacle.setup(false, Vector2(cos(angle), -sin(angle)) * speed)

	# global_position はツリーに追加してから設定する（未追加時は意図どおり反映されない）
	_obstacles.add_child(obstacle)
	obstacle.global_position = Vector2(x, py - SPAWN_OFFSET if meteor else py + SPAWN_OFFSET)


func _random_away_from(player_x: float) -> float:
	# プレイヤーの真上/真下付近には生成しない（避けられない事故を防ぐ）
	for _i in 20:
		var x := randf_range(-HALF_STAGE_WIDTH + 60.0, HALF_STAGE_WIDTH - 60.0)
		if absf(x - player_x) >= 120.0:
			return x
	return randf_range(-HALF_STAGE_WIDTH + 60.0, HALF_STAGE_WIDTH - 60.0)


func _update_hud() -> void:
	var altitude := _altitude_m()
	var fraction := clampf(altitude / GOAL_ALTITUDE_M, 0.0, 1.0)
	_altitude_label.text = "高度 %d m / %d m" % [int(altitude), int(GOAL_ALTITUDE_M)]

	var h := _alt_bar.size.y * fraction
	_alt_fill.position = Vector2(0.0, _alt_bar.size.y - h)
	_alt_fill.size = Vector2(_alt_bar.size.x, h)


func _update_lives_label() -> void:
	_lives_label.text = "残機 %d" % _lives


func _show_message(text: String, duration := 1.2) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_timer = duration if not (_cleared or _game_over) else 0.0


func _build_walls() -> void:
	var mid_y := (goal_y + GROUND_Y) * 0.5
	for side in [-1.0, 1.0]:
		var wall := StaticBody2D.new()
		wall.name = "WallLeft" if side < 0.0 else "WallRight"
		wall.position = Vector2(side * (HALF_STAGE_WIDTH + WALL_THICKNESS * 0.5), mid_y)

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(WALL_THICKNESS, world_height + WALL_THICKNESS * 2.0)
		shape.shape = rect
		wall.add_child(shape)
		add_child(wall)


func _build_ground() -> void:
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.position = Vector2(0.0, GROUND_Y + 200.0)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(DESIGN_WIDTH + WALL_THICKNESS * 2.0, 400.0)
	shape.shape = rect
	ground.add_child(shape)
	add_child(ground)

	var visual := Polygon2D.new()
	visual.name = "GroundVisual"
	visual.color = Color(0.25, 0.2, 0.16, 1)
	# カメラが常にプレイヤー中心のため、接地時に見える範囲（+430px）まで描く
	visual.polygon = PackedVector2Array([
		Vector2(-HALF_STAGE_WIDTH - 720.0, GROUND_Y),
		Vector2(HALF_STAGE_WIDTH + 720.0, GROUND_Y),
		Vector2(HALF_STAGE_WIDTH + 720.0, GROUND_Y + 430.0),
		Vector2(-HALF_STAGE_WIDTH - 720.0, GROUND_Y + 430.0),
	])
	add_child(visual)
