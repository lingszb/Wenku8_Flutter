---
name: local-library-integrity
description: 修改本地分类、作者/标签/系列分组、书架筛选、合订/解散、书籍 ID、偏好、进度、书签或备份等持久状态时使用。
---

# 本地书库与持久状态完整性

遵守[共享规则](../../PROJECT_GUIDE.md)。现行能力读[源码范围](../../../docs/SOURCE_BUILD.md)，不把[上游阅读参考](../../../docs/READER.md)中的在线书架当作当前功能。

## 数据入口与约束

- `lib/local_books.dart` 的 `LocalBookStore` 管理原书、合订映射、身份、来源与封面；`lib/local_library_preferences.dart` 管理手动分类、选中项与序列化。
- `lib/book_dynamic_categories.dart`、`lib/book_tag_catalog.dart` 派生作者、标签、系列；`lib/local_book_series.dart`、`lib/local_series_actions.dart`、`lib/local_series_editor.dart` 管理提示与显式操作。
- `lib/local_library_page.dart`、`lib/bookshelf_scope.dart` 连接筛选与展示，`lib/book_collection_region_toolbar.dart` 实现立体书架分类级联控件；`lib/library_state.dart` 及相关存储管理历史、进度和书签。
- `_author:`、`_tag:`、`_series:` 及无标签 / 无系列视图是只读投影，不覆盖手动分类。作者 / 标签 / 系列候选保持既有排序、计数、筛选 ID 与旧偏好兼容。
- 系列优先使用 `LocalBookStore.seriesFor`，再用 `seriesHint`，最后才是标题推断。纯数字标题不自动构成系列，系列名称不触发自动合订。
- 所有书架 / 列表筛选传递一致的本地元数据；显式合订、重排、解散保留原文件、稳定 ID 和章节映射，不能将虚拟合订项当作可删除原书。

## 修改与回归

1. 追踪源文件 → LocalBookStore → 书籍 / 合订快照 → 派生分类 → 视图 → 持久化，先区分权威状态与派生状态。
2. 修改键、ID、序列化或坐标前审查旧数据读取与失败恢复，保持书签、标注、阅读历史、封面和备份兼容。需要迁移时在任务范围内明确方案与恢复路径，不静默迁移或清库。
3. 选择与变更相关的回归：混合 / 缺失元数据、手动分类、歧义标题、陈旧选中项、合订重排 / 解散、坏 JSON、部分导入或原文件缺失；失败不得使其他书籍失效。
4. 分类数据仍使用现有模型；立体书架分类保持“全部书籍 / 按作者分类 / 按系列分类 / 按标签分类”一级入口及右侧二级选择，不退回平铺全部候选。相关控件定向测试为 `test/shelf_category_picker_test.dart`。
5. 删除手动分组或移除合订展示项不得隐式删除原书、进度或书签。回归使用合成状态 / 可分发样本，真实用户书库和设备重启测试需另行授权。

交付时说明存储契约影响、源文件保护、相关测试和未验证的迁移 / 设备行为。UI 几何变化结合 `flutter-ui-regression`，导入变化结合 `book-import-pipeline`。
