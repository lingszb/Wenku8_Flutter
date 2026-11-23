import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_search_field.dart';
import 'app_ui.dart';
import 'book_documents.dart';
import 'catalog.dart';
import 'feature_pages.dart' show confirmNovelAction;
import 'library_state.dart';
import 'listening/widgets.dart';
import 'local_books.dart';
import 'local_book_removal.dart';
import 'local_import_batch.dart';
import 'local_import_review.dart';
import 'local_library_preferences.dart';
import 'local_maintenance_page.dart';
import 'local_series_editor.dart';

Future<void> openLocalBookBatch(
  BuildContext context, {
  required LocalBookStore books,
  required LibraryState library,
  Set<int>? selected,
  BookDocuments? documents,
}) => pushNovelPage<void>(
  context,
  LocalBookBatchPage(
    books: books,
    library: library,
    selected: selected,
    documents: documents,
  ),
  reduceMotion: library.reduceMotion,
);

class LocalBookBatchPage extends StatefulWidget {
  const LocalBookBatchPage({
    super.key,
    required this.books,
    required this.library,
    this.selected,
    this.documents,
  });
  final LocalBookStore books;
  final LibraryState library;
  final Set<int>? selected;
  final BookDocuments? documents;
  @override
  State<LocalBookBatchPage> createState() => _LocalBookBatchPageState();
}

enum _BatchTask { volumes, archive, category, cover }

enum _CoverMode { shared, ordered }

class _LocalBookBatchPageState extends State<LocalBookBatchPage> {
  late final _selected = {...?widget.selected};
  final _search = TextEditingController();
  final _results = <String>[];
  bool _busy = false, _stop = false, _hidden = false, _stoppable = false;
  int _done = 0, _total = 0;
  _BatchTask _task = _BatchTask.volumes;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _archived => _task == _BatchTask.archive && _hidden;

  List<Novel> get _targets {
    if (_selected.isEmpty) return [];
    final available = {
      for (final book in widget.books.books)
        if (widget.library.localBookVisible(book.id) != _archived)
          book.id: book,
    };
    return _selected.map((id) => available[id]).whereType<Novel>().toList();
  }

  List<Novel> get _visible {
    final words = _search.text.trim().toLowerCase().split(RegExp(r'\s+'));
    return widget.books.books.where((book) {
      final hidden = !widget.library.localBookVisible(book.id);
      final text = '${book.title} ${book.author}'.toLowerCase();
      return hidden == _archived && words.every(text.contains);
    }).toList();
  }

  void _progress(int done, int total) {
    if (mounted) {
      setState(() {
        _done = done;
        _total = total;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _targets.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _stop = false;
      _done = 0;
      _total = 0;
      _results.clear();
    });
    try {
      await action();
    } catch (error) {
      _results.add(
        error is FormatException ? error.message : '操作未完成，请重试；原书和阅读记录保留',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stoppable = false;
        });
      }
    }
  }

  Future<void> _stopListening(Iterable<int> ids) async {
    final playing = ListeningScope.maybeOf(context);
    final id = playing?.snapshot.value.novel?.id;
    final originals = widget.books.maintenanceOriginals(ids);
    if (id != null && (ids.contains(id) || originals.contains(id))) {
      await playing!.stop();
    }
  }

  Future<void> _category() async {
    final organization = widget.library.organization;
    final value = await showJellySheet<String>(
      context: context,
      reduceMotion: widget.library.reduceMotion,
      heightFactor: .65,
      builder: (sheet) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const ArchiveSection(title: '移动分类', code: 'LOCAL / CATEGORY'),
          for (final entry in {
            LocalLibraryPreferences.unfiled: '未分类',
            ...organization.groups,
          }.entries)
            GlassTextButton(
              onPressed: () => Navigator.pop(sheet, entry.key),
              child: AppText(entry.value),
            ),
          GlassTextButton(
            onPressed: () => Navigator.pop(sheet, '_new'),
            child: const AppText('新建分类'),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    String target = value;
    if (value == '_new') {
      final name = await _askName('新建分类');
      if (name == null || !mounted) return;
      try {
        target = await organization.addGroup(name);
      } catch (error) {
        if (mounted) {
          showNovelFeedback(
            context,
            error is FormatException ? error.message : '分类创建失败，请重试',
          );
        }
        return;
      }
    }
    if (!mounted) return;
    await _run(() async {
      final ids = _targets.map((book) => book.id).toList();
      await organization.assignMany(ids, target);
      _results.add('已移动 ${ids.length} 本书至${organization.nameOf(target)}');
    });
  }

  Future<String?> _askName(String title) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 160,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, controller.text),
              child: const Text('确认'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _remove({required bool archived}) async {
    final choice = archived
        ? LocalBookRemoval.files
        : await showJellySheet<LocalBookRemoval>(
            context: context,
            reduceMotion: widget.library.reduceMotion,
            heightFactor: .48,
            builder: (sheet) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const ArchiveSection(title: '移除所选书籍', code: 'LOCAL / REMOVE'),
                const AppText(
                  '仅移出保留文件，可从“已移出书架”中恢复。删除本机文件只处理 App 管理的副本，原文件和阅读记录保留。',
                ),
                GlassTextButton(
                  onPressed: () =>
                      Navigator.pop(sheet, LocalBookRemoval.shelfOnly),
                  child: const AppText('仅移出书架'),
                ),
                GlassTextButton(
                  onPressed: () => Navigator.pop(sheet, LocalBookRemoval.files),
                  child: const AppText('同时删除本机文件'),
                ),
              ],
            ),
          );
    if (!mounted || choice == null) return;
    await _run(() async {
      final ids = _targets.map((b) => b.id).toSet();
      if (choice == LocalBookRemoval.files &&
          !await confirmNovelAction(
            context,
            title: '删除 ${ids.length} 本书的本机文件？',
            message: '合订本包含的分卷一起删除。只删除 App 管理的副本，不删除外部原文件；阅读进度和书签保留。',
            confirmLabel: '删除本机文件',
            reduceMotion: widget.library.reduceMotion,
          )) {
        return;
      }
      if (!mounted) return;
      await _stopListening(ids);
      final result = await removeLocalBooks(
        ids: ids,
        choice: choice,
        books: widget.books,
        library: widget.library,
        onProgress: _progress,
      );
      _selected.removeAll(result.removed);
      _results.add(
        '已处理 ${result.removed.length} 本，失败 ${result.failed.length} 本',
      );
      for (final id in result.failed) {
        _results.add('${widget.books.book(id)?.title ?? '书籍'}：移除未完成，请重试');
      }
    });
  }

  Future<void> _restore() => _run(() async {
    final ids = _targets.map((b) => b.id).toList();
    await widget.library.setLocalBooksHidden(ids, false);
    _selected.removeAll(ids);
    _results.add('已恢复 ${ids.length} 本书');
  });

  Future<void> _covers({bool restore = false}) => _run(() async {
    final books = _targets;
    final documents = widget.documents ?? BookDocuments();
    final images = <BookDocumentSelection>[];
    try {
      _CoverMode? mode;
      if (!restore) {
        mode = await showDialog<_CoverMode>(
          context: context,
          builder: (dialog) => SimpleDialog(
            title: const Text('批量更换封面'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialog, _CoverMode.shared),
                child: const Text('共用一张图片'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialog, _CoverMode.ordered),
                child: const Text('按勾选顺序逐本配图'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text('第 1 本勾选的书使用第 1 张图片，以此类推。全选时按当前列表顺序加入队列。'),
              ),
            ],
          ),
        );
        if (!mounted || mode == null) return;
        final ordered = mode == _CoverMode.ordered;
        final imageCount = ordered ? books.length : 1;
        for (var index = 0; index < imageCount; index++) {
          if (ordered) {
            final proceed = await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: Text('选择图片 ${index + 1} / $imageCount'),
                content: SingleChildScrollView(child: Text(books[index].title)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('取消队列'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('选择图片'),
                  ),
                ],
              ),
            );
            if (!mounted || proceed != true) return;
          }
          final image = await documents.pickImage();
          if (image == null) return;
          images.add(image);
          if (!mounted) return;
          if (image.path?.isNotEmpty != true) {
            throw FormatException(image.error ?? '图片不可读取，请重新选择');
          }
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('确认更换 ${books.length} 本书的封面'),
            content: SizedBox(
              width: 420,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: books.length,
                itemBuilder: (_, index) => ListTile(
                  title: Text('${index + 1}. ${books[index].title}'),
                  subtitle: Text(images[ordered ? index : 0].name),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('更换封面'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      setState(() => _stoppable = true);
      _progress(0, books.length);
      for (final (index, book) in books.indexed) {
        if (_stop) break;
        try {
          final updated = restore
              ? await widget.books.restoreCover(book.id)
              : await widget.books.setCover(
                  book.id,
                  images[mode == _CoverMode.ordered ? index : 0].path!,
                );
          await widget.library.setShelfMembership(
            updated.id,
            widget.library.contains(updated.id),
            novel: updated,
          );
          _results.add('${book.title}：封面已${restore ? '恢复' : '更换'}');
        } catch (error) {
          _results.add(
            '${book.title}：${error is FormatException ? error.message : '封面保存失败，请重试'}',
          );
        }
        _progress(index + 1, books.length);
      }
      if (_done < _total) _results.add('已停止，剩余 ${_total - _done} 本未处理');
    } finally {
      if (images.isNotEmpty) {
        try {
          await documents.releaseBooks(images);
        } catch (_) {
          _results.add('选图临时文件清理失败');
        }
      }
    }
  });

  Future<void> _maintenance() async {
    final ids = _targets.map((book) => book.id).toSet();
    await _stopListening(ids);
    if (!mounted) return;
    await pushNovelPage<void>(
      context,
      LocalMaintenancePage(
        books: widget.books,
        library: widget.library,
        selected: ids,
      ),
      reduceMotion: widget.library.reduceMotion,
    );
  }

  Future<void> _merge({bool suggestions = false}) async {
    if (suggestions) {
      await pushNovelPage<void>(
        context,
        LocalImportReview(
          books: widget.books,
          library: widget.library,
          mergeOnly: true,
          report: LocalImportReport(
            bookIds:
                (_targets.isEmpty
                        ? widget.books.books.where(
                            (book) => widget.library.localBookVisible(book.id),
                          )
                        : _targets)
                    .map((b) => b.id)
                    .toList(),
          ),
        ),
        reduceMotion: widget.library.reduceMotion,
      );
    } else {
      final selected = _targets;
      final collections = selected
          .where((book) => widget.books.seriesFor(book.id)?.id == book.id)
          .toList();
      if (collections.length > 1) {
        showNovelFeedback(context, '请只选择一个已有合订本作为目标，再选择要加入的独立分卷；多个合订本请先分别解散。');
        return;
      }
      if (collections.isNotEmpty) {
        selected.remove(collections.single);
        selected.insert(0, collections.single);
      }
      if (selected.isEmpty) return;
      await pushNovelPage<LocalSeriesEditResult>(
        context,
        LocalSeriesEditor(
          book: selected.first,
          books: widget.books,
          library: widget.library,
          initialIds: selected.map((b) => b.id).toList(),
        ),
        reduceMotion: widget.library.reduceMotion,
      );
    }
    if (mounted) {
      setState(() {
        _selected.removeWhere(
          (id) => !widget.books.books.any((b) => b.id == id),
        );
      });
    }
  }

  Widget _actions(bool active) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: switch (_task) {
      _BatchTask.volumes => [
        _action('合并与分卷顺序', active ? () => _merge() : null),
        _action('推荐合并', _busy ? null : () => _merge(suggestions: true)),
      ],
      _BatchTask.archive => [
        if (_archived) _action('恢复到书架', active ? _restore : null),
        _action(
          _archived ? '删除本机文件' : '移除书籍',
          active ? () => _remove(archived: _archived) : null,
        ),
        _action('修复与整理', active ? _maintenance : null),
      ],
      _BatchTask.category => [_action('移动分类', active ? _category : null)],
      _BatchTask.cover => [
        _action('更换封面', active ? () => _covers() : null),
        _action('恢复原封面', active ? () => _covers(restore: true) : null),
      ],
    },
  );

  Widget _action(String label, VoidCallback? onPressed) =>
      GlassTextButton(onPressed: onPressed, child: AppText(label));

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_busy,
    child: Scaffold(
      body: Atmosphere(
        child: GlassHeaderLayout(
          header: ArchiveHeaderBar(
            leading: GlassIconButton(
              icon: CupertinoIcons.back,
              label: '返回',
              onPressed: _busy ? null : () => Navigator.pop(context),
            ),
            title: const ArchiveRouteTitle(title: '批量整理', code: ''),
          ),
          body: ListenableBuilder(
            listenable: Listenable.merge([
              widget.books,
              widget.library.shelfViewChanges,
              widget.library.organization,
            ]),
            builder: (context, _) {
              final visible = _visible;
              final positions = {
                for (final (index, book) in _targets.indexed)
                  book.id: index + 1,
              };
              final active = !_busy && positions.isNotEmpty;
              return CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.paddingOf(context).top +
                          FrostedHeader.toolbarHeight +
                          12,
                      16,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final (task, icon, label) in const [
                                (
                                  _BatchTask.volumes,
                                  ArchiveSymbol.layers,
                                  '合并分卷',
                                ),
                                (
                                  _BatchTask.archive,
                                  ArchiveSymbol.folder,
                                  '归档处理',
                                ),
                                (
                                  _BatchTask.category,
                                  ArchiveSymbol.grid,
                                  '批量分类',
                                ),
                                (_BatchTask.cover, ArchiveSymbol.image, '批量封面'),
                              ])
                                ChoiceChip(
                                  avatar: ArchiveIcon.symbol(icon, size: 18),
                                  label: Text(label),
                                  showCheckmark: false,
                                  selected: _task == task,
                                  onSelected: _busy
                                      ? null
                                      : (_) => setState(() {
                                          _task = task;
                                          _results.clear();
                                        }),
                                ),
                            ],
                          ),
                          if (_task == _BatchTask.archive)
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final (hidden, label) in const [
                                  (false, '书架上'),
                                  (true, '已移出书架'),
                                ])
                                  ChoiceChip(
                                    label: Text(label),
                                    selected: _hidden == hidden,
                                    onSelected: _busy
                                        ? null
                                        : (_) => setState(() {
                                            _hidden = hidden;
                                            _results.clear();
                                          }),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          AppSearchField(
                            controller: _search,
                            hint: '搜索书名、作者',
                            onChanged: (_) => setState(() {}),
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _busy || visible.isEmpty
                                    ? null
                                    : () => setState(
                                        () => _selected.addAll(
                                          visible.map((book) => book.id),
                                        ),
                                      ),
                                child: const Text('全选结果'),
                              ),
                              TextButton(
                                onPressed: _busy || visible.isEmpty
                                    ? null
                                    : () => setState(
                                        () => _selected.removeAll(
                                          visible.map((book) => book.id),
                                        ),
                                      ),
                                child: const Text('取消选择结果'),
                              ),
                              Text('已选 ${positions.length} 本'),
                            ],
                          ),
                          _actions(active),
                          if (_task == _BatchTask.volumes && positions.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('未选书籍时，推荐合并会检查书架上的全部书籍。'),
                            ),
                          if (_task == _BatchTask.cover)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('勾选顺序即配图顺序。也可为所选书籍共用同一张图片。'),
                            ),
                          if (_busy) ...[
                            const SizedBox(height: 12),
                            if (_total > 0)
                              LinearProgressIndicator(value: _done / _total),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _total == 0 ? '处理中' : '处理中 $_done / $_total',
                                ),
                                if (_stoppable)
                                  TextButton(
                                    onPressed: _stop
                                        ? null
                                        : () => setState(() => _stop = true),
                                    child: Text(_stop ? '等待当前操作完成' : '停止'),
                                  ),
                              ],
                            ),
                          ],
                          if (_results.isNotEmpty)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 128),
                              child: ListView.builder(
                                padding: const EdgeInsets.only(top: 8),
                                primary: false,
                                shrinkWrap: true,
                                itemCount: _results.length,
                                itemBuilder: (_, index) =>
                                    AppText(_results[index]),
                              ),
                            ),
                          const Divider(height: 24),
                          if (visible.isEmpty) const Text('当前范围没有书籍'),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      0,
                      8,
                      MediaQuery.paddingOf(context).bottom + 16,
                    ),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final book = visible[index];
                        final position = positions[book.id];
                        return CheckboxListTile(
                          value: position != null,
                          title: Text(book.title),
                          subtitle: Text(
                            _task == _BatchTask.cover && position != null
                                ? '队列第 $position 本 · ${book.author}'
                                : book.author,
                          ),
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(book.id);
                                  } else {
                                    _selected.remove(book.id);
                                  }
                                }),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
