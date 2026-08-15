#!/usr/bin/env python3
"""assets/fonts/NotoSansJP-Regular.ttf を作り直す。

Web 書き出しには OS のフォントが無いので SystemFont は使えない（日本語が豆腐になる）。
そのため日本語フォントを同梱するが、Noto Sans JP の全部（約 9.5MB）は Web には重い。
ここで JIS 第一水準までにサブセットして 1MB 前後に落としている。

使い方（フォントを差し替えたい・収録文字を増やしたいときだけ）:

    python -m pip install --user fonttools brotli
    python tools/make_jp_font.py

ネットワークから Noto Sans JP（OFL）を取得するので、オフラインでは動かない。
生成物 assets/fonts/NotoSansJP-Regular.ttf はコミット済みなので、
普段の開発でこのスクリプトを実行する必要は無い。
"""

from __future__ import annotations

import io
import pathlib
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

FONT_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf"
LICENSE_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosansjp/OFL.txt"

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_FONT = ROOT / "assets" / "fonts" / "NotoSansJP-Regular.ttf"
OUT_LICENSE = ROOT / "assets" / "fonts" / "NotoSansJP-OFL.txt"

WEIGHT = 400  # 可変フォントをこの太さで固定する（Godot 側は embolden で太らせる）


def jis_x0208_chars() -> set[str]:
    """JIS X 0208 のうち第一水準漢字・かな・記号を EUC-JP コーデックから列挙する。

    外部の漢字リストを持たずに「日本語として普通に書く文字」を網羅できる。
    第二水準（EUC 先頭バイト 0xCF 以降）は容量のため入れていない。
    """
    chars: set[str] = set()
    for lead in range(0xA1, 0xCF):  # 区 1〜47 ＝ 記号・かな・第一水準漢字
        for trail in range(0xA1, 0xFF):
            try:
                chars.add(bytes((lead, trail)).decode("euc_jp"))
            except UnicodeDecodeError:
                continue
    return chars


def extra_chars() -> set[str]:
    chars: set[str] = set()
    chars |= {chr(c) for c in range(0x20, 0x7F)}  # ASCII
    chars |= {chr(c) for c in range(0x3000, 0x3100)}  # 和文約物・ひらがな・カタカナ
    chars |= {chr(c) for c in range(0xFF01, 0xFF61)}  # 全角英数記号
    chars |= set("─│┌┐└┘━┃…※→←↑↓♪♭°±×÷≠≦≧∞©®™—–‘’“”€")
    return chars


def project_text_chars() -> set[str]:
    """プロジェクト内の .tscn / .gd に書かれている文字を必ず含める（取りこぼし防止）。"""
    chars: set[str] = set()
    for pattern in ("**/*.tscn", "**/*.gd", "**/*.tres"):
        for path in ROOT.glob(pattern):
            if ".godot" in path.parts:
                continue
            chars |= set(path.read_text(encoding="utf-8", errors="ignore"))
    return {c for c in chars if ord(c) >= 0x20}


def main() -> None:
    print("downloading Noto Sans JP ...")
    with urllib.request.urlopen(FONT_URL) as res:
        raw = res.read()
    with urllib.request.urlopen(LICENSE_URL) as res:
        license_text = res.read().decode("utf-8")

    font = TTFont(io.BytesIO(raw))
    print(f"  variable font: {len(raw) / 1024 / 1024:.1f} MB")

    # updateFontNames を付けないと名前が可変フォント既定の "Thin" のまま残る（字形は 400）
    font = instancer.instantiateVariableFont(
        font, {"wght": WEIGHT}, inplace=True, updateFontNames=True
    )

    wanted = jis_x0208_chars() | extra_chars() | project_text_chars()
    print(f"  subset target: {len(wanted)} chars")

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.drop_tables += ["DSIG"]
    options.recalc_bounds = True
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=[ord(c) for c in wanted])
    subsetter.subset(font)

    OUT_FONT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT_FONT)
    OUT_LICENSE.write_text(license_text, encoding="utf-8", newline="\n")

    size = OUT_FONT.stat().st_size
    print(f"wrote {OUT_FONT.relative_to(ROOT)} ({size / 1024:.0f} KB)")
    print(f"wrote {OUT_LICENSE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
