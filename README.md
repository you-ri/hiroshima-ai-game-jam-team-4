# hiroshima-ai-game-jam-team-4

広島 AI ゲームジャム team 4 の Godot **4.7.1-stable** プロジェクト（Forward+ / GDScript / Jolt Physics）。
**AI エージェント（Claude Code / OpenCode など）で複数人が同時に開発する**前提で構成している。

開発 OS は **Windows 限定**。コマンドは **Git Bash** で実行する。

## はじめかた

```sh
git clone https://github.com/you-ri/hiroshima-ai-game-jam-team-4
cd hiroshima-ai-game-jam-team-4

bash tools/godot.sh path      # Godot 本体の場所が解決できるか
bash tools/godot.sh import    # アセットのインポート
```

`path` で見つからないと言われたら [docs/setup.md](docs/setup.md) へ。

> `scenes/main.tscn` は**仮のプレースホルダ**（ラベルを出すだけ）。ゲーム本体はこれから作る。
> `bash tools/godot.sh check` が `--- OK: ERROR なし` で終われば環境は正常。

## よく使うコマンド

```sh
bash tools/godot.sh import                       # 再インポート（.tscn/.gd/class_name を足したら必須）
bash tools/godot.sh check                        # ヘッドレス起動スモークテスト
bash tools/godot.sh verify res://_verify_x.gd    # 挙動を数値で検証
bash tools/godot.sh run                          # ウィンドウ付きで実行
bash tools/godot.sh editor                       # エディタを開く
```

PowerShell を使っている場合も `bash tools/godot.sh ...` でそのまま動く（`.\tools\godot.ps1 <同じコマンド>` は転送用ラッパー）。
Godot の GUI ビルドは PowerShell から出力を捕捉できないため、**中身は必ず Bash 経由**で走る。

## ドキュメント

| ファイル | 中身 |
|---|---|
| [AGENTS.md](AGENTS.md) | **AI エージェントへの指示書（唯一の正）**。ルール変更はここを直す |
| [CLAUDE.md](CLAUDE.md) | Claude Code の入口。`AGENTS.md` を取り込む薄いファイル |
| [docs/setup.md](docs/setup.md) | 環境構築・Godot の置き場所の登録 |
| [docs/workflow.md](docs/workflow.md) | バイブコーディングの回し方とヘッドレス検証 |
| [docs/godot-conventions.md](docs/godot-conventions.md) | ディレクトリ / 命名 / `.tscn` 手書き書式 / 罠 |
| [docs/team-rules.md](docs/team-rules.md) | 分担・ブランチ運用・コンフリクト回避 |
| [docs/troubleshooting.md](docs/troubleshooting.md) | 症状から引く対処表 |
| [docs/decisions.md](docs/decisions.md) | 決定ログ |

## 開発の原則

1. **「読み込めた」を「動いた」と混同しない。** Godot は壊れたシーンを黙って読み込む。`check` の先の `verify` まで回す。
2. **Godot は `tools/godot.sh` 経由で呼ぶ。** 環境差をコードに持ち込まない。
3. **1 機能 = 1 フォルダ = 1 担当。** `.tscn` の同時編集を避ける。
4. **決めたことは [docs/decisions.md](docs/decisions.md) に残す。** 他メンバーの AI が読めるのはリポジトリの中身だけ。
