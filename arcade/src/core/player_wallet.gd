class_name PlayerWallet
extends RefCounted

## プレイヤーの手持ち。
##
## 設計書 6.1 の核心: メダルは現金に戻せない。逆両替の関数はここに絶対に生やさない。
## 現金・XP・預かりメダルは経済を組む Phase 2 で足す。今はメダルだけ。

signal medals_changed(medals: int)

var _medals := 0


func medals() -> int:
	return _medals


## 台に 1 枚入れる。手持ちが無ければ false。
func spend_medal() -> bool:
	if _medals <= 0:
		return false
	_medals -= 1
	medals_changed.emit(_medals)
	return true


## 台から出たぶんを受け取る。
func add_medals(count: int) -> void:
	if count <= 0:
		return
	_medals += count
	medals_changed.emit(_medals)
