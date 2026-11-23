# Wenku8 Flutter Fork —— Android 模拟器构建 / 安装 / 打开 driver
# 用法见同目录 SKILL.md。仅覆盖"拉取 APK + 启动模拟器 + 安装 / 打开"授权操作，
# 不包含点击、滑动等设备功能测试。
#
# 参数：
#   -NoBuild     跳过 Flutter 构建，复用 build/app/outputs/flutter-apk/app-debug.apk
#   -Emulator    目标 AVD id（默认 Wenku8_API_36；已在线设备优先）
#   -SkipHead    不输出 HEAD（用于纯文档场景，一般不需要）

param(
    [switch]$NoBuild,
    [string]$Emulator = 'Wenku8_API_36',
    [switch]$SkipHead
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
# 说明：$PSScriptRoot = <repo>/.agents/skills/run-wenku8，上溯三层回到 <repo>
$apk  = Join-Path $repo 'build/app/outputs/flutter-apk/app-debug.apk'
$shotDir = Join-Path $repo '.tmp/verification/run-wenku8'

function Get-AdbSerial([string]$fallback) {
    $out = & adb devices 2>$null
    foreach ($line in $out) {
        if ($line -match '^(emulator-\d+|\S+)\s+device$') { return $Matches[1] }
    }
    # 没有得到或静默失败，用 fallback（启动模拟器时通常是第一次出现）
    return $fallback
}

function Wait-Boot([string]$serial, [int]$timeoutSec = 240) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    do {
        Start-Sleep -Seconds 3
        $boot = (& adb -s $serial shell getprop sys.boot_completed 2>$null) -join '' | Out-String
        if ($boot -match '1') { return }
    } while ((Get-Date) -lt $deadline)
    throw "模拟器 $serial boot 超时（${timeoutSec}s）"
}

# 0) 基线提示：构建 / 安装前按项目规则确认真实目标与来源
if (-not $SkipHead) {
    Push-Location $repo
    Write-Host "repo : $repo"
    Write-Host "HEAD : $(& git rev-parse HEAD)"
    Write-Host "status: $((& git status --short) -join ' | ')"
    Write-Host "请核对已与 origin/master 同步；APK 属 Debug 非正式签名，安装前确认包名与签名。"
    Pop-Location
}

# 1) 设备：优先在线设备，否则启动模拟器
$serial = Get-AdbSerial 'emulator-5554'
$online = & adb -s $serial get-state 2>$null | Out-String
if ($online.Trim() -ne 'device') {
    Write-Host "无在线设备，启动模拟器 $Emulator ..."
    & flutter emulators --launch $Emulator 2>$null | Out-Null
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 2
        $serial = Get-AdbSerial $serial
        $online = (& adb -s $serial get-state 2>$null | Out-String).Trim()
        if ($online -eq 'device') { break }
    }
    if ($online -ne 'device') { throw '模拟器未能上线（adb 未发现 device）' }
}
Write-Host "设备 : $serial ($((& adb -s $serial shell getprop ro.product.cpu.abi) -join '' | Out-String).Trim())"

# 2) 等待系统启动完成
Wait-Boot $serial

# 3) 构建（可选）
if (-not $NoBuild) {
    $abi = (& adb -s $serial shell getprop ro.product.cpu.abi 2>$null | Out-String).Trim()
    $target = if ($abi -match 'arm64') { 'android-arm64' } else { 'android-x64' }
    Write-Host "构建 x64 debug APK（target=$target）..."
    Push-Location $repo
    & flutter build apk --debug --target-platform $target --no-pub
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'flutter build apk 失败' }
    Pop-Location
} else {
    if (-not (Test-Path $apk)) { throw "未找到 $apk，且启用了 -NoBuild" }
}

# 4) 安装
Write-Host "安装 $apk ..."
& adb -s $serial install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'adb install 失败' }

# 5) 解析入口并打开（applicationId 与 activity 因 flavor 变化，动态解析）
$pkg = ((& adb -s $serial shell pm list packages 2>$null) -split "`n" |
    ForEach-Object { ($_ -replace '^package:', '').Trim() } |
    Where-Object { $_ -match 'wenku' } |
    Select-Object -First 1)
if (-not $pkg) { throw '未找到已安装的 wenku 包名' }
$resolved = (& adb -s $serial shell cmd package resolve-activity --brief `
    -a android.intent.action.MAIN -c android.intent.category.LAUNCHER $pkg 2>$null) -split "`n"
$component = ($resolved | Where-Object { $_ -match '\S/\S' } | Select-Object -Last 1).Trim()
if (-not $component) { throw "未解析到启动 activity（来自 $pkg）" }
Write-Host "入口 : $component"
& adb -s $serial shell am start -n $component
if ($LASTEXITCODE -ne 0) { throw 'am start 失败' }

# 6) 等应用窗口起来并截图
Write-Host "等待应用首屏渲染 ..."
Start-Sleep -Seconds 8
$pidf = (& adb -s $serial shell pidof $pkg 2>$null | Out-String).Trim()
Write-Host "进程 : $pidf"
if (-not $pidf) { Write-Warning 'pidof 未返回，应用可能未保持前台或进程名与包名不同' }

if (-not (Test-Path $shotDir)) { New-Item -ItemType Directory -Path $shotDir | Out-Null }
$shot = Join-Path $shotDir ("launch-$((Get-Date -Format 'yyyyMMdd-HHmmss')).png")
# PowerShell 管道会把 native stdout 当文本而非原始字节，用 cmd 重定向保留 PNG 二进制
cmd /c "adb -s `"$serial`" exec-out screencap -p > `"$shot`" 2>&1"
if (-not (Test-Path $shot)) { throw '截图命令未生成文件' }
Write-Host "截图 : $shot ($((Get-Item $shot).Length) bytes)"