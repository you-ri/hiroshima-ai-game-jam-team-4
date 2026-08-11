extends Node2D
## 縦スクロール・クライマー「アポフィス」（射撃なし）。
## 仕様（docs/Spec.txt）:
## - スタートは 0m。地面の上に立つ。ゴールは 3000m（= 6 画面分。1m = 1.44px、scripts/units.gd）
##   ゴール = 大気圏界面。超えるとカメラが止まり、機体が自動で上昇して画面外へ抜けたらクリア
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

## Spec: ゴールは 3000m。この高度が大気圏界面（背景に光る線として描かれる）
const GOAL_ALTITUDE_M := 3000.0
## 界面が近いことを 1 度だけ知らせる高度
const ATMOSPHERE_WARN_ALTITUDE_M := 2700.0
## Spec: 隕石はプレイヤーが高度 1000m に到達してから生成される
const METEOR_UNLOCK_ALTITUDE_M := 1000.0

## 大気圏突破後の自動上昇（脱出演出）。操作を切り、カメラを止めて機体だけ画面外へ抜ける
const ESCAPE_SPEED_START_MPS := 60.0
const ESCAPE_SPEED_MAX_MPS := 420.0
const ESCAPE_ACCEL_MPS2 := 260.0
## 機体が完全に画面外へ出たと見なすための余裕（px）
const ESCAPE_OFFSCREEN_MARGIN := 90.0

## 結果画面（クリア／ゲームオーバー）の遷移先
const GAME_CLEAR_SCENE_PATH := "res://scenes/ui/game_clear.tscn"
const GAME_OVER_SCENE_PATH := "res://scenes/ui/game_over.tscn"
## 決着してから結果画面へ切り替わるまでの余韻（秒）。
## 0 にすると何が起きたか分からないまま画面が変わる
const RESULT_DELAY := 1.8

## Spec: 岩は 0.5s ごと、速度 120〜150 m/s のランダム
const ROCK_INTERVAL := 0.5
const ROCK_SPEED_MIN_MPS := 140.0
const ROCK_SPEED_MAX_MPS := 170.0
## Spec: 隕石は 0.7s ごと、速度 30〜50 m/s のランダム
const METEOR_INTERVAL := 0.7
const METEOR_SPEED_MIN_MPS := 40.0
const METEOR_SPEED_MAX_MPS := 70.0
## カメラの半高さ（DESIGN_HEIGHT/2）より外側にスポーンさせるための余裕
const SPAWN_OFFSET := 430.0

const OBSTACLE_SCENE: PackedScene = preload("res://actors/obstacle/obstacle.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://actors/explosion/explosion.tscn")

## 爆発してからスタート地点に再出撃するまでの時間（秒）
const RESPAWN_DELAY := 1.0
## 被弾時のカメラシェイクの強さ（px）と減衰（px/s）
const SHAKE_STRENGTH := 14.0
const SHAKE_DECAY := 30.0

## 雲海（背景の CLOUD_LAYERS 最上段 1300m）を抜けるとアポフィスが視界に入り、
## その圧で画面が常時細かく振動する。この高度からフェード幅をかけて最大になる
const APOPHIS_RUMBLE_START_ALTITUDE_M := 1350.0
const APOPHIS_RUMBLE_FADE_M := 250.0
## 常時振動の最大振幅（px）。被弾シェイクより明確に弱く、HUD が読める範囲に抑える
const APOPHIS_RUMBLE_STRENGTH := 3.0

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
var _atmosphere_warned := false
## 大気圏突破後の自動上昇中。この間は操作・スポーンを止め、カメラを固定する
var _escaping := false
var _escape_speed := 0.0
var _camera_locked := false
var _camera_locked_pos := Vector2.ZERO
var _invuln_timer := 0.0
var _spawn_timer_rock := 0.0
var _spawn_timer_meteor := 0.0
var _message_timer := 0.0
var _shake := 0.0
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

	# 大気圏突破後は操作も障害物の生成も止め、脱出演出だけを進める
	if _escaping:
		_process_escape(delta)
		return

	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			_rocket.set_invulnerable(false)

	var altitude := _altitude_m()

	# 大気圏界面に到達。ここでクリアにはせず、自動上昇して画面外へ抜けるまで待つ
	if altitude >= GOAL_ALTITUDE_M:
		_start_escape(altitude)
		return

	if not _atmosphere_warned and altitude >= ATMOSPHERE_WARN_ALTITUDE_M:
		_atmosphere_warned = true
		_show_message("まもなく大気圏外！ 光る線を抜けろ", 2.0)

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
	# Spec: カメラは常にプレイヤーを中心に映す（クランプなし）。爆発中はシェイクを乗せる。
	# ただし大気圏突破後は境界が見える位置で固定し、機体が画面外へ抜けるのを見せる
	var offset := Vector2.ZERO
	if _shake > 0.0:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
	# アポフィスの圧による常時微振動（雲海を抜けた高度からフェードイン。降りると消える）
	var rumble := clampf((_altitude_m() - APOPHIS_RUMBLE_START_ALTITUDE_M)
			/ APOPHIS_RUMBLE_FADE_M, 0.0, 1.0) * APOPHIS_RUMBLE_STRENGTH
	if rumble > 0.0:
		offset += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * rumble
	if _camera_locked:
		# 大気圏突破の演出中もアポフィスは居るので、固定位置の上に微振動だけ乗せる
		_camera.global_position = _camera_locked_pos + offset
	else:
		_camera.global_position = _rocket.global_position + offset
	_update_hud()

	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false


## 高度（m）。地面に接地した状態が 0m
func _altitude_m() -> float:
	return maxf(Units.px_to_m(GROUND_CENTER_Y - _rocket.global_position.y), 0.0)


## 大気圏界面を超えた瞬間。操作を取り上げ、カメラを止めて自動上昇へ移る。
## 演出中は controls_enabled = false なので障害物に当たっても被弾しない
func _start_escape(altitude: float) -> void:
	_escaping = true
	_escape_speed = Units.m_to_px(ESCAPE_SPEED_START_MPS)
	_camera_locked = true
	_camera_locked_pos = _camera.global_position
	_shake = 0.0

	_rocket.controls_enabled = false
	_rocket.escape_burn = true  # 入力なしでも噴射しっぱなしに見せる
	_rocket.angular_velocity = 0.0
	_rocket.linear_velocity = Vector2.ZERO
	# 以降は位置をこちらで動かすので物理は止める（area_entered 中でも安全なよう deferred）
	_rocket.set_deferred("freeze", true)

	_show_message("大気圏突破！", 4.0)
	print("[main] atmosphere exit at %.0fm" % altitude)


## 自動上昇。加速しながら真上へ抜け、画面上端より外へ出たらクリアにする
func _process_escape(delta: float) -> void:
	_escape_speed = minf(_escape_speed + Units.m_to_px(ESCAPE_ACCEL_MPS2) * delta,
			Units.m_to_px(ESCAPE_SPEED_MAX_MPS))
	_rocket.global_position.y -= _escape_speed * delta
	_rocket.rotation = lerp_angle(_rocket.rotation, 0.0, minf(delta * 6.0, 1.0))

	var screen_top := _camera_locked_pos.y - DESIGN_HEIGHT * 0.5
	if _rocket.global_position.y + ESCAPE_OFFSCREEN_MARGIN > screen_top:
		return

	# 画面外へ出た = クリア
	_escaping = false
	_cleared = true
	_rocket.escape_burn = false
	_rocket.visible = false
	_show_message("大気圏外へ脱出！")
	print("[main] CLEARED off-screen at %.0fm" % _altitude_m())
	_go_to_result(GAME_CLEAR_SCENE_PATH)


func _on_rocket_hit() -> void:
	if _cleared or _game_over:
		return
	_lives -= 1
	_update_lives_label()
	print("[main] HIT lives=%d" % _lives)

	# ドッカーン。機体は爆発して消える
	_spawn_explosion.call_deferred(_rocket.global_position)
	_shake = SHAKE_STRENGTH
	_rocket.visible = false
	_rocket.controls_enabled = false
	# 爆発中に再被弾しないよう当たり判定を切る（無敵タイマーはリスポーン時に開始）
	_rocket.set_invulnerable(true)
	# area_entered のフラッシュ中は body mode を変えられないため deferred にする
	_rocket.set_deferred("freeze", true)

	if _lives <= 0:
		_game_over = true
		_show_message("失敗…残機なし")
		print("[main] GAME OVER")
		_go_to_result(GAME_OVER_SCENE_PATH)
		return
	_respawn_after_explosion()


## 爆発の余韻を置いてからスタート地点に再出撃する
func _respawn_after_explosion() -> void:
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if _cleared or _game_over or not is_inside_tree():
		return
	_respawn_to_start()
	_rocket.visible = true
	_rocket.controls_enabled = true
	_invuln_timer = INVULN_TIME  # ここから 2 秒の無敵（点滅）
	_show_message("スタートへ戻った")


func _spawn_explosion(pos: Vector2) -> void:
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	add_child(explosion)
	explosion.global_position = pos


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
	if _escaping or _cleared:
		_altitude_label.text = "高度 %d m ／ 大気圏突破！" % int(altitude)
	else:
		_altitude_label.text = "高度 %d m / 大気圏外 %d m" % [int(altitude), int(GOAL_ALTITUDE_M)]

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
	# 夜景に合わせた暗い地面。背景（山・街 z=-10）より手前、ロケット（z=0）より奥
	visual.color = Color(0.16, 0.13, 0.11, 1)
	visual.z_index = -5
	# カメラが常にプレイヤー中心のため、接地時に見える範囲（+430px）まで描く
	visual.polygon = PackedVector2Array([
		Vector2(-HALF_STAGE_WIDTH - 720.0, GROUND_Y),
		Vector2(HALF_STAGE_WIDTH + 720.0, GROUND_Y),
		Vector2(HALF_STAGE_WIDTH + 720.0, GROUND_Y + 430.0),
		Vector2(-HALF_STAGE_WIDTH - 720.0, GROUND_Y + 430.0),
	])
	add_child(visual)
