import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/book_documents.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/local_book_batch_page.dart';
import 'package:wenku8_flutter/local_book_removal.dart';
import 'package:wenku8_flutter/local_book_series.dart';
import 'package:wenku8_flutter/local_import_batch.dart';
import 'package:wenku8_flutter/local_library_page.dart';

class BatchBooks extends LocalBookStore {
  BatchBooks() : super(Directory('.tmp/verification/batch-test-unused'));
  final coverWrites = <(int, String)>[];

  @override
  Future<Novel> setCover(int id, String path) async {
    coverWrites.add((id, path));
    return book(id)!;
  }

  static const first = Novel(
    id: 0x60000001,
    title: '星空旅人 2',
    author: '作者甲',
    genre: '',
    summary: '',
    colors: [],
  );
  static const second = Novel(
    id: 0x60000002,
    title: '星空旅人 1',
    author: '作者甲',
    genre: '',
    summary: '',
    colors: [],
  );
  static const third = Novel(
    id: 0x60000003,
    title: '另一部有着很长很长名字的书籍测试窄屏文字换行',
    author: '作者乙',
    genre: '',
    summary: '',
    colors: [],
  );
  @override
  List<Novel> get books => [first, second, third];
  @override
  List<Novel> get originals => books;
  @override
  Novel? book(int id) => books.where((b) => b.id == id).firstOrNull;
  @override
  bool contains(int id) => book(id) != null;
  @override
  LocalSeriesHint? seriesHint(int id) => id == first.id
      ? const LocalSeriesHint('星空旅人', 2)
      : id == second.id
      ? const LocalSeriesHint('星空旅人', 1)
      : null;
}

class CoverLibrary extends LibraryState {
  CoverLibrary(super.preferences);

  @override
  Future<void> setShelfMembership(
    int id,
    bool present, {
    Novel? novel,
    int? restoredAddedAt,
  }) async {}
}

class BatchImages extends BookDocuments {
  final released = <String>[];
  var picked = 0;
  int? cancelAt;

  @override
  Future<BookDocumentSelection?> pickImage() async {
    picked++;
    return picked == cancelAt
        ? null
        : BookDocumentSelection(name: '封面$picked.png', path: 'cover-$picked');
  }

  @override
  Future<void> releaseBooks(Iterable<BookDocumentSelection> books) async {
    released.addAll(books.map((book) => book.path!));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late LibraryState library;
  late BatchBooks books;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    library = LibraryState(preferences);
    books = BatchBooks();
  });
  tearDown(() {
    library.dispose();
    books.dispose();
  });

  test('hide and restore keep books and survive state reload', () async {
    final result = await removeLocalBooks(
      ids: [BatchBooks.first.id],
      choice: LocalBookRemoval.shelfOnly,
      books: books,
      library: library,
    );
    expect(result.removed, {BatchBooks.first.id});
    expect(result.failed, isEmpty);
    expect(books.contains(BatchBooks.first.id), isTrue);
    expect(library.localBookVisible(BatchBooks.first.id), isFalse);
    final reloaded = LibraryState(preferences);
    expect(reloaded.localBookVisible(BatchBooks.first.id), isFalse);
    await reloaded.setLocalBooksHidden([BatchBooks.first.id], false);
    expect(reloaded.localBookVisible(BatchBooks.first.id), isTrue);
    expect(preferences.getStringList('local_shelf_hidden'), isEmpty);
    reloaded.dispose();
  });

  test('series review sorts selected volumes and never mutates books', () {
    final groups = localImportGroups(books, [
      BatchBooks.first.id,
      BatchBooks.second.id,
      BatchBooks.third.id,
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.volumes.map((v) => v.bookId), [
      BatchBooks.second.id,
      BatchBooks.first.id,
    ]);
    expect(books.books, hasLength(3));
    expect(localImportGroups(books, [BatchBooks.third.id]), isEmpty);
  });

  testWidgets('local library opens the organizer independently of import', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocalLibraryPage(books: books, state: library, onOpen: (_, _) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('local-import-book')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('local-batch-organizer')));
    await tester.pumpAndSettle();
    expect(find.byType(LocalBookBatchPage), findsOneWidget);
    expect(find.text('推荐合并'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (mode, cancel) in [
    ('共用一张图片', false),
    ('按勾选顺序逐本配图', false),
    ('按勾选顺序逐本配图', true),
  ]) {
    testWidgets('cover queue $mode picker cancellation $cancel', (
      tester,
    ) async {
      final images = BatchImages()..cancelAt = cancel ? 2 : null;
      final coverLibrary = CoverLibrary(preferences);
      addTearDown(coverLibrary.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LocalBookBatchPage(
            books: books,
            library: coverLibrary,
            documents: images,
          ),
        ),
      );
      await tester.tap(find.text('批量封面'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(BatchBooks.second.title));
      await tester.pump();
      await tester.tap(find.text(BatchBooks.first.title));
      await tester.pumpAndSettle();
      expect(find.text('队列第 1 本 · 作者甲'), findsOneWidget);
      await tester.tap(find.text('更换封面'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();

      if (mode == '按勾选顺序逐本配图') {
        for (var i = 1; i <= 2; i++) {
          expect(find.text('选择图片 $i / 2'), findsOneWidget);
          await tester.tap(find.text('选择图片'));
          await tester.pumpAndSettle();
        }
      }

      expect(books.coverWrites, isEmpty);
      if (cancel) {
        expect(images.released, ['cover-1']);
      } else {
        expect(find.text('1. ${BatchBooks.second.title}'), findsOneWidget);
        expect(find.text('2. ${BatchBooks.first.title}'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, '更换封面'));
        await tester.pumpAndSettle();
        expect(books.coverWrites, [
          (BatchBooks.second.id, 'cover-1'),
          (BatchBooks.first.id, mode == '共用一张图片' ? 'cover-1' : 'cover-2'),
        ]);
        expect(images.released, ['cover-1', if (mode != '共用一张图片') 'cover-2']);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.6),
  ]) {
    testWidgets('search selection persists at $size scale $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: LocalBookBatchPage(books: books, library: library),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '作者甲');
      await tester.pump();
      await tester.tap(find.text('全选结果'));
      await tester.pump();
      expect(find.text('已选 2 本'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '另一部');
      await tester.pump();
      expect(find.text('已选 2 本'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
