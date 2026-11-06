---
name: book-import-pipeline
description: 修改本地 TXT/EPUB 文件选择、Android 文件夹扫描、导入队列、编码、章节解析、封面资源、关联文件和导入维护时使用。
---

# 本地导入与扫描

遵守[共享规则](../../PROJECT_GUIDE.md)，先查[当前导入范围](../../../docs/SOURCE_BUILD.md)。仅在需要排版背景时参考[上游阅读说明](../../../docs/READER.md)，不能从格式名称常量推断实际支持。

## 入口与真实范围

- `lib/book_import_limits.dart` 的 `supportsBookImport` 当前仅接受 TXT / EPUB；限制分别为 128 MiB / 512 MiB。Android 已实现授权文件夹和主共享存储扫描；其他格式转换不能因原生库或标签存在而宣称可用。
- `lib/local_book_importer.dart`、`lib/local_import_page.dart`、`lib/local_import_batch.dart`、`lib/local_import_review.dart`：导入、队列与结果。
- `lib/local_book_scanner.dart`、`lib/local_scan_page.dart`、`lib/local_scan_selection.dart`：扫描、候选选择与导入交接；原生目录遍历沿 Dart 通道定位。
- `lib/local_text_import.dart`、`lib/local_text_rules.dart`、`lib/book_text_encoding.dart`：TXT；`lib/local_epub_markup.dart`、`lib/local_epub_navigation.dart`、`lib/local_epub_media.dart`：EPUB。
- `lib/local_document_reference.dart`、`lib/local_document_input.dart`、`lib/local_book_media.dart`、`lib/local_book_import_issues.dart`、`lib/local_coordinate_upgrade.dart`：文件授权、媒体、失败反馈和坐标升级。

## 必须保留的行为

1. 导入前验证类型、大小、可读性与文件授权；大文件处理保持内存边界，避免阻塞 UI。扫描不修改或删除原文件，不将发现候选变成自动导入。
2. 区分关联原文件和 App 管理副本；维护持久授权及撤权后的恢复提示。扫描指纹仅在成功导入后保存，失败、取消或未勾选条目应可重试。
3. TXT 编码、BOM、中文旧编码、标题规则失败不得丢失正文；EPUB 保留阅读顺序、锚点、嵌套目录、内嵌图与封面，坏资源明确反馈。
4. 重导入和升级保持身份与源坐标；文本不同不能盲目搬移书签 / 标注。系列提示不自动触发合订或重分类。
5. 批次隔离失败、保留成功结果；权限、损坏归档、空间不足和中断有可理解的反馈。公开诊断不暴露私人路径与书籍。

## 风险匹配验证

- 扫描改动优先运行 `flutter test test/local_scan_test.dart --no-pub`；解析改动选择小型可分发样本，覆盖本次涉及的编码、章节规则、EPUB 锚点 / 资源与错误路径。
- 状态变化核对重复导入、失败重试、原文件保留和进度兼容，结合 `local-library-integrity`；排版变化结合 `reader-rendering`。
- 系统文件选择器、持久授权、撤权、重启和真实存储行为属于设备验收，未获许可不得执行。报告 Dart 回归、构建与设备验证各自的结果和缺口。
