// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'book_documents.dart';
import 'local_import_batch.dart';

/// Scans the already-selected snapshot and imports the requested tokens.
///
/// Desktop uses this for a one-shot folder import; the mobile build additionally
/// supports automatic scans through the same contract.
Future<LocalScanResult> scanLocalBooks({
  required BookDocuments documents,
  required BookScanSnapshot snapshot,
  required Set<String> selectedTokens,
  required bool linkText,
  required Future<LocalImportReport> Function(BookDocumentSelection source)
  importSource,
  required bool Function() current,
  required void Function(int done, int total) onProgress,
}) async {
  final bookIds = <int>[];
  final failures = <LocalImportNotice>[];
  final notices = <LocalImportNotice>[];
  var added = 0;
  var existing = 0;
  var done = 0;
  for (final entry in snapshot.books) {
    if (!current()) break;
    if (!selectedTokens.contains(entry.token)) continue;
    try {
      final source = linkText
          ? await documents.linkScanBook(entry.token)
          : await documents.stageScanBook(entry.token);
      final report = await importSource(source);
      bookIds.addAll(report.bookIds);
      added += report.added;
      existing += report.existing;
      failures.addAll(report.failures);
      notices.addAll(report.notices);
      if (report.failures.isEmpty) await documents.markScanBook(entry.token);
    } catch (error) {
      failures.add((name: entry.name, message: error.toString()));
    } finally {
      done++;
      onProgress(done, selectedTokens.length);
    }
  }
  return LocalScanResult(
    report: LocalImportReport(
      bookIds: bookIds,
      added: added,
      existing: existing,
      failures: failures,
      notices: notices,
    ),
    total: snapshot.total,
    unchanged: snapshot.unchanged,
    warnings: snapshot.warnings,
  );
}
