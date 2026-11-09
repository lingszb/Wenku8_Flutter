import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import 'app_interactions.dart';
import 'app_ui.dart';
import 'feature_pages.dart' show confirmNovelAction;
import 'local_library_preferences.dart';
import 'catalog.dart';
import 'local_books.dart';
import 'book_dynamic_categories.dart';

/// Shelf and local library use one category vocabulary and assignment store.
Future<void> showBookCategories(
  BuildContext context,
  LocalLibraryPreferences organization, {
  bool shelf = false,
  bool reduceMotion = false,
  Iterable<Novel> books = const [],
  LocalBookStore? localBooks,
  int unknownAuthorCount = 0,
}) async {
  final selected = shelf ? organization.shelfSelected : organization.selected;
  final result = await showJellySheet<String>(
    context: context,
    reduceMotion: reduceMotion,
    heightFactor: .72,
    builder: (sheet) => _CategoryListSheet(
      organization: organization,
      selected: selected,
      reduceMotion: reduceMotion,
      onSelected: (value) => Navigator.pop(sheet, value),
    ),
  );
  if (!context.mounted || result == null) return;
  try {
    if (result == '_authors' || result == '_tags' || result == '_series') {
      final groups = switch (result) {
        '_authors' => BookDynamicCategories.authors(
          books,
          unknownCount: unknownAuthorCount,
        ),
        '_tags' => BookDynamicCategories.tags(books),
        _ => BookDynamicCategories.series(books, local: localBooks),
      };
      final category = await _chooseDynamicCategory(
        context,
        title: switch (result) {
          '_authors' => '按作者分类',
          '_tags' => '按标签分类',
          _ => '按系列分类',
        },
        code: switch (result) {
          '_authors' => 'LIBRARY / AUTHORS',
          '_tags' => 'LIBRARY / TAGS',
          _ => 'LIBRARY / SERIES',
        },
        emptyMessage: switch (result) {
          '_authors' => '当前书库暂无作者信息',
          '_tags' => '当前书库暂无标签',
          _ => '当前书库暂无系列信息',
        },
        selected: selected,
        groups: groups,
        reduceMotion: reduceMotion,
      );
      if (category != null) await organization.select(category, shelf: shelf);
    } else {
      await organization.select(result, shelf: shelf);
    }
  } catch (e) {
    if (context.mounted) {
      showNovelFeedback(
        context,
        e is FormatException ? e.message : '分类保存失败，请重试',
      );
    }
  }
}

/// Dynamic grouping changes the selected view, not custom assignments.
Future<String?> _chooseDynamicCategory(
  BuildContext context, {
  required String title,
  required String code,
  required String emptyMessage,
  required String selected,
  required Map<String, BookCategoryCount> groups,
  required bool reduceMotion,
}) => showJellySheet<String>(
  context: context,
  reduceMotion: reduceMotion,
  heightFactor: .72,
  builder: (sheet) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    children: [
      ArchiveSection(title: title, code: code),
      const SizedBox(height: 16),
      if (groups.isEmpty) AppText(emptyMessage),
      for (final entry in groups.entries)
        GlassTextButton(
          key: ValueKey('dynamic-category-${entry.key}'),
          selected: entry.key == selected,
          onPressed: () => Navigator.pop(sheet, entry.key),
          child: Row(
            children: [
              Expanded(child: AppText(entry.value.label)),
              const SizedBox(width: 12),
              AppText(
                '${entry.value.count} 本',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
    ],
  ),
);

Future<String?> chooseBookCategory(
  BuildContext context,
  LocalLibraryPreferences organization, {
  int? bookId,
  String? selected,
  Iterable<int>? bookIds,
  bool reduceMotion = false,
}) async {
  final ids = bookIds?.toSet() ?? {?bookId};
  final current = selected == null
      ? ids.map(organization.groupOf).toSet()
      : {selected};
  return showJellySheet<String>(
    context: context,
    reduceMotion: reduceMotion,
    heightFactor: .72,
    builder: (sheet) => _CategoryListSheet(
      organization: organization,
      selected: current.length == 1 ? current.single : '',
      reduceMotion: reduceMotion,
      assignment: true,
      onSelected: (value) => Navigator.pop(sheet, value),
    ),
  );
}

class _CategoryNameSheet extends StatefulWidget {
  const _CategoryNameSheet({required this.organization, this.id});
  final LocalLibraryPreferences organization;
  final String? id;
  @override
  State<_CategoryNameSheet> createState() => _CategoryNameSheetState();
}

class _CategoryNameSheetState extends State<_CategoryNameSheet> {
  late final text = TextEditingController(
    text: widget.id == null ? '' : widget.organization.groups[widget.id],
  );
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final id = widget.id ?? await widget.organization.addGroup(text.text);
      if (widget.id != null) {
        await widget.organization.renameGroup(id, text.text);
      }
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        showNovelFeedback(context, e is FormatException ? e.message : '分类保存失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ArchiveSection(
          title: widget.id == null ? '新建分类' : '重命名分类',
          code: 'LIBRARY / CATEGORY',
        ),
        const SizedBox(height: 20),
        CupertinoTextField(
          key: const ValueKey('category-name'),
          onTap: () => AppHaptics.play(context, HapticCue.selection),
          onSubmitted: (_) => AppHaptics.play(context, HapticCue.action),
          controller: text,
          enabled: !busy,
          placeholder: appText(context, '分类名称'),
          maxLength: 30,
          padding: const EdgeInsets.all(16),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 18),
        GlassPillButton(
          icon: CupertinoIcons.checkmark,
          key: const ValueKey('category-save'),
          label: '保存分类',
          onPressed: busy ? null : save,
        ),
      ],
    ),
  );
}

class _CategoryListSheet extends StatefulWidget {
  const _CategoryListSheet({
    required this.organization,
    required this.selected,
    required this.reduceMotion,
    required this.onSelected,
    this.assignment = false,
  });
  final LocalLibraryPreferences organization;
  final String selected;
  final bool assignment;
  final bool reduceMotion;
  final ValueChanged<String> onSelected;
  @override
  State<_CategoryListSheet> createState() => _CategoryListSheetState();
}

class _CategoryListSheetState extends State<_CategoryListSheet> {
  List<String>? _pendingOrder;
  String? _revealed;
  bool _busy = false;

  Future<void> _editCategory([String? id]) async {
    setState(() => _revealed = null);
    await showJellySheet<String>(
      context: context,
      reduceMotion: widget.reduceMotion,
      heightFactor: .58,
      builder: (_) =>
          _CategoryNameSheet(organization: widget.organization, id: id),
    );
  }

  Future<void> _deleteCategory(String id) async {
    setState(() => _revealed = null);
    try {
      if (await confirmNovelAction(
        context,
        title: '删除这个分类？',
        message: '书籍会回到未分类，原书与阅读记录保留。',
        confirmLabel: '删除分类',
        reduceMotion: widget.reduceMotion,
      )) {
        await widget.organization.removeGroup(id);
      }
    } catch (error) {
      if (mounted) {
        showNovelFeedback(
          context,
          error is FormatException ? error.message : '分类删除失败，请重试',
        );
      }
    }
  }

  Future<void> _reorder(int from, int to) async {
    if (_busy) return;
    final order = widget.organization.groups.keys.toList();
    final item = order.removeAt(from);
    order.insert(to, item);
    setState(() {
      _pendingOrder = order;
      _busy = true;
      _revealed = null;
    });
    try {
      await widget.organization.reorderGroups(order);
    } catch (error) {
      if (mounted) {
        showNovelFeedback(
          context,
          error is FormatException ? error.message : '分类顺序保存失败，请重试',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingOrder = null;
          _busy = false;
        });
      }
    }
  }

  Widget _fixedCategory(String id, String name) => GlassTextButton(
    key: ValueKey('category-select-$id'),
    selected: id == widget.selected,
    onPressed: _busy ? null : () => widget.onSelected(id),
    child: AppText(name),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.organization,
    builder: (context, _) {
      final groups = widget.organization.groups;
      final order = (_pendingOrder ?? groups.keys.toList())
          .where(groups.containsKey)
          .toList();
      order.addAll(groups.keys.where((id) => !order.contains(id)));
      return ReorderableListView.builder(
        key: const ValueKey('custom-category-list'),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => PhysicalShape(
            key: const ValueKey('category-drag-proxy'),
            clipper: const _CategoryDragClipper(),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.surface,
            shadowColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .18),
            elevation:
                widget.reduceMotion || MediaQuery.disableAnimationsOf(context)
                ? 0
                : 6 * Curves.easeInOut.transform(animation.value),
            child: child,
          ),
        ),
        onReorderItem: _reorder,
        onReorderStart: (_) {
          setState(() => _revealed = null);
          AppHaptics.play(context, HapticCue.action);
        },
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ArchiveSection(title: '书籍分类', code: 'LIBRARY / CATEGORIES'),
            const SizedBox(height: 16),
            if (!widget.assignment) ...[
              const ArchiveSection(title: '自动分类', code: 'LIBRARY / GROUP BY'),
              const SizedBox(height: 12),
              for (final choice in const {
                '_authors': '按作者分类',
                '_tags': '按标签分类',
                '_series': '按系列分类',
              }.entries)
                GlassTextButton(
                  key: ValueKey(
                    'category-by-${choice.key.substring(1).replaceFirst('authors', 'author').replaceFirst('tags', 'tag')}',
                  ),
                  onPressed: _busy ? null : () => widget.onSelected(choice.key),
                  child: AppText(choice.value),
                ),
              const SizedBox(height: 20),
            ],
            ArchiveSection(
              title: widget.assignment ? '自定义分类' : '全部与自定义分类',
              code: 'LIBRARY / CUSTOM',
            ),
            const SizedBox(height: 12),
            if (!widget.assignment)
              _fixedCategory(LocalLibraryPreferences.all, '全部书籍'),
            _fixedCategory(LocalLibraryPreferences.unfiled, '未分类'),
          ],
        ),
        itemCount: order.length,
        itemBuilder: (context, index) {
          final id = order[index], name = groups[id]!;
          return ReorderableDelayedDragStartListener(
            key: ValueKey('custom-category-$id'),
            index: index,
            enabled: !_busy,
            child: _CategorySwipeRow(
              id: id,
              name: name,
              selected: id == widget.selected,
              revealed: _revealed == id,
              reduceMotion: widget.reduceMotion,
              onReveal: (value) =>
                  setState(() => _revealed = value ? id : null),
              index: index,
              onSelect: _busy ? null : () => widget.onSelected(id),
              onEdit: _busy ? null : () => _editCategory(id),
              onDelete: _busy ? null : () => _deleteCategory(id),
            ),
          );
        },
        footer: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: GlassPillButton(
            key: const ValueKey('category-create'),
            icon: CupertinoIcons.plus,
            label: '新建自定义分类',
            onPressed: _busy ? null : _editCategory,
          ),
        ),
      );
    },
  );
}

class _CategorySwipeRow extends StatefulWidget {
  const _CategorySwipeRow({
    required this.id,
    required this.index,
    required this.name,
    required this.selected,
    required this.revealed,
    required this.reduceMotion,
    required this.onReveal,
    this.onSelect,
    this.onEdit,
    this.onDelete,
  });
  final String id, name;
  final int index;
  final bool selected, revealed, reduceMotion;
  final ValueChanged<bool> onReveal;
  final VoidCallback? onSelect, onEdit, onDelete;
  @override
  State<_CategorySwipeRow> createState() => _CategorySwipeRowState();
}

class _CategorySwipeRowState extends State<_CategorySwipeRow> {
  double _dragOffset = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final colors = Theme.of(context).colorScheme;
      final actionWidth = math.min(56.0, constraints.maxWidth / 2);
      final extent = actionWidth * 2;
      final offset = _dragging
          ? _dragOffset.clamp(0.0, extent)
          : (widget.revealed ? extent : 0.0);
      return Semantics(
        customSemanticsActions: {
          if (widget.onEdit != null)
            CustomSemanticsAction(label: '编辑分类 ${widget.name}'): widget.onEdit!,
          if (widget.onDelete != null)
            CustomSemanticsAction(label: '删除分类 ${widget.name}'):
                widget.onDelete!,
        },
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !widget.revealed,
                  child: ExcludeSemantics(
                    excluding: !widget.revealed,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: actionWidth,
                          child: GlassIconButton(
                            key: ValueKey('category-edit-${widget.id}'),
                            icon: CupertinoIcons.pencil,
                            label: '重命名 ${widget.name}',
                            onPressed: widget.onEdit,
                            liveGlass: false,
                          ),
                        ),
                        SizedBox(
                          width: actionWidth,
                          child: GlassIconButton(
                            key: ValueKey('category-delete-${widget.id}'),
                            icon: CupertinoIcons.trash,
                            label: '删除分类 ${widget.name}',
                            color: colors.error,
                            onPressed: widget.onDelete,
                            liveGlass: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onHorizontalDragStart: widget.onSelect == null
                    ? null
                    : (_) => setState(() {
                        _dragging = true;
                        _dragOffset = widget.revealed ? extent : 0;
                      }),
                onHorizontalDragUpdate: widget.onSelect == null
                    ? null
                    : (details) => setState(() {
                        _dragOffset = (_dragOffset - details.delta.dx).clamp(
                          0.0,
                          extent,
                        );
                      }),
                onHorizontalDragEnd: widget.onSelect == null
                    ? null
                    : (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        widget.onReveal(
                          velocity < -300 ||
                              (velocity <= 300 && _dragOffset > extent * .35),
                        );
                        setState(() => _dragging = false);
                      },
                onHorizontalDragCancel: () => setState(() => _dragging = false),
                child: AnimatedContainer(
                  duration:
                      _dragging ||
                          widget.reduceMotion ||
                          MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : NovelMotion.contact,
                  curve: NovelMotion.ease,
                  transform: Matrix4.translationValues(-offset, 0, 0),
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: 4,
                        bottom: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                      GlassTextButton(
                        key: ValueKey('category-select-${widget.id}'),
                        selected: widget.selected,
                        onPressed: widget.onSelect == null
                            ? null
                            : () {
                                if (widget.revealed) {
                                  widget.onReveal(false);
                                } else {
                                  widget.onSelect!();
                                }
                              },
                        child: Row(
                          children: [
                            Expanded(child: AppText(widget.name)),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        bottom: 4,
                        right: 0,
                        width: 48,
                        child: ReorderableDragStartListener(
                          key: ValueKey('category-drag-${widget.id}'),
                          index: widget.index,
                          enabled: widget.onSelect != null,
                          child: Semantics(
                            label: '调整分类顺序',
                            child: const Center(
                              child: ArchiveIcon(
                                CupertinoIcons.line_horizontal_3,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Match the optical plate, including GlassTextButton's four-pixel gutters.
class _CategoryDragClipper extends CustomClipper<Path> {
  const _CategoryDragClipper();
  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 4, size.width, math.max(0, size.height - 8)),
        const Radius.circular(22),
      ),
    );
  @override
  bool shouldReclip(_CategoryDragClipper oldClipper) => false;
}
