# 项目文档索引与维护约定

本目录区分现行指南、上游参考和历史实施记录。功能是否可用以当前代码为准；旧 PR 的验证结果不代表当前提交已通过验收，也不授予再次操作设备的权限。

## 现行构建、发布与功能维护

| 文档 | 用途 |
| --- | --- |
| [SOURCE_BUILD.md](SOURCE_BUILD.md) | Android 构建、当前 Fork 范围和已知限制；新任务先读 |
| [CI_CD.md](CI_CD.md)、[RELEASING.md](RELEASING.md) | PR 门禁、APK、独立签名、Tag 发布与回滚限制 |
| [CUSTOM_SPEECH.md](CUSTOM_SPEECH.md) | Microsoft SSML / OpenAI Speech 配置、凭据与协议边界 |
| [SEASONAL_ART.md](SEASONAL_ART.md) | 当前四季背景的调用、数据兼容与维护入口 |
| [READING_STATISTICS.md](READING_STATISTICS.md)、[TOUCH_FINGERPRINT.md](TOUCH_FINGERPRINT.md) | 阅读统计和触摸记录；具体能力仍按代码核对 |
| [DESIGN.md](DESIGN.md)、[ICON_SYSTEM.md](ICON_SYSTEM.md)、[HAPTICS.md](HAPTICS.md) | 视觉、图标和触觉规范；上游页面示例不代表当前导航 |
| [THIRD_PARTY.md](THIRD_PARTY.md) | 第三方来源、许可和分发条件 |

## 上游参考：先核对当前实现

以下文档保留了上游跨平台或在线功能说明，不作为本 Fork 的完整功能承诺，保留原路径以兼容既有链接：

| 文档 | 使用边界 |
| --- | --- |
| [READER.md](READER.md) | 阅读器及导入参考；在线账号、在线书架和部分格式不适用于当前 Fork；自定义语音以 CUSTOM_SPEECH.md 为准 |
| [SEARCH.md](SEARCH.md) | 包含已移除的发现、联网搜索及合并在线书架；当前仅保留本地检索 |
| [CLOUD_IMPORT.md](CLOUD_IMPORT.md) | 独立云盘导入参考；须核对实际提供方和平台入口 |
| [READING_WIDGETS.md](READING_WIDGETS.md) | 多平台小组件设计参考；宿主存在或文档列出不代表该平台已验收 |

## 历史实施与 PR 记录

| 记录 | 基线与用途 |
| --- | --- |
| [2026-11-04 本地阅读移除](archive/2026-11-04-local-reader-removal.md) | 功能删除 checkpoints、当时设备验收与限制；不是现行 Git 提交流程 |
| [2026-11-06 四季资产审计](archive/2026-11-06-seasonal-art-audit.md) | 修复前缺图、调用链、问答选择和实施过程；现行约定见 SEASONAL_ART.md |
| [2026-11-11 EPUB 性能优化](archive/2026-11-11-epub-performance.md) | 图片密集型章节加载的实现、测量结果与未验证项；现行阅读器行为见 READER.md |

## 资产与 Agent 入口

- [共享项目规则](../.agents/PROJECT_GUIDE.md)维护跨 Agent 的项目约束；[skill 索引](../.agents/skills/README.md)按任务选择专项流程。
- `docs/images/` 保存文档展示资源，包含上游页面截图；运行时图片位于 `assets/`，由 `pubspec.yaml` 声明，不将文档截图视作 App 已实现能力的证据。
- [seasonal-art-prompts.json](seasonal-art-prompts.json)保存四季图片的生成来源与问答选择，不含运行日志；资产替换时同步维护来源记录。
- `site/`、`tools/update-mirror/` 和第三方源码继续使用各自 README，不将其操作手册复制到本目录。

## 文档生命周期

1. 长期指南沿用现有主题名；新增主题使用大写下划线 `.md` 文件名，并在本索引登记用途和适用范围。避免为同一功能维护多份现行说明。
2. PR / 阶段记录放入 `archive/YYYY-MM-DD-topic.md`，写明基线 SHA、当时范围、实际验证和未验证项；长期有效结论提炼进现行指南后，保留原记录，不直接抹除历史证据。
3. 历史记录中的旧状态不随功能迭代改写；在页首标明历史属性并链接现行说明。不要继续将旧缺图、占位或测试结果当作当前状态。
4. 修改行为时同步更新对应指南；修改路径时检索 README、skill、站点工具及文档引用，更新相对链接与 `tools/public-source-files.txt` 的精确路径。禁止为整理文档放宽源码门禁。
5. skill 只维护任务特有流程，通用协作、Worktree 和授权规则集中在共享项目规则。新增或修改 skill 时保持 frontmatter、触发范围和实际实现一致。
6. 临时 PR 草稿、设备日志、截图、测试书和 APK 放在 `.tmp/verification/` 等既有本地输出目录，不作为长期文档或公开资产提交。
