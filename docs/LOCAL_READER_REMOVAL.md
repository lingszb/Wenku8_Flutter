# 本地阅读功能移除与验收

日期：2026-11-04。目标平台：Android x86_64 模拟器。此次未验收 iOS、HarmonyOS 或真实 ARM64 手机。

## 最终功能范围

主导航只保留“本地”和“我的”。移除文库发现与排行榜、在线搜索、出版分类、文库账号与签到、文库云书架、推荐与书评/回复、在线详情/目录/正文获取、章节/卷下载任务、站点封面与插图传输、在线续读交接。作者/标签/书名/ID 查询只使用本地书库。

保留 TXT/EPUB 导入、封面与插图、本地阅读、通用分享、统计、书签、设置和备份。已有历史正文/插图缓存可读取和由用户确认后手动清理；缺少章节时提示导入本地文件。此次没有清空旧书架、书签、阅读坐标、书籍文件或备份格式，也未改应用包名和本地 MethodChannel 标识。

独立云盘、听书、字体下载与应用更新仍保留。原先缺失的扫描、局域网等高级能力仍受 [源码构建说明](SOURCE_BUILD.md) 中的限制；本次没有扩展这些功能。

## Git checkpoint

先将原先未提交的工具链/最小可运行修复保存为两个基线提交，再通过三个 worktree 并行删除功能。仅主代理串行整合提交，冲突按对应功能删除范围解决。最终历史按单功能保留，未压成一个混合提交。

| Commit | Checkpoint |
| --- | --- |
| `40a396b` | build(android): configure local Flutter toolchain and mirrors |
| `e49ced8` | fix(android): restore runnable local source preview |
| `c9d4bfc` | refactor(handoff): remove Wenku online book handoff |
| `b22773e` | refactor(community): remove Wenku reviews and recommendations |
| `61e93c3` | refactor: remove Wenku publication categories |
| `b396407` | refactor: remove Wenku cloud bookshelf synchronization |
| `68299eb` | refactor(covers): remove Wenku cover requests and retry cache |
| `2f88fb2` | refactor: remove Wenku account and sign-in features |
| `54caf58` | refactor(discovery): remove online discovery and rankings |
| `643d591` | refactor: remove Wenku offline download jobs and controls |
| `dc7db70` | refactor(illustrations): read images from local files and saved cache |
| `2e7c2a5` | refactor(search): keep book and author queries local |
| `8ec1c19` | refactor: read books and chapters from local sources only |
| `f36dbb8` | refactor(notices): describe local reading and historical collections |

临时分支 `remove/community`、`remove/publications`、`remove/cloud-shelf` 与对应 worktree 已清理，无任务 stash；既有历史未重写。验收文档另行提交。

## 验证证据

- 各功能执行相应 Flutter 静态检查，主分支完整 `flutter analyze lib --no-pub --no-fatal-infos` 通过：0 error、0 warning、12 条已有 deprecated infos。
- `flutter build apk --debug --target-platform android-x64 --no-pub` 通过。使用已有 Android 用户目录中的同一调试证书 `adb install -r` 成功覆盖安装，未卸载或清空应用。
- 实际 Android UI：原有 `wenku8-smoke` TXT 仍在；主导航只有本地/我的；输入 `wenku8` 返回一个本地搜索结果；我的页保留统计/书签/设置/关于，未显示账号/云书架。
- 系统文件选择器导入自制 EPUB 后书库从 1 本变为 2 本；本地封面、目录、中文正文、内嵌插图及大图查看器正常；系统分享面板显示书名/作者，详情无评论/推荐/下载操作。
- 验收结束通过 App 配置页仅移除自制 EPUB 副本，书库回到原有 1 本 TXT。原有书籍和数据保留；测试书的阅读记录按应用现有移除规则保留。
- 本次运行日志未检出 `FATAL EXCEPTION`、`Unhandled Exception`、`E/flutter` 或 `MissingPluginException`。
- 构建仍有既有 Gradle/AGP/Kotlin 后续版本兼容提示，本次未扩大范围升级工具链。未验证真实云服务、远程语音、旧缓存迁移样本、ARM64、iOS 或 HarmonyOS。

本地证据位于 `.tmp/verification/`：`removal-final-analyze.log`、`removal-final-build.log`、`removal-runtime.log`，以及 `removal-home`、`removal-epub-detail`、`removal-epub-reader`、`removal-reader-gallery`、`removal-local-search`、`removal-my`、`removal-clean-library` 对应截图/XML。日志、截图、测试文件和 APK 均不纳入 Git。

APK：`build/app/outputs/flutter-apk/app-debug.apk`。

SHA256：`FE8A6E0849EB87ACFD5FACCA467275FC5D20189FAF385165F63DF6C3C5231EF6`。
