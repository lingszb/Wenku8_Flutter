# Android 本地阅读器 CI/CD 基线

> 范围：**Android ARM64 Debug 构建验证与测试包交付**。不等同于生产 APK 发行。本说明基于当前公开 Fork 的构建配置与源码状态；任何构建成功声明以 GitHub Actions 运行详情为准。

## 1. 现状调研

当前继承的工作流：

| 工作流 | 功能 | 能证明 APK 可编译吗？ |
| --- | --- | --- |
| `.github/workflows/flutter-ci.yml` | 用 `tools/check_public_source.py` 审核当前提交的公开源码清单及受限代码 | **不能** |
| `.github/workflows/project-pages.yml` | 构建并部署项目网页 | **不能** |
| `.github/workflows/sign-distribution.yml` | 使用上游作者的密钥，对已审核发行包进行签名；有 `github.repository == 'mikufoxxx/Wenku8_Flutter'` 限制 | **不能**，Fork 无法直接使用 |

本 Fork 的 `docs/LOCAL_READER_REMOVAL.md` 记载了 Android **x86_64 Debug 模拟器**成功构建/安装与 TXT、EPUB 基础验收；当前提交 `2157a71` 已有[云端 ARM64 Debug 成功运行](https://github.com/lingszb/Wenku8_Flutter/actions/runs/41961796954)。不要把上游绿勾、源码检查绿勾或本地模拟器通过等同于 ARM64 Release 成功。

## 2. 新增流水线

`.github/workflows/android-apk.yml`

- **触发**：PR、`master` push、Actions 页面手动触发 `workflow_dispatch`。
- **运行环境**：`ubuntu-24.04`、JDK 17、Flutter 3.47.9（Dart 3.13.7）、Android SDK 36；Android Gradle Plugin 与 Kotlin Plugin 依赖仓库本身的 `android/settings.gradle.kts`（当前 AGP 8.11.1、Kotlin 2.2.20）。
- **第一道门**：运行已有 `tools/check_public_source.py`，避免偷偷加入上游限制发布的实现或本地密钥。
- **SDK 初始化**：使用 GitHub Ubuntu Runner 预装的 Android SDK 命令行工具安装 API 36、Build Tools 36 与 CMake 3.22.1。避免使用会调用已删除 `sdkmanager tools` 包的 `android-actions/setup-android@v3`（首次 Run 曾在此处失败）。
- **静态检查**：`flutter pub get`，`flutter analyze lib test --no-pub --no-fatal-infos`。该命令不会忽略 error 或 warning，但允许已有 deprecated info。
- **从干净源码恢复 Gradle Wrapper**：公开快照只有 `android/gradle/wrapper/gradle-wrapper.properties`，没有 `gradlew`、`gradlew.bat`、`gradle-wrapper.jar`。CI 使用**已固定版本的 Flutter SDK**在临时目录生成 Android 模板，复制这三个文件到原项目，并保留原来的 Gradle 8.14 配置与 SHA-256 校验。绝不覆盖原 `android/build.gradle.kts` 或 `android/app/build.gradle.kts`。
- **构建门**：`flutter build apk --debug --target-platform android-arm64 --no-pub`，要求 APK 文件存在且非空。
- **交付**：计算 APK SHA-256，在任务摘要输出哈希，使用 `actions/upload-artifact@v4` 保存 `app-debug.apk` 与 `apk-sha256.txt`，保留 14 天。

当前 ARM64 Debug 构建已有成功记录；新增门禁的实际验证应以对应 PR 的四项检查结果为准。

### Gradle Wrapper 特殊说明

Gradle 官方推荐将全部四个 Wrapper 文件（`gradlew`、`gradlew.bat`、`gradle-wrapper.jar`、`gradle-wrapper.properties`）纳入版本管理。当前缺少三项属于公开快照问题。本次 CI 的临时恢复为过渡方案；建议在经过源代码清单与 Wrapper JAR 安全校验后，另起 PR 正式补齐、去掉临时恢复步骤。

构建还依赖 `distributionUrl=https://repo.huaweicloud.com/gradle/gradle-8.14-all.zip`。如 Runner 无法访问此镜像，应该单独检查 Gradle 下载与 SHA-256，必要时改用官方分发地址；不得关闭 `distributionSha256Sum` 规避校验。

## 3. 如何使用

### PR / Push

创建或更新 PR 后，进入 Fork 的 **Actions → Android APK build** 查看执行情况。Merge 到 `master` 后同样会运行。

若 **Actions 中没有任何运行记录**：先检查 GitHub 是否要求为 Fork 手动启用 Actions。单纯在上游完成工作流不会触发 Fork 的构建。

### 手动验证

合并此工作流后，在默认分支的 Actions 页面选择 **Android APK build → Run workflow**。等待该次执行完成，在详情页下方 **Artifacts** 下载 `local-reader-arm64-debug-<run_number>`。

解压后得到 `app-debug.apk` 和 `apk-sha256.txt`。Debug 包使用调试签名，仅供个人/设备内测。下载的 Artifact 压缩包并不是 APK 本身，需先解压。

### Windows 真机安装和验证

```powershell
adb devices
adb install -r app-debug.apk
adb shell pm list packages | findstr source_preview
```

如已有同 package 的 APK 使用不同签名，`adb install -r` 会报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`。**不要贸然卸载清空书库**。先备份数据，或改用隔离应用 ID/相同测试签名。

必测：TXT 与 EPUB 导入、书架分类、目录跳转、插图、书签、退出重启恢复进度、断网阅读、不同 Android 版本的文件授权。

### 本地与 CI 等价命令

```powershell
flutter --version
flutter pub get
flutter analyze lib test --no-pub --no-fatal-infos
flutter build apk --debug --target-platform android-arm64 --no-pub
```

本地执行前必须已安装匹配的 Java/Android SDK，且本地 Android 目录包含可用的 Gradle Wrapper。CI 在此基础上额外审查公开源码并补齐缺失 Wrapper。

## 4. 确认边界

| 能力 | 现有新流程是否涵盖 |
| --- | --- |
| 公开源码策略检查 | 是 |
| Flutter/Dart 静态分析 | 是 |
| 干净 Runner 的 Android ARM64 Debug 编译 | 是，已有成功运行 |
| Debug APK Artifact 下载与校验值 | 是，已有成功产出 |
| 自动化 `flutter test` | 是；运行 `flutter test --no-pub`，当前包含本地检索单元回归，尚无 Widget/E2E 覆盖 |
| 真机 UI、性能和长时间稳定性 | 否；需单独设备验收 |
| 生产 Release 签名、AAB、商店/Release 发布 | 否 |
| iOS、HarmonyOS 打包 | 否 |

## 5. 后续增量路线

1. **打通 ARM64 CI 基线**：记录首次成功的 Run URL、SDK/AGP/Gradle 版本、APK SHA-256；失败时先区分环境下载、缺失 Wrapper、Dart 分析和 Android 编译问题。
2. **补测试与 Wrapper**：明确修改公开源码校验策略以容纳可公开的 `test/`，添加本地导入、分类、阅读进度及系列合订回归；正式提交经校验的 Wrapper 文件。
3. **独立 Preview Release**：使用不会覆盖正式应用的数据隔离包名，构建 Release-mode APK 验证性能。Release 模式不等于生产签名；不能把 Debug 签名包当作公开正式版。
4. **生产发行 CD**：重新设计 Fork 自己的包名、版本号、更新源和签名；将 keystore 与密码保存在 GitHub Secrets，限制生产签名仅可信 tag/受保护环境运行，再上传到 GitHub Releases。

上游签名 workflow 明确限定原作者仓库，不要试图直接在 Fork 复用原作者的私钥或发行身份。

## 6. master 合并门禁

`master` 使用 GitHub 分支保护，以下四项 GitHub Actions 检查必须成功，且 PR 分支必须与最新目标分支同步：

- `Public source policy`：检查精确提交的公开源码与清单。
- `Static analysis`：`flutter analyze lib test --no-pub --no-fatal-infos`。
- `Flutter tests`：`flutter test --no-pub`。无测试套件或测试失败时不得视为通过。
- `Android ARM64 debug build`：依赖分析与测试成功后构建 APK、校验产物并上传。

检查绑定 GitHub Actions App，管理员同样受保护；通过 PR 合并，不额外要求审批人数。禁止强推和删除 `master`。这些是仓库远端设置，工作流文件本身不能替代分支保护；新 fork 需要另行配置。

公开源码策略仅允许清单登记的 `test/**/*_test.dart`；未登记测试、原生私有测试材料与其他受限内容仍被拒绝。新增公开测试时同时更新 `tools/public-source-files.txt`。当前测试只验证本地检索，不代表导入、阅读或设备 E2E 已自动化。

## 7. 外部文档

- [Flutter 官方 Android 构建/ABI 说明](https://docs.flutter.dev/deployment/android)
- [Flutter 官方持续交付说明](https://docs.flutter.dev/deployment/cd)
- [Flutter Action（subosito）](https://github.com/subosito/flutter-action)
- [GitHub Actions Artifact](https://docs.github.com/en/actions/tutorials/store-and-share-data)
- [Gradle 官方 Wrapper 说明](https://docs.gradle.org/current/userguide/gradle_wrapper.html)
