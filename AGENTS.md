# AGENTS.md

このリポジトリで作業する AI エージェント（Claude Code / OpenCode / その他）への指示書。
**このファイルが唯一の正**で、`CLAUDE.md` はここを読み込むだけの薄いファイル。ルールを変えるならここを直す。

人間向けの入口は [README.md](README.md)。

---

## 1. プロジェクト

- 広島 AI ゲームジャム team 4 の Godot **4.7.1-stable** プロジェクト（Forward+ / GDScript）。
- リモート: `https://github.com/you-ri/hiroshima-ai-game-jam-team-4`
- 作っているのは **「アポフィス（Apophis）」— 2D 縦スクロールのロケットクライマー**（射撃なし）。W 連打で噴射、A / D で旋回し、重力に逆らって 6 画面分登り切ればクリア。下から来る岩と上から来る隕石に当たると残機が減り（初期 3）、スタート地点へ戻される。0 で失敗。
  - **仕様の正は [docs/Spec.txt](docs/Spec.txt)。** 実装がここと食い違っていたら実装のほうが誤り。
  - 仕様の「ゴール 3000m」と「6 画面上部でクリア」は **1m = 1.44px**（`scripts/units.gd` の `Units`）で両立させている。速度・高度の定数は m 単位で持ち、px へは `Units` で変換する。
  - 実装: `scenes/copy_main.gd`（ステージ・カメラ・クリア／被弾判定・障害物スポーン）、`actors/rocket/`（RigidBody2D の物理挙動）、`actors/obstacle/`（岩・隕石。Area2D）、`scenes/ui/`（タイトル・クリア・ゲームオーバー）。
  - **本番シーンは `scenes/copy_main.tscn`**（タイトル・リトライの遷移先）。`scenes/main.tscn` は試作として残っているだけなので、機能追加は copy_main 側へ。ルートは `Node2D`、地面の上面が世界 `y = 0`（高度 0m）で、上へ行くほど `y` は負。
- **開発 OS は Windows 限定**（Git Bash 前提）。macOS / Linux 向けの分岐は書かない。
- **複数メンバーが別々のマシン・別々の AI 環境で同時に触る。** 自分の手元だけで通ることより、他人の環境で再現することを優先する。

## 2. 最重要ルール

1. **「読み込めた」を「動いた」と混同しない。** Godot は壊れたシーンを黙って読み込む。ノードパス違い・コリジョン未設定・入力アクション名の綴り違いはエラーを出さない。必ず実行して数値で確かめる（[docs/workflow.md](docs/workflow.md)）。
2. **Godot は必ず `tools/godot.sh` 経由で呼ぶ。** バイナリの場所はメンバーごとに違う。フルパスをコードやドキュメントに直書きしない。
3. **Godot の実行は Bash ツール（Git Bash）で。** Godot の GUI ビルドは PowerShell から標準出力を捕捉できず、`print()` が届かない。「出力が無い」を「エラーが無い」と読み違える。`tools/godot.ps1` は `godot.sh` への転送役でしかないので、ロジックを足すなら `.sh` 側に足す（`.ps1` は **ASCII のみ**。日本語を書くと PowerShell 5.1 が解析に失敗する）。
4. **GUI ビルドなので終了コードは当てにならない。** 成否は標準出力の `ERROR` / `SCRIPT ERROR` で判定する（`tools/godot.sh` がやっている）。
5. **エディタを開いたまま `.tscn` を書き換えない。** 開いているシーンはエディタ側のメモリが正で、保存時にディスクの変更を潰す。
6. **`.godot/` は生成物。** 触らない・コミットしない。壊れたら削除して `tools/godot.sh import` で作り直す。
7. **`.tscn` は同時編集で壊れやすい。** 1 シーン 1 担当。他人のシーンを勝手に作り替えない（[docs/team-rules.md](docs/team-rules.md)）。

## 3. 基本ループ

```sh
# 0. 事前確認（見つからなければ docs/setup.md）
bash tools/godot.sh path

# 1. ファイルを書く（.gd → .tscn → project.godot の順が楽）

# 2. インポート：新規アセット・スクリプト・class_name を認識させる
bash tools/godot.sh import

# 3. スモークテスト：ロード時と最初の数秒の実行時エラーを出す
bash tools/godot.sh check

# 4. 挙動テスト：入力を発火して結果を数値で確認する（ここまでやって初めて「動いた」）
bash tools/godot.sh verify res://_verify_player.gd
```

3 が無言で通っても何も確認できていない。**4 まで必ずやる。**
その他: `run`（ウィンドウ付き実行）、`editor`（エディタ）、`version`。

## 4. ディレクトリ構成

```
scenes/     画面・ステージ（copy_main.tscn ＝ ゲーム本編, main.tscn ＝ 旧試作, background.gd ＝ 背景）
              ui/  title.tscn / game_clear.tscn / game_over.tscn
actors/     再利用する実体。1 機能 1 フォルダで .tscn と .gd を同居させる
              rocket/    プレイヤー（RigidBody2D）
              obstacle/  岩・隕石（Area2D）
scripts/    autoload・共通ユーティリティ（どのシーンにも属さないコード）
assets/     art/ audio/ fonts/（日本語同梱フォント。tools/make_jp_font.py で生成）
tools/      godot.sh / godot.ps1
docs/       このドキュメント群
```

ファイル名は `snake_case`、ノード名と `class_name` は `PascalCase`、変数・関数は `snake_case`（private は `_` 始まり）。
詳細と `.tscn` の書式は [docs/godot-conventions.md](docs/godot-conventions.md)。

## 5. やってはいけないこと

- `.godot/` の編集・コミット
- Godot バイナリのフルパスをスクリプトやドキュメントに直書き（`tools/godot.sh` の解決順に任せる）
- 検証用の使い捨てスクリプト（`_verify_*.gd`）と `.gd.uid` の commit（gitignore 済みだが生成したら消す）
- C# の使用（`_mono_` の付かないビルドでは動かない。GDScript で書く）
- 他メンバーが編集中の `.tscn` の同時編集（[docs/team-rules.md](docs/team-rules.md)）

## 6. project.godot の現在の設定

コードに影響するもの:

| 設定 | 値 | 意味 |
|---|---|---|
| `run/main_scene` | `res://scenes/ui/title.tscn` | 起動はタイトル画面から。本編は `scenes/copy_main.tscn`（タイトル・結果画面の遷移先定数も合わせて直す。消すと `Can't run project` で全員が動かせなくなる） |
| `[input]` | `thrust`(W) / `rotate_left`(A) / `rotate_right`(D) | 定義済みアクション。追加するときは既存の命名（動詞 `snake_case`）に合わせ、`physical_keycode` で書く |
| `gui/theme/custom_font` | `res://assets/fonts/NotoSansJP-Regular.ttf` | 日本語の既定フォント。**`SystemFont` は使わない**（Web 書き出しに OS のフォントは無く、日本語が消える）。[docs/godot-conventions.md](docs/godot-conventions.md) の「フォント（日本語）」 |
| stretch | `canvas_items` / `expand` | 基準ビューポートに対して UI を組む。ウィンドウサイズからピクセル位置を計算しない |
| 3D physics | Jolt Physics | **2D には効かない。** このゲームは 2D なので実質未使用 |
| renderer | Forward+ / D3D12(Windows) | シェーダは Forward+ 互換で書く |

テキストは UTF-8 / LF（[.editorconfig](.editorconfig), [.gitattributes](.gitattributes)）。

## 7. ドキュメント索引

| ファイル | 中身 |
|---|---|
| [docs/Spec.txt](docs/Spec.txt) | **ゲーム仕様の唯一の正。** 何を作るかで迷ったらここ。実装がここと違う場合は実装のほうが誤り |
| [docs/setup.md](docs/setup.md) | 環境構築。Godot の置き場所の登録方法、最初の動作確認 |
| [docs/workflow.md](docs/workflow.md) | バイブコーディングの回し方。ヘッドレス検証スクリプトの雛形と検証項目 |
| [docs/godot-conventions.md](docs/godot-conventions.md) | ディレクトリ / 命名 / `.tscn`・`project.godot` の手書き書式 / よく踏む罠 |
| [docs/team-rules.md](docs/team-rules.md) | 複数人・複数 AI 環境での分担、ブランチ運用、コンフリクト回避 |
| [docs/troubleshooting.md](docs/troubleshooting.md) | 症状から引く対処表 |

## 8. AI 環境ごとの補足

- **OpenCode** — このファイル（`AGENTS.md`）を自動で読む。加えて [opencode.json](opencode.json) の
  `instructions` で `CLAUDE.md` も読ませている（OpenCode は `AGENTS.md` と `CLAUDE.md` が両方あると
  既定では `AGENTS.md` しか読まないため、これが無いと Claude Code 側との差が出る）。
- **Claude Code** — `CLAUDE.md` が `@AGENTS.md` でこれを取り込む。`godot-vibe-coding` スキルを持っていれば併用してよいが、**スキルはリポジトリに入っていない個人環境の資産**なので、そこで得た知見は `docs/` に書き戻して全員が使えるようにする。
- どの環境でも、リポジトリ内のドキュメントだけで作業が完結する状態を保つこと。
