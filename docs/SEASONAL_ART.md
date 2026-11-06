# 四季纪念背景维护

当前纪念和摘录的所有主题共用四季风景，保留八种主题的 ID、别名、布局与颜色。审计基线、修复前缺图及用户选择过程见[历史实施记录](archive/2026-11-06-seasonal-art-audit.md)，其中旧缺图结论不描述当前状态。

## 运行时资源与日期

| 月份 | 背景文件 |
| --- | --- |
| 3–5 月 | `assets/report/season-spring.png`，春观夜樱 |
| 6–8 月 | `assets/report/season-summer.png`，夏望繁星 |
| 9–11 月 | `assets/report/season-autumn.png`，秋赏满月 |
| 12–2 月 | `assets/report/season-winter.png`，冬会初雪 |

四张 PNG 均为 1536×1024，使用低饱和纸感版画、纯风景、无人物、无文字。生成来源和用户选择见 [seasonal-art-prompts.json](seasonal-art-prompts.json)；不从上游 APK 提取未知许可图片。

真实纪念按 `earnedAt`、有日期摘录按 `recordedAt` 选季；无日期摘录固定本次 `artAt`，预览与导出使用同一值。背景替换不修改历史记录日期、真实书籍封面、书籍 ID 或备份格式。

## 调用与回退

- `lib/reading_export_theme.dart` 和 `lib/reading_visual_theme.dart` 选择背景；`lib/reading_keepsake_theme.dart` 适配纪念主题。
- `lib/reading_artwork.dart` 的 `loadReadingArtwork` / `ReadingArtworkImage` 统一处理资源解码与确定性纸面山线 PNG 回退。
- 纪念内容、离屏导出和 `lib/quote_card.dart` 共用背景决策；替换资源时同时核对 `pubspec.yaml`、源码清单和预览 / PNG 导出，不只更改缩略图。
- 图片不存在或损坏不应阻断文字内容；权限、分享和真实渲染错误仍应报告。基础统计报告页不因此获得完整报告编辑 / 导出能力。

## 验证边界

`test/reading_artwork_test.dart` 覆盖季节、旧主题兼容、资源解码、损坏回退和离屏导出。测试输出不替代真实中文字体和设备相册 / 分享验收；设备操作遵守[共享项目规则](../.agents/PROJECT_GUIDE.md)的测试授权边界。
