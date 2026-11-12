# 项目 skill 索引

本目录维护九个按任务加载的项目 skill，通用规则统一见 [PROJECT_GUIDE.md](../PROJECT_GUIDE.md)，文档分类见 [docs/README.md](../../docs/README.md)。多 Agent 分工、提交整合和设备授权均以共享规则为准；下列验收步骤不构成设备操作许可。

| skill | 使用场景 |
| --- | --- |
| [android-build-ci](android-build-ci/SKILL.md) | Flutter / Android 工具链、Gradle、CI、APK、签名与发行 |
| [asset-fallback-export](asset-fallback-export/SKILL.md) | 图片来源、背景回退、纪念 / 摘录预览和导出、相册与分享 |
| [book-import-pipeline](book-import-pipeline/SKILL.md) | TXT / EPUB 导入、Android 扫描、编码、解析和源文件保留 |
| [flutter-ui-regression](flutter-ui-regression/SKILL.md) | 布局、字体、书架、主题、动效与无障碍 |
| [icon-motion-design](icon-motion-design/SKILL.md) | 原创图标、状态姿态 SVG、图标动效与本地试验场评审 |
| [local-library-integrity](local-library-integrity/SKILL.md) | 分类、系列、书籍 ID、持久化、进度、书签与备份 |
| [reader-rendering](reader-rendering/SKILL.md) | 排版、分页、翻页、阅读坐标与性能 |
| [run-wenku8](run-wenku8/SKILL.md) | 在模拟器 / 设备上构建、安装、打开并截图本项目应用 |
| [source-boundary-audit](source-boundary-audit/SKILL.md) | 缺失源码、公开清单、新增文件、来源与分发边界 |

## 维护约定

- 保留目录名与 frontmatter 的 `name` 一致，`description` 说明触发条件；只读与任务匹配的 skill，跨模块时按需组合。
- `SKILL.md` 写任务特有约束、代码入口和最小验证；通用授权、Git 流程、机器路径、PR 复盘和历史日志不复制进各 skill。
- 持续维护的行为说明放在 `docs/`；阶段记录放在 `docs/archive/`；只有足够长且仅对该 skill 有用的细节才放其 `references/`。不创建空目录或预留脚本。
- 代码变更后同步核对相关入口和已知限制，避免继续将已修复能力描述为缺失。移动文档时修复相对链接，新增公开文件同步精确源码清单。

## 选择与验证边界

- 同一任务先选直接负责该行为的 skill，只在跨越数据、排版、平台或公开边界时组合；不因一个改动涉及 UI 就默认加载全部七个。
- 静态检查、定向单元 / Widget 测试、APK 构建、设备启动和设备功能验收分别报告。文档改动不构建 APK，小型 Dart 修改不强制本地全量构建；既有 PR 必过项保持不变。
- skill 不授予子代理派遣、提交、推送、发布或设备操作权限；需要并行时遵循共享规则中的 Herdr / Codex Worktree 流程。
- 自定义语音的协议、安全存储和收费服务边界先读 [CUSTOM_SPEECH.md](../../docs/CUSTOM_SPEECH.md)；本目录没有独立语音 skill，不将构建 skill 当作完整的语音协议审计。其他未覆盖专题也先查当前文档与代码，不为目录齐全创建占位 skill。
