class_name ViewportCapture
extends Node

## 指定した経過秒で画面を PNG に落とす開発用の道具。
##
## 見た目を詰めるにはレンダリング結果そのものを見る必要があるが、
## ゲーム窓は動き続けていて手元では止められない。
## `--shots=<出力先> --shot-at=2,10,30` で任意の時刻の絵を取り出す。

var output_dir := ""
## 起動からの秒数。昇順に並べておくこと。
var schedule: Array[float] = []

var _elapsed := 0.0
var _next := 0


static func create(dir: String, times: Array[float]) -> ViewportCapture:
	var capture := ViewportCapture.new()
	capture.name = "ViewportCapture"
	capture.output_dir = dir
	capture.schedule = times
	return capture


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)


func _process(delta: float) -> void:
	_elapsed += delta
	if _next >= schedule.size() or _elapsed < schedule[_next]:
		return
	var at := schedule[_next]
	_next += 1
	_capture(at)


func _capture(at: float) -> void:
	# 描画が終わったフレームを掴む。同フレーム内で読むと 1 枚前の絵が出る。
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	# ミリ秒で名前を付ける。転がりや崩れは 0.05 秒刻みで連写しないと見えないので、
	# 秒で丸めるとファイル名が衝突する。
	var path := "%s/shot_%06dms.png" % [output_dir, int(round(at * 1000.0))]
	var error := image.save_png(path)
	if error != OK:
		push_error("スクリーンショットの保存に失敗: %s (%d)" % [path, error])
		return
	print("[capture] %s" % path)
