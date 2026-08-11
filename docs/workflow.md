# バイブコーディングの回し方

エディタ GUI を開かずに、**ファイルを書く → ヘッドレスで検証する**を繰り返す。
GUI 起動は見た目の最終確認に一度使えば足りることが多い。

## ループ

```sh
# 1. 書く      .gd → .tscn → project.godot の順が楽
# 2. 認識させる
bash tools/godot.sh import
# 3. 起動できるか
bash tools/godot.sh check
# 4. 意図どおり動くか（ここが本番）
bash tools/godot.sh verify res://_verify_player.gd
```

### 各段階で何が分かるか

| 段階 | 分かること | 分からないこと |
|---|---|---|
| `import` | アセット・`class_name` が登録された | 何も動くとは限らない |
| `check` | ロード時エラー、最初の数秒の実行時エラー | 挙動が正しいか、入力が繋がっているか、当たり判定が効くか |
| `verify` | 実際の座標・速度・状態遷移 | 見た目・色・シェーダ |
| `run` | 見た目と操作感 | （人間の目視が必要） |

**`check` が無言で通ったことを「完成」と報告しない。** Godot は壊れたシーンを黙って読み込む。

## 検証スクリプトの雛形

`SceneTree` を継承した使い捨てスクリプトをリポジトリ直下に `_verify_<対象>.gd` で置き、`verify` で回す。

```gdscript
extends SceneTree

var _t := 0.0
var _main: Node
var _rocket: RigidBody2D
var _done := {}

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/copy_main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)          # これを忘れると _ready() も物理も走らない
	_rocket = _main.get_node("Rocket")

# true を返すと終了する
func _process(delta: float) -> bool:
	_t += delta
	_at(1.0, func(): Input.action_press("thrust"))
	_at(1.1, func(): Input.action_release("thrust"))   # 連打式なので押しっぱなしでは 1 回しか効かない
	_at(2.0, func(): print("speed = %.2f" % _rocket.linear_velocity.length()))
	if _t >= 3.0:
		print("pos = %.2v" % _player.global_position)
		return true
	return false

func _at(mark: float, fn: Callable) -> void:
	if _t >= mark and not _done.has(mark):
		_done[mark] = true
		fn.call()
```

**使い終わったら `_verify_*.gd` と一緒に生成される `.gd.uid` を消す。**（gitignore 済みだが残骸を放置しない）

### 落とし穴

- **`_initialize()` の中で `await` しない。** コルーチンが保持されず再開しないため、最初の `print` だけ出て無言で終わる。フレーム進行は `_process()` に書く。
- **フレーム数 ≠ 秒数。** ヘッドレスは vsync 無しで実速度より速く回る（140fps 超）。時間依存の検証は `delta` を積算して秒で判定する。
- **`root.add_child()` を忘れない。**
- 終了時の `ObjectDB instances were leaked` 警告は無害（検証スクリプトが後始末していないだけ）。
- `Input.action_press()` はヘッドレスでも `project.godot` の `[input]` 定義を実際に経由する。**アクション名の綴り間違いはこれで捕まる。**

## 何を数値で確認するか

| 確かめたいこと | 見る値 |
|---|---|
| 床に正しく乗っているか | 静止後の `global_position.y` が形状の半径/高さと一致するか |
| 入力が繋がっているか | `Input.action_press()` の前後で速度・位置が変化するか |
| 移動方向が正しいか | 噴射で `y` が**減る**か（2D は上が負。**符号**を確認） |
| 上限速度が効いているか | 十分加速させた後の水平速度が設定値でクランプされるか |
| 当たり判定が働くか | `Area` に触れさせて対象が消えたか（子ノード数の減少） |
| 壁で止まるか | 押し付け続けた後の座標と、その間の `y` の最大値（摩擦でよじ登ることがある） |
| UI 文字列 | `Label.text` をそのまま print（書式指定子と日本語の確認になる） |
| 復帰処理 | 場外座標へ飛ばして一定時間後に戻っているか |

## 作業の粒度

- **1 タスク = 1 機能 = 1 コミット。** ジャム中は特に、大きな変更を溜めない（[team-rules.md](team-rules.md)）。
- 実装前に、触るファイルを宣言してから書き始める（他メンバーとの衝突は着手前にしか防げない）。
- 実装が終わったら **`check` + `verify` の出力を報告に貼る。** 「たぶん動く」で渡さない。

## 見た目の確認

ヘッドレスは dummy レンダラなので描画結果は得られない。色・レイアウト・シェーダを見たいときだけ:

```sh
bash tools/godot.sh run
```

レイアウト以外の大半はヘッドレスで詰められるので、GUI 起動は最後に一度で足りる。
