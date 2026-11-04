// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'book_documents.dart';
import 'catalog.dart';
import 'local_books.dart';

/// A single non-fatal import message.
typedef LocalImportNotice = ({String name, String message});

class LocalImportReport {
  const LocalImportReport({
    this.bookIds = const [],
    this.added = 0,
    this.existing = 0,
    this.failures = const [],
    this.notices = const [],
  });

  final List<int> bookIds;
  final int added, existing;
  final List<LocalImportNotice> failures, notices;

  String get summary {
    final parts = <String>[
      if (added > 0) '导入 $added 本',
      if (existing > 0) '已存在 $existing 本',
      if (failures.isNotEmpty) '失败 ${failures.length} 本',
      if (notices.isNotEmpty) '提示 ${notices.length} 条',
    ];
    return parts.isEmpty ? '没有可导入的书籍' : parts.join('，');
  }
}

class LocalScanResult {
  const LocalScanResult({
    required this.report,
    this.total = 0,
    this.unchanged = 0,
    this.warnings = const [],
    this.pending = 0,
  });

  final LocalImportReport report;
  final int total, unchanged, pending;
  final List<String> warnings;

  String get summary {
    if (total == 0) return '扫描目录中没有书籍';
    final parts = <String>[
      '发现 $total 本',
      if (report.added > 0) '导入 ${report.added} 本',
      if (report.existing > 0) '已存在 ${report.existing} 本',
      if (pending > 0) '待确认 $pending 本',
      if (warnings.isNotEmpty) '警告 ${warnings.length} 条',
    ];
    return parts.join('，');
  }
}

class LocalImportGroup {
  const LocalImportGroup({
    required this.seed,
    required this.title,
    this.needsTarget = false,
    this.targetId,
    this.volumes = const [],
  });

  final int seed;
  final String title;
  final bool needsTarget;
  final int? targetId;
  final List<({int bookId, String title})> volumes;
}

/// Series grouping is private in this snapshot. Returning an empty set keeps
/// local imports simple and avoids inventing volume associations.
List<LocalImportGroup> localImportGroups(
  LocalBookStore books,
  List<int> bookIds,
) => const [];

/// Prepares every selected document, imports the resulting files, and keeps
/// per-file failures from aborting the rest of the batch.
Future<LocalImportReport> importLocalDocuments({
  required List<BookDocumentSelection> selections,
  required BookDocuments documents,
  required LocalBookStore books,
  required Future<Novel> Function(String name, String path) importFile,
  required Future<Novel> Function(BookDocumentSelection selected)
  importSelection,
  bool releaseSources = false,
  void Function(Iterable<BookDocumentSelection> failed)? onCleanupFailed,
  required void Function(int done, int total) onProgress,
}) async {
  final prepared = <BookDocumentSelection>[];
  final failures = <LocalImportNotice>[];
  for (final selection in selections) {
    try {
      final staged = await documents.stageForImport(selection);
      for (final book in await documents.prepareBook(staged)) {
        if (book.error case final message?) {
          failures.add((name: book.name, message: message));
        } else {
          prepared.add(book);
        }
      }
    } catch (error) {
      failures.add((name: selection.name, message: '$error'));
    }
  }

  final ids = <int>[];
  var imported = 0;
  for (var index = 0; index < prepared.length; index++) {
    final selection = prepared[index];
    try {
      final novel = await importSelection(selection);
      ids.add(novel.id);
      imported++;
    } catch (error) {
      failures.add((name: selection.name, message: '$error'));
    }
    onProgress(index + 1, prepared.length);
  }

  if (releaseSources && selections.isNotEmpty) {
    try {
      await documents.releaseBooks(selections);
    } catch (_) {
      onCleanupFailed?.call(selections);
    }
  }

  return LocalImportReport(
    bookIds: ids,
    added: imported,
    existing: 0,
    failures: failures,
  );
}
