class_name MedalSoundPicker
extends RefCounted

## 枚数から鳴らすメダル音を選ぶ。
##
## 設計書 §11 が要求している形。
##   「コイン落下音の多層サンプル(1枚 / 数枚 / 大量 の3系統をランダム選択)」
##
## 同じサンプルを鳴らし続けると即座に嘘だとバレるので、
## 系統ごとに直前の 1 つを覚えておいて避ける。
##
## 乱数は種を指定して持つ(グローバルの randi() は使わない)。
## 同じ種なら同じ順で鳴るので、挙動を再現しながら詰められる。

enum Layer { SINGLE, FEW, MANY }

## 「数枚」に切り替わる枚数。
const FEW_MIN := 2
## 「大量」に切り替わる枚数。山が崩れたときの枚数を目安にしている。
const MANY_MIN := 6

const ASSET_DIR := "res://assets/audio/medal"
const TRAY_DIR := "res://assets/audio/tray"

## ファイル名の接頭辞と系統の対応。docs/audio-credits.md の表と揃える。
const ASSET_PREFIXES := {
	Layer.SINGLE: "chips-collide",
	Layer.FEW: "chips-stack",
	Layer.MANY: "chips-handle",
}

## トレイの金属音も同じ「枚数で選ぶ」形に乗る。
## 1 枚なら軽く、山で出てきたら重い音になる。
const TRAY_PREFIXES := {
	Layer.SINGLE: "impactMetal_light",
	Layer.FEW: "impactMetal_medium",
	Layer.MANY: "impactMetal_heavy",
}

var _banks: Dictionary = {}
## 系統ごとに直前に鳴らしたもの。連続を避けるために覚える。
var _last: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(banks: Dictionary, seed_value: int = 20260916) -> void:
	_banks = banks
	_rng.seed = seed_value


## 枚数から系統を決める。
##
## 0 枚以下は「1 枚」に倒す。呼び出し側の数え間違いで音が消えるより、
## 1 枚ぶん鳴るほうがまし。
static func layer_for(count: int) -> Layer:
	if count >= MANY_MIN:
		return Layer.MANY
	if count >= FEW_MIN:
		return Layer.FEW
	return Layer.SINGLE


## 盤面のメダル音。
static func from_assets(seed_value: int = 20260916) -> MedalSoundPicker:
	return from_dir(ASSET_DIR, ASSET_PREFIXES, seed_value)


## 払い出しトレイの金属音。
static func from_tray_assets(seed_value: int = 20260916) -> MedalSoundPicker:
	return from_dir(TRAY_DIR, TRAY_PREFIXES, seed_value)


## 置いてある音源をファイル名の接頭辞で系統に振り分ける。
static func from_dir(dir: String, prefixes: Dictionary, seed_value: int) -> MedalSoundPicker:
	var banks := {}
	var names := DirAccess.get_files_at(dir)
	names.sort()  # 並びを固定しないと種を固定しても再現しない
	for layer in prefixes:
		var bank: Array[String] = []
		for file_name in names:
			# 取り込み後は .import が付くことがあるので拡張子で絞る
			if not file_name.ends_with(".ogg"):
				continue
			if file_name.begins_with(prefixes[layer]):
				bank.append("%s/%s" % [dir, file_name])
		banks[layer] = bank
	return MedalSoundPicker.new(banks, seed_value)


## この系統の音源一覧。
func bank(layer: Layer) -> Array:
	return _banks.get(layer, [])


## 枚数に合う音を 1 つ選ぶ。音源が無ければ空文字。
func pick(count: int) -> String:
	var layer := layer_for(count)
	var choices: Array = _banks.get(layer, [])
	if choices.is_empty():
		return ""
	# 1 つしか無い系統では「連続させない」を満たせない。素直にそれを返す。
	if choices.size() == 1:
		_last[layer] = choices[0]
		return choices[0]

	var previous: String = _last.get(layer, "")
	var chosen: String = choices[_rng.randi_range(0, choices.size() - 1)]
	if chosen == previous:
		# 直前と同じなら隣へずらす。引き直しではないのでループしない。
		var index := choices.find(chosen)
		chosen = choices[(index + 1) % choices.size()]
	_last[layer] = chosen
	return chosen
