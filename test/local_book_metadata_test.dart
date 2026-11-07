import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/local_book_editor.dart';
import 'package:wenku8_flutter/app_ui.dart';
import 'package:wenku8_flutter/book_dynamic_categories.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/local_import_batch.dart';
import 'package:wenku8_flutter/reading_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LocalBookStore store;
  late Novel first;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('book-metadata-');
    store = LocalBookStore(root);
    first = await store.import(
      LocalBookInput(
        '星空旅人 第1卷.txt',
        Uint8List.fromList(utf8.encode('第一章 出发\n这是第一卷的正文。')),
      ),
    );
  });
  tearDown(() async {
    store.dispose();
    await root.delete(recursive: true);
  });

  Future<Novel> update({String? seriesName, bool? omnibus}) =>
      store.updateMetadata(
        first.id,
        title: first.title,
        author: first.author,
        summary: first.summary,
        seriesName: seriesName,
        isOmnibus: omnibus,
      );

  for (final brightness in Brightness.values) {
    testWidgets(
      'recent history shows cover and keeps row usable on $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final library = LibraryState(await SharedPreferences.getInstance());
        addTearDown(library.dispose);
        final novel = (await tester.runAsync(
          () => store.updateMetadata(
            first.id,
            title: '一本拥有很长很长书名的测试作品用于最近阅读展示',
            author: '拥有很长名字的测试作者',
            summary: first.summary,
          ),
        ))!;
        await library.savePosition(
          novel: novel,
          chapter: 0,
          offset: 20,
          maximum: 100,
          width: 320,
        );
        int? opened;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: ReadingHistoryPage(
              state: library,
              repository: const DemoNovelRepository(),
              onOpen: (_, id, _) => opened = id,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byKey(ValueKey('history-book-${novel.id}'));
        expect(
          find.descendant(of: row, matching: find.byType(NovelCover)),
          findsOneWidget,
        );
        expect(find.text(novel.author), findsWidgets);
        await tester.ensureVisible(row);
        await tester.tap(
          find.descendant(of: row, matching: find.byType(NovelCover)),
        );
        expect(opened, novel.id);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'editable series and omnibus survive reload without changing identity',
    () async {
      final chapters = first.chapters.map((c) => c.id).toList();
      final original = (await store.original(first.id)).bytes;
      await update(seriesName: '自定义系列', omnibus: true);
      expect(store.book(first.id)!.genre, contains('本地合订本'));
      expect(
        BookDynamicCategories.seriesName(store.book(first.id)!, store),
        '自定义系列',
      );
      await store.load();
      expect(store.seriesName(first.id), '自定义系列');
      expect(store.isOmnibus(first.id), isTrue);
      final duplicate = await store.import(await store.original(first.id));
      expect(duplicate.id, first.id);
      await store.maintain(first.id, LocalMaintenanceTask.storage);
      await store.load();
      expect(store.isOmnibus(first.id), isTrue);
      expect(store.book(first.id)!.genre, contains('本地合订本'));
      expect(store.book(first.id)!.chapters.map((c) => c.id), chapters);
      expect((await store.original(first.id)).bytes, original);
      await update(omnibus: false);
      expect(store.isOmnibus(first.id), isFalse);
      expect(store.book(first.id)!.genre, isNot(contains('本地合订本')));
      expect(store.seriesName(first.id), '自定义系列');
    },
  );

  test(
    'explicit empty series suppresses inference and survives backup',
    () async {
      expect(store.seriesName(first.id), '星空旅人');
      await update(seriesName: '');
      expect(store.seriesName(first.id), isNull);
      expect(
        BookDynamicCategories.seriesKey(store.book(first.id)!, store),
        isNull,
      );
      final backup = store.exportMetadata();
      await store.load();
      expect(store.seriesName(first.id), isNull);
      expect(backup['${first.id}']['seriesName'], '');
      await update(seriesName: '新的系列');
      final restored = Map<String, dynamic>.from(backup['${first.id}']);
      restored['at'] = DateTime.now().millisecondsSinceEpoch + 10000;
      await store.mergeMetadata({'${first.id}': restored});
      expect(store.seriesName(first.id), isNull);
    },
  );

  test('old backups and omitted fields preserve new metadata', () async {
    await update(seriesName: '保留系列', omnibus: true);
    final old = Map<String, dynamic>.from(store.exportMetadata()['${first.id}'])
      ..remove('seriesName')
      ..remove('isOmnibus')
      ..['title'] = '旧客户端的新书名'
      ..['at'] = DateTime.now().millisecondsSinceEpoch + 10000;
    await store.mergeMetadata({'${first.id}': old});
    await update();
    expect(store.seriesName(first.id), '保留系列');
    expect(store.isOmnibus(first.id), isTrue);
    expect(store.exportMetadata()['${first.id}']['isOmnibus'], isTrue);
  });

  test('batch suggestions respect edited series and premerged files', () async {
    final second = await store.import(
      LocalBookInput(
        '星空旅人 第2卷.txt',
        Uint8List.fromList(utf8.encode('第一章 归来\n这是第二卷的正文。')),
      ),
    );
    final ids = [first.id, second.id];
    expect(localImportGroups(store, ids), hasLength(1));
    expect(store.relatedVolumes(first.id).map((b) => b.id), [second.id]);
    await update(seriesName: '用户系列');
    expect(localImportGroups(store, ids), isEmpty);
    expect(store.relatedVolumes(first.id), isEmpty);
    await store.updateMetadata(
      second.id,
      title: second.title,
      author: second.author,
      summary: second.summary,
      seriesName: '用户系列',
    );
    expect(localImportGroups(store, ids).single.title, '用户系列');
    expect(store.relatedVolumes(first.id).map((b) => b.id), [second.id]);
    await update(seriesName: '');
    expect(localImportGroups(store, ids), isEmpty);
    await update(seriesName: '用户系列', omnibus: true);
    expect(localImportGroups(store, ids), isEmpty);
    expect(store.relatedVolumes(first.id), isEmpty);
    expect(store.relatedVolumes(second.id), isEmpty);
    await update(omnibus: false);
    expect(localImportGroups(store, ids), hasLength(1));
  });

  test(
    'virtual collections retain name across edits, backups and reload',
    () async {
      final second = await store.import(
        LocalBookInput(
          '星空旅人 第2卷.txt',
          Uint8List.fromList(utf8.encode('第一章 归来\n这是第二卷的正文。')),
        ),
      );
      final combined = await store.saveSeries(
        title: '合订书名',
        volumes: [
          (bookId: first.id, title: '第一卷'),
          (bookId: second.id, title: '第二卷'),
        ],
      );
      final before = store.seriesFor(combined.id)!;
      await store.updateMetadata(
        combined.id,
        title: combined.title,
        author: combined.author,
        summary: combined.summary,
        seriesName: '作品系列',
      );
      await store.saveSeries(
        id: combined.id,
        title: '改名的合订本',
        volumes: [
          (bookId: second.id, title: '第二卷'),
          (bookId: first.id, title: '第一卷'),
        ],
      );
      var series = store.seriesFor(combined.id)!;
      expect(series.seriesName, '作品系列');
      final old = Map<String, Object>.from(series.toJson())
        ..remove('seriesName');
      old['at'] = series.updatedAt + 100;
      await store.mergeSeries({
        'version': 1,
        'series': [old],
      });
      await store.load();
      series = store.seriesFor(combined.id)!;
      expect(store.seriesName(combined.id), '作品系列');
      expect(store.isOmnibus(combined.id), isTrue);
      for (final volume in series.volumes) {
        expect(
          volume.chapterIds,
          before.volumes
              .singleWhere((v) => v.bookId == volume.bookId)
              .chapterIds,
        );
      }
      await expectLater(
        store.updateMetadata(
          combined.id,
          title: combined.title,
          author: combined.author,
          summary: combined.summary,
          isOmnibus: false,
        ),
        throwsFormatException,
      );
      expect(store.seriesFor(combined.id), isNotNull);
    },
  );

  test('new metadata rejects invalid backup fields', () {
    final base = {'title': '书', 'author': '', 'summary': '', 'at': 1};
    expect(
      () => LocalBookStore.validateMetadata({
        '${first.id}': {...base, 'seriesName': 123},
      }),
      throwsFormatException,
    );
    expect(
      () => LocalBookStore.validateMetadata({
        '${first.id}': {...base, 'isOmnibus': 'true'},
      }),
      throwsFormatException,
    );
  });

  testWidgets('omnibus cover badge fits narrow cover at large text scale', (
    tester,
  ) async {
    final book = (await tester.runAsync(() => update(omnibus: true)))!;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: NovelCover(book, width: 48, height: 68)),
        ),
      ),
    );
    expect(find.text('合订'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'editor places editable series after author and toggles ordinary omnibus',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final library = LibraryState(prefs);
      addTearDown(library.dispose);
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: LocalBookEditor(book: first, books: store, library: library),
        ),
      );
      await tester.pumpAndSettle();
      final series = find.byKey(const ValueKey('local-edit-系列'));
      await tester.ensureVisible(series);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('local-edit-作者')), findsOneWidget);
      expect(
        tester.getTopLeft(series).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('local-edit-作者'))).dy,
        ),
      );
      await tester.enterText(series, '可编辑系列');
      final toggle = find.byKey(const ValueKey('local-edit-omnibus'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
