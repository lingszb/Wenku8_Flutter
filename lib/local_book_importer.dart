import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_interactions.dart';
import 'app_ui.dart';
import 'book_documents.dart';
import 'book_sync.dart';
import 'catalog.dart';
import 'cloud_library_page.dart';
import 'cloud_sources.dart';
import 'cloud_book_sync_panel.dart';
import 'library_state.dart';
import 'local_books.dart';
import 'local_document_reference.dart';
import 'local_book_scanner.dart';
import 'local_import_batch.dart';
import 'local_import_review.dart';
import 'local_import_page.dart';
import 'local_library_preferences.dart';
import 'local_series_actions.dart';
import 'local_scan_page.dart';
import 'local_scan_selection.dart';

/// Category writes follow the finite selected batch, not every parsed member.
/// Books are durable first; a failed assignment is reported without reimporting
/// or deleting them. Repeated books retain their last observed target category.
class _ImportedCategoryBatch {
  final _assignments = <int, ({String group, String name, int revision})>{};

  void add(Novel book, String group, int revision) {
    _assignments[book.id] = (
      group: group,
      name: book.title,
      revision: revision,
    );
  }

  Future<List<LocalImportNotice>> commit(
    LocalLibraryPreferences organization,
    Iterable<int> imported,
  ) async {
    if (_assignments.isEmpty) return const [];
    final accepted = imported.toSet();
    final groups = <String, Map<int, ({String name, int revision})>>{};
    for (final entry in _assignments.entries) {
      if (accepted.contains(entry.key) &&
          organization.assignmentRevision(entry.key) == entry.value.revision) {
        (groups[entry.value.group] ??= {})[entry.key] = (
          name: entry.value.name,
          revision: entry.value.revision,
        );
      }
    }
    final notices = <LocalImportNotice>[];
    for (final entry in groups.entries) {
      try {
        await organization.assignMany(
          entry.value.keys,
          entry.key,
          expectedRevisions: {
            for (final book in entry.value.entries)
              book.key: book.value.revision,
          },
        );
      } catch (_) {
        notices.addAll([
          for (final book in entry.value.entries)
            if (organization.assignmentRevision(book.key) ==
                book.value.revision)
              (name: book.value.name, message: '已导入，但分类未保存。可在“全部书籍”中重新分类。'),
        ]);
      }
    }
    return notices;
  }
}

/// The task belongs to the library, rather than the route that started it.
class _LocalImportSession extends ChangeNotifier {
  bool busy = false;
  (int, int)? progress;
  String? error, status;
  LocalScanResult? scanResult;
  LocalImportReport? report;
  BookScanSnapshot? pendingScan;
  BookDocuments? scanDocuments;
  void changed() => notifyListeners();
}

/// Shared by the two library entry points, including series review and cleanup.
class LocalBookImporter extends ChangeNotifier {
  LocalBookImporter({
    required this.books,
    required this.library,
    BookDocuments? documents,
    CloudSourceSettings? cloudSettings,
  }) : documents = documents ?? BookDocuments(),
       _cloud = cloudSettings ?? CloudSourceSettings(),
       _ownsCloud = cloudSettings == null {
    _session.addListener(_relayChanges);
  }
  final LocalBookStore books;
  final LibraryState library;
  final BookDocuments documents;
  final CloudSourceSettings _cloud;
  final bool _ownsCloud;
  static final _sessions = Expando<_LocalImportSession>();
  late final _session = _sessions[library] ??= _LocalImportSession();
  bool _disposed = false;
  bool get busy => _session.busy;
  set busy(bool value) => _session.busy = value;
  (int, int)? get progress => _session.progress;
  set progress((int, int)? value) => _session.progress = value;
  String? get error => _session.error;
  set error(String? value) => _session.error = value;
  LocalScanResult? get scanResult => _session.scanResult;
  set scanResult(LocalScanResult? value) => _session.scanResult = value;
  bool get hasPendingScan => _session.pendingScan != null;
  bool get hasStatus => busy || hasPendingScan || _session.status != null;
  bool get canShowStatus =>
      _session.scanDocuments != null || _session.report != null;
  String get statusLabel => busy
      ? progress == null
            ? _session.status ?? '正在准备导入…'
            : '正在导入 ${progress!.$1} / ${progress!.$2} 本'
      : hasPendingScan
      ? '扫描完成，待确认 ${_session.pendingScan!.books.length} 本，点击继续选择'
      : _session.status ?? '';

  void dismissStatus() {
    if (busy || hasPendingScan) return;
    _session.status = null;
    _session.report = null;
    _changed();
  }

  Future<void> discardPendingScan() async {
    if (busy || !hasPendingScan) return;
    await (_session.scanDocuments ?? documents).finishBookScan();
    _session.pendingScan = null;
    _session.scanDocuments = null;
    _session.status = '已清除待选扫描结果，可重新扫描；原文件和已导入书籍保留';
    _changed();
  }

  Future<void> showStatus(BuildContext context) async {
    if (hasPendingScan || busy && _session.scanDocuments != null) {
      await openScanPage(context);
    } else if (_session.report case final report?) {
      await pushNovelPage<void>(
        context,
        LocalImportReview(books: books, library: library, report: report),
        reduceMotion: library.reduceMotion,
      );
    } else if (_session.scanDocuments != null) {
      await openScanPage(context);
    }
  }

  static bool _scanning = false;
  static DateTime? _lastAutomaticScan;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Future<void> scanOnEntry(BuildContext context, {bool resumed = false}) async {
    if (!_foreground ||
        busy ||
        _disposed ||
        _scanning ||
        hasPendingScan ||
        (!resumed &&
            _lastAutomaticScan != null &&
            DateTime.now().difference(_lastAutomaticScan!) <
                const Duration(minutes: 1))) {
      return;
    }
    try {
      final folder = await documents.scanFolderInfo();
      if (folder == null ||
          !folder.automatic ||
          !folder.readable ||
          !_foreground ||
          !context.mounted ||
          _disposed ||
          ModalRoute.isCurrentOf(context) == false ||
          !TickerMode.valuesOf(context).enabled) {
        return;
      }
      await run(context, fromScan: true, automatic: true);
    } catch (_) {
      /* Revoked folders remain actionable from the scan page. */
    }
  }

  void _relayChanges() {
    if (!_disposed) notifyListeners();
  }

  void _changed() => _session.changed();

  Future<void> showMenu(
    BuildContext context, {
    bool management = false,
    VoidCallback? onManage,
    VoidCallback? onBatch,
    BookSync? sync,
  }) async {
    if (busy) return;
    final action = await showGlassMenu<String>(
      context: context,
      reduceMotion: library.reduceMotion,
      builder: (menu) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassMenuItem(
            label: '导入书籍',
            onPressed: () => Navigator.pop(menu, 'local'),
          ),
          if (onBatch != null)
            GlassMenuItem(
              order: 1,
              label: '批量整理',
              onPressed: () => Navigator.pop(menu, 'batch'),
            ),
          if (management)
            GlassMenuItem(
              order: 2,
              label: '本地分类与同步',
              onPressed: () => Navigator.pop(menu, 'manage'),
            ),
        ],
      ),
    );
    if (!context.mounted || action == null || _disposed) return;
    if (action == 'manage') {
      onManage?.call();
      return;
    }
    if (action == 'batch') {
      onBatch?.call();
      return;
    }
    await openImportPage(context, sync: sync);
  }

  Future<void> openScanPage(BuildContext context) => pushNovelPage<void>(
    context,
    LocalScanPage(
      documents: _session.scanDocuments ?? documents,
      changes: this,
      hasPending: () => hasPendingScan,
      onDiscard: discardPendingScan,
      isBusy: () => busy,
      progress: () => progress,
      result: () => scanResult,
      failure: () => error,
      onScan: (page) => run(page, fromScan: true),
    ),
    reduceMotion: library.reduceMotion,
  );

  /// Existing callers share the same hub and retain their picker contracts.
  Future<void> openImportPage(BuildContext context, {BookSync? sync}) async {
    if (busy || _disposed) return;
    BookSync? ownedSync;
    final activeSync =
        sync ??
        (ownedSync = BookSync(
          books: books,
          state: library,
          preferences: await SharedPreferences.getInstance(),
          documents: documents,
          organization: library.organization,
          cloudSources: _cloud,
        ));
    try {
      if (ownedSync != null) await activeSync.load();
      if (!context.mounted || _disposed) return;
      await pushNovelPage<void>(
        context,
        LocalImportPage(
          library: library,
          changes: this,
          isBusy: () => busy,
          progress: () => progress,
          failure: () => error,
          onScan: openScanPage,
          onManual: (page) => run(page),
          onCloud: (page) => run(page, fromCloud: true),
          onSyncSettings: (page) async {
            await _cloud.load();
            if (!page.mounted || _disposed) return;
            await showJellySheet<void>(
              context: page,
              reduceMotion: library.reduceMotion,
              heightFactor: .86,
              builder: (_) => CloudBookSyncPanel(sync: activeSync),
            );
          },
        ),
        reduceMotion: library.reduceMotion,
      );
    } finally {
      ownedSync?.dispose();
    }
  }

  Future<void> run(
    BuildContext context, {
    bool fromCloud = false,
    bool fromScan = false,
    bool automatic = false,
    bool copyLocal = false,
    List<BookDocumentSelection>? selectedBooks,
    Future<void> Function(LocalImportReport report)? onImported,
  }) async {
    if (busy || _disposed || fromScan && _scanning) return;
    if (fromScan) {
      _scanning = true;
      _lastAutomaticScan = DateTime.now();
      scanResult = null;
    }
    busy = true;
    progress = null;
    _session.report = null;
    _session.status = fromScan ? '正在扫描本地文件夹…' : '正在准备导入…';
    if (fromScan) {
      _session.scanDocuments ??= documents;
    } else if (!hasPendingScan) {
      _session.scanDocuments = null;
    }
    error = null;
    _changed();
    LocalLibraryPreferences? organization;
    List<BookDocumentSelection> selections = const [];
    final staged = <BookDocumentSelection>[];
    var stagingReleased = false;
    Future<void> releaseStaging() async {
      if (stagingReleased) return;
      final cleanup = <String, BookDocumentSelection>{
        for (final item in [...selections, ...staged])
          item.path ?? item.token ?? 'error:${item.name}': item,
      };
      try {
        await documents.releaseBooks(cleanup.values);
        stagingReleased = true;
      } catch (_) {
        /* Durable imports stay readable even if cache cleanup fails. */
      }
    }

    LocalImportReport? report;
    var keepScan = false;
    final scanDocuments = _session.scanDocuments ?? documents;
    try {
      final prefs = await SharedPreferences.getInstance();
      organization = library.organization;
      final encoding = prefs.getString('localTxtEncoding') ?? 'auto';
      final importOptions = organization.importOptions.effective;
      final fresh = <int>{};
      var categoryWarning = false;
      Future<Novel> registerImported(
        Novel imported, {
        _ImportedCategoryBatch? categories,
      }) async {
        final parent = books.seriesFor(imported.id);
        final book = parent == null ? imported : books.book(parent.id)!;
        if (parent != null) await reconcileLocalSeries(books, library);
        await library.setShelfMembership(book.id, false, novel: book);
        final group = library.combinedShelf
            ? organization!.shelfSelected
            : organization!.selected;
        if (group != LocalLibraryPreferences.all &&
            !LocalLibraryPreferences.dynamicCategory(group)) {
          if (categories == null) {
            await organization.assign(book.id, group);
          } else {
            categories.add(
              book,
              group,
              organization.assignmentRevision(book.id),
            );
          }
        }
        if (parent == null) fresh.add(book.id);
        return book;
      }

      Future<Novel> importFile(
        String name,
        String path, {
        _ImportedCategoryBatch? categories,
      }) async {
        String? decoded;
        late Novel imported;
        try {
          if (name.toLowerCase().endsWith('.txt')) {
            decoded = await documents.decodeTextFile(path, encoding: encoding);
          }
          imported = await books.importFile(
            name,
            path,
            decodedPath: decoded,
            options: importOptions,
            recoverDamagedEpub:
                !automatic && name.toLowerCase().endsWith('.epub'),
          );
          if ((copyLocal || !organization!.linkLocalBooks) &&
              books.isLinkedBook(imported.id)) {
            if (!books.isLinkedText(imported.id)) {
              await books.saveOriginalCopy(imported.id, path: path);
            } else {
              final reference = await documents.stagedTextReference(path);
              try {
                await books.saveLinkedCopy(imported.id, reference: reference);
              } finally {
                await books.textAccess.release(reference);
              }
            }
          }
        } finally {
          if (decoded != null) {
            final temporary = BookDocumentSelection(
              name: 'decoded.txt',
              path: decoded,
            );
            try {
              await documents.releaseBooks([temporary]);
            } catch (_) {
              staged.add(temporary);
            }
          }
        }
        return registerImported(imported, categories: categories);
      }

      Future<LocalImportReport> importPrepared(
        List<BookDocumentSelection> sources, {
        bool updateProgress = true,
        bool releaseSources = false,
      }) async {
        final origins = <String, LocalDocumentSource>{};
        // Scanner acknowledgement depends on each source's category succeeding.
        // Its immediate write/failure contract remains unchanged.
        final categories = fromScan ? null : _ImportedCategoryBatch();
        try {
          final imported = await importLocalDocuments(
            selections: sources,
            documents: documents,
            books: books,
            importFile: (name, path) =>
                importFile(name, path, categories: categories),
            importSelection: (selected) async {
              if (selected.originReference case final reference?) {
                final original = origins[reference] ??= await books
                    .documentAccess
                    .inspect(reference);
                String? decoded;
                try {
                  if (selected.name.toLowerCase().endsWith('.txt')) {
                    decoded = await documents.decodeTextFile(
                      selected.path!,
                      encoding: encoding,
                    );
                  }
                  return await registerImported(
                    await books.importDerivedDocument(
                      selected.name,
                      selected.path!,
                      originalName: selected.originName!,
                      original: original,
                      options: importOptions,
                      decodedPath: decoded,
                      renewReference: selectedBooks != null,
                    ),
                    categories: categories,
                  );
                } finally {
                  if (decoded != null) {
                    final temporary = BookDocumentSelection(
                      name: 'decoded.txt',
                      path: decoded,
                    );
                    try {
                      await documents.releaseBooks([temporary]);
                    } catch (_) {
                      staged.add(temporary);
                    }
                  }
                }
              }
              if (selected.reference case final reference?) {
                return registerImported(
                  selected.name.toLowerCase().endsWith('.txt')
                      ? await books.importLinkedText(
                          selected.name,
                          reference,
                          encoding: encoding,
                          options: importOptions,
                          renewReference: selectedBooks != null,
                        )
                      : await books.importLinkedDocument(
                          selected.name,
                          reference,
                          options: importOptions,
                          renewReference: selectedBooks != null,
                          recoverDamagedEpub:
                              !automatic &&
                              selected.name.toLowerCase().endsWith('.epub'),
                        ),
                  categories: categories,
                );
              }
              return importFile(
                selected.name,
                selected.path!,
                categories: categories,
              );
            },
            releaseSources: releaseSources,
            onCleanupFailed: staged.addAll,
            onProgress: (done, total) {
              if (updateProgress) {
                progress = (done, total);
                _changed();
              }
            },
          );
          final notices = await categories?.commit(
            organization!,
            imported.bookIds,
          );
          if (notices == null || notices.isEmpty) return imported;
          categoryWarning = true;
          return LocalImportReport(
            bookIds: imported.bookIds,
            added: imported.added,
            existing: imported.existing,
            failures: imported.failures,
            notices: [...imported.notices, ...notices],
          );
        } finally {
          for (final reference
              in sources.map((s) => s.reference).whereType<String>().toSet()) {
            await books.releaseUnusedOriginalReference(reference);
          }
        }
      }

      if ((!context.mounted || _disposed) && !fromScan) return;
      if (fromScan) {
        final snapshot =
            _session.pendingScan ?? await scanDocuments.scanBooks();
        if (!automatic) {
          _session.pendingScan = snapshot;
          keepScan = true;
        }
        scanResult = LocalScanResult(
          report: const LocalImportReport(),
          total: snapshot.total,
          unchanged: snapshot.unchanged,
          warnings: snapshot.warnings,
          pending: snapshot.books.length,
        );
        _changed();
        if (!automatic && (!context.mounted || _disposed)) return;
        if (automatic) {
          scanResult = LocalScanResult(
            report: const LocalImportReport(bookIds: [], added: 0, existing: 0),
            total: snapshot.total,
            unchanged: snapshot.unchanged,
            warnings: snapshot.warnings,
            pending: snapshot.books.length,
          );
          _changed();
          _session.status = scanResult!.summary;
          return;
        }
        final selected = snapshot.books.isEmpty
            ? <String>{}
            : await pushNovelPage<Set<String>>(
                context,
                LocalScanSelection(snapshot: snapshot),
                reduceMotion: library.reduceMotion,
              );
        if (selected == null) return;
        // Once the user has confirmed a finite batch, route disposal must not
        // cancel it. Pending discovery stays resumable if selection is closed.
        keepScan = false;
        _session.pendingScan = null;
        progress = (0, selected.length);
        _session.status = '正在导入扫描书籍…';
        _changed();
        scanResult = await scanLocalBooks(
          documents: scanDocuments,
          snapshot: snapshot,
          selectedTokens: selected,
          linkText: organization.linkLocalBooks && !copyLocal,
          importSource: (source) async {
            try {
              return await importPrepared(
                [source],
                updateProgress: false,
                releaseSources: true,
              );
            } finally {
              try {
                await documents.releaseBooks(staged);
                staged.clear();
              } catch (_) {
                /* Retry cleanup when the batch closes. */
              }
            }
          },
          current: () => true,
          onProgress: (done, total) {
            progress = (done, total);
            _changed();
          },
        );
        report = scanResult!.report;
        _changed();
      } else if (fromCloud) {
        await _cloud.load();
        if (!context.mounted || _disposed) return;
        await pushNovelPage<void>(
          context,
          CloudLibraryPage(
            settings: _cloud,
            onImport: importFile,
            onImportBatch: (name, path) async {
              final batch = await importPrepared([
                BookDocumentSelection(name: name, path: path),
              ]);
              try {
                await documents.releaseBooks(staged);
                staged.clear();
              } catch (_) {
                /* Retry disposable staging cleanup when the route closes. */
              }
              report = LocalImportReport(
                bookIds: {...?report?.bookIds, ...batch.bookIds}.toList(),
                added: (report?.added ?? 0) + batch.added,
                existing: (report?.existing ?? 0) + batch.existing,
                failures: [...?report?.failures, ...batch.failures],
                notices: [...?report?.notices, ...batch.notices],
              );
              return (
                imported: batch.added + batch.existing,
                failed: batch.failures.length,
              );
            },
            reduceMotion: library.reduceMotion,
          ),
          reduceMotion: library.reduceMotion,
        );
        if (report == null && fresh.isNotEmpty) {
          report = LocalImportReport(
            bookIds: fresh.toList(),
            added: fresh.length,
            existing: 0,
          );
        }
      } else {
        selections =
            selectedBooks ??
            (organization.linkLocalBooks && !copyLocal
                ? await documents.pickForImport()
                : await documents.pickCopiesForImport());
        if (selections.isEmpty || !context.mounted || _disposed) return;
        progress = (0, selections.length);
        _changed();
        report = await importPrepared(selections, releaseSources: true);
      }
      final completed = report;
      if (completed == null) return;
      _session.report = completed;
      _session.status = fromScan ? scanResult!.summary : completed.summary;
      await releaseStaging();
      if (!automatic) {
        for (final id in completed.bookIds) {
          await library.setLocalBookHidden(id, false);
        }
      }
      if (!context.mounted || _disposed) return;
      if (automatic) {
        if (completed.added > 0 &&
            ModalRoute.isCurrentOf(context) != false &&
            TickerMode.valuesOf(context).enabled) {
          showNovelFeedback(context, scanResult!.summary);
        }
        return;
      }
      AppHaptics.play(
        context,
        categoryWarning
            ? HapticCue.warning
            : completed.failures.isNotEmpty
            ? (completed.added > 0 ? HapticCue.warning : HapticCue.error)
            : (completed.added > 0 ? HapticCue.success : null),
      );
      if (onImported != null) {
        await onImported(completed);
        return;
      }
      if (localImportGroups(books, completed.bookIds).isNotEmpty ||
          completed.failures.isNotEmpty ||
          completed.notices.isNotEmpty) {
        await pushNovelPage<void>(
          context,
          LocalImportReview(books: books, library: library, report: completed),
          reduceMotion: library.reduceMotion,
        );
      } else {
        showNovelFeedback(
          context,
          fromScan ? scanResult!.summary : completed.summary,
        );
      }
    } catch (failure) {
      error = cloudFailureMessage(failure);
      _session.status = error;
      if (context.mounted && !_disposed) {
        showNovelFeedback(
          context,
          error!,
          haptic: automatic ? null : HapticCue.error,
        );
      }
    } finally {
      await releaseStaging();
      if (fromScan && !keepScan) {
        _session.pendingScan = null;
        try {
          await scanDocuments.finishBookScan();
        } catch (_) {
          // Closing a page must not hide an already committed import.
        }
      }
      busy = false;
      if (report == null && !hasPendingScan && error == null && !automatic) {
        _session.status = null;
      }
      if (fromScan) _scanning = false;
      progress = null;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_relayChanges);
    if (_ownsCloud) _cloud.dispose();
    super.dispose();
  }
}

class LocalBookImportButton extends StatefulWidget {
  const LocalBookImportButton({
    super.key,
    required this.books,
    required this.library,
    this.onManage,
  });
  final LocalBookStore books;
  final LibraryState library;
  final VoidCallback? onManage;
  @override
  State<LocalBookImportButton> createState() => _LocalBookImportButtonState();
}

class _LocalBookImportButtonState extends State<LocalBookImportButton>
    with WidgetsBindingObserver {
  late final importer = LocalBookImporter(
    books: widget.books,
    library: widget.library,
  );
  bool _active = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      importer.scanOnEntry(context, resumed: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active =
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false;
    if (active && !_active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) importer.scanOnEntry(context);
      });
    }
    _active = active;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    importer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: importer,
    builder: (context, _) => GlassMenuAnchor(
      child: Builder(
        builder: (anchor) => GlassIconButton(
          key: const ValueKey('shelf-import-book'),
          icon: CupertinoIcons.arrow_down_doc,
          label: switch (importer.progress) {
            final progress? => '正在导入 ${progress.$1} / ${progress.$2} 本',
            _ => importer.busy ? '正在导入书籍' : '导入书籍',
          },
          onPressed: importer.busy
              ? null
              : () => importer.showMenu(
                  anchor,
                  management: widget.onManage != null,
                  onManage: widget.onManage,
                ),
        ),
      ),
    ),
  );
}

/// A library-level task stays visible while the collection itself scrolls.
class LocalImportStatus extends StatelessWidget {
  const LocalImportStatus({super.key, required this.importer});
  final LocalBookImporter importer;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: AppText(importer.statusLabel)),
            GlassIconButton(
              key: const ValueKey('local-import-status-open'),
              icon: CupertinoIcons.info_circle,
              label: '查看扫描或导入结果',
              onPressed: importer.canShowStatus
                  ? () => importer.showStatus(context)
                  : null,
            ),
            if (!importer.busy && !importer.hasPendingScan)
              GlassIconButton(
                key: const ValueKey('local-import-status-dismiss'),
                icon: CupertinoIcons.xmark,
                label: '收起导入结果',
                onPressed: importer.dismissStatus,
              ),
          ],
        ),
        if (importer.busy)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: LinearProgressIndicator(
              key: const ValueKey('local-import-progress'),
              value: importer.progress == null || importer.progress!.$2 == 0
                  ? null
                  : importer.progress!.$1 / importer.progress!.$2,
              minHeight: 3,
            ),
          ),
      ],
    ),
  );
}
