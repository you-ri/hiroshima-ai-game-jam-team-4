class_name ScoreBoard
## 最終スコアの受け渡し用（Autoload を使わない静的置き場）。
## docs/Spec.txt の Point セクションの内訳を 1 回分だけ保持し、
## クリア／ゲームオーバー画面から読めるようにする。

static var total := 0
static var time_score := 0
static var lives_score := 0
static var item_score := 0
static var special_score := 0
static var cleared := false


static func store(new_total: int, new_time: int, new_lives: int, new_items: int,
		new_special: int, is_clear: bool) -> void:
	total = new_total
	time_score = new_time
	lives_score = new_lives
	item_score = new_items
	special_score = new_special
	cleared = is_clear
