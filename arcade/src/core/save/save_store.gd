class_name SaveStore
extends RefCounted

## セーブファイルの読み書き。
##
## 読むのは前回の自分が書いたとは限らないファイル。壊れていても、
## 途中で切れていても、人が手で書き換えていても、**起動できなくならないこと**を
## いちばんの条件にしている。読めなければ初期状態で始める。

const PATH := "user://player.json"
## 書き込み中に落ちても元のセーブを壊さないよう、いったんここへ出してから置き換える。
const TEMP_SUFFIX := ".tmp"


## 書き出す。成功したら true。
##
## 直接上書きすると、書いている途中で 電源 が落ちたときに
## 唯一のセーブが壊れる。一時ファイルに書き切ってから置き換える。
static func save(state: PlayerState, path := PATH) -> bool:
	var temp_path := path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("セーブを書けない: %s" % temp_path)
		return false
	file.store_string(JSON.stringify(state.to_dict(), "\t"))
	file.close()

	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	return dir.rename(temp_path.get_file(), path.get_file()) == OK


## 読み込む。無い・壊れている・形が違う場合はすべて初期状態。
static func load_state(path := PATH) -> PlayerState:
	if not FileAccess.file_exists(path):
		return PlayerState.new()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("セーブを読めない: %s" % path)
		return PlayerState.new()
	var text := file.get_as_text()
	file.close()

	# 壊れた JSON は null で返る。例外にはならない。
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("セーブの形が違う。初期状態で始める: %s" % path)
		return PlayerState.new()
	return PlayerState.from_dict(parsed)
