class_name ArcadeMachine
extends Node3D

## 店内に置ける台 1 台の最小限の契約。
##
## 意図的に薄い。2 台目(クレーン / スロット)が実在するまで抽象化を広げないこと。
## 1 台しか無い状態で設計したインタフェースは必ず外す。
##
## 今ここにあるのは「メダルを入れる」「メダルが出る」という、
## メダルコーナーの台すべてに共通する部分だけ。

## 台が払い出したメダルの枚数。財布側はこれだけを見る。
signal medals_paid_out(count: int)
## 台がメダルを飲み込んだ枚数。投入が受理されたときに発火する。
signal medals_consumed(count: int)

## 筐体に貼られた台名。店内で並べたときの識別に使う。
var machine_name := "台"
## メダル 1 枚あたりのレート(設計書 12 章の denomination)。
var denomination := 1


## メダルを 1 枚投入する。受理されたら true。
## lane は投入位置の左右指定で、-1.0(左端)〜 1.0(右端)に正規化してある。
## 台によって意味が違う(プッシャーはシュート位置、スロットは無視)。
func insert_medal(_lane := 0.0) -> bool:
	return false


## プレイヤーがこの台の前に立ったときのカメラ位置と注視点。
## 店内移動(Phase 3)が入るまでは main がこれを直接使う。
func view_anchor() -> Transform3D:
	return Transform3D.IDENTITY
