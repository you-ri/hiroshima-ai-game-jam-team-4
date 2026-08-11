class_name Units
## 単位変換ユーティリティ（どのシーンにも属さない共通コード）。
## docs/Spec.txt は m 単位、ワールドは px 単位。
## 「ゴールは 3000m」と「6 画面上部に達するとクリア」（720px × 6 = 4320px）を
## 同時に満たすよう、1m = 1.44px（= 4320 / 3000）と定義する。

const PIXELS_PER_METER := 1.44

## 設計解像度（project.godot の display/window/size と一致させる）
const DESIGN_WIDTH := 1280.0
const DESIGN_HEIGHT := 720.0


static func m_to_px(meters: float) -> float:
	return meters * PIXELS_PER_METER


static func px_to_m(pixels: float) -> float:
	return pixels / PIXELS_PER_METER
