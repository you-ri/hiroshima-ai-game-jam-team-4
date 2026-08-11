#!/usr/bin/env bash
# Godot ランナー（Windows / Git Bash 前提）
#
# 開発 OS は Windows 限定。Git for Windows 同梱の Git Bash で実行する。
# メンバーごとに Godot 本体の置き場所が違うので、ここで解決を一元化する。
# 解決順:  $GODOT_BIN  →  リポジトリ直下の .godot-path  →  PATH  →  よくある場所を探索
#
# 使い方:
#   tools/godot.sh path                # 解決されたバイナリのパスを表示
#   tools/godot.sh import              # アセット再インポート（.tscn/.gd 追加後は必須）
#   tools/godot.sh check [frames]      # ヘッドレス起動スモークテスト（既定 180 フレーム）
#   tools/godot.sh verify res://_verify_x.gd   # SceneTree 検証スクリプトを実行
#   tools/godot.sh run [args...]       # ウィンドウ付きで実行
#   tools/godot.sh editor              # エディタを開く
#
# check / verify / import は出力に ERROR が含まれていれば終了コード 1 を返す。
# （Godot の GUI ビルドは終了コードが当てにならないため、標準出力を見て判定している）
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

to_slash() { printf '%s' "${1//\\//}"; }

find_godot() {
	local c d

	# 設定されているのに存在しない場合は、黙って探索へ落ちずに知らせる
	if [ -n "${GODOT_BIN:-}" ]; then
		if [ -f "$GODOT_BIN" ]; then printf '%s' "$GODOT_BIN"; return 0; fi
		echo "警告: GODOT_BIN が指すファイルが無い: $GODOT_BIN" >&2
	fi

	if [ -f "$ROOT/.godot-path" ]; then
		c="$(head -n1 "$ROOT/.godot-path" | tr -d '\r')"
		if [ -n "$c" ]; then
			if [ -f "$c" ]; then printf '%s' "$c"; return 0; fi
			echo "警告: .godot-path が指すファイルが無い: $c" >&2
		fi
	fi

	for c in godot4 godot Godot; do
		if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
	done

	local dirs=()
	if [ -n "${USERPROFILE:-}" ]; then
		dirs+=("$(to_slash "$USERPROFILE")/Desktop" "$(to_slash "$USERPROFILE")/Downloads")
	fi
	dirs+=("$HOME/Desktop" "$HOME/Downloads" "/c/Program Files/Godot" "/c/Godot")
	for d in "${dirs[@]}"; do
		for c in "$d"/Godot_v4.*_win64.exe; do
			if [ -f "$c" ]; then printf '%s' "$c"; return 0; fi
		done
	done

	return 1
}

GODOT="$(find_godot)"
if [ -z "$GODOT" ]; then
	cat >&2 <<'MSG'
Godot 本体が見つからない。次のどちらかを設定してから再実行すること:
  1) 環境変数:  export GODOT_BIN="/path/to/Godot_v4.7.1-stable_win64.exe"
  2) リポジトリ直下に .godot-path（1 行にフルパス / .gitignore 済み）
詳細は docs/setup.md を参照。
MSG
	exit 127
fi

# 出力をそのまま流しつつ ERROR を検出する
run_scanned() {
	local out status
	out="$("$GODOT" "$@" 2>&1)"
	printf '%s\n' "$out"
	if printf '%s' "$out" | grep -qE 'SCRIPT ERROR|ERROR:|Can.t run project|Failed to load'; then
		echo "--- NG: 上記の ERROR を解消すること" >&2
		return 1
	fi
	echo "--- OK: ERROR なし"
	return 0
}

cmd="${1:-check}"
[ $# -gt 0 ] && shift

case "$cmd" in
	path)
		printf '%s\n' "$GODOT"
		;;
	version)
		"$GODOT" --headless --version
		;;
	import)
		run_scanned --headless --path . --import
		;;
	check)
		frames="${1:-180}"
		run_scanned --headless --path . --quit-after "$frames"
		;;
	verify)
		if [ $# -eq 0 ]; then echo "使い方: tools/godot.sh verify res://_verify_xxx.gd" >&2; exit 2; fi
		run_scanned --headless --path . --script "$1"
		;;
	run)
		"$GODOT" --path . "$@"
		;;
	editor)
		"$GODOT" -e --path . "$@"
		;;
	*)
		echo "不明なコマンド: $cmd（path|version|import|check|verify|run|editor）" >&2
		exit 2
		;;
esac
