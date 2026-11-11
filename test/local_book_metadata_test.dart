import 'dart:convert';
import 'dart:async';
import 'package:wenku8_flutter/pages.dart';
import 'package:wenku8_flutter/offline_repository.dart';
import 'package:wenku8_flutter/offline_cache.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:wenku8_flutter/local_epub_media.dart';
import 'package:wenku8_flutter/local_document_input.dart';
import 'package:wenku8_flutter/local_book_media.dart';
import 'package:flutter/services.dart' show PlatformException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/local_library_preferences.dart';
import 'package:wenku8_flutter/local_book_editor.dart';
import 'package:wenku8_flutter/app_ui.dart';
import 'package:wenku8_flutter/book_dynamic_categories.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/local_import_batch.dart';
import 'package:wenku8_flutter/reading_history.dart';

class _SlowLocalDetail extends OfflineNovelRepository {
  _SlowLocalDetail({required super.cache, required super.local});
  final loaded = Completer<Novel>();
  int chapterRequests = 0;
  @override
  Future<Novel> detail(Novel novel) => loaded.future;
  @override
  Future<List<NovelChapter>> chapters(int id) {
    chapterRequests++;
    return super.chapters(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LocalBookStore store;
  late Novel first;

  test(
    'optional dimension hints preserve revocation feedback and discard old source results',
    () async {
      final previousRoot = LocalBookMedia.root;
      final previousReader = LocalBookMedia.externalImage;
      final previousBatch = LocalBookMedia.externalImages;
      final previousDimensions = LocalBookMedia.externalDimensions;
      final previousWarnings = LocalBookMedia.importWarnings;
      try {
        LocalBookMedia.root = root;
        const source = 'wenku-local://1610612736/img-1.png';
        LocalBookMedia.externalDimensions = (_, _) async =>
            throw PlatformException(code: 'permission_lost');
        expect(await LocalBookMedia.dimensions([source]), isEmpty);
        var calls = 0;
        LocalBookMedia.externalDimensions = (_, _) async {
          calls++;
          return {'img-1.png': (width: 2, height: 3)};
        };
        expect(
          await LocalBookMedia.dimensions([source], current: () => false),
          isEmpty,
        );
        expect(calls, 0);
        final started = Completer<void>();
        final dimensions = Completer<Map<String, LocalBookImageDimensions>>();
        LocalBookMedia.externalDimensions = (_, _) {
          started.complete();
          return dimensions.future;
        };
        final pending = LocalBookMedia.dimensions([source]);
        await started.future;
        LocalBookMedia.root = root;
        dimensions.complete({'img-1.png': (width: 2, height: 3)});
        expect(await pending, isEmpty);
      } finally {
        LocalBookMedia.root = previousRoot;
        LocalBookMedia.externalImage = previousReader;
        LocalBookMedia.externalImages = previousBatch;
        LocalBookMedia.externalDimensions = previousDimensions;
        LocalBookMedia.importWarnings = previousWarnings;
      }
    },
  );

  final image = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFElEQVR4nGOUD6hgYGBgYgADKAUAESAA7c/6xDcAAAAASUVORK5CYII=',
  );
  final jpeg = base64Decode(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAADAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAABf/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AIUAyGf/2Q==',
  );

  test(
    'EPUB dimension hints agree with codec and reject truncated/EXIF headers',
    () async {
      for (final bytes in [image, jpeg]) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          expect(localEpubImageHeaderDimensions(bytes), (
            width: descriptor.width,
            height: descriptor.height,
          ));
          for (var length = 0; length < 24; length++) {
            expect(
              localEpubImageHeaderDimensions(
                Uint8List.sublistView(bytes, 0, length),
              ),
              isNull,
            );
          }
        } finally {
          descriptor.dispose();
          buffer.dispose();
        }
      }
      final exif = Uint8List.fromList([
        255,
        216,
        255,
        225,
        0,
        8,
        69,
        120,
        105,
        102,
        0,
        0,
        ...jpeg.skip(2),
      ]);
      expect(localEpubImageHeaderDimensions(exif), isNull);
      expect(
        localEpubImageHeaderDimensions(Uint8List.fromList([0, 1, 2])),
        isNull,
      );
    },
  );

  test(
    'EPUB dimensions cache rebuilds corruption and invalidates resource mapping',
    () async {
      final folder = Directory('${root.path}/image-dimensions')..createSync();
      final archive = Archive()
        ..addFile(ArchiveFile('a.png', image.length, image))
        ..addFile(ArchiveFile('b.jpg', jpeg.length, jpeg));
      final original = File('${folder.path}/original')
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final index = File('${folder.path}/media.json')
        ..writeAsStringSync(
          jsonEncode({
            'version': 1,
            'entries': {'img-1.png': 'a.png'},
          }),
        );
      final request = (
        directory: folder.path,
        names: ['img-1.png'],
        original: LocalDocumentInput.file(original.path),
        identity: 'test-source',
      );
      expect(readLocalEpubImageDimensionsFromInput(request)['img-1.png'], (
        width: 2,
        height: 3,
      ));
      final cache = File('${folder.path}/.image-dimensions.json');
      expect(cache.existsSync(), isTrue);
      cache.writeAsStringSync('{truncated');
      expect(readLocalEpubImageDimensionsFromInput(request)['img-1.png'], (
        width: 2,
        height: 3,
      ));
      index.writeAsStringSync(
        jsonEncode({
          'version': 1,
          'entries': {'img-1.png': 'missing.png'},
        }),
      );
      expect(readLocalEpubImageDimensionsFromInput(request), isEmpty);
      index.writeAsStringSync(
        jsonEncode({
          'version': 1,
          'entries': {'img-1.png': 'b.jpg'},
        }),
      );
      expect(readLocalEpubImageDimensionsFromInput(request)['img-1.png'], (
        width: 2,
        height: 3,
      ));
      original.writeAsBytesSync([0, 1, 2, 3]);
      expect(
        () => readLocalEpubImageDimensionsFromInput(request),
        throwsFormatException,
      );
    },
  );

  test(
    'new EPUB import carries verified dimensions into the reader without a repair cache',
    () async {
      final archive = Archive();
      final extraImages = [for (var i = 2; i <= 5; i++) 'b$i.jpg', 'bad.jpg'];
      void text(String name, String value) {
        final bytes = utf8.encode(value);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      text('mimetype', 'application/epub+zip');
      text(
        'META-INF/container.xml',
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
      );
      text(
        'content.opf',
        '<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="book-id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="book-id">dimension-fixture</dc:identifier><dc:title>尺寸索引测试</dc:title><dc:language>zh-CN</dc:language></metadata><manifest><item id="body" href="chapter.xhtml" media-type="application/xhtml+xml"/><item id="a" href="a.png" media-type="image/png"/><item id="b" href="b.jpg" media-type="image/jpeg"/></manifest><spine><itemref idref="body"/></spine></package>'
            .replaceFirst(
              '</manifest>',
              '${extraImages.map((name) => '<item id="$name" href="$name" media-type="image/jpeg"/>').join()}</manifest>',
            ),
      );
      text(
        'chapter.xhtml',
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>插图</title></head><body><p><img src="a.png"/></p><p><img src="b.jpg"/></p></body></html>'
            .replaceFirst(
              '</body>',
              '${extraImages.map((name) => '<p><img src="$name"/></p>').join()}</body>',
            ),
      );
      archive.addFile(ArchiveFile('a.png', image.length, image));
      archive.addFile(ArchiveFile('b.jpg', jpeg.length, jpeg));
      for (final name in extraImages) {
        archive.addFile(
          name == 'bad.jpg'
              ? ArchiveFile.noCompress(name, jpeg.length, jpeg)
              : ArchiveFile(name, jpeg.length, jpeg),
        );
      }
      final epub = Uint8List.fromList(ZipEncoder().encode(archive));
      final zip = ZipDirectory()..read(InputMemoryStream(epub));
      final bad = zip.fileHeaders.firstWhere(
        (entry) => entry.filename == 'bad.jpg',
      );
      final bytes = ByteData.sublistView(epub);
      final payload =
          bad.localHeaderOffset +
          30 +
          bytes.getUint16(bad.localHeaderOffset + 26, Endian.little) +
          bytes.getUint16(bad.localHeaderOffset + 28, Endian.little);
      epub[payload + jpeg.length - 1] ^= 1;
      final book = await store.import(LocalBookInput('尺寸索引测试.epub', epub));
      final folder = '${root.path}/${book.id}';
      final index =
          jsonDecode(File('$folder/media.json').readAsStringSync()) as Map;
      final record =
          jsonDecode(File('$folder/book.json').readAsStringSync()) as Map;
      final name =
          (index['entries'] as Map).entries
                  .firstWhere((entry) => entry.value == 'b.jpg')
                  .key
              as String;
      expect(index['dimensions'][name], [2, 3]);
      expect(index['dimensionSource'], record['source']['digest']);
      final result = readLocalEpubImageDimensionsFromInput((
        directory: folder,
        names: [name],
        original: LocalDocumentInput.file('$folder/original'),
        identity: record['source']['digest'] as String,
      ));
      expect(result[name], (width: 2, height: 3));
      expect(File('$folder/.image-dimensions.json').existsSync(), isFalse);
      final badName =
          (index['entries'] as Map).entries
                  .firstWhere((entry) => entry.value == 'bad.jpg')
                  .key
              as String;
      expect(index['dimensions'][badName], isNull);
      expect(
        () => readLocalEpubImageFromFile((
          directory: folder,
          name: badName,
          original: '$folder/original',
        )),
        throwsFormatException,
      );
    },
  );

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

  testWidgets('detail thumbnail releases the old transition cover', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = LibraryState(await SharedPreferences.getInstance());
    addTearDown(library.dispose);
    final repository = _SlowLocalDetail(
      cache: OfflineCacheStore(root),
      local: store,
    );
    const old = Novel(
      id: 100,
      title: '封面同步',
      author: '作者',
      genre: '',
      summary: '',
      colors: [Colors.brown, Colors.grey],
      coverUrl: 'assets/report/season-spring.png',
    );
    const current = Novel(
      id: 100,
      title: '封面同步',
      author: '作者',
      genre: '',
      summary: '',
      colors: [Colors.brown, Colors.grey],
      coverUrl: 'assets/report/season-autumn.png',
    );
    Widget page(Novel novel) => MaterialApp(
      home: DetailPage(
        novel: novel,
        transitionNovel: old,
        state: library,
        repository: repository,
      ),
    );
    await tester.pumpWidget(page(old));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(current));
    await tester.pumpAndSettle();
    final covers = tester.widgetList<NovelCover>(find.byType(NovelCover));
    expect(covers, isNotEmpty);
    expect(
      covers.every((cover) => cover.novel.coverUrl == current.coverUrl),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'omnibus cover follows confirmed stable chapters and preserves originals',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = LibraryState(await SharedPreferences.getInstance());
      addTearDown(library.dispose);
      final second = await store.import(
        LocalBookInput(
          '星空旅人 第2卷.txt',
          Uint8List.fromList(utf8.encode('第一章 第二卷\n正文。')),
        ),
      );
      await store.setCover(first.id, 'assets/report/season-spring.png');
      await store.setCover(second.id, 'assets/report/season-autumn.png');
      final firstCover = store.book(first.id)!.coverUrl;
      final secondCover = store.book(second.id)!.coverUrl;
      final before = (await store.original(first.id)).bytes;
      final combined = await store.saveSeries(
        title: '封面切换样本',
        volumes: [
          (bookId: first.id, title: '第一卷'),
          (bookId: second.id, title: '第二卷'),
        ],
      );
      store.readingCoverChapterId = (id) {
        final current = library.positionFor(id);
        final snapshot = store.seriesSnapshot(id);
        final confirmed =
            snapshot != null && library.shouldRemindReadingJump(snapshot)
            ? current?.returnPoint
            : current;
        return confirmed?.chapterId;
      };
      Future<void> save(int chapter) => library.savePosition(
        novel: combined,
        chapter: chapter,
        offset: .5,
        maximum: 1,
        width: 390,
      );
      await save(0);
      expect(store.books.single.coverUrl, firstCover);
      await save(1);
      expect(store.book(combined.id)!.coverUrl, secondCover);
      expect(store.books.single.coverUrl, secondCover);
      await library.beginReadingJump(
        combined,
        library.positionFor(combined.id)!,
      );
      await save(0);
      expect(store.books.single.coverUrl, secondCover);
      await library.setReadingJumpReminderPercent(100);
      expect(store.books.single.coverUrl, firstCover);
      await library.setReadingJumpReminderPercent(5);
      expect(store.books.single.coverUrl, secondCover);
      await library.resolveReadingJump(combined, restore: true);
      expect(store.books.single.coverUrl, secondCover);
      await library.beginReadingJump(
        combined,
        library.positionFor(combined.id)!,
      );
      await save(0);
      await library.resolveReadingJump(combined, restore: false);
      expect(store.books.single.coverUrl, firstCover);
      await store.saveSeries(
        id: combined.id,
        title: combined.title,
        volumes: [
          (bookId: second.id, title: '第二卷'),
          (bookId: first.id, title: '第一卷'),
        ],
      );
      expect(store.books.single.coverUrl, firstCover);
      await store.load();
      expect(store.book(combined.id)!.coverUrl, firstCover);
      await store.setVolumeCover(combined.id, second.id);
      final fallbackRecords = await File(
        '${store.directory.path}/covers.json',
      ).readAsString();
      expect(store.hasCustomCover(combined.id), isTrue);
      expect(store.book(combined.id)!.coverUrl, firstCover);
      await save(1);
      expect(store.book(combined.id)!.coverUrl, secondCover);
      expect(store.books.single.coverUrl, secondCover);
      expect(
        await File('${store.directory.path}/covers.json').readAsString(),
        fallbackRecords,
      );
      await store.restoreCover(combined.id);
      expect(store.book(combined.id)!.coverUrl, secondCover);
      expect((await store.original(first.id)).bytes, before);
    },
  );

  testWidgets('local details render immediately while navigation is prepared', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = LibraryState(await SharedPreferences.getInstance());
    addTearDown(library.dispose);
    final cache = OfflineCacheStore(Directory('${root.path}/cache'));
    final repository = _SlowLocalDetail(cache: cache, local: store);
    addTearDown(repository.dispose);
    addTearDown(cache.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DetailLoaderPage(
          novel: first,
          state: library,
          repository: repository,
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<DetailPage>(find.byType(DetailPage)).isLoading,
      isFalse,
    );
    expect(find.byKey(const ValueKey('detail-meta-skeleton')), findsNothing);
    expect(repository.loaded.isCompleted, isFalse);
    repository.loaded.complete(first);
    await tester.pumpAndSettle();
    expect(repository.chapterRequests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

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
      final category = find.byKey(const ValueKey('local-edit-category'));
      await tester.ensureVisible(category);
      await tester.pumpAndSettle();
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        '配置中新建',
      );
      await tester.tap(find.byKey(const ValueKey('category-save')));
      await tester.pumpAndSettle();
      expect(library.organization.groups.values, contains('配置中新建'));
      expect(
        find.byKey(const ValueKey('custom-category-list')),
        findsOneWidget,
      );
      final id = library.organization.groups.entries
          .singleWhere((e) => e.value == '配置中新建')
          .key;
      await tester.tap(find.byKey(ValueKey('category-select-$id')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: category, matching: find.text('配置中新建')),
        findsOneWidget,
      );
      expect(
        library.organization.groupOf(first.id),
        LocalLibraryPreferences.unfiled,
      );
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(ValueKey('custom-category-$id')),
        const Offset(-220, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('category-delete-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除分类'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('custom-category-list')),
        findsOneWidget,
      );
      expect(library.organization.groups.containsKey(id), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: category, matching: find.text('未分类')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
