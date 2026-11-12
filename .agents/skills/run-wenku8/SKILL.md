---
name: run-wenku8
description: 构建、启动并驱动本项目 Android 应用时使用。当被要求运行 app、启动/截图 UI、验证改动在模拟器或设备上的实际表现时加载。通过 .agents/skills/run-wenku8/driver.ps1 在 Android 模拟器上构建、安装、打开并截图应用。
---

# 运行与驱动 Wenku8 Flutter（Android）

本仓库是 Android 为主的 Flutter 应用（包名见下方），无 Windows / Web 宿主工程。标准路径：开启模拟器 → 构建 Debug APK → 安装 → 打开入口 → 截屏确认首屏。使用 PowerShell 7（`pwsh`）执行；本 driver 已在 pwsh 7.6 验证。

授权边界：本 skill 只覆盖"拉取 APK + 启动模拟器 + 安装 / 打开 APK"。点击、滑动、导入、保存、分享、语音等设备功能测试需用户显式授权，driver 不含这些操作。

## Prerequisites

本机已就绪（Windows）：Flutter SDK、Android SDK（含 `platform-tools` 的 `adb`）、至少一个 AVD。现场用 `flutter --version`、`flutter emulators` 核对。仓库已有 `.githooks` pre-push 检查。

## Baseline（构建 / 安装 / 交付必做）

```sh
# 在仓库根目录执行
git fetch --prune origin
git rev-parse HEAD && git status --short
# 对 master 构建前，落后则：git switch master && git pull --ff-only 后再次 rev-parse 核对
```

## Run（agent 路径）

首选直接运行 driver，一条命令完成 模拟器（无则启动）→ 构建 → 安装 → 打开 → 截图：

```powershell
# 主工作树：完整流程（构建 x64 debug APK 依赖设备 ABI，见下）
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/run-wenku8/driver.ps1

# 复用上次构建产物，跳过构建（APK 必须是当前基线下构建）
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/run-wenku8/driver.ps1 -NoBuild

# 指定其他 AVD
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/run-wenku8/driver.ps1 -Emulator Wenku8_API_36_32G
```

driver 会打印 repo、HEAD、`git status --short`、设备、入口组件，并通过 `pidof` 确认进程存活；截图落到 `.tmp/verification/run-wenku8/launch-<时间戳>.png`。**读完截图确认首屏渲染，空白 / 错误页 = 失败。**

## Run（agent 手工路径）

同一条折不进 driver 时手工执行（已在本机验证通过）：

```powershell
# 1. 模拟器：无在线设备时启动；x86_64 模拟器对应 android-x64
flutter emulators --launch Wenku8_API_36
adb wait-for-device
# 轮询直到 getprop sys.boot_completed = 1（模拟器 1-3 分钟）
adb shell getprop sys.boot_completed

# 2. 构建（模拟器 x86_64；ARM64 真机改用 android-arm64）
flutter build apk --debug --target-platform android-x64 --no-pub
#   产物：build/app/outputs/flutter-apk/app-debug.apk

# 3. 安装 & 打开。入口组件动态解析：
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER org.mewx.wenku8_flutter
#   本机当前（source_preview flavor）解析为：
#   org.mewx.wenku8_flutter.source_preview/org.mewx.wenku8_flutter.MainActivity
adb shell am start -n org.mewx.wenku8_flutter.source_preview/org.mewx.wenku8_flutter.MainActivity

# 4. 确认进程存活并截图
adb shell pidof org.mewx.wenku8_flutter
adb exec-out screencap -p > .tmp/verification/run-wenku8/launch.png
```

包名来自 `android/app/build.gradle.kts` 的 `applicationId` 分支（`io.github.lingszb.wenku8.localreader` vs `org.mewx.wenku8_flutter` + flavor 后缀），**不要硬编码 wenku8_flutter**——每次用 resolve-activity 解析真实入口。

## Build / Test

```powershell
flutter pub get            # 依赖变化时
dart format --output=none --set-exit-if-changed <变更的 dart 文件>
flutter analyze lib test --no-pub --no-fatal-infos
flutter test --no-pub
```

## Gotchas

- **统一用 `pwsh`（PowerShell 7）调用 driver**：`powershell` 5.1 会把脚本按 ANSI 读，中文与引号错位（还可能导致解析失败）；pwsh 7 输出正常。
- **包名不是 `wenku8_flutter`**：装出来的是 `org.mewx.wenku8_flutter.source_preview`（本次），入口组件随 flavor 变。直接用 `am start -n wenku8_flutter/.MainActivity` 报 `Error type 3`。
- **`adb shell screencap -p <file>` 参数会被吞**：用法帮助里出现 `usage: screencap` 就是参数没传进。改用 `adb exec-out screencap -p > file`。
- **ABI 决定构建目标**：x86_64 模拟器用 `--target-platform android-x64`；ARM64 真机用 `android-arm64`。Debug APK 非正式签名，不能覆盖正式发行包。
- **构建前必须核对基线**：本分支落后 `origin/master` 时先同步再构建，不能拿旧 HEAD 的 APK 当最新产物。

## Troubleshooting

- **`powershell` 5.1 下中文乱码 / 解析错位**：改用 `pwsh -File ...` 调用 driver；修复后用带 BOM 的 UTF-8 保存脚本。
- **`Error type 3` / `Activity class ... does not exist`**：包名写死错误。用 `resolve-activity` 拿真实组件再 `am start -n`。
- **`usage: screencap ...` 帮助文本而非截图**：换成 `adb exec-out screencap -p > <file>`。
- **adb 无设备但已执行 `--launch`**：模拟器未完成 boot。轮询 `getprop sys.boot_completed` 直到 `1`，超时约 240s。
- **Kotlin 版本警告**（`will soon be dropped`）：仅警告，当前不影响构建；不随本任务升级工具链。