import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/book_documents.dart';
import 'package:wenku8_flutter/local_book_scanner.dart';
import 'package:wenku8_flutter/local_import_batch.dart';
import 'package:wenku8_flutter/local_scan_page.dart';

class ScanDocuments extends BookDocuments {
  BookScanFolder? folder;
  BookScanFolder? choice;
  Set<String> formats = {'txt', 'epub'};
  final marked = <String>[];
  final staged = <String>[];

  @override
  Future<BookScanFolder?> scanFolderInfo() async => folder;
  @override
  Future<Set<String>> scanFormats() async => formats;
  @override
  Future<BookScanFolder?> selectScanFolder() async => folder = choice ?? folder;
  @override
  Future<void> setScanFormats(Set<String> value) async => formats = value;
  @override
  Future<void> disconnectScanFolder() async => folder = null;
  @override
  Future<BookDocumentSelection> stageScanBook(String token) async {
    staged.add(token);
    if (token == 'revoked') {
      throw PlatformException(code: 'document', message: '读取授权已失效');
    }
    return BookDocumentSelection(name: token, path: token);
  }

  @override
  Future<void> markScanBook(String token) async => marked.add(token);
}

void main() {
  test(
    'scan imports only selected files and acknowledges successful imports',
    () async {
      final documents = ScanDocuments();
      final result = await scanLocalBooks(
        documents: documents,
        snapshot: const BookScanSnapshot(
          books: [
            (token: 'ok', name: 'ok.txt'),
            (token: 'bad', name: 'bad.epub'),
            (token: 'revoked', name: 'revoked.txt'),
            (token: 'unselected', name: 'unselected.txt'),
          ],
          total: 5,
          unchanged: 1,
        ),
        selectedTokens: {'ok', 'bad', 'revoked'},
        linkText: false,
        importSource: (source) async => source.name == 'bad'
            ? const LocalImportReport(
                failures: [(name: 'bad', message: '损坏的 EPUB')],
              )
            : const LocalImportReport(bookIds: [1], added: 1),
        current: () => true,
        onProgress: (_, _) {},
      );
      expect(documents.staged, ['ok', 'bad', 'revoked']);
      expect(documents.marked, ['ok']);
      expect(result.report.added, 1);
      expect(result.report.failures, hasLength(2));
      expect(result.unchanged, 1);
    },
  );

  test('leaving scan does not stage or acknowledge remaining files', () async {
    final documents = ScanDocuments();
    await scanLocalBooks(
      documents: documents,
      snapshot: const BookScanSnapshot(books: [(token: 'ok', name: 'ok.txt')]),
      selectedTokens: {'ok'},
      linkText: false,
      importSource: (_) async => const LocalImportReport(),
      current: () => false,
      onProgress: (_, _) {},
    );
    expect(documents.staged, isEmpty);
    expect(documents.marked, isEmpty);
  });

  Future<void> showPage(
    WidgetTester tester,
    ScanDocuments documents,
    VoidCallback scan,
  ) async {
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: LocalScanPage(
          documents: documents,
          changes: changes,
          isBusy: () => false,
          progress: () => null,
          result: () => null,
          failure: () => null,
          onScan: (_) async => scan(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'folder selection enables scan; disconnect disables it without importing',
    (tester) async {
      final documents = ScanDocuments()
        ..choice = const BookScanFolder(
          name: 'Books',
          automatic: false,
          readable: true,
        );
      var scans = 0;
      await showPage(tester, documents, () => scans++);
      expect(find.text('尚未选择扫描位置'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scan-select-folder')));
      await tester.pumpAndSettle();
      expect(find.text('扫描位置：Books'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('scan-start')));
      await tester.tap(find.byKey(const ValueKey('scan-start')));
      await tester.pumpAndSettle();
      expect(scans, 1);
      await tester.ensureVisible(find.byKey(const ValueKey('scan-disconnect')));
      await tester.tap(find.byKey(const ValueKey('scan-disconnect')));
      await tester.pumpAndSettle();
      expect(documents.folder, isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('scan-start')));
      await tester.tap(find.byKey(const ValueKey('scan-start')));
      expect(scans, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'revoked folder cannot start scan and preserves recovery controls',
    (tester) async {
      final documents = ScanDocuments()
        ..folder = const BookScanFolder(
          name: 'Books',
          automatic: true,
          readable: false,
        );
      var scans = 0;
      await showPage(tester, documents, () => scans++);
      expect(find.text('读取授权已失效，请重新选择文件夹或授权共享存储。'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('scan-start')));
      await tester.tap(find.byKey(const ValueKey('scan-start')));
      expect(scans, 0);
      expect(find.byKey(const ValueKey('scan-select-folder')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'scan controls remain reachable on narrow $brightness screen with large text',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final documents = ScanDocuments()
          ..folder = const BookScanFolder(
            name: '很长的文件夹名称与子目录',
            automatic: false,
            readable: true,
          );
        final changes = ChangeNotifier();
        addTearDown(changes.dispose);
        var scans = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: LocalScanPage(
              documents: documents,
              changes: changes,
              isBusy: () => false,
              progress: () => null,
              result: () => null,
              failure: () => null,
              onScan: (_) async => scans++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('scan-start')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const ValueKey('scan-start')));
        await tester.pumpAndSettle();
        expect(scans, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
