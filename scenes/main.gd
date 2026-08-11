extends Node
## 仮のメインシーン。差し替え前提のプレースホルダ。
##
## ゲーム本体を作るときは、このノードの下に各 actor（actors/<機能>/*.tscn）を
## インスタンス化して足していく。UI は UI(CanvasLayer) の下へ。
## 詳細は docs/godot-conventions.md を参照。

@onready var _title: Label = $UI/Title
@onready var _hint: Label = $UI/Hint


func _ready() -> void:
	# ヘッドレス検証（bash tools/godot.sh check）で起動を確認するための目印
	print("[main] ready: %s" % _title.text)
	print("[main] hint: %s" % _hint.text)
