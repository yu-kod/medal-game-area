# CI と同じ検査をローカルで回す。
#
#   .\scripts\check.ps1              全部(format:check → lint → import → test)
#   .\scripts\check.ps1 -Fix         先に gdformat をかけてから全部
#   .\scripts\check.ps1 -Only lint   1 つだけ回す(format / lint / import / test)
#
# CI が実行するコマンドはこのスクリプトと同じものにしてある。
# 片方だけ直すと必ずズレるので、検査を足すときは .github/workflows/ci.yml も一緒に直すこと。
#
# このファイルは UTF-8 BOM 付きで保存すること。
# Windows PowerShell 5.1 は BOM が無いと ANSI として読み、日本語が化けて構文エラーになる。

param(
    [switch]$Fix,
    [ValidateSet("", "format", "lint", "import", "test")][string]$Only = ""
)

# 外部コマンドの stderr で止めない。合否は $LASTEXITCODE で自分で見る。
# Stop のままだと PowerShell 5.1 が native の stderr を NativeCommandError に変えてしまう。
$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $PSScriptRoot

# gdtoolkit を持っている python を探す。
# PATH の python が Microsoft Store のスタブなことがあるので、実際に import できるかで選ぶ。
function Find-Python {
    $candidates = @()
    if ($env:PYTHON) { $candidates += $env:PYTHON }
    $candidates += "python"
    $candidates += "py"
    Get-ChildItem "$env:LOCALAPPDATA\Python\*\python.exe" -ErrorAction SilentlyContinue |
        ForEach-Object { $candidates += $_.FullName }

    foreach ($candidate in $candidates) {
        & $candidate -c "import gdtoolkit" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { return $candidate }
    }
    return $null
}

$python = Find-Python
$godot = if ($env:GODOT) { $env:GODOT } else { "C:\Users\yukku\tools\godot\Godot_v4.7.1-stable_win64_console.exe" }

# gdformat / gdlint をかける範囲。addons は外部のコードなので触らない。
$sources = @("arcade/src", "arcade/tests", "phase0-pusher/src")

$failed = @()

function Invoke-Step {
    param([string]$Name, [scriptblock]$Body)
    if ($Only -ne "" -and $Only -ne $Name) { return }
    Write-Host ""
    Write-Host "--- ${Name} ---" -ForegroundColor Cyan
    & $Body
    if ($LASTEXITCODE -ne 0) {
        $script:failed += $Name
        Write-Host "${Name}: NG" -ForegroundColor Red
    } else {
        Write-Host "${Name}: OK" -ForegroundColor Green
    }
}

Push-Location $repo
try {
    if (-not $python) {
        throw "gdtoolkit を入れた python が見つからない。python -m pip install gdtoolkit==4.* を実行するか、環境変数 PYTHON でパスを指定する"
    }
    if (-not (Test-Path $godot)) {
        throw "Godot が見つからない: $godot / 環境変数 GODOT で場所を指定できる"
    }

    if ($Fix) {
        Write-Host ""
        Write-Host "--- gdformat ---" -ForegroundColor Cyan
        & $python -m gdtoolkit.formatter @sources
    }

    Invoke-Step "format" { & $python -m gdtoolkit.formatter --check @sources }
    Invoke-Step "lint"   { & $python -m gdtoolkit.linter @sources }

    # クリーンな状態には .godot/ が無く、グローバルクラスが未登録で
    # "Identifier not declared" になる。テストの前に必ず通すこと。
    Invoke-Step "import" {
        & $godot --path arcade --headless --import | Out-Null
        & $godot --path phase0-pusher --headless --import | Out-Null
    }

    Invoke-Step "test" {
        & $godot --path arcade --headless `
            -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd `
            --ignoreHeadlessMode -a res://tests
    }

    Write-Host ""
    if ($failed.Count -gt 0) {
        Write-Host ("失敗: " + ($failed -join ", ")) -ForegroundColor Red
        exit 1
    }
    Write-Host "すべて通った" -ForegroundColor Green
} finally {
    Pop-Location
}
