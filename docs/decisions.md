# 決定ログ

構成・仕様・命名の判断をここに追記する。**メンバーの AI が共有できる文脈はリポジトリの中身だけ**なので、
ここに残っていない決定は「無かったこと」になり、次の誰かが善意で元に戻す。

書式は 1 件 3 行。新しいものを下に足す。

```
## YYYY-MM-DD 決めたこと
- 理由:
- 影響:
```

---

## 2026-08-11 AI 向けドキュメントを整備した
- 理由: Claude Code / OpenCode と複数メンバーで共有するため、指示の正を 1 か所（`AGENTS.md`）に置く必要があった。
- 影響: ルール変更は `AGENTS.md` を直す。`CLAUDE.md` は `@AGENTS.md` で取り込むだけなので追従不要。

## 2026-08-11 Godot の起動を `tools/godot.sh` に一元化した
- 理由: バイナリの場所がメンバーごとに違い、フルパス直書きは他人の環境で動かない。GUI ビルドは終了コードが当てにならず、成否を出力の `ERROR` で判定する処理も共通化したかった。
- 影響: Godot を直接叩かない。パスの登録方法は [setup.md](setup.md)。

## 2026-08-11 ディレクトリ構成を `scenes/` `actors/` `scripts/` `assets/` にした
- 理由: `actors/<機能>/` に .tscn と .gd を同居させ、1 機能 1 フォルダ 1 担当にすると `.tscn` の同時編集事故を減らせる。
- 影響: [godot-conventions.md](godot-conventions.md) の構成に従う。変える場合はここに追記する。

## 2026-08-11 開発 OS を Windows 限定にした
- 理由: メンバー全員が Windows。分岐を持つとテストされない経路が増える。
- 影響: `tools/godot.sh` の探索先は Windows のパスのみ。macOS / Linux 向けの記述は書かない。実行シェルは Git Bash（Git for Windows）に統一。

## 2026-08-11 PowerShell ラッパーは転送役だけにした
- 理由: Godot の GUI ビルドは PowerShell から標準出力を捕捉できず（実測で無出力）、成否判定ができない。さらに PowerShell 5.1 は BOM 無し UTF-8 の日本語を含む `.ps1` を解析できず壊れる。
- 影響: ロジックは `tools/godot.sh` のみに置く。`tools/godot.ps1` は `bash tools/godot.sh` へ渡すだけ・**ASCII のみ**。

## 2026-08-11 仮の main シーンを置いた（`scenes/main.tscn`）
- 理由: `run/main_scene` が未設定だと誰も `check` を通せず、環境構築の成否が判定できない。ジャンル未定のためルートは中立な `Node`（2D/3D どちらにも寄せられる）とし、UI は `CanvasLayer` 配下に置いた。日本語表示の確認を兼ねてラベルに `SystemFont` を指定している。
- 影響: 差し替え前提のプレースホルダ。作り込むときは `project.godot` の `run/main_scene` との整合を保つこと。ルートを 2D/3D どちらにするかは未決定。

## 2026-08-11 ゲーム方針を「攻撃なしのロケット登り」にした（仮 main シーンを差し替え）
- 理由: 2D 縦スクロールで、ロケットがプレイヤー。無操作で自然落下、W で噴射（炎）、A/D で左右旋回、ステージ最下部からスタートして 6 画面分（4320px）を登り最上部に到達でクリア。
- 影響: `scenes/main.tscn` のルートを `Node2D` にした。ステージ寸法は設計解像度 1280x720 基準（`SCREEN_COUNT = 6`）。射撃・敵は無し。

## 2026-08-11 入力アクションと設計解像度を project.godot に追加した
- 理由: `ui_*` は矢印キーのみなので WASD 用に `thrust`(W) / `rotate_left`(A) / `rotate_right`(D) を `physical_keycode` で定義。ステージの「画面」の基準になるよう `window/size/viewport_width=1280` `viewport_height=720` も設定。
- 影響: `[input]` セクションを追加。`get_viewport_rect()` は stretch 拡張で窓サイズを返すため、ステージ寸法はスクリプト内の `DESIGN_WIDTH/HEIGHT` 定数で固定（`scenes/main.gd`）。

## 2026-08-11 ロケットは RigidBody2D、旋回は角速度の直接制御にした
- 理由: 「物理的な挙動」の要望に合わせ、重力はプロジェクト既定（980）、推力は 1600（質量 1 換算で重力を上回る）。A/D は `angular_velocity = TURN_SPEED * axis` で毎物理フレーム上書きし、操作を離すと即座に停止するカチッとした挙動にした。
- 影響: `actors/rocket/rocket.gd` + `rocket.tscn` を新規追加。クリア判定・落下リスポーン・左右の壁は `scenes/main.gd` 側。`RigidBody2D.global_position` の直接代入は物理が戻すため、リスポーンは freeze→transform 変更→unfreeze で行う。

## 2026-08-11 仕様（docs/Spec.txt）に合わせて実装を修正した
- 理由: `docs/Spec.txt` に仕様が定まっていたため、それに揃えた。
  - W は**連打方式**（押した瞬間に炎＋上向きの推進力。押しっぱなしは無効。1 連打で速度 -300）
  - **地面を追加**（上面 = 世界 y=0）。スタートは 0m、ロケットは地面に接地
  - カメラは**常にプレイヤー中心**（縦のクランプを撤廃。横だけ壁の外を見せない）
  - **残機制 3**。被弾で残機-1 → スタート（地面）へ戻って無敵 2 秒（点滅）。0 で「失敗」
  - **障害物**: 下から登る岩（v=130 上向き）と上から落ちる隕石（v=180 下向き）。Area2D なので物理的な押し合いはしない
- 影響: クリア目標は `goal_y = -4350`（ロケット中心の 6 画面分）。当たり判定は Rocket の子 `Hitbox`(Area2D, mask=2) と障害物(Area2D, layer=2) の `area_entered` で行い、RigidBody の挙動を汚さない。障害物はスポーン位置をプレイヤー真上下の ±120px 外にして避けられない事故を防ぐ。

## 2026-08-11 被弾時の物理状態変更は deferred にする
- 理由: `area_entered`（物理クエリのフラッシュ中）に `RigidBody2D.freeze` を直接切り替えると `Can't change this state while flushing queries` エラーになる。
- 影響: リスポーン処理は `_respawn_to_start.call_deferred()`、ゲームオーバーの freeze は `set_deferred("freeze", true)` で実行する。障害物の色変更は `@onready` ではなく `get_node("Body")` を使う（ツリー追加前に呼ばれるため）。

<!-- 以降、決定したことを追記していく -->