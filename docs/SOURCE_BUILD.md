# Android 最小源码构建

此 fork 补齐公开快照缺失模块的最小接口，使现有 Android 应用可以编译、启动并使用基本本地阅读流程。这不是正式发行版功能的完整恢复。

## 构建与启动

使用当前已配置的 Flutter 3.47.9、Dart 3.13.7、JDK 17 和 Android SDK 35/36：

```powershell
flutter pub get
flutter analyze --no-fatal-infos
flutter build apk --debug --target-platform android-x64
flutter run -d emulator-5554
```

`android-x64` 为本机模拟器构建；真实 ARM64 设备应使用 `--target-platform android-arm64`，该目标本次未验收。调试包使用独立的 `org.mewx.wenku8_flutter.source_preview` applicationId。

## 当前范围

- 保留现有应用界面、书库、基础阅读、设置以及已提供的原生通道。
- 手动导入支持 TXT / EPUB，仍使用系统文件选择器、原有暂存、路径校验及大小限制。
- 未公开的局域网同步、自定义 TTS、声音增强、文件夹扫描和高级格式转换不伪装为已实现；入口隐藏、禁用或明确提示暂不可用。
- 批量系列整理与报告图片导出暂不可用；基础报告显示实际已有统计。
- 缺失曲面翻页求解器使用平面投影回退；保留现有页面快照与翻页调用接口。
- 缺失报告装饰图不打包，预览使用已有纯色回退。
- SkSL 使用固定采样回退，Impeller 保留原有着色器导数路径。
- 移除缺失 DOC 转换器留下、没有源码引用且阻断 API 24 dex 构建的 POI 依赖；未提高最低 Android 版本。

在线组件仍遵循上游公开快照的限制。本次没有恢复在线书库接口，也没有新增依赖。

## 参考实现来源

部分缺失模块接口改编自上游 [issue #43](https://github.com/mikufoxxx/Wenku8_Flutter/issues/43) 的社区源码附件，包括局域网页面占位、本地导入报告与选择界面、基础阅读报告、小组件预览接口。Android 文件暂存与转换适配、自定义 TTS 不可用接口、平面翻页几何由本次按现有调用补齐。保留仓库原有许可证及 NOTICE。

本地构建、启动与界面验收日志位于 `.tmp/verification/`，不作为应用资源打包。
