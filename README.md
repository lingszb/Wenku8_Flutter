# 纸间 · 本地阅读

[English](README_EN.md) · [项目文档](docs/README.md) · [Agent 项目规则](.agents/PROJECT_GUIDE.md) · [专项 Skill](.agents/skills/README.md)

> [!NOTE]
> **Fork 说明**：本仓库是 [Wenku8 Flutter](https://github.com/mikufoxxx/Wenku8_Flutter) 的独立 Fork。品牌与本地维护以「纸间」为准，独立发布与维护，不再跟随或接收上游仓库的更新；上游的新版本、标签与变更不会自动进入本项目。

纸间以 Android 为主要目标：导入自己的 TXT / EPUB，离线阅读、整理书库并听书。

> [!IMPORTANT]
> 本项目是第三方阅读工具，与轻小说文库（Wenku8）无隶属关系，也不是其官方应用。应用不运营在线书库、不发布小说资源，安装包不附带任何书籍；小说、封面和插图的权利归各自权利人所有，请只导入和使用你有权访问的内容。

## 当前范围

主导航只有「本地」和「我的」。文库发现与排行、在线搜索、账号与签到、文库云书架、评论、在线目录与正文请求、站点下载等在线功能已移除，未经任务要求不会重新引入。

保留的流程：

- 本地书库、TXT / EPUB 导入与阅读、封面与插图、书签、阅读统计、设置、备份与本地搜索。
- 听书、字体下载与应用更新。
- 网盘导入与手动同步等独立能力，因此这不是一个完全断网的应用。

## 功能

### 本地书库

- 通过系统文件选择器导入 TXT / EPUB；可选择关联原文件或复制到应用。
- Android 支持授权文件夹递归扫描与主共享存储扫描，列出候选书籍后勾选导入。
- 同系列分卷合并、分类整理、批量移动或删除、更换封面。
- 本地搜索支持按书名、作者、标签筛选。

### 阅读

- 上下滚动、横排翻页、竖排翻页三种模式；翻页效果与速度可调。
- 字体、字号、字重、字间距、行距与四边页边距；独立主题配色与背景。
- 自动翻页或自动滚动、音量键翻页、章内查找。
- 封面与插图双指缩放、原图保存。
- 书签、批注、摘录卡片与阅读纪念；四季背景随记录日期切换，可保存图片。
- 阅读统计（总览、节律、书目、记号、触摸）。
- Android 桌面小组件，支持小、中、大尺寸与浅色 / 深色模式。
- 备份与恢复书架、阅读进度、书签、阅读历史、最近搜索和偏好。

### 听书

- 系统 TTS、Edge 在线语音，以及 Microsoft SSML / OpenAI Speech 自定义语音接口。
- 倍速、段落跟随、睡眠定时、后台播放、锁屏与耳机控制。
- 自定义语音配置与凭据存储说明见 [CUSTOM_SPEECH.md](docs/CUSTOM_SPEECH.md)。

### 其他

- 阅读字体按需下载，或导入 TTF / OTF。
- 网盘导入：OpenList / WebDAV、夸克网盘、S3 兼容对象存储。
- 应用内更新检查。

## 当前限制

- 只能导入 TXT / EPUB，不提供其他格式的转换。
- 局域网续读、声音增强、高级格式转换、批量系列整理以及完整的阅读报告编辑 / 导出仍未实现，代码中存在入口不代表可用。
- iOS 与 HarmonyOS 宿主工程仍在仓库中，但当前 Fork 以 Android 为验收目标；不要从 Flutter 的跨平台能力推断这些平台已经可用。
- 小组件使用应用内配置（Android）；系统负责刷新时机，不做持续动画。

## 构建

CI 基线为 Flutter `3.47.9`、JDK `17`、Android SDK `36`。本机版本、路径和设备需要现场确认。

```powershell
flutter pub get

# 静态检查与测试
flutter analyze lib test --no-pub --no-fatal-infos
flutter test --no-pub

# 按目标设备选择架构
flutter build apk --debug --target-platform android-arm64 --no-pub
flutter build apk --debug --target-platform android-x64 --no-pub

# 安装与运行
adb devices
flutter run -d <device-id>
```

构建细节、签名与发布流程见 [SOURCE_BUILD.md](docs/SOURCE_BUILD.md)、[CI_CD.md](docs/CI_CD.md) 和 [RELEASING.md](docs/RELEASING.md)。

## 数据与隐私

- 书籍引用、阅读进度、书签、分类与偏好保存在本机；备份由用户手动导出，不包含离线正文和账号信息。
- 自定义语音的接口密钥使用 Android Keystore 加密保存，不进入常规偏好和备份。
- 本应用没有账号体系，不上传阅读记录；网盘导入、在线语音和更新检查会按配置访问相应服务。

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/README.md](docs/README.md) | 文档索引与维护约定 |
| [docs/SOURCE_BUILD.md](docs/SOURCE_BUILD.md) | 当前构建范围、扫描与已知限制 |
| [docs/READER.md](docs/READER.md) | 阅读器、排版与导入参考 |
| [docs/CUSTOM_SPEECH.md](docs/CUSTOM_SPEECH.md) | 自定义语音协议与凭据边界 |
| [docs/CLOUD_IMPORT.md](docs/CLOUD_IMPORT.md) | 网盘导入参考 |
| [docs/READING_WIDGETS.md](docs/READING_WIDGETS.md) | 桌面小组件 |
| [docs/READING_STATISTICS.md](docs/READING_STATISTICS.md) | 阅读统计 |
| [docs/SEASONAL_ART.md](docs/SEASONAL_ART.md) | 四季纪念与摘录背景 |
| [docs/DESIGN.md](docs/DESIGN.md) | 视觉与交互规范 |
| [docs/THIRD_PARTY.md](docs/THIRD_PARTY.md) | 第三方组件与许可 |

## 致谢与许可

本项目基于 [mikufoxxx/Wenku8_Flutter](https://github.com/mikufoxxx/Wenku8_Flutter) 修改，保留其原有许可与署名要求。感谢上游作者及所有开源组件、字体作者。

- 仓库根目录 [LICENSE](LICENSE) 与 [GPL v3 文本](assets/licenses/GPL-3.0.txt) 适用于已发布源码，具体说明见 [NOTICE](NOTICE)。
- 可下载字体遵循各自的 SIL OFL 1.1 许可。
- 在线语音适配参考 [rany2/edge-tts](https://github.com/rany2/edge-tts)，[LGPL v3](assets/licenses/edge-tts.txt)。

第三方组件的版权和许可分别保留，源码许可不授予书籍内容的任何使用权。