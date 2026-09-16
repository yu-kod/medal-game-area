class_name MedalShop
extends RefCounted

## メダル購入の段階レート(設計書 §6.2)。
##
## 連続レートではなく離散的な購入オプションとして出す。これにより
## 「金がない者ほど単価が高い」状況が自然に生まれる。
##
## **1200 円の段が設計上の核心。**
## 端数かつ追加分の単価が突出して安いため、1000 円を選ぼうとした瞬間に強い引力が働く。
## 実際のメダルコーナーにもこうした歪んだ段が必ず存在するので、リアリティも同時に満たす。
## この歪みが消えると購入画面は体験装置として死ぬ。
## medal_shop_test.gd の test_the_1200_yen_step_is_the_sweetest_deal が見張っている。
##
## **画面には金額と枚数しか出さないこと。** 単価も追加分単価も表示しない。
## プレイヤーが自分で割り算に気づくのが正しい(設計書 §6.2)。

## 購入できる段。調整はここだけでやる。UI 側に数値を書かない。
const OPTIONS := [
	{"yen": 100, "medals": 15},
	{"yen": 500, "medals": 90},
	{"yen": 1000, "medals": 200},
	# ↓ 追加分 200 円で 100 枚。1 枚あたり 2.0 円で全段中もっとも安い。
	{"yen": 1200, "medals": 300},
	{"yen": 3000, "medals": 900},
	{"yen": 5000, "medals": 1700},
]


## 1 段ぶん買う。買えなければ何も動かさずに false。
##
## 現金とメダルは**必ず両方**動くか、どちらも動かないかのどちらか。
## 片方だけ動く状態を作らない。
static func purchase(wallet: PlayerWallet, option_index: int) -> bool:
	if option_index < 0 or option_index >= OPTIONS.size():
		return false
	var option: Dictionary = OPTIONS[option_index]
	if not wallet.spend_cash(option["yen"]):
		return false
	wallet.add_medals(option["medals"])
	return true


## いまの所持金で買える段の添字。UI の出し分けに使う。
static func affordable_indices(cash: int) -> Array[int]:
	var indices: Array[int] = []
	for index in OPTIONS.size():
		if int(OPTIONS[index]["yen"]) <= cash:
			indices.append(index)
	return indices
