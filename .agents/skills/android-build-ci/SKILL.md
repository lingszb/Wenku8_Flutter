---
name: android-build-ci
description: 排查或修改本仓库 Flutter/Android 工具链、Gradle/NDK/CMake、GitHub Actions、APK 构建与交付、发行签名和更新发布流程时使用。
---

# Android 构建与 CI

遵守[共享规则](../../PROJECT_GUIDE.md)，包括 Herdr 工作树边界和设备授权。构建问题读[源码构建说明](../../../docs/SOURCE_BUILD.md)；CI 问题读[CI/CD](../../../docs/CI_CD.md)及对应 workflow；签名与发行问题再读[发布说明](../../../docs/RELEASING.md)。

## 事实来源与边界

- 工具版本以 `pubspec.yaml`、`pubspec.lock`、`android/settings.gradle.kts`、`android/gradle/wrapper/gradle-wrapper.properties` 和实际 workflow 为准；本机可执行文件、SDK、环境变量与目标 ABI 现场确认，不把 CI 配置当作本机安装证明。
- `.github/workflows/flutter-ci.yml` 执行公开源码门禁；`android-apk.yml` 执行静态分析、Flutter 测试和 ARM64 Debug 构建；`fork-release.yml` 管理 fork 发行。站点与上游签名流程的状态以当前文件为准，不自动启用。
- 核对 Wrapper 三个文件是否实际存在；仅缺失时沿用 CI 的临时模板恢复方法。不得以 `flutter create .` 覆盖宿主，不禁用分发 SHA-256 校验。
- 检查 `android/app/build.gradle.kts` 的 `wenkuForkDistribution`、`wenkuReaderPreview`、`wenkuUnsignedRelease` 与签名条件；不要假定所有 APK 包名和证书相同。签名冲突不以卸载清数据解决。

## 排查与修改

1. 记录失败提交、job/step、命令、ABI 和首个底层错误；分别定位源码门禁、依赖下载、分析、测试、Gradle、原生编译、签名、Artifact 或安装阶段。
2. 仅修复责任层。下载慢时先查既有 Flutter/pub/Maven/Gradle 镜像与缓存配置；切换镜像须保持同一版本与校验值，不关闭 TLS 校验或使用未知替代二进制。
3. Dart 改动按需定向测试；Gradle、原生或打包改动构建受影响 ABI。依赖未变且已解析时不重复 `pub get`。不为纯文档改动构建 APK。
4. PR 门禁保留完整源码检查、静态分析、测试和 ARM64 Debug 构建；本地最小验证不替代这些合并检查。远端结果对应具体 head/merge SHA，旧 run 成功不证明新提交通过。

```powershell
flutter analyze lib test --no-pub --no-fatal-infos
flutter test --no-pub
# 按目标选择 android-arm64 或 android-x64
flutter build apk --debug --target-platform android-arm64 --no-pub
```

## 交付与验证

交付时记录实际执行的检查、未执行项、目标 ABI、构建模式和必要的包名 / 签名核验。交付 APK 时提供文件、SHA-256 和可用的 Artifact 链接；ZIP Artifact、APK、已签名 Release 和设备启动是不同结果。不得打印或提交签名密码、密钥与本机配置。设备安装、启动及功能验收只在共享规则和用户授权范围内执行。
