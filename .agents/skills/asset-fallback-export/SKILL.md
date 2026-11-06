---
name: asset-fallback-export
description: 修复或修改纪念、摘录、主题预览的图片加载与回退、离屏 PNG 导出、相册保存或分享链路时使用；新增图片还需核对来源与公开清单。
---

# 图片回退与导出一致性

遵守[共享规则](../../PROJECT_GUIDE.md)。四季背景读[现行资产说明](../../../docs/SEASONAL_ART.md)；新增或替换资源再查[第三方与分发条件](../../../docs/THIRD_PARTY.md)。历史缺图审计不是当前状态。

## 代码入口

- `lib/reading_export_theme.dart`、`lib/reading_keepsake_theme.dart`：主题、日期与背景解析。
- `lib/reading_artwork.dart`：`loadReadingArtwork`、`ReadingArtworkImage` 共用解码与确定性 PNG 回退。
- `lib/reading_moment_content.dart`、`lib/reading_moment_export.dart`、`lib/quote_card.dart`：预览、预热、离屏绘制与摘录导出。
- `lib/reading_visual_theme_picker.dart`、`lib/reading_moments_ui.dart`、`lib/gallery_save_button.dart`、`lib/local_platform.dart`：选择器及保存 / 分享入口；平台问题继续追踪原生通道。

## 修复约束

1. 核对实际文件、`pubspec.yaml` 声明和解析后的路径；分别识别缺图、坏图、解码、布局、内存、文件写入及权限失败。
2. 复用现有四季图片和回退加载器，确保缩略图、预览与导出使用相同日期和背景决策；不另建重复回退层，不只隐藏 UI 错误却让导出继续抛错。
3. 保留八种主题 ID / 别名、布局与颜色、真实日期、书籍封面和文字内容；背景替换不得伪造统计、重写历史或改变备份。
4. 约束图片解码、画布尺寸、PNG 大小及文本布局，保留正文分页、裁切与语义。可选封面失败不应丢失正文；真实渲染、保存与分享失败仍需报告。
5. 不提取未知许可安装包中的图，不因缺图就断言其私有；新增图片核对来源和分发条件，并使用 `source-boundary-audit` 审查清单。

## 最小验证与交付

- 修改背景或导出链路时优先运行 `flutter test test/reading_artwork_test.dart --no-pub`；按实际影响选择季节、主题、浅深色、缺失 / 损坏背景或封面、尺寸与内容回归，不机械扩大到无关平台。
- 分别报告 Widget 预览、离屏 PNG、平台相册 / 分享三层结果。按钮回调成功不证明文件有效，离屏导出成功不证明设备中文字体和系统分享可用。
- 设备上的点击、保存、分享与权限测试必须另有用户许可；未获许可时列出待验收项。响应式或文本溢出同时参考 `flutter-ui-regression`。
