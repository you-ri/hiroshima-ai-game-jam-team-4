# トラブルシュート

症状から引く。ほとんどは「インポートしていない」か「エディタが開いている」。

## 起動・ツール系

| 症状 | 原因 | 対処 |
|---|---|---|
| `Godot 本体が見つからない` | パス未登録 | [setup.md](setup.md) の「置き場所を登録する」 |
| `Can't run project: no main scene defined` | `run/main_scene` が消えた／シーンを差し替えて設定が合っていない | `project.godot` の `[application]` に `run/main_scene="res://scenes/ui/title.tscn"` があるか確認 |
| 出力が途中で切れる / `print()` が出ない | PowerShell から Godot を直接叩いている（GUI ビルドの出力は捕捉できない） | Git Bash で `bash tools/godot.sh ...` を使う |
| `.ps1` が `Unexpected token` / `missing the terminator` で落ちる | PowerShell 5.1 が BOM 無し UTF-8 の日本語を解析できない | `.ps1` は ASCII のみで書く。説明は `docs/` に日本語で書く |
| `bash` が見つからない | Git for Windows 未インストール | [setup.md](setup.md) の手順 0 |
| 終了コードが空・0 なのに壊れている | GUI ビルドは終了コードが当てにならない | 標準出力の `ERROR` / `SCRIPT ERROR` を見る（`tools/godot.sh` が判定している） |
| 書き換えた `.tscn` が反映されない | エディタが開いていて保存時に上書きした | エディタを閉じてから書く。閉じてもう一度書き直す |
| 追加したシーン / `class_name` が見つからない | インポート未実行 | `bash tools/godot.sh import` |
| `.godot/` が壊れた気配 | キャッシュ不整合 | `.godot/` を削除して `bash tools/godot.sh import` |

## 実行時

| 症状 | 原因 | 対処 |
|---|---|---|
| ノードが `null` | `$Path` とノード名が不一致 | ノード名を確認。リネームしたら参照元も直す |
| 入力が効かない | アクション名の綴り違い（`InputMap` に無いアクションは黙って false） | `Input.action_press("名前")` を検証スクリプトで撃って挙動が変わるか見る |
| WASD が効かない | `ui_*` は既定で矢印キーのみ | `project.godot` の `[input]` に自分で定義（[godot-conventions.md](godot-conventions.md)） |
| 上下の移動が逆 | 2D は **y が下向き**（上へ登るほど y は負） | 符号を確認する |
| RigidBody2D を動かしても戻される | `global_position` 代入は物理サーバーに効かない | `_integrate_forces(state)` で `state.transform` / `state.linear_velocity` を設定。リスポーンは freeze → 変更 → unfreeze |
| `Can't change this state while flushing queries` | `area_entered` などの物理コールバック中に `freeze` を切り替えた | `set_deferred("freeze", true)` / `処理.call_deferred()` に逃がす |
| 当たり判定が効かない（Area2D） | `collision_layer` / `collision_mask` が噛み合っていない。`monitorable = false` の見落とし | 検出する側に mask、される側に layer（Rocket の `Hitbox` は mask=2、障害物は layer=2） |
| W を押しっぱなしで上がらない | 仕様どおり（`thrust` は連打式で 1 入力 1 噴射） | 検証では `action_press` の後に `action_release` を入れる |
| 壁をよじ登る | 摩擦で押し上がっている | 検証中の `y` の最大値を見る。形状か摩擦を調整 |

## 表示

| 症状 | 原因 | 対処 |
|---|---|---|
| 日本語が豆腐／空白 | 内蔵フォントに CJK グリフが無い | 同梱の `assets/fonts/NotoSansJP-Regular.ttf` を `theme_override_fonts/font` に指す（[godot-conventions.md](godot-conventions.md) の「フォント（日本語）」） |
| **エディタでは出るのに書き出すと日本語が消える／文字化けする** | `SystemFont`（`Yu Gothic UI` 等）を使っている。**Web 書き出しには OS のフォントが無い** | 同上。`SystemFont` を残す場合は `fallbacks` に同梱フォントを入れる |
| 同梱フォントにしたのに一部の字だけ豆腐 | サブセットが JIS 第一水準までなので第二水準・異体字は入っていない | `python tools/make_jp_font.py` で作り直して `bash tools/godot.sh import` |
| UI が中央に来ない | `anchors_preset` だけ書いてアンカー値が無い | `anchor_*` と `offset_*` を併記 |
| ウィンドウサイズを変えると崩れる | ピクセル位置をハードコードしている | stretch は `canvas_items`/`expand`。基準ビューポートに対して組む |
| ヘッドレスで画が取れない | dummy レンダラなので当然 | `bash tools/godot.sh run` でウィンドウ起動して目視 |

## スクリプト（GDScript）

| 症状 | 原因 | 対処 |
|---|---|---|
| `Parse Error: Cannot infer the type of "x"` | `var x := load(...)` は Variant | `var x: PackedScene = load(...)` |
| C# が動かない | `_mono_` の付かないビルド | GDScript で書く |
| 検証スクリプトが最初の `print` だけで終わる | `_initialize()` の中で `await` した | フレーム進行は `_process()` に書く |
| 検証の待ち時間が短すぎる／長すぎる | ヘッドレスは vsync 無しで 140fps 超で回る | フレーム数ではなく `delta` の積算で秒を判定する |
| 終了時に `ObjectDB instances were leaked` | 検証スクリプトが後始末していないだけ | 無害。無視してよい |

## git

| 症状 | 対処 |
|---|---|
| `.tscn` がコンフリクトした | 手マージしない。片方を捨てて作り直す方が速い。今後は同時編集を避ける（[team-rules.md](team-rules.md)） |
| `.godot/` が差分に出る | `.gitignore` を確認。既に追跡されているなら `git rm -r --cached .godot` |
| `_verify_*.gd` が差分に出る | 消す。`.gitignore` 済みだが追跡済みなら `git rm --cached` |
