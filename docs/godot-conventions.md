# Godot の書き方（構成・命名・手書き書式）

このリポジトリでは `.tscn` / `.gd` / `project.godot` を**直接テキストで書く**。
エディタ GUI で作ってもよいが、生成された差分がここの規約から外れていないか確認すること。

## ディレクトリ構成

```
scenes/          画面・ステージ。main.tscn, stage_01.tscn, ui/title.tscn
actors/          再利用する実体。1 機能 1 フォルダで .tscn と .gd を同居
                   actors/player/player.tscn
                   actors/player/player.gd
scripts/         autoload・共通ユーティリティ（どのシーンにも属さないコード）
assets/art/      画像・モデル
assets/audio/    BGM・SE
assets/fonts/    フォント
tools/           godot.sh / godot.ps1
docs/            ドキュメント
```

**`actors/<機能>/` に閉じ込めるのが衝突回避の要。** 自分の担当機能のフォルダの中だけで完結させ、
`scenes/main.tscn` は各 actor をインスタンス化するだけの薄いシーンに保つ。

構成を変える場合は、理由が分かるように PR の説明に書く。

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
- ノード参照は `@onready var _mesh: MeshInstance3D = $Mesh`。
- 状態は**持ち主に持たせる**。収集物側でスコアを数えず、シグナルで親へ投げて親が数える。
- `class_name` を足したら `bash tools/godot.sh import` を回す（`.godot/global_script_class_cache.cfg` が更新されるまで他スクリプトから解決できない）。

## .tscn の書式

INI 風のテキスト。セクションの順序は固定: `gd_scene` → `ext_resource` → `sub_resource` → `node` → `connection`。

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://actors/player/player.gd" id="1_player"]
[ext_resource type="PackedScene" path="res://actors/coin/coin.tscn" id="2_coin"]

[sub_resource type="SphereShape3D" id="Shape_ball"]
radius = 0.5

[node name="Player" type="CharacterBody3D"]
script = ExtResource("1_player")

[node name="Shape" type="CollisionShape3D" parent="."]
shape = SubResource("Shape_ball")

[node name="Coin" parent="." instance=ExtResource("2_coin")]

[connection signal="body_entered" from="Area" to="." method="_on_body_entered"]
```

- `format=3` が Godot 4。`load_steps` は `ext_resource` + `sub_resource` の総数 + 1。
- 最初の `[node]` がルート（`parent` を書かない）。以降の `parent` は**ルートからの相対パス**（`Child/Grand`）。
- 別シーンのインスタンスは `type` を書かず `instance=ExtResource("...")`。
- `sub_resource` は参照される前に定義する。
- `path=` の代わりに `uid="uid://..."` も使えるが、手書きでは `path=` でよい。

### Node3D の配置

```
position = Vector3(0, 1.5, 0)
rotation_degrees = Vector3(0, 90, 0)     # 度数で書ける。手計算不要
scale = Vector3(2, 2, 2)
```

`Transform3D(...)` の引数は**基底ベクトルを列で並べた順**（行優先で書くと転置される）。
`position` / `rotation_degrees` で済むならそちらを使う。

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

`Input.get_vector(neg_x, pos_x, neg_y, pos_y)` は「奥方向 = y が -1」を返す。3D の前後に使うときは符号の反転を忘れない。

## よく踏む罠

エンジンが黙って受け入れて、実行時に初めて壊れるもの。

| 症状 | 原因 | 対処 |
|---|---|---|
| UI の日本語が豆腐／空白 | 内蔵フォントに CJK グリフが無い | `SystemFont` を `theme_override_fonts/font` に指定 |
| RigidBody を移動させても戻される | `global_position` への代入は物理サーバーの状態を書き換えない | `_integrate_forces(state)` 内で `state.transform` / `state.linear_velocity` を設定 |
| 転がる物体の接地判定が効かない | 子の RayCast3D は本体と一緒に回転する | `get_world_3d().direct_space_state.intersect_ray()` を毎フレーム直接呼ぶ |
| `Cannot infer the type of "x"` | `var x := load(...)` は Variant | `var x: PackedScene = load(...)` |
| 入力が効かない | アクション名の綴り違い。`InputMap` に無いアクションは黙って false | 検証スクリプトで `Input.action_press("名前")` を撃って挙動が変わるか見る |
| ノードが `null` | `$Path` はノード名に完全一致で依存 | リネームしたら参照元スクリプトも直す |
| 追加したシーン／`class_name` が見つからない | インポート未実行 | `bash tools/godot.sh import` |

3D 物理は **Jolt** を使っている。コリジョン挙動や一部の `PhysicsServer3D` パラメータが既定エンジンと違うので、
ネットで拾った Godot Physics 前提の数値をそのまま信じない。

## まだ決まっていないこと（着手時に決める）

`scenes/main.tscn` は**仮のプレースホルダ**（ルート `Main`(Node) ＋ `UI`(CanvasLayer) ＋ ラベル 2 枚）で、
`run/main_scene` は設定済み。差し替えるときは以下を決める。

- ルートを 2D にするか 3D にするか（仮シーンのルートは中立な `Node`。世界のノードを足す人が決める）
- 入力アクションの命名（`move_left` などチーム共通で使う名前。`ui_*` は矢印キーのみなので自分で定義する）
- スコアなど共有状態の置き場所（autoload にするか、main シーンが持つか）
- カメラの基準（移動方向をカメラ basis から作るか、ワールド固定か）
