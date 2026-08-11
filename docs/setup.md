# 環境構築

**開発 OS は Windows 限定。** やることは 3 つ。**Git for Windows を入れる**、**Godot を入れる**、**置き場所を登録する**。

## 0. Git for Windows（Git Bash）

[git-scm.com](https://git-scm.com/download/win) から入れる。**Git Bash が必須。**
Godot の GUI ビルドは PowerShell から標準出力を捕捉できないため、ビルド・検証コマンドはすべて Bash 経由で走らせる。

## 1. Godot 4.7.1-stable を入れる

[godotengine.org](https://godotengine.org/download/) から **Windows 版 4.7.1-stable の標準版**（`.NET`／Mono 版ではない方）を取得する。
バージョンがずれると `.tscn` の書式差分で無駄なコンフリクトが出るので、チーム内でバージョンを揃える。

> C# は使わない。標準ビルドでは動かないので GDScript で書くこと。

## 2. 置き場所を登録する

Godot は PATH に入っていないことが多く、置き場所はメンバーごとに違う。
`tools/godot.sh` が次の順で解決するので、**どれか 1 つ**を満たしていればよい。

| 優先 | 方法 | 備考 |
|---|---|---|
| 1 | 環境変数 `GODOT_BIN` | シェルの設定に書いておくのが一番楽 |
| 2 | リポジトリ直下の `.godot-path` | 1 行にフルパスを書くだけ。`.gitignore` 済みなので他人に影響しない |
| 3 | `PATH` 上の `godot` / `godot4` | PATH を通している人向け |
| 4 | 自動探索 | `%USERPROFILE%\Desktop`, `Downloads`, `C:\Program Files\Godot`, `C:\Godot` の `Godot_v4.*_win64.exe` |

デスクトップやダウンロードフォルダに置いてあるなら **4 に引っかかるので設定不要**。

```sh
# 方法 1（Git Bash / そのセッション限り）
export GODOT_BIN="/c/Users/<you>/Desktop/Godot_v4.7.1-stable_win64.exe"

# 方法 1（PowerShell / ユーザー環境変数として恒久化）
[Environment]::SetEnvironmentVariable("GODOT_BIN", "C:\path\to\Godot_v4.7.1-stable_win64.exe", "User")

# 方法 2（リポジトリ直下に置くだけ。gitignore 済み）
echo "C:/Users/<you>/Desktop/Godot_v4.7.1-stable_win64.exe" > .godot-path
```

設定したパスにファイルが無い場合は警告を出して次の方法へ進むので、消し忘れで無言の失敗にはならない。

## 3. 動作確認

```sh
git clone https://github.com/you-ri/hiroshima-ai-game-jam-team-4
cd hiroshima-ai-game-jam-team-4

bash tools/godot.sh path      # 解決されたバイナリのパスが出る
bash tools/godot.sh version   # 4.7.1.stable.official....
bash tools/godot.sh import    # .godot/ が生成される → "--- OK: ERROR なし"
bash tools/godot.sh check     # main シーンが起動する → "--- OK: ERROR なし"
```

`path` で「Godot 本体が見つからない」と出たら 2 に戻る。

`check` が次のように出れば準備完了:

```
[main] ready height=4320 goal_y=-4350 lives=3
--- OK: ERROR なし
```

`bash tools/godot.sh run` でウィンドウ起動するとゲーム本編が立ち上がる（HUD の日本語が豆腐になっていなければフォント設定も正常）。

## 4. シェルについて

コマンドはすべて **Git Bash** で実行する。

- PowerShell を使っている場合も、そのまま `bash tools/godot.sh check` と打てば動く。
  ラッパーの `.\tools\godot.ps1 <同じコマンド>` も用意してあるが、中身は `tools/godot.sh` へ転送しているだけ。
- **ロジックを増やすのは `tools/godot.sh` 側だけ。** `.ps1` は転送役に留める。
- `.ps1` は **ASCII のみで書く**（Windows PowerShell 5.1 は BOM 無し UTF-8 の日本語を解析できず、スクリプトが壊れる）。
- 改行は LF に正規化される（[.gitattributes](../.gitattributes)）。エディタ設定は [.editorconfig](../.editorconfig) に従う。

## 5. AI エージェント側の準備

追加設定は不要。リポジトリを開けば自動的に読まれる。

- **OpenCode** — [AGENTS.md](../AGENTS.md)
- **Claude Code** — [CLAUDE.md](../CLAUDE.md)（中で `AGENTS.md` を取り込む）

作業を始める前に、エージェントに [docs/workflow.md](workflow.md) と [docs/godot-conventions.md](godot-conventions.md) を読ませると事故が減る。
