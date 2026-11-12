# Android 项目管理与 CI/CD

当前主线只管理 Android；iOS、HarmonyOS 暂缓。所有开发通过功能分支和 PR 进入 `master`。

## 1. PR 检查与合并

`master` 分支保护要求以下四项 GitHub Actions 检查成功，并与最新主线同步；管理员同样受约束，不额外要求他人审批，禁止强推和删除主线。

| 必过检查 | 内容 |
| --- | --- |
| Public source policy | 精确提交的源码清单与敏感内容检查 |
| Static analysis | `flutter analyze lib test --no-pub --no-fatal-infos` |
| Flutter tests | `flutter test --no-pub`，包含检索单元回归、搜索框输入/提交/清空 Widget 测试和 fork 更新资产回归 |
| Android ARM64 debug build | 前两项成功后构建 Debug APK、生成 SHA256、上传 Artifact |

测试只覆盖当前已有的回归场景，不代表设备 E2E、性能或全部阅读行为已经自动化。新增公开测试需更新 `.gitignore` 的明确允许项与 `tools/public-source-files.txt`；清单登记的 `test/**/*_test.dart` 仍接受敏感内容检查。

`pubspec.yaml`、`lib/updates/app_updates.dart` 的版本常量和 `CHANGELOG.md` 的版本章节必须同步修改；当前四项门禁不校验三者一致，普通 PR 只改其中一处仍可能通过，合并前需人工确认。

构建使用 Ubuntu 24.04、JDK 17、Flutter 3.47.9、Android API 36、Build Tools 36、CMake 3.22.1。Gradle 8.14 华为镜像保留 SHA256 校验。本地其他 Maven 镜像不自动继承到 GitHub Runner。

公开源码快照仍缺少三个受版本管理的 Wrapper 文件，CI 从固定 Flutter 模板恢复，不覆盖现有 Android 配置。本地新机器需同等准备 Wrapper。

## 2. Debug APK 手机测试

`Android APK build` 在 PR、master push 和手动运行时执行。Artifact 为 `local-reader-arm64-debug-<run_number>`，内含 APK 与校验值，保留 14 天。解压后安装，不能把 Artifact ZIP 当作 APK。

Debug 包名：`org.mewx.wenku8_flutter.source_preview`。CI Runner 使用临时 Debug 证书，与不同 Runner 或本机构建的签名不一致；签名不一致时 Android 只能先卸载再安装，`versionCode` 相同也不能覆盖。签名一致时，相同或更高 `versionCode` 可以覆盖安装，因此能否覆盖取决于签名，不是版本号。安装或卸载前先备份书库；不要为覆盖安装而卸载有重要书库的数据，也不要假设预览包一定可升级。正式发行包使用下述独立身份。

## 3. Release：构建 → 签名 → 发布

新增 `Android Release` 工作流：

1. 版本 Tag `v<version>` 或 `v<version>+<build>` 必须与 `pubspec.yaml` 一致，版本常量与 CHANGELOG 对应章节也必须一致。Tag 必须指向已进入 `master` 的提交。
2. 对精确提交重新执行源码检查、静态分析与单元/Widget 测试，然后构建 ARM64 **未签名 Release-mode APK**。
3. 独立签名 job 从 `android-release` 环境获取证书，签名并验证包名、版本号、非 Debug 属性、ABI 和固定证书 SHA256。
4. 发布签名 APK、`SHA256SUMS.txt`、公开证书指纹和 CHANGELOG 版本说明到当前 fork 的 GitHub Releases。已存在的 Release 不覆盖，失败重跑前应先查明原因。

发行包名：`io.github.lingszb.wenku8.localreader`，名称“轻小说文库 · 本地阅读”。通过 Gradle 的 `wenkuForkDistribution` 属性隔离发行身份，不改变现有 Debug 预览包；签名独立于上游与 Debug。原生 MethodChannel、书籍数据和备份格式不改。发行包与预览包独立安装，迁移书库请使用应用备份/导入，不要卸载旧包清空数据。

更新默认来源已切换为 `lingszb/Wenku8_Flutter`，不再默认请求上游作者的更新镜像。APK 命名沿用更新器契约 `wenku8-<version>-arm64-v8a.apk`，校验文件另行记录构建身份。当前只交付 ARM64 APK，其他 ABI 不宣称已支持。

### 手动验证，不公开发布

先在 Actions 中选择 `Android Release`，在 **master** 运行，或：

```powershell
gh workflow run fork-release.yml --repo lingszb/Wenku8_Flutter --ref master
```

手动运行同样执行 Release 构建、签名与验证，上传 `local-reader-signed-release-<run_number>`，保留 14 天；**不会创建 Tag 或 GitHub Release**。这用于在正式发布前验证签名、包身份及安装。

### 正式发版

在功能分支同步更新 `pubspec.yaml`、`lib/updates/app_updates.dart` 的版本常量、`CHANGELOG.md` 的对应版本说明，经过四项门禁合并；Android build number 必须递增。普通功能 PR 不递增版本，预览 / Debug 包沿用当前版本号，不能作为发版标识。随后从最新 master 创建版本 Tag：

```powershell
git switch master
git pull --ff-only
git tag v0.5.7  # 示例；必须与本次已合并版本一致
git push origin v0.5.7
```

只给已审核主线打 Tag。Tag 是公开发布触发器；手动验证不等同于发版。当前仍保留历史版本号，首次实际发布前应完成上述版本与说明更新，不能把上游旧说明当作本 fork 更新记录。

## 4. 签名凭据与权限

`android-release` 环境仅允许 master 分支与 `v*` 标签部署。环境 Secrets：`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEY_ALIAS`、`ANDROID_STORE_PASSWORD`、`ANDROID_KEY_PASSWORD`；公开变量 `ANDROID_SIGNING_CERT_SHA256` 固定证书身份。

本机证书位于 `D:\Android\Signing\Wenku8_Flutter`，目录 ACL 仅当前用户和 SYSTEM 可访问。`release-credentials.clixml` 中的密码使用 Windows DPAPI 加密，依赖当前 Windows 用户/机器解密；它不是可随意搬到其他机器使用的明文密码备份。证书必须长期保留并在后续发版持续使用。不要提交、打印或上传私钥到 Artifact/Release。

构建 job 只有仓库读取权限且不接触签名 Secrets；独立签名 job 仅在发布环境取得凭据；只有 Tag 发布 job 获得 `contents: write`。临时私钥随签名临时目录清理。

分支保护、环境规则、Secrets 和 Action 启停是 GitHub 仓库设置，不会随 clone 自动复制到新 fork。

## 5. 工作流启停

| 工作流 | 当前管理方式 |
| --- | --- |
| Flutter source checks | 保留，PR 源码门禁 |
| Android APK build | 保留，分析、单元/Widget 测试与 Debug APK |
| Android Release | 保留，手动签名验证 / Tag 正式发布 |
| Publish project page | 已在当前 fork 禁用；不运行网页定时部署 |
| Sign reviewed distribution | 已禁用；属于上游作者，不复用其签名身份 |

CI 日志以对应提交的 Actions Run 为准。Debug 构建、Release 签名验证、设备运行和正式发布是不同验收结果，不互相替代。
