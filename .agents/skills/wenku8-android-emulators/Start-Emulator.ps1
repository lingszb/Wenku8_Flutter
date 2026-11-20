#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [ValidateSet('Agent', 'Review')]
    [string]$Mode,
    [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'
$env:ANDROID_HOME = 'D:\Android\Sdk'
$env:ANDROID_AVD_HOME = 'D:\Android\Avd'
$sdk = $env:ANDROID_HOME
$adb = Join-Path $sdk 'platform-tools/adb.exe'
$emulator = Join-Path $sdk 'emulator/emulator.exe'
$manager = Join-Path $sdk 'cmdline-tools/latest/bin/avdmanager.bat'
$image = 'system-images;android-36;default;x86_64'

$profile = switch ($Mode) {
    'Agent' { @{ Name = 'Wenku8_Agent_API36'; Port = 5560; Cores = 4; Ram = 3072; Disk = 16; Width = 720; Height = 1600; Density = 280; Hertz = 60 } }
    'Review' { @{ Name = 'Wenku8_Review_API36'; Port = 5562; Cores = 4; Ram = 4096; Disk = 32; Width = 1080; Height = 2400; Density = 420; Hertz = 120 } }
}
$name = $profile.Name
$serial = "emulator-$($profile.Port)"
$config = Join-Path $env:ANDROID_AVD_HOME "$name.avd/config.ini"
$settings = [ordered]@{
    'abi.type' = 'x86_64'
    'image.sysdir.1' = 'system-images\android-36\default\x86_64\'
    'PlayStore.enabled' = 'no'
    'hw.cpu.ncore' = $profile.Cores
    'hw.ramSize' = $profile.Ram
    'disk.dataPartition.size' = "$($profile.Disk)G"
    'hw.gpu.enabled' = 'yes'
    'hw.gpu.mode' = 'host'
    'hw.lcd.width' = $profile.Width
    'hw.lcd.height' = $profile.Height
    'hw.lcd.density' = $profile.Density
    'hw.lcd.vsync' = $profile.Hertz
    'hw.keyboard' = 'yes'
    'fastboot.forceColdBoot' = 'no'
    'fastboot.forceFastBoot' = 'yes'
}

foreach ($tool in @($adb, $emulator, $manager)) {
    if (!(Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Missing SDK tool: $tool" }
}
$devices = @(& $adb devices)
if ($LASTEXITCODE) { throw 'adb devices failed' }
foreach ($line in $devices) {
    if ($line -notmatch '^(emulator-\d+)\s+(\S+)') { continue }
    $device = $Matches[1]
    $state = $Matches[2]
    if ($state -ne 'device') {
        continue
    }
    $running = (& $adb -s $device emu avd name | Select-Object -First 1).Trim()
    if ($device -eq $serial -and $running -ne $name) { throw "$serial belongs to $running" }
    if ($running -eq $name -and $device -ne $serial) { throw "$name already runs on $device" }
}

if (!(Test-Path -LiteralPath $config)) {
    New-Item -ItemType Directory -Path $env:ANDROID_AVD_HOME -Force | Out-Null
    'no' | & $manager create avd --name $name --package $image --device pixel_7 | Out-Host
    if ($LASTEXITCODE -or !(Test-Path -LiteralPath $config)) { throw "Create AVD failed: $name" }
    $existing = @(Get-Content -LiteralPath $config | Where-Object { ($_ -split '=', 2)[0] -notin $settings.Keys })
    $existing + @($settings.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) |
        Set-Content -LiteralPath $config -Encoding utf8
}
$lines = Get-Content -LiteralPath $config
foreach ($key in $settings.Keys) {
    $matching = @($lines | Where-Object { ($_ -split '=', 2)[0] -eq $key })
    if ($matching.Count -ne 1 -or $matching[0] -cne "$key=$($settings[$key])") {
        throw "$name configuration differs at $key. Inspect $config before changing it."
    }
}
Write-Host "$Mode $name $serial ($config)"
if ($ConfigureOnly) { return }

if (!($devices -match "^$serial\s+")) {
    $arguments = @('-avd', $name, '-port', $profile.Port, '-gpu', 'host', '-no-boot-anim')
    if ($Mode -eq 'Agent') {
        $arguments += @('-no-window', '-no-audio', '-no-snapshot')
        Start-Process -FilePath $emulator -ArgumentList $arguments -WindowStyle Hidden
    } else {
        Start-Process -FilePath $emulator -ArgumentList $arguments
    }
}
$deadline = (Get-Date).AddMinutes(4)
do {
    $ready = & $adb -s $serial shell getprop sys.boot_completed 2>$null
    if ($ready -eq '1') {
        $running = (& $adb -s $serial emu avd name | Select-Object -First 1).Trim()
        if ($running -ne $name) { throw "$serial belongs to $running" }
        $runtime = Get-Content -LiteralPath (Join-Path (Split-Path $config) 'hardware-qemu.ini')
        foreach ($key in @('hw.cpu.ncore', 'hw.ramSize', 'disk.dataPartition.size', 'hw.gpu.mode',
                'hw.lcd.width', 'hw.lcd.height', 'hw.lcd.density', 'hw.lcd.vsync')) {
            $actual = @($runtime | Where-Object { ($_ -split '=', 2)[0].Trim() -eq $key })
            if ($actual.Count -ne 1 -or ($actual[0] -split '=', 2)[1].Trim() -ne "$($settings[$key])") {
                throw "$name runtime configuration differs at $key"
            }
        }
        $launch = Get-Content -LiteralPath (Join-Path (Split-Path $config) 'emu-launch-params.txt')
        if (($launch -contains '-no-window') -ne ($Mode -eq 'Agent')) {
            throw "$name window mode differs from $Mode"
        }
        & $adb -s $serial shell wm size
        & $adb -s $serial shell wm density
        & $adb -s $serial shell df -h /data
        return
    }
    Start-Sleep -Seconds 3
} while ((Get-Date) -lt $deadline)
throw "$name did not finish booting on $serial"
