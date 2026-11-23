---
name: wenku8-android-emulators
description: 在 Windows 上启动纸间的固定 Android 模拟器、安装已核对的 APK、进行 Agent 无头测试或交给用户可见验收时使用。
---

# 纸间 Android 模拟器

统一使用 PowerShell 7 执行 [Start-Emulator.ps1](Start-Emulator.ps1)。两套配置使用同一 Android 36 AOSP x86_64 镜像和宿主 GPU，AVD 固定存放在 `D:\Android\Avd`。每个工作树使用相同名称和端口。脚本校验配置及设备身份，发现不匹配时停止。启动已有设备前先确认它是否正在被其他会话使用。

| 场景 | AVD | ADB | CPU / RAM | 屏幕 | 数据分区 |
| --- | --- | --- | --- | --- | --- |
| Agent 无头测试 | Wenku8_Agent_API36 | emulator-5560 | 4 核 / 3072 MiB | 720×1600，280 dpi，60 Hz | 16 GiB |
| 用户可见验收 | Wenku8_Review_API36 | emulator-5562 | 4 核 / 4096 MiB | 1080×2400，420 dpi，最高 120 Hz | 32 GiB |

```powershell
pwsh -NoProfile -File .agents/skills/wenku8-android-emulators/Start-Emulator.ps1 -Mode Agent
pwsh -NoProfile -File .agents/skills/wenku8-android-emulators/Start-Emulator.ps1 -Mode Review
```

`-ConfigureOnly` 只创建或核对 AVD。Agent 使用无窗口、静音、宿主 GPU 和冷启动。命令禁用快照，仍使用同一份持久数据磁盘。Review 使用可见窗口和 Quick Boot，供用户操作。屏幕的 120 Hz 是验收机显示上限，检查实际渲染效果时按应用测量。

## APK 与验收

遵守[共享项目规则](../../PROJECT_GUIDE.md#source-baseline-and-apk-provenance)。构建只在目标工作树内进行，记录完整 HEAD、未提交差异、时间、ABI、版本和 SHA-256。同一签名可覆盖安装的 APK 使用 `adb -s <serial> install -r <apk>`。安装前用 `adb -s <serial> emu avd name` 确认 AVD。通过 `cmd package resolve-activity` 查实际入口，启动后核对进程、版本与安装包哈希。截图和日志存放当前工作树的 `.tmp/verification/`。设备操作依照用户授权和[设备测试规则](../../PROJECT_GUIDE.md#device-testing-authorization)。

## 数据保存

- 两个 AVD 分别保留系统盘、应用数据和文件选择器授权。测试书籍使用各自模拟器的 `Download/epub-test-books`，主目录 `.tmp/books` 只作为源文件。关联导入时保持模拟器中文件的路径和授权。
- Review 用于用户书库、阅读进度、书签和批注。Agent 测试使用自己的文件和状态。启动脚本不安装 APK、不清理数据、不删除快照。
- 更换 APK 签名、清理 AVD 或迁移数据前，确认旧书库、关联文件和需要保留的阅读记录均已备份或明确可丢弃。签名冲突时保留现有应用数据，优先使用另一套已确认目标。重建后以导入结果、书籍记录和文件数量核对测试书库。
