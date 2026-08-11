extends Control
## タイトル画面「Apophis」。隕石をよけて地球を脱出するゲームの入口。
##
## 決定（ui_accept: Space / Enter / 左クリック）でゲーム本編へ、
## キャンセル（ui_cancel: Escape）で終了する。
## 背景の描画は Backdrop（space_backdrop.gd）が持っていて、ここは入力と遷移だけを見る。

## 遷移先。本編は copy_main.tscn（main.tscn は試作として残してある）
const GAME_SCENE_PATH := "res://scenes/copy_main.tscn"

## PRESS ... の明滅周期（秒）
const BLINK_PERIOD := 1.4
## 起動直後の押しっぱなしで飛ばさないための入力受付猶予（秒）
const INPUT_DELAY := 0.35
## 決定してから実際に遷移するまでの間（秒）。この間だけ高速点滅する
const FLASH_DURATION := 0.45

signal start_requested

@onready var _logo: Label = $Layout/Logo
@onready var _prompt: Label = $Layout/Prompt

var _elapsed := 0.0
var _accepted := false


func _ready() -> void:
	print("[title] ready: %s / %s" % [_logo.text, $Layout/Tagline.text])


func _process(delta: float) -> void:
	_elapsed += delta
	_update_prompt()
	if _accepted or _elapsed < INPUT_DELAY:
		return
	# ヘッドレス検証から Input.action_press() で叩けるように、イベントではなくポーリングで見る
	if Input.is_action_just_pressed("ui_accept"):
		start_game()
	elif Input.is_action_just_pressed("ui_cancel"):
		quit_game()


func _unhandled_input(event: InputEvent) -> void:
	if _accepted or _elapsed < INPUT_DELAY:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_game()
		get_viewport().set_input_as_handled()


## ゲーム本編へ遷移する。二重に呼ばれても 1 回しか走らない。
func start_game() -> void:
	if _accepted:
		return
	_accepted = true
	start_requested.emit()
	print("[title] start -> %s" % GAME_SCENE_PATH)
	await get_tree().create_timer(FLASH_DURATION).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(GAME_SCENE_PATH)


func quit_game() -> void:
	print("[title] quit")
	get_tree().quit()


func _update_prompt() -> void:
	# 決定後は速い点滅にして「押した」ことを見せる
	var period := 0.12 if _accepted else BLINK_PERIOD
	var t := fmod(_elapsed, period) / period
	_prompt.modulate.a = 0.30 + 0.70 * (0.5 + 0.5 * cos(t * TAU))
