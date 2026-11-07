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
}) => pushNovelPage<void>(
  context,
  LocalBookBatchPage(books: books, library: library, selected: selected),
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

class _LocalBookBatchPageState extends State<LocalBookBatchPage> {
  late final _selected = {...?widget.selected};
  final _search = TextEditingController();
  final _results = <String>[];
  bool _busy = false, _stop = false, _hidden = false, _stoppable = false;
  int _done = 0, _total = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Novel> get _targets =>
      widget.books.books.where((book) => _selected.contains(book.id)).toList();

  List<Novel> get _visible {
    final words = _search.text.trim().toLowerCase().split(RegExp(r'\s+'));
    return widget.books.books.where((book) {
      final hidden = !widget.library.localBookVisible(book.id);
      final text = '${book.title} ${book.author}'.toLowerCase();
      return hidden == _hidden && words.every(text.contains);
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

  Future<void> _remove() async {
    final choice = await showJellySheet<LocalBookRemoval>(
      context: context,
      reduceMotion: widget.library.reduceMotion,
      heightFactor: .48,
      builder: (sheet) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const ArchiveSection(title: '移除所选书籍', code: 'LOCAL / REMOVE'),
          const AppText('仅移出保留文件，可从“已移出书架”中恢复。删除本机文件只处理 App 管理的副本，原文件和阅读记录保留。'),
          GlassTextButton(
            onPressed: () => Navigator.pop(sheet, LocalBookRemoval.shelfOnly),
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
    _stoppable = true;
    final books = _targets;
    final documents = widget.documents ?? BookDocuments();
    final image = restore ? null : await documents.pickImage();
    if (!restore && image == null) return;
    try {
      final path = image?.path;
      if (!restore && (path == null || path.isEmpty)) {
        throw const FormatException('图片不可读取，请重新选择');
      }
      for (final (index, book) in books.indexed) {
        if (_stop) break;
        try {
          final updated = restore
              ? await widget.books.restoreCover(book.id)
              : await widget.books.setCover(book.id, path!);
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
    } finally {
      if (image != null) await documents.releaseBooks([image]);
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
          report: LocalImportReport(
            bookIds: _targets.map((b) => b.id).toList(),
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
            title: const ArchiveRouteTitle(
              title: '批量整理本地书',
              code: 'LOCAL / BATCH',
            ),
          ),
          body: ListenableBuilder(
            listenable: Listenable.merge([
              widget.books,
              widget.library.shelfViewChanges,
              widget.library.organization,
            ]),
            builder: (context, _) {
              final visible = _visible;
              final active = !_busy && _targets.isNotEmpty;
              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.paddingOf(context).top +
                        FrostedHeader.toolbarHeight +
                        12,
                    16,
                    8,
                  ),
                  child: Column(
                    children: [
                      AppSearchField(
                        controller: _search,
                        hint: '搜索书名、作者',
                        onChanged: (_) => setState(() {}),
                      ),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilterChip(
                            label: const Text('已移出书架'),
                            selected: _hidden,
                            onSelected: _busy
                                ? null
                                : (value) => setState(() => _hidden = value),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _selected.addAll(
                                      visible.map((b) => b.id),
                                    ),
                                  ),
                            child: const Text('全选结果'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _selected.removeAll(
                                      visible.map((b) => b.id),
                                    ),
                                  ),
                            child: const Text('取消选择结果'),
                          ),
                          Text('已选 ${_targets.length} 本'),
                        ],
                      ),
                      if (_busy) ...[
                        LinearProgressIndicator(
                          value: _total == 0 ? null : _done / _total,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('处理中 $_done / $_total'),
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
                      Expanded(
                        child: visible.isEmpty
                            ? const Center(child: Text('当前范围没有书籍'))
                            : ListView.builder(
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final book = visible[index];
                                  return CheckboxListTile(
                                    value: _selected.contains(book.id),
                                    title: Text(book.title),
                                    subtitle: Text(book.author),
                                    onChanged: _busy
                                        ? null
                                        : (value) => setState(() {
                                            value == true
                                                ? _selected.add(book.id)
                                                : _selected.remove(book.id);
                                          }),
                                  );
                                },
                              ),
                      ),
                      if (_results.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 130),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final message in _results) AppText(message),
                            ],
                          ),
                        ),
                      SizedBox(
                        height: 96,
                        child: SingleChildScrollView(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              GlassTextButton(
                                onPressed: active ? _category : null,
                                child: const AppText('移动分类'),
                              ),
                              GlassTextButton(
                                onPressed: active ? _remove : null,
                                child: const AppText('移除'),
                              ),
                              if (_hidden)
                                GlassTextButton(
                                  onPressed: active ? _restore : null,
                                  child: const AppText('恢复到书架'),
                                ),
                              GlassTextButton(
                                onPressed: active ? _maintenance : null,
                                child: const AppText('修复与整理'),
                              ),
                              GlassTextButton(
                                onPressed: active ? () => _covers() : null,
                                child: const AppText('更换封面'),
                              ),
                              GlassTextButton(
                                onPressed: active
                                    ? () => _covers(restore: true)
                                    : null,
                                child: const AppText('恢复原封面'),
                              ),
                              GlassTextButton(
                                onPressed: active ? () => _merge() : null,
                                child: const AppText('合并与分卷顺序'),
                              ),
                              GlassTextButton(
                                onPressed: active
                                    ? () => _merge(suggestions: true)
                                    : null,
                                child: const AppText('同系列分卷建议'),
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
          ),
        ),
      ),
    ),
  );
}
