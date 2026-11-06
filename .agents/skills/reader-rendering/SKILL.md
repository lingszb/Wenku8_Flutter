---
name: reader-rendering
description: 修改阅读器分页/滚动、横竖排、字体段落、翻页、内嵌图片、文本选择、阅读锚点或渲染性能时使用。
---

# 阅读排版与位置稳定性

遵守[共享规则](../../PROJECT_GUIDE.md)。先确认[当前源码范围](../../../docs/SOURCE_BUILD.md)；需要交互和视觉背景时再查[阅读参考](../../../docs/READER.md)与[设计规范](../../../docs/DESIGN.md)，上游说明不保证所有模式已实现。

## 代码入口

- `lib/reader_pagination.dart`、`lib/reader_reflow.dart`、`lib/reader_paged_view.dart`、`lib/reader_scroll_stream.dart`：度量、重排与呈现。
- `lib/reader_book_style.dart`、`lib/reader_preferences.dart`、`lib/reader_content.dart`、`lib/reader_rich_content.dart`：样式、设置与富文本。
- `lib/reader_vertical_text.dart`、`lib/reader_embedded_vertical.dart`、`lib/reader_illustrations.dart`：竖排、混排与插图。
- `lib/reader_coordinate_map.dart`、`lib/reader_page_anchor.dart`、`lib/reader_book_progress.dart`、`lib/reader_annotations.dart`：源坐标、进度与标注。

## 不变量

1. 章节 / 段落源偏移是持久坐标；页码与像素随宽度、字体和模式变化，不能作为唯一存储位置。修改布局从源锚点重映射，保留进度、标注范围、书签与搜索返回位置。
2. 保留实际可用的 CJK / Latin、标点、长连续文本、Ruby、竖排 / RTL 和图片规则，不为塞入页面而删字、隐藏内容或伪造章节。
3. 文件缺失或不完整必须显式反馈，不联网补回已移除的正文服务，不改变书籍 ID。
4. 保持分批处理、让出 UI 执行机会和有界布局 / 缓存；性能开关不能禁用基本阅读。样式与尺寸变化需核对缓存失效，避免复用旧分页。

## 最小工作流

- 先定位解析、坐标、样式、分页、呈现或翻页合成中的责任层，再用小型可分发样本复现本次问题。
- 优先定向 Dart / Flutter 回归，覆盖受影响的章节边界、锚点往返、换字体 / 宽度 / 模式及坏资源；仅在实际构建风险需要时追加 APK，保留 PR 门禁。
- 设备验收按影响选择章节首尾、长章节、进度、书签、选择、字体切换与方向 / 模式切换；未经用户许可不得执行手势或设备自动化。
- 性能结论需对应测量对象与模式。CI 耗时不能证明帧率或流畅度；无设备测量时不声明性能验收通过。

交付时报告源坐标兼容、受影响模式、缓存变化、测试结果和待授权的设备验证。
