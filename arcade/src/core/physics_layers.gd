class_name PhysicsLayers
extends RefCounted

## 物理レイヤの割り当て。台をまたいで共通なのでここに集約する。
##
## 台ごとに勝手な番号を振ると、複数台を同じシーンに並べた瞬間に破綻する。

## 台の静的形状(床・壁・筐体)。
const FIELD := 1 << 0
## メダル本体。
const MEDAL := 1 << 1
## 動く機構(プッシャー盤、クレーンのアームなど)。
const MECHANISM := 1 << 2
## 落下検出の Area3D。メダルだけを見る。
const SINK := 1 << 3

## メダルが衝突する相手。Area3D(SINK)は衝突ではなく検出側から見るので含めない。
const MEDAL_MASK := FIELD | MEDAL | MECHANISM
