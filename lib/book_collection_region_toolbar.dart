import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'library_toolbar.dart';
import 'local_library_preferences.dart';
import 'local_platform.dart';

/// A region's controls stay beside the books they affect, using the same
/// category, filter and view hit areas as the existing collection toolbar.
class BookCollectionRegionToolbar extends StatelessWidget {
  const BookCollectionRegionToolbar({
    super.key,
    required this.title,
    required this.category,
    required this.count,
    required this.onCategory,
    required this.onFilter,
    required this.onView,
    this.categoryKey,
    this.filterKey,
    this.viewKey,
    this.subtitle,
    this.loading = false,
    this.activeFilters = 0,
    this.onLayout,
    this.layoutKey,
  });
  final String title, category;
  final String? subtitle;
  final int count, activeFilters;
  final bool loading;
  final VoidCallback? onCategory, onFilter, onView, onLayout;
  final Key? categoryKey, filterKey, viewKey, layoutKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: ArchiveSection(
              title: title,
              code: 'COLLECTION / REGION',
              subtitle: subtitle ?? '',
            ),
          ),
          if (onLayout != null) ...[
            const SizedBox(width: 12),
            GlassTextButton(
              key: layoutKey,
              compact: true,
              onPressed: onLayout,
              child: const AppText('整体布局'),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      LibraryToolbar(
        category: category,
        count: count,
        onCategory: onCategory,
        onOptions: onFilter,
        onView: onView,
        categoryKey: categoryKey,
        optionsKey: filterKey,
        viewKey: viewKey,
        loading: loading,
        activeFilters: activeFilters,
      ),
    ],
  );
}

/// Picking a region category changes only the caller's view preference, never
/// book membership. Source and follow controls stay in the filter drawer.
Future<String?> chooseBookCollectionRegionCategory(
  BuildContext context, {
  required Map<String, String> options,
  required String selected,
  required bool reduceMotion,
  Future<String?> Function(BuildContext)? chooseCustomCategory,
}) => showJellySheet<String>(
  context: context,
  reduceMotion: reduceMotion,
  heightFactor: .72,
  builder: (_) => BookShelfCategoryPicker(
    options: options,
    selected: selected,
    reduceMotion: reduceMotion,
    chooseCustomCategory: chooseCustomCategory,
  ),
);

enum _CategoryFamily {
  all('全部书籍'),
  authors('按作者分类'),
  series('按系列分类'),
  tags('按标签分类');

  const _CategoryFamily(this.label);
  final String label;

  static _CategoryFamily? of(String id) {
    if (id == LocalLibraryPreferences.all) return all;
    if (LocalLibraryPreferences.categoryAuthor(id) != null) return authors;
    if (id == LocalLibraryPreferences.noSeries ||
        LocalLibraryPreferences.categorySeries(id) != null) {
      return series;
    }
    if (id == LocalLibraryPreferences.noTag ||
        LocalLibraryPreferences.categoryTag(id) != null) {
      return tags;
    }
    return null;
  }
}

/// A view-only cascading selector. Custom categories retain their original
/// button style; creation and editing remain in the category management sheet.
class BookShelfCategoryPicker extends StatefulWidget {
  const BookShelfCategoryPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.reduceMotion,
    this.chooseCustomCategory,
  });

  final Map<String, String> options;
  final String selected;
  final bool reduceMotion;
  final Future<String?> Function(BuildContext)? chooseCustomCategory;

  @override
  State<BookShelfCategoryPicker> createState() =>
      _BookShelfCategoryPickerState();
}

class _BookShelfCategoryPickerState extends State<BookShelfCategoryPicker> {
  late _CategoryFamily _family =
      _CategoryFamily.of(widget.selected) ?? _CategoryFamily.all;
  final _controllers = <_CategoryFamily, FixedExtentScrollController>{};
  final _choices = <_CategoryFamily, String>{};

  List<MapEntry<String, String>> _items(_CategoryFamily family) => [
    for (final entry in widget.options.entries)
      if (_CategoryFamily.of(entry.key) == family) entry,
  ];

  String? _choice(List<MapEntry<String, String>> items) {
    if (items.isEmpty) return null;
    final requested = _choices[_family] ?? widget.selected;
    return items.any((entry) => entry.key == requested)
        ? requested
        : items.first.key;
  }

  String _label(MapEntry<String, String> entry) {
    final prefix = switch (_CategoryFamily.of(entry.key)) {
      _CategoryFamily.authors => '作者 · ',
      _CategoryFamily.series => '系列 · ',
      _CategoryFamily.tags => '标签 · ',
      _ => '',
    };
    return prefix.isNotEmpty && entry.value.startsWith(prefix)
        ? entry.value.substring(prefix.length)
        : entry.value;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = _family;
    final items = _items(_family);
    final choice = _choice(items);
    final reduced =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    final scale = MediaQuery.textScalerOf(context);
    final itemExtent = math.max(56.0, scale.scale(14) * 2.8 + 8);
    final wheelHeight = (MediaQuery.sizeOf(context).height * .36).clamp(
      168.0,
      320.0,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: ArchiveSection(
                  title: '立体书架分类',
                  code: 'UPPER / CATEGORY',
                ),
              ),
              GlassIconButton(
                key: const ValueKey('shelf-category-cancel'),
                icon: CupertinoIcons.xmark,
                label: '取消分类选择',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppText(
            '当前：${widget.options[widget.selected] ?? '原有分类'}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: wheelHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: ListView(
                    key: const ValueKey('shelf-category-primary'),
                    padding: EdgeInsets.zero,
                    children: [
                      for (final family in _CategoryFamily.values)
                        GlassTextButton(
                          key: ValueKey('shelf-category-family-${family.name}'),
                          compact: true,
                          selected:
                              family == _family &&
                              (family != _CategoryFamily.all ||
                                  widget.selected ==
                                      LocalLibraryPreferences.all),
                          onPressed: () {
                            if (family == _CategoryFamily.all) {
                              Navigator.pop(
                                context,
                                LocalLibraryPreferences.all,
                              );
                            } else {
                              setState(() => _family = family);
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: AppText(
                                  family.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (family != _CategoryFamily.all) ...[
                                const SizedBox(width: 3),
                                const ArchiveIcon(
                                  CupertinoIcons.chevron_right,
                                  size: 11,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('shelf-category-secondary-${_family.name}'),
                    tween: Tween(begin: 0, end: 1),
                    duration: reduced ? Duration.zero : NovelMotion.enter,
                    curve: Curves.easeOutCubic,
                    builder: (context, opacity, child) =>
                        Opacity(opacity: opacity, child: child),
                    child: _family == _CategoryFamily.all
                        ? const Center(
                            child: AppText(
                              '选择左侧分类方式',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : items.isEmpty
                        ? Center(
                            child: AppText(switch (_family) {
                              _CategoryFamily.authors => '当前书库暂无作者信息',
                              _CategoryFamily.series => '当前书库暂无系列信息',
                              _ => '当前书库暂无标签',
                            }, textAlign: TextAlign.center),
                          )
                        : CupertinoPicker.builder(
                            key: ValueKey(
                              'shelf-category-wheel-${_family.name}',
                            ),
                            scrollController: _controllers.putIfAbsent(
                              _family,
                              () => FixedExtentScrollController(
                                initialItem: items.indexWhere(
                                  (entry) => entry.key == choice,
                                ),
                              ),
                            ),
                            itemExtent: itemExtent,
                            childCount: items.length,
                            onSelectedItemChanged: (index) {
                              if (_family != family) return;
                              setState(
                                () => _choices[family] = items[index].key,
                              );
                              if (LocalPlatform.android ||
                                  LocalPlatform.harmony) {
                                AppHaptics.play(context, HapticCue.detent);
                              }
                            },
                            itemBuilder: (context, index) => Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: AppText(
                                  _label(items[index]),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_family != _CategoryFamily.all && choice != null)
            AppText(
              '已选：${_label(items.firstWhere((entry) => entry.key == choice))}',
              key: const ValueKey('shelf-category-pending'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          if (_family != _CategoryFamily.all) ...[
            const SizedBox(height: 8),
            GlassTextButton(
              key: const ValueKey('shelf-category-confirm'),
              onPressed: choice == null
                  ? null
                  : () => Navigator.pop(context, choice),
              child: const AppText('使用分类'),
            ),
          ],
          if (widget.chooseCustomCategory != null) ...[
            const SizedBox(height: 20),
            GlassTextButton(
              key: const ValueKey('shelf-manage-custom-categories'),
              onPressed: () async {
                final category = await widget.chooseCustomCategory!(context);
                if (context.mounted && category != null) {
                  Navigator.pop(context, category);
                }
              },
              child: const AppText('自定义分类'),
            ),
          ] else if (widget.options.keys.any(
            (id) => _CategoryFamily.of(id) == null,
          )) ...[
            const SizedBox(height: 20),
            const ArchiveSection(title: '自定义分类', code: 'LIBRARY / CUSTOM'),
            const SizedBox(height: 12),
            for (final entry in widget.options.entries)
              if (_CategoryFamily.of(entry.key) == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GlassTextButton(
                    key: ValueKey('shelf-custom-category-${entry.key}'),
                    onPressed: () => Navigator.pop(context, entry.key),
                    child: AppText(
                      '${entry.key == widget.selected ? '✓  ' : ''}${entry.value}',
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
