extends Node2D
## 縦スクロール・クライマー「アポフィス」（射撃なし）。
## 仕様（docs/Spec.txt）:
## - スタートは 0m。地面の上に立つ。6 画面分（4320m）登って最上部に到達でクリア
## - カメラは常にプレイヤーを中心に映す
## - W 連打で推進（A/D で旋回、無操作は自然落下）
## - 残機制 3。下からの岩・上からの隕石に 3 回当たると失敗
##
## 当たり判定は Rocket の Hitbox(Area2D) と障害物(Area2D) の重なりで行う。
## 障害物は物理的な押し合いをせず、RigidBody の挙動を汚さない。

const SCREEN_COUNT := 6
## 設計解像度（project.godot の display/window/size と一致させる）
const DESIGN_WIDTH := 1280.0
const DESIGN_HEIGHT := 720.0
const HALF_STAGE_WIDTH := DESIGN_WIDTH * 0.5
## 地面の上面 = 世界 y=0。ロケット中心（半径 30）が接地する高さ
const GROUND_Y := 0.0
const GROUND_CENTER_Y := GROUND_Y - 30.0
const WALL_THICKNESS := 24.0

const START_LIVES := 3
const INVULN_TIME := 2.0

## 結果画面（クリア／ゲームオーバー）の遷移先
const GAME_CLEAR_SCENE_PATH := "res://scenes/ui/game_clear.tscn"
const GAME_OVER_SCENE_PATH := "res://scenes/ui/game_over.tscn"
## 決着してから結果画面へ切り替わるまでの余韻（秒）。
## 0 にすると何が起きたか分からないまま画面が変わる
const RESULT_DELAY := 1.8

const ROCK_SPEED := 130.0
const METEOR_SPEED := 180.0
const ROCK_INTERVAL := 1.5
const METEOR_INTERVAL := 2.0
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

var world_screen_height := DESIGN_HEIGHT
var world_height := 0.0
var goal_y := 0.0

var _lives := START_LIVES
var _cleared := false
var _game_over := false
var _invuln_timer := 0.0
var _spawn_timer_rock := 0.0
var _spawn_timer_meteor := 0.0
var _message_timer := 0.0
var _obstacles: Node2D


func _ready() -> void:
	world_height = world_screen_height * SCREEN_COUNT
	goal_y = GROUND_CENTER_Y - world_height

	_obstacles = Node2D.new()
	_obstacles.name = "Obstacles"
	add_child(_obstacles)

	_build_walls()
	_build_ground()
	_background.setup(goal_y, GROUND_Y, HALF_STAGE_WIDTH, world_screen_height)

	# カメラは常にプレイヤー中心（縦はクランプしない）。横だけ壁の外を見せない
	_camera.limit_left = -int(HALF_STAGE_WIDTH)
	_camera.limit_right = int(HALF_STAGE_WIDTH)

	_alt_bar.position = Vector2(DESIGN_WIDTH - 56.0, 40.0)
	_alt_bar.size = Vector2(32.0, DESIGN_HEIGHT - 80.0)

	_rocket.hit.connect(_on_rocket_hit)
	_update_lives_label()
	print("[main] ready height=%.0f goal_y=%.0f lives=%d" % [world_height, goal_y, _lives])


func _physics_process(delta: float) -> void:
	if _cleared or _game_over:
		return

	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			_rocket.set_invulnerable(false)

	if _rocket.global_position.y <= goal_y:
		_cleared = true
		_rocket.controls_enabled = false
		_rocket.freeze = true
		_show_message("クリア！")
		print("[main] CLEARED at y=%.1f" % _rocket.global_position.y)
		_go_to_result(GAME_CLEAR_SCENE_PATH)
		return
	_spawn_timer_rock -= delta
	_spawn_timer_meteor -= delta
	if _spawn_timer_rock <= 0.0:
		_spawn_timer_rock = ROCK_INTERVAL
		_spawn_obstacle(false)
	if _spawn_timer_meteor <= 0.0:
		_spawn_timer_meteor = METEOR_INTERVAL
		_spawn_obstacle(true)


func _process(delta: float) -> void:
	_camera.global_position = _rocket.global_position
	_update_hud()

	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false


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
	# global_position はツリーに追加してから設定する（未追加時は意図どおり反映されない）
	_obstacles.add_child(obstacle)

	var px := _rocket.global_position.x
	var py := _rocket.global_position.y
	var x := _random_away_from(px)

	if meteor:
		obstacle.global_position = Vector2(x, py - SPAWN_OFFSET)
		obstacle.velocity = Vector2(0.0, METEOR_SPEED)
		obstacle.set_body_color(Color(0.85, 0.45, 0.2, 1))
	else:
		obstacle.global_position = Vector2(x, py + SPAWN_OFFSET)
		obstacle.velocity = Vector2(0.0, -ROCK_SPEED)
		obstacle.set_body_color(Color(0.5, 0.52, 0.58, 1))


func _random_away_from(player_x: float) -> float:
	# プレイヤーの真上/真下付近には生成しない（避けられない事故を防ぐ）
	for _i in 20:
		var x := randf_range(-HALF_STAGE_WIDTH + 60.0, HALF_STAGE_WIDTH - 60.0)
		if absf(x - player_x) >= 120.0:
			return x
	return randf_range(-HALF_STAGE_WIDTH + 60.0, HALF_STAGE_WIDTH - 60.0)


func _update_hud() -> void:
	var altitude := maxf(GROUND_CENTER_Y - _rocket.global_position.y, 0.0)
	var fraction := clampf(altitude / world_height, 0.0, 1.0)
	_altitude_label.text = "高度 %d / %d" % [int(altitude), int(world_height)]

	var h := _alt_bar.size.y * fraction
	_alt_fill.position = Vector2(0.0, _alt_bar.size.y - h)
	_alt_fill.size = Vector2(_alt_bar.size.x, h)


func _update_lives_label() -> void:
	_lives_label.text = "残機 %d" % _lives


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_timer = 1.2 if not (_cleared or _game_over) else 0.0


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
	visual.polygon = PackedVector2Array([
		Vector2(-HALF_STAGE_WIDTH, GROUND_Y),
		Vector2(HALF_STAGE_WIDTH, GROUND_Y),
		Vector2(HALF_STAGE_WIDTH, GROUND_Y + 300.0),
		Vector2(-HALF_STAGE_WIDTH, GROUND_Y + 300.0),
	])
	add_child(visual)