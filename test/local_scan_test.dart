import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/local_book_importer.dart';
import 'package:wenku8_flutter/local_import_options.dart';
import 'package:wenku8_flutter/book_documents.dart';
import 'package:wenku8_flutter/local_book_scanner.dart';
import 'package:wenku8_flutter/local_import_batch.dart';
import 'package:wenku8_flutter/local_scan_page.dart';
import 'package:wenku8_flutter/local_library_preferences.dart';

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

class SessionDocuments extends ScanDocuments {
  final discovery = Completer<BookScanSnapshot>();
  int scans = 0, finishes = 0;
  final released = <BookDocumentSelection>[];
  @override
  Future<BookScanSnapshot> scanBooks() {
    scans++;
    return discovery.future;
  }

  @override
  Future<void> finishBookScan() async => finishes++;
  @override
  Future<void> releaseBooks(Iterable<BookDocumentSelection> books) async {
    released.addAll(books);
  }
}

class SessionBooks extends LocalBookStore {
  SessionBooks() : super(Directory('.tmp/verification/unused-scan-store'));
  final firstImport = Completer<void>();
  final imported = <String>[];
  @override
  Future<Novel> importFile(
    String name,
    String path, {
    String? text,
    String? decodedPath,
    LocalImportOptions options = const LocalImportOptions(),
    bool recoverDamagedEpub = false,
  }) async {
    imported.add(name);
    if (imported.length == 1) await firstImport.future;
    if (name == 'bad.epub') throw const FormatException('测试损坏文件');
    return Novel(
      id: localBookIdStart + imported.length,
      title: name,
      author: '',
      genre: '',
      summary: '',
      colors: const [],
    );
  }
}

void main() {
  for (final category in [
    LocalLibraryPreferences.noTag,
    LocalLibraryPreferences.noSeries,
    LocalLibraryPreferences.tagCategory('奇幻'),
    LocalLibraryPreferences.seriesCategory('测试系列'),
    LocalLibraryPreferences.authorCategory('测试作者'),
    LocalLibraryPreferences.unfiled,
    'manual',
  ]) {
    testWidgets('scan imports from $category without assigning projections', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'linkLocalBooks.v1': false});
      final library = LibraryState(await SharedPreferences.getInstance());
      final books = SessionBooks()..firstImport.complete();
      final documents = SessionDocuments();
      final importer = LocalBookImporter(
        books: books,
        library: library,
        documents: documents,
      );
      addTearDown(importer.dispose);
      addTearDown(library.dispose);
      addTearDown(books.dispose);
      final group = category == 'manual'
          ? await library.organization.addGroup('手动分类')
          : category;
      await library.organization.select(group);
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold();
            },
          ),
        ),
      );
      documents.discovery.complete(
        const BookScanSnapshot(
          books: [(token: 'one.epub', name: 'one.epub')],
          total: 1,
        ),
      );
      LocalImportReport? result;
      final task = importer.run(
        page,
        fromScan: true,
        copyLocal: true,
        onImported: (report) async {
          result = report;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('导入所选书籍'));
      await tester.pumpAndSettle();
      await task;
      expect(result?.added, 1);
      expect(result?.failures, isEmpty);
      expect(documents.marked, ['one.epub']);
      expect(documents.released.any((book) => book.path == 'one.epub'), isTrue);
      expect(
        library.organization.groupOf(localBookIdStart + 1),
        category == 'manual' ? group : LocalLibraryPreferences.unfiled,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'discovery and confirmed imports survive route and importer disposal',
    (tester) async {
      SharedPreferences.setMockInitialValues({'linkLocalBooks.v1': false});
      final library = LibraryState(await SharedPreferences.getInstance());
      final books = SessionBooks();
      final documents = SessionDocuments();
      var importer = LocalBookImporter(
        books: books,
        library: library,
        documents: documents,
      );
      final observer = LocalBookImporter(
        books: books,
        library: library,
        documents: documents,
      );
      addTearDown(observer.dispose);
      addTearDown(library.dispose);
      addTearDown(books.dispose);
      late BuildContext home, page;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              home = context;
              return const Scaffold(body: Text('书库'));
            },
          ),
        ),
      );
      void pushScan() {
        Navigator.of(home).push<void>(
          MaterialPageRoute(
            builder: (context) {
              page = context;
              return const Scaffold(body: Text('扫描'));
            },
          ),
        );
      }

      pushScan();
      await tester.pumpAndSettle();
      final discovery = importer.run(page, fromScan: true, copyLocal: true);
      await tester.pump();
      expect(observer.busy, isTrue);
      expect(observer.statusLabel, contains('正在扫描'));
      Navigator.of(home).pop();
      await tester.pumpAndSettle();
      importer.dispose();
      documents.discovery.complete(
        const BookScanSnapshot(
          books: [
            (token: 'one.epub', name: 'one.epub'),
            (token: 'bad.epub', name: 'bad.epub'),
          ],
          total: 2,
        ),
      );
      await discovery;
      expect(observer.hasPendingScan, isTrue);
      expect(observer.busy, isFalse);
      expect(documents.finishes, 0);
      expect(documents.staged, isEmpty);
      importer = LocalBookImporter(
        books: books,
        library: library,
        documents: documents,
      );
      expect(importer.statusLabel, contains('待确认 2 本'));
      pushScan();
      await tester.pumpAndSettle();
      final importing = importer.run(page, fromScan: true, copyLocal: true);
      await tester.pumpAndSettle();
      expect(find.text('选择要导入的书籍（2）'), findsOneWidget);
      expect(documents.scans, 1);
      await tester.tap(find.text('导入所选书籍'));
      await tester.pumpAndSettle();
      expect(observer.progress, (
        0,
        2,
      ), reason: observer.error ?? observer.statusLabel);
      expect(observer.busy, isTrue);
      Navigator.of(home).pop();
      await tester.pumpAndSettle();
      importer.dispose();
      books.firstImport.complete();
      await importing;
      expect(books.imported, ['one.epub', 'bad.epub']);
      expect(documents.marked, ['one.epub']);
      expect(documents.finishes, 1);
      expect(observer.busy, isFalse);
      expect(observer.progress, isNull);
      expect(observer.hasPendingScan, isFalse);
      expect(observer.statusLabel, contains('导入 1 本'));
      expect(observer.statusLabel, contains('失败 1 本'));
      unawaited(observer.showStatus(home));
      await tester.pumpAndSettle();
      expect(find.textContaining('测试损坏文件'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving during preparation still scans; pending results can be discarded',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = LibraryState(await SharedPreferences.getInstance());
      final books = SessionBooks();
      final documents = SessionDocuments();
      final importer = LocalBookImporter(
        books: books,
        library: library,
        documents: documents,
      );
      addTearDown(importer.dispose);
      addTearDown(library.dispose);
      addTearDown(books.dispose);
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold();
            },
          ),
        ),
      );
      final task = importer.run(page, fromScan: true);
      // Dispose the initiating context before SharedPreferences returns.
      await tester.pumpWidget(const SizedBox.shrink());
      documents.discovery.complete(
        const BookScanSnapshot(books: [(token: 'a', name: 'a.epub')], total: 1),
      );
      await task;
      expect(documents.scans, 1);
      expect(importer.hasPendingScan, isTrue);
      expect(documents.staged, isEmpty);
      await importer.discardPendingScan();
      expect(documents.finishes, 1);
      expect(importer.hasPendingScan, isFalse);
      expect(documents.staged, isEmpty);
      expect(importer.statusLabel, contains('可重新扫描'));
    },
  );

  testWidgets('scan failure is retained after its route is closed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = LibraryState(await SharedPreferences.getInstance());
    final books = SessionBooks();
    final documents = SessionDocuments();
    final importer = LocalBookImporter(
      books: books,
      library: library,
      documents: documents,
    );
    addTearDown(importer.dispose);
    addTearDown(library.dispose);
    addTearDown(books.dispose);
    late BuildContext home, page;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            home = context;
            return const Scaffold();
          },
        ),
      ),
    );
    Navigator.of(home).push<void>(
      MaterialPageRoute(
        builder: (context) {
          page = context;
          return const Scaffold();
        },
      ),
    );
    await tester.pumpAndSettle();
    final task = importer.run(page, fromScan: true);
    await tester.pump();
    Navigator.of(home).pop();
    await tester.pumpAndSettle();
    documents.discovery.completeError(
      PlatformException(code: 'document', message: '读取授权已失效'),
    );
    await task;
    expect(importer.busy, isFalse);
    expect(importer.error, isNotNull);
    expect(importer.statusLabel, importer.error);
    expect(documents.finishes, 1);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('task status fits narrow $brightness screen with large text', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final library = LibraryState(await SharedPreferences.getInstance());
      final books = SessionBooks();
      final importer = LocalBookImporter(books: books, library: library)
        ..busy = true
        ..progress = (11, 25);
      addTearDown(importer.dispose);
      addTearDown(library.dispose);
      addTearDown(books.dispose);
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: LocalImportStatus(importer: importer),
            ),
          ),
        ),
      );
      await tester.pump();
      final indicator = find.byKey(const ValueKey('local-import-progress'));
      expect(indicator, findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(indicator).value, 11 / 25);
      expect(find.text('正在导入 11 / 25 本'), findsOneWidget);
      expect(tester.takeException(), isNull);
      importer.busy = false;
    });
  }

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
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('scan-start')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<Widget>(find.byKey(const ValueKey('scan-start'))),
        isNotNull,
      );
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
