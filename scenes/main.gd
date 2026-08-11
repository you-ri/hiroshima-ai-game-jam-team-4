extends Node2D
## 縦スクロール・クライマー（射撃なし）。
## ステージ最下部からスタートし、6 画面分（世界の高さ）を登って最上部に
## 到達するとクリア。ロケットが画面下まで落ちたらスタート位置へ戻す。

const SCREEN_COUNT := 6
## 設計解像度（project.godot の display/window/size と一致させる）
const DESIGN_WIDTH := 1280.0
const DESIGN_HEIGHT := 720.0
const HALF_STAGE_WIDTH := DESIGN_WIDTH * 0.5
const START_Y := -80.0
const RESPAWN_Y := 240.0
const WALL_THICKNESS := 24.0

@onready var _rocket: Rocket = $Rocket
@onready var _camera: Camera2D = $Camera2D
@onready var _background: Node2D = $Background
@onready var _altitude_label: Label = $UI/Altitude
@onready var _message_label: Label = $UI/Message
@onready var _alt_bar: Control = $UI/AltitudeBar
@onready var _alt_fill: ColorRect = $UI/AltitudeBar/Fill

var world_screen_height := 720.0
var world_height := 0.0
var world_top_y := 0.0
var world_bottom_y := 0.0

var _cleared := false
var _message_timer := 0.0


func _ready() -> void:
	# stretch は canvas_items / expand のため get_viewport_rect() は窓サイズを返す。
	# ステージの寸法は設計解像度（DESIGN_WIDTH × DESIGN_HEIGHT）基準で組む。
	world_screen_height = DESIGN_HEIGHT
	world_height = world_screen_height * SCREEN_COUNT
	world_bottom_y = 0.0
	world_top_y = -world_height

	_build_walls()
	_background.setup(world_top_y, world_bottom_y, HALF_STAGE_WIDTH, world_screen_height)

	_camera.limit_top = int(world_top_y)
	_camera.limit_bottom = int(world_bottom_y)
	_camera.limit_left = -int(HALF_STAGE_WIDTH)
	_camera.limit_right = int(HALF_STAGE_WIDTH)

	_alt_bar.position = Vector2(DESIGN_WIDTH - 56.0, 40.0)
	_alt_bar.size = Vector2(32.0, DESIGN_HEIGHT - 80.0)

	print("[main] ready design=%.0fx%.0f world_height=%.0f top=%.0f" % [
		DESIGN_WIDTH, DESIGN_HEIGHT, world_height, world_top_y
	])


func _physics_process(_delta: float) -> void:
	if not _cleared and _rocket.global_position.y <= world_top_y:
		_cleared = true
		_rocket.controls_enabled = false
		_rocket.freeze = true
		_show_message("クリア！")
		print("[main] CLEARED at y=%.1f" % _rocket.global_position.y)
	elif not _cleared and _rocket.global_position.y > RESPAWN_Y:
		_respawn()


func _process(delta: float) -> void:
	_camera.global_position = _rocket.global_position
	_update_hud()

	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false


func _respawn() -> void:
	_rocket.freeze = true
	_rocket.rotation = 0.0
	_rocket.linear_velocity = Vector2.ZERO
	_rocket.angular_velocity = 0.0
	_rocket.global_position = Vector2(0.0, START_Y)
	_rocket.freeze = false
	_show_message("落下！やり直し")
	print("[main] RESPAWN at y=%.1f" % _rocket.global_position.y)


func _update_hud() -> void:
	var altitude := world_bottom_y - _rocket.global_position.y
	var fraction := clampf(altitude / world_height, 0.0, 1.0)
	_altitude_label.text = "高度 %d / %d" % [int(altitude), int(world_height)]

	var h := _alt_bar.size.y * fraction
	_alt_fill.position = Vector2(0.0, _alt_bar.size.y - h)
	_alt_fill.size = Vector2(_alt_bar.size.x, h)


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_timer = 1.2 if not _cleared else 0.0


func _build_walls() -> void:
	var mid_y := (world_top_y + world_bottom_y) * 0.5
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