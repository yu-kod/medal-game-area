class_name PlayerWallet
extends RefCounted

## プレイヤーの手持ち。
##
## 設計書 6.1 の核心: メダルは現金に戻せない。逆両替の関数はここに絶対に生やさない。
##
## 現金とメダルを同じ器で持っているが、値が動く向きは**現金 → メダルの一方通行だけ**。
## 現金を減らす口は spend_cash() しかなく、メダルを現金に変える口は存在しない。
## player_wallet_test.gd の test_wallet_has_no_way_back_to_cash が見張っている。
## XP・預かりメダルはまだ無い。

signal medals_changed(medals: int)
signal cash_changed(cash: int)

var _medals := 0
var _cash := 0


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


func cash() -> int:
	return _cash


## クリッカー等で稼いだぶんを受け取る。
func add_cash(amount: int) -> void:
	if amount <= 0:
		return
	_cash += amount
	cash_changed.emit(_cash)


## メダルの購入で支払う。足りなければ何も動かさず false。
##
## **これが現金を減らす唯一の口。** 逆向き(メダル → 現金)は作らない。
func spend_cash(amount: int) -> bool:
	if amount <= 0 or amount > _cash:
		return false
	_cash -= amount
	cash_changed.emit(_cash)
	return true
