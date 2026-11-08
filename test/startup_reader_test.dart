import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/pages.dart';
import 'package:wenku8_flutter/local_book_media.dart';
import 'package:wenku8_flutter/reader_illustrations.dart';
import 'package:wenku8_flutter/reader_paged_view.dart';
import 'package:wenku8_flutter/reader_preferences.dart';

class _DelayedRepository extends DemoNovelRepository {
  final directory = Completer<List<NovelChapter>>();
  final text = Completer<String>();
  int contentRequests = 0;
  int directoryRequests = 0;

  @override
  Future<List<NovelChapter>> chapters(int id) {
    directoryRequests++;
    return directory.future;
  }

  @override
  Future<String> chapterContent(int novelId, NovelChapter chapter) {
    contentRequests++;
    return text.future;
  }
}

void main() {
  late LibraryState state;
  late _DelayedRepository repository;
  final book = demoNovels.first;

  tearDown(() => state.dispose());

  Future<void> open(
    WidgetTester tester, {
    bool reduced = false,
    double scale = 1,
    ReaderMode mode = ReaderMode.scroll,
    int? savedParagraph,
  }) async {
    SharedPreferences.setMockInitialValues({});
    state = await LibraryState.load();
    await state.setReaderPreferences(
      state.readerPreferencesFor(book.id).copyWith(mode: mode),
      persist: false,
    );
    if (savedParagraph != null) {
      await state.savePosition(
        novel: book,
        chapter: 0,
        offset: 5000,
        maximum: 10000,
        width: 390,
        paragraphIndex: savedParagraph,
        textOffset: 0,
      );
    }
    repository = _DelayedRepository();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: ReaderLoaderPage(
          novel: book,
          state: state,
          repository: repository,
          openingCover: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(repository.directoryRequests, 1);
  }

  for (final variant in [
    (ReaderMode.paged, true),
    (ReaderMode.paged, false),
    (ReaderMode.vertical, true),
  ]) {
    testWidgets(
      'cover waits for ${variant.$1.name} image measurement and saved page, reduced=${variant.$2}',
      (tester) async {
        final previousRoot = LocalBookMedia.root;
        final previousReader = LocalBookMedia.externalImage;
        final previousBatch = LocalBookMedia.externalImages;
        final output = Directory('.tmp/verification')
          ..createSync(recursive: true);
        final root = output.createTempSync('startup-pagination-');
        late Completer<Uint8List> image;
        var requested = false;
        const url = 'wenku-local://1610612736/img-801.png';
        final bytes = File('assets/report/season-spring.png').readAsBytesSync();
        LocalBookMedia.root = root;
        LocalBookMedia.externalImage = (_, _) {
          requested = true;
          return image.future;
        };
        ReaderIllustrationCache.shared.clearMemory();
        addTearDown(() {
          if (!image.isCompleted) image.complete(bytes);
          ReaderIllustrationCache.shared.clearMemory();
          LocalBookMedia.root = previousRoot;
          LocalBookMedia.externalImage = previousReader;
          LocalBookMedia.externalImages = previousBatch;
          root.deleteSync(recursive: true);
        });
        late Future<Uint8List> pendingImage;
        await tester.runAsync(() async {
          image = Completer<Uint8List>();
          pendingImage = LocalBookMedia.load(url);
          for (var attempt = 0; !requested && attempt < 1000; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
          expect(requested, isTrue);
        });
        await open(
          tester,
          mode: variant.$1,
          reduced: variant.$2,
          savedParagraph: 10,
        );
        repository.directory.complete(book.chapters.take(1).toList());
        await tester.pumpAndSettle();
        repository.text.complete(
          '<!--image-->$url<!--image-->\n\n${List.generate(30, (i) => '第 $i 段合成正文，验证分页完成与阅读锚点恢复。' * 8).join('\n\n')}',
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        final view = tester.widget<ReaderPagedView>(
          find.byType(ReaderPagedView),
        );
        expect(view.controller.ready, isFalse);
        expect(find.text('正在继续阅读…'), findsOneWidget);
        await tester.runAsync(() async {
          image.complete(bytes);
          await pendingImage;
        });
        await tester.pumpAndSettle();
        expect(view.controller.ready, isTrue);
        expect(view.controller.anchor?.paragraph, 10);
        expect(find.text('正在继续阅读…'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'scroll cover stays until the saved paragraph finishes restoring',
    (tester) async {
      await open(tester, reduced: true, savedParagraph: 80);
      repository.directory.complete(book.chapters.take(1).toList());
      await tester.pumpAndSettle();
      repository.text.complete(
        List.generate(
          200,
          (i) => '第 $i 段合成正文，验证滚动锚点恢复。' * (i % 17 + 1),
        ).join('\n\n'),
      );
      double? firstRevealedOffset;
      ScrollController? scroll;
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final views = find.descendant(
          of: find.byType(ReaderPage),
          matching: find.byType(CustomScrollView),
        );
        if (views.evaluate().isEmpty) continue;
        scroll = tester.widget<CustomScrollView>(views.first).controller;
        if (find.text('正在继续阅读…').evaluate().isEmpty &&
            scroll?.hasClients == true) {
          firstRevealedOffset ??= scroll!.offset;
        }
      }
      await tester.pumpAndSettle();
      expect(firstRevealedOffset, isNotNull);
      expect(scroll!.offset, greaterThan(0));
      expect(firstRevealedOffset, closeTo(scroll.offset, .5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'one cover spans directory and chapter preparation without remount',
    (tester) async {
      await open(tester);
      expect(find.text('正在继续阅读…'), findsOneWidget);
      repository.directory.complete(book.chapters.take(1).toList());
      await tester.pumpAndSettle();
      expect(find.byType(ReaderPage), findsOneWidget);
      expect(find.text('正在继续阅读…'), findsOneWidget);
      final reader = tester.state(find.byType(ReaderPage));
      repository.text.complete('第一章\n合成测试正文，用于验证启动续读的加载交接。');
      await tester.pumpAndSettle();
      expect(find.text('正在继续阅读…'), findsNothing);
      expect(tester.state(find.byType(ReaderPage)), same(reader));
      expect(repository.contentRequests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('directory failure reveals retry and is not hidden by cover', (
    tester,
  ) async {
    await open(tester);
    repository.directory.completeError(const FormatException('测试目录不可用'));
    await tester.pumpAndSettle();
    expect(find.text('正在继续阅读…'), findsNothing);
    expect(find.text('测试目录不可用'), findsOneWidget);
    expect(find.text('暂时无法打开本书'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reduced motion removes cover after initial position is restored',
    (tester) async {
      await open(tester, reduced: true);
      repository.directory.complete(book.chapters.take(1).toList());
      await tester.pumpAndSettle();
      repository.text.complete('测试正文。');
      await tester.pumpAndSettle();
      expect(find.text('正在继续阅读…'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('chapter failure also removes startup cover', (tester) async {
    await open(tester);
    repository.directory.complete(book.chapters.take(1).toList());
    await tester.pumpAndSettle();
    repository.text.completeError(const FormatException('测试正文不可用'));
    await tester.pumpAndSettle();
    expect(find.text('正在继续阅读…'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('large text in short landscape viewport keeps cover scrollable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, scale: 2);
    expect(find.text('正在继续阅读…'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
