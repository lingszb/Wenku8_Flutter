import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/local_book_batch_page.dart';
import 'package:wenku8_flutter/local_book_removal.dart';
import 'package:wenku8_flutter/local_book_series.dart';
import 'package:wenku8_flutter/local_import_batch.dart';

class BatchBooks extends LocalBookStore {
  BatchBooks() : super(Directory('.tmp/verification/batch-test-unused'));
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
