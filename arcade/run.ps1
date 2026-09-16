# 台を起動する。既定は手で遊ぶ状態(自動投入なし・計器なし)。
#
#   .\run.ps1                      窓を開けて手で遊ぶ
#   .\run.ps1 -Debug               左上に検証用の計器を出す(-Dev も同じ)
#   .\run.ps1 -Demo                自動投入を回して放置観察する
#   .\run.ps1 -Stations 6          6 席の島にする(既定は 4 席)
#   .\run.ps1 -Shots C:\out -At 5,40,120   指定秒でスクリーンショットを撮る
#   .\run.ps1 -Seconds 60          60 秒で自動終了
#
# 挙動を詰めるときは -Debug -Demo を並べる。これが従来の放置観察モード。
#
# 新しい class_name を追加したあとは -Import を付けて 1 度起動すること。
# グローバルクラスの登録が更新されないと "Identifier not declared" で落ちる。

param(
    [switch]$Import,
    [Alias("Debug")][switch]$Dev,
    [switch]$Demo,
    [int]$Seconds = 0,
    [int]$Credit = 0,
    [ValidateSet(0, 4, 6)][int]$Stations = 0,
    [string]$Shots = "",
    [string]$At = "",
    [string]$Cam = "",
    [string]$Look = "",
    [double]$Fov = 0,
    [string]$Resolution = "1600x900"
)

$ErrorActionPreference = "Stop"
$godot = "C:\Users\yukku\tools\godot\Godot_v4.7.1-stable_win64_console.exe"
$project = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $godot)) { throw "Godot が見つからない: $godot" }

if ($Import) {
    & $godot --path $project --headless --import
}

$userArgs = @()
if ($Dev)            { $userArgs += "--debug" }
if ($Demo)           { $userArgs += "--demo" }
if ($Seconds -gt 0)  { $userArgs += "--seconds=$Seconds" }
if ($Credit -gt 0)   { $userArgs += "--credit=$Credit" }
if ($Stations -gt 0) { $userArgs += "--stations=$Stations" }
if ($Shots -ne "")   { $userArgs += "--shots=$Shots" }
if ($At -ne "")      { $userArgs += "--shot-at=$At" }
if ($Cam -ne "")     { $userArgs += "--cam=$Cam" }
if ($Look -ne "")    { $userArgs += "--look=$Look" }
if ($Fov -gt 0)      { $userArgs += "--fov=$Fov" }

& $godot --path $project --resolution $Resolution -- @userArgs
