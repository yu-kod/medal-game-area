class_name PlayerState
extends RefCounted

## セッションを跨いで残るもの(設計書 §12)。
##
## **手持ちのメダルはここに入れない。** 設計書 §12 の PlayerState に項目が無く、
## §8 が「セッションを跨いで残る唯一の永続資産」は預かりメダルだと定めている。
## 手持ちが毎回消えることが、預かりと失効という仕組みが要る理由そのもの。
## §7.3 の「残高は常にゼロ付近を推移する」もここに乗っている。
##
## いま実際に持っているのは現金と来店日だけ。
## xp / xp_tier / stored_medals / prizes / daily_work_remaining は
## それぞれの担当チケットで足す。**項目が増えても古いセーブは読める**ように、
## 欠けている項目は既定値で埋める。

## セーブ形式の版。形を変えたときに古いセーブだと気づけるようにする。
const VERSION := 1

const SECONDS_PER_DAY := 86400

## クリッカーで稼いだ現金。
var cash := 0
## 最終来店の Unix 時刻。0 は未訪問。預かりメダルの失効判定に使う。
var stored_last_visit := 0


## 書き出す形。**手持ちメダルの項目は作らない。**
func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"cash": cash,
		"stored_last_visit": stored_last_visit,
	}


## 読み込む。外から来た壊れたデータが相手なので、何を渡されても落ちない。
##
## 起動できないより初期値で始まるほうがましなので、
## 読めない項目は黙って既定値にする。
static func from_dict(data: Dictionary) -> PlayerState:
	var state := PlayerState.new()
	state.cash = _read_int(data, "cash")
	state.stored_last_visit = _read_int(data, "stored_last_visit")
	return state


## 来店を記録する。**時刻は外から渡す。**
## Time を直接呼ぶと日付の絡む挙動を決定的にテストできなくなる。
func stamp_visit(now_unix: int) -> void:
	stored_last_visit = now_unix


## 最終来店からの経過日数。
##
## 未訪問(0)は 0 日として扱う。1970 年からの経過日数にすると、
## 初回起動でいきなり失効判定が走ってしまう。
## 時計が巻き戻された場合も負にはしない。
func days_since_visit(now_unix: int) -> int:
	if stored_last_visit <= 0:
		return 0
	return maxi(0, (now_unix - stored_last_visit) / SECONDS_PER_DAY)


## 数値として読めるものだけ受け取る。負の値は 0 に丸める。
##
## JSON.parse_string は数値をすべて float で返すので int を通す。
## 文字列や null が入っていても既定値に倒す。
static func _read_int(data: Dictionary, key: String) -> int:
	if not data.has(key):
		return 0
	var value: Variant = data[key]
	if not (value is int or value is float):
		return 0
	return maxi(0, int(value))
