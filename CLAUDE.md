# CLAUDE.md

Claude Code 向けの入口。実際の指示は [AGENTS.md](AGENTS.md) にまとまっている（OpenCode など他の AI 環境と共有するため）。
**ルールを変更するときは AGENTS.md 側を直すこと。** このファイルには Claude Code 固有の事情だけを書く。

OpenCode も [opencode.json](opencode.json) の `instructions` でこのファイルを読む
（OpenCode は `AGENTS.md` と `CLAUDE.md` の両方がある場合、既定では `AGENTS.md` しか読まないため）。
どの AI でも同じ内容が届くので、ここに書いたことは全環境に効く。

@AGENTS.md

## 迷ったら

**ゲームの仕様で迷ったら [docs/Spec.txt](docs/Spec.txt) を見る。** 何を作るかの正はここ。
書かれていないことは勝手に決めずに確認する。書式や進め方の迷いは AGENTS.md 側。

## Claude Code 固有のメモ

- Godot の実行は **Bash ツール**で `bash tools/godot.sh ...` を使う。PowerShell ツール経由だとエンジンの標準出力が途中で切れ、`print()` の結果が届かないことがある（「出力が無い」を「エラーが無い」と誤読する）。
- `godot-vibe-coding` スキルを持っている場合は、`.tscn` を手書きする前に読み込んでよい。ただしこれは**個人環境にあるスキルでリポジトリには含まれない**ため、他メンバーは同じものを持っていない。スキル由来の知見に依存した実装をしたら、要点を [docs/godot-conventions.md](docs/godot-conventions.md) に書き戻す。
- 検証用の使い捨てスクリプトは `_verify_<対象>.gd` の名前でリポジトリ直下に置き、使い終わったら `.gd.uid` ごと削除する（gitignore 済み）。
