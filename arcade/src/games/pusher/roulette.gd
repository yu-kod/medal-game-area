class_name Roulette
extends Node

## チェッカーを通ったメダルで回る抽選。
##
## 流れは実機と同じ順序にしてある。
##   1. メダルがチェッカーを通過 → 保留が 1 つ溜まる
##   2. 保留を 1 つ消化する。**この瞬間に当落が決まる**
##   3. リールが回り、決まっている結果に向けて演出が出て、そこで止まる
##
## 回っているあいだに結果を探すのではなく、先に決めてから見せる。
## 実機の抽選もこの順序で、リールの動きは決まった結果の表示でしかない。
##
## 設計書 5 章が禁じているのは「還元率を確率で作ること」であって、抽選そのものではない。
## 盤面の払い出しは形状だけで決まっており、ここの乱数はそちらに一切触れない。
## 獲得量の調整はこの確率表でやる。

signal stock_changed(stock: int)
## 抽選が始まった。結果はこの時点で確定している。
signal spin_started(outcome: int)
## リールが止まって結果が確定表示された。
signal spin_finished(outcome: int, reward: int)

enum Outcome { LOSE, SMALL, BIG, JACKPOT }

## 保留の上限。実機のランプの数に合わせる。
const STOCK_MAX := 6

## 抽選表。重みと配当枚数。
## 獲得量の調整はここでやる。盤面の形状には触らない。
const TABLE := [
	{"outcome": Outcome.LOSE, "weight": 820, "reward": 0},
	{"outcome": Outcome.SMALL, "weight": 150, "reward": 10},
	{"outcome": Outcome.BIG, "weight": 28, "reward": 60},
	{"outcome": Outcome.JACKPOT, "weight": 2, "reward": 400},
]

## ドラムが回っている時間。3 本を順に止めるので、単発のリールより長く取る。
const SPIN_SEC := 2.8
## 止まってから次の抽選に移るまでの間。当たりのときは長めに見せる。
const HOLD_SEC := 1.1
const HOLD_SEC_WIN := 2.6

var stock := 0
var spinning := false
var last_outcome := Outcome.LOSE

var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _hold := 0.0
var _pending_reward := 0


func _init(seed_value: int = 20260816) -> void:
	_rng.seed = seed_value


## チェッカーを 1 枚通過した。
func add_stock() -> void:
	if stock >= STOCK_MAX:
		return
	stock += 1
	stock_changed.emit(stock)


func _process(delta: float) -> void:
	if spinning:
		_timer -= delta
		if _timer <= 0.0:
			_finish()
		return

	if _hold > 0.0:
		_hold -= delta
		return

	if stock > 0:
		_start()


## 保留を 1 つ消化して抽選する。当落はここで決まる。
func _start() -> void:
	stock -= 1
	stock_changed.emit(stock)

	var entry := _draw()
	last_outcome = entry["outcome"]
	_pending_reward = entry["reward"]
	spinning = true
	_timer = SPIN_SEC
	spin_started.emit(last_outcome)


func _finish() -> void:
	spinning = false
	_hold = HOLD_SEC_WIN if _pending_reward > 0 else HOLD_SEC
	spin_finished.emit(last_outcome, _pending_reward)
	_pending_reward = 0


func _draw() -> Dictionary:
	var total := 0
	for entry in TABLE:
		total += int(entry["weight"])
	var roll := _rng.randi_range(1, total)
	for entry in TABLE:
		roll -= int(entry["weight"])
		if roll <= 0:
			return entry
	return TABLE[0]
