extends Control
## ゲームオーバー画面。タイトルと同じレイアウトで、地球が砕けた姿になる。
##
## 決定（ui_accept: Space / Enter / 左クリック）でリトライ、
## キャンセル（ui_cancel: Escape）でタイトルへ戻る。
## 背景の描画は Backdrop（space_backdrop.gd）が earth_destroyed = true で持つ。

## リトライ先。ゲーム本編。
const RETRY_SCENE_PATH := "res://scenes/copy_main.tscn"
## キャンセル時の戻り先。
const TITLE_SCENE_PATH := "res://scenes/ui/title.tscn"

## PRESS ... の明滅周期（秒）
const BLINK_PERIOD := 1.4
## 死んだ直後の入力を拾わないための受付猶予（秒）。タイトルより長めに取る
const INPUT_DELAY := 0.8
## 決定してから実際に遷移するまでの間（秒）。この間だけ高速点滅する
const FLASH_DURATION := 0.45

signal retry_requested
signal title_requested

@onready var _logo: Label = $Layout/Logo
@onready var _prompt: Label = $Layout/Prompt

var _elapsed := 0.0
var _accepted := false


func _ready() -> void:
	print("[game_over] ready: %s / %s" % [_logo.text, $Layout/Tagline.text])


func _process(delta: float) -> void:
	_elapsed += delta
	_update_prompt()
	if _accepted or _elapsed < INPUT_DELAY:
		return
	# ヘッドレス検証から Input.action_press() で叩けるように、イベントではなくポーリングで見る
	if Input.is_action_just_pressed("ui_accept"):
		retry()
	elif Input.is_action_just_pressed("ui_cancel"):
		back_to_title()


func _unhandled_input(event: InputEvent) -> void:
	if _accepted or _elapsed < INPUT_DELAY:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		retry()
		get_viewport().set_input_as_handled()


## ゲーム本編をやり直す。二重に呼ばれても 1 回しか走らない。
func retry() -> void:
	_go(RETRY_SCENE_PATH, retry_requested)


## タイトルへ戻る。
func back_to_title() -> void:
	_go(TITLE_SCENE_PATH, title_requested)


func _go(path: String, sig: Signal) -> void:
	if _accepted:
		return
	_accepted = true
	sig.emit()
	print("[game_over] -> %s" % path)
	await get_tree().create_timer(FLASH_DURATION).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(path)


func _update_prompt() -> void:
	# 決定後は速い点滅にして「押した」ことを見せる
	var period := 0.12 if _accepted else BLINK_PERIOD
	var t := fmod(_elapsed, period) / period
	_prompt.modulate.a = 0.30 + 0.70 * (0.5 + 0.5 * cos(t * TAU))
