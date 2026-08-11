# Godot の書き方（構成・命名・手書き書式）

このリポジトリでは `.tscn` / `.gd` / `project.godot` を**直接テキストで書く**。
エディタ GUI で作ってもよいが、生成された差分がここの規約から外れていないか確認すること。

## ディレクトリ構成

```
scenes/          画面・ステージ。main.tscn, ui/title.tscn
actors/          再利用する実体。1 機能 1 フォルダで .tscn と .gd を同居
                   actors/rocket/rocket.tscn
                   actors/rocket/rocket.gd
scripts/         autoload・共通ユーティリティ（どのシーンにも属さないコード）
assets/art/      画像・モデル
assets/audio/    BGM・SE
assets/fonts/    フォント
tools/           godot.sh / godot.ps1
docs/            ドキュメント
```

**`actors/<機能>/` に閉じ込めるのが衝突回避の要。** 自分の担当機能のフォルダの中だけで完結させ、
`scenes/main.tscn` は各 actor をインスタンス化するだけの薄いシーンに保つ。

構成を変える場合は、理由が分かるようにコミットメッセージに書く。

## 命名

| 対象 | 規則 | 例 |
|---|---|---|
| ファイル・フォルダ | `snake_case` | `player_controller.gd`, `stage_01.tscn` |
| ノード名 | `PascalCase` | `Player`, `HealthBar`, `SpawnPoint` |
| `class_name` | `PascalCase` | `class_name PlayerController` |
| 変数・関数 | `snake_case` | `move_speed`, `apply_damage()` |
| private | `_` 始まり | `_velocity`, `_on_body_entered()` |
| 定数 | `SCREAMING_SNAKE` | `const MAX_HP := 100` |
| シグナル | 過去形 `snake_case` | `signal coin_collected(amount: int)` |

ノード名はスクリプトの `$Path` / `@onready` が**完全一致で依存する**。リネームは参照元とセットで行う。

## GDScript

- インデントは**タブ**（Godot の標準。[.editorconfig](../.editorconfig) 参照）。
- 型は書く。`var speed := 5.0` / `func apply_damage(amount: int) -> void:`
- `var x := load(...)` は **Variant になって `Cannot infer the type of "x"` になる。** `var x: PackedScene = load(...)` と明示する。
- ノード参照は `@onready var _flame: Polygon2D = $Flame`。
- 状態は**持ち主に持たせる**。収集物側でスコアを数えず、シグナルで親へ投げて親が数える。
- `class_name` を足したら `bash tools/godot.sh import` を回す（`.godot/global_script_class_cache.cfg` が更新されるまで他スクリプトから解決できない）。

## .tscn の書式

INI 風のテキスト。セクションの順序は固定: `gd_scene` → `ext_resource` → `sub_resource` → `node` → `connection`。

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://actors/rocket/rocket.gd" id="1_rocket"]
[ext_resource type="PackedScene" path="res://actors/obstacle/obstacle.tscn" id="2_obstacle"]

[sub_resource type="CircleShape2D" id="Shape_rocket"]
radius = 30.0

[node name="Rocket" type="RigidBody2D"]
script = ExtResource("1_rocket")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("Shape_rocket")

[node name="Obstacle" parent="." instance=ExtResource("2_obstacle")]

[connection signal="area_entered" from="Hitbox" to="." method="_on_hitbox_area_entered"]
```

- `format=3` が Godot 4。`load_steps` は `ext_resource` + `sub_resource` の総数 + 1。
- 最初の `[node]` がルート（`parent` を書かない）。以降の `parent` は**ルートからの相対パス**（`Child/Grand`）。
- 別シーンのインスタンスは `type` を書かず `instance=ExtResource("...")`。
- `sub_resource` は参照される前に定義する。
- `path=` の代わりに `uid="uid://..."` も使えるが、手書きでは `path=` でよい。

### Node2D の配置

```
position = Vector2(0, -120)
rotation = 1.5708                        # ラジアン。度数で書きたいなら rotation_degrees
scale = Vector2(2, 2)
```

**2D は y が下向き。** 上へ登るほど `y` は負になる（このゲームのゴールは `y = -4350`）。
`Transform2D(...)` を手書きするより `position` / `rotation_degrees` で済ませる。

### Control（UI）

```
[node name="Message" type="Label" parent="UI"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -300.0
offset_top = -70.0
offset_right = 300.0
offset_bottom = 70.0
grow_horizontal = 2
grow_vertical = 2
theme_override_fonts/font = SubResource("Font_ui")
theme_override_font_sizes/font_size = 44
horizontal_alignment = 1
vertical_alignment = 1
```

- **`anchors_preset` だけではアンカーは設定されない。** `anchor_*` と `offset_*` も併記する。
- stretch が `canvas_items` / `expand` なので、**基準ビューポート**に対して組む。ウィンドウサイズからピクセル位置を計算しない。
- **日本語は内蔵フォントに CJK グリフが無く豆腐になる。** `SystemFont` を挿す:

```
[sub_resource type="SystemFont" id="Font_ui"]
font_names = PackedStringArray("Yu Gothic UI", "Meiryo UI", "MS UI Gothic", "Segoe UI")
```

## project.godot

エンジンが管理するファイル。既存のセクション構造を壊さない。コメントは `;`。

```
[application]
run/main_scene="res://scenes/main.tscn"    ; 未設定だと実行できない
```

入力アクションは `[input]` セクション。`ui_*` は既定で矢印キーのみなので、WASD が欲しければ自分で定義する。
`physical_keycode` を使うとキーボードレイアウトに依存しない。

```
[input]

move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

| キー | 値 | キー | 値 |
|---|---|---|---|
| A / D / W / S | 65 / 68 / 87 / 83 | Space | 32 |
| R | 82 | Escape | 4194305 |
| ← / ↑ / → / ↓ | 4194319 / 4194320 / 4194321 / 4194322 | Enter | 4194309 |

左右 1 軸だけなら `Input.get_axis(neg, pos)` で足りる（`rocket.gd` の旋回がこれ）。
`Input.get_vector(...)` を使う場合、**2D は y が下向き**なので「上 = -1」。符号の扱いを間違えやすい。

## よく踏む罠

エンジンが黙って受け入れて、実行時に初めて壊れるもの。

| 症状 | 原因 | 対処 |
|---|---|---|
| UI の日本語が豆腐／空白 | 内蔵フォントに CJK グリフが無い | `SystemFont` を `theme_override_fonts/font` に指定 |
| RigidBody2D を移動させても戻される | `global_position` への代入は物理サーバーの状態を書き換えない | `_integrate_forces(state)` 内で `state.transform` / `state.linear_velocity` を設定。リスポーンは freeze → transform 変更 → unfreeze |
| `Can't change this state while flushing queries` | `area_entered` などの物理コールバック中に `freeze` やノード追加をした | `set_deferred("freeze", true)` / `処理.call_deferred()` に逃がす（`scenes/main.gd` の被弾処理） |
| Area2D 同士が当たらない | 片方の `collision_layer` ともう片方の `collision_mask` が噛み合っていない。`monitorable = false` も見落としやすい | 検出する側に mask、検出される側に layer（Rocket の `Hitbox` は mask=2、障害物は layer=2） |
| `Cannot infer the type of "x"` | `var x := load(...)` は Variant | `var x: PackedScene = load(...)` |
| 入力が効かない | アクション名の綴り違い。`InputMap` に無いアクションは黙って false | 検証スクリプトで `Input.action_press("名前")` を撃って挙動が変わるか見る |
| ノードが `null` | `$Path` はノード名に完全一致で依存 | リネームしたら参照元スクリプトも直す |
| 追加したシーン／`class_name` が見つからない | インポート未実行 | `bash tools/godot.sh import` |

`project.godot` の Jolt 設定は **3D 物理にしか効かない。** このゲームは 2D なので、
挙動を疑うときに Jolt を犯人にしない（2D は Godot 標準の物理）。

## このゲームの前提（`scenes/main.tscn`）

仮シーンではなく本編。作り込むときの決まりごと:

- ルートは `Node2D`。ステージ寸法は `DESIGN_WIDTH/HEIGHT`(1280x720) 定数で固定する。
  `get_viewport_rect()` は stretch 拡張で**実ウィンドウサイズ**を返すので、ステージ計算に使わない。
- 地面の上面が世界 `y = 0`（＝高度 0m）。上へ行くほど `y` は負。ゴールは 6 画面分（`SCREEN_COUNT = 6`）。
- 共有状態（残機・高度・クリア判定）は autoload ではなく `scenes/main.gd` が持つ。
- 入力アクションは `thrust` / `rotate_left` / `rotate_right`。追加するときは動詞の `snake_case` で揃える。
