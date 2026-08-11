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

<!-- 以降、決定したことを追記していく -->
