import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:wenku8_flutter/main.dart' show NovelApp;
import 'package:wenku8_flutter/home_navigation.dart';
import 'package:wenku8_flutter/glass_dock.dart';
import 'package:wenku8_flutter/app_ui.dart';
import 'package:wenku8_flutter/updates/app_updates.dart';
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

class _WaitingUpdates extends AppUpdates {
  _WaitingUpdates(SharedPreferences preferences)
    : super(preferences: preferences, packageUpdates: false);
  final ready = Completer<void>();
  @override
  Future<void> loadInstalled({bool refresh = false}) => ready.future;
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

  testWidgets(
    'launch first frame is the cover, reader handoff never mounts home',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({'openRecentOnLaunch': true});
      state = await LibraryState.load();
      await state.savePosition(
        novel: book,
        chapter: 0,
        offset: .4,
        maximum: 1,
        width: 390,
      );
      repository = _DelayedRepository();
      await tester.pumpWidget(NovelApp(state: state, repository: repository));
      expect(find.byType(ReaderOpeningCover), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ReaderLoaderPage), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      expect(repository.directoryRequests, 1);
      // Back constructs the home for the first time; persisted tab IDs survive.
      Navigator.of(tester.element(find.byType(ReaderLoaderPage))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
      final navigation = HomeNavigation(state, null);
      expect(navigation.tabs, [1, 2, 3]);
      expect(navigation.destination(1), 1);
      expect(navigation.destination(2), 2);
      expect(navigation.destination(0), 2);
      navigation.dispose();
      final dock = tester.widget<GlassDock>(find.byType(GlassDock));
      expect(dock.items.map((item) => item.label), ['书架', '本地', '我的']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('cancel launch cover while startup metadata is pending', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({'openRecentOnLaunch': true});
    final prefs = await SharedPreferences.getInstance();
    state = LibraryState(prefs);
    await state.savePosition(
      novel: book,
      chapter: 0,
      offset: .4,
      maximum: 1,
      width: 390,
    );
    // Use load to consume the real serialized launch preference and history.
    state.dispose();
    state = await LibraryState.load();
    repository = _DelayedRepository();
    final updates = _WaitingUpdates(prefs);
    addTearDown(updates.dispose);
    await tester.pumpWidget(
      NovelApp(state: state, repository: repository, updates: updates),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeShell), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(HomeShell), findsOneWidget);
    updates.ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderLoaderPage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('detail reveal overlaps incoming cover flight', (tester) async {
    SharedPreferences.setMockInitialValues({});
    state = await LibraryState.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openDetail(
                context,
                book,
                state,
                const DemoNovelRepository(),
                coverHeroTag: 'test-cover',
              ),
              child: const Text('打开详情'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开详情'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 150));
    final reveal = tester.widget<RevealFromTop>(
      find.byKey(const ValueKey('detail-meta-reveal')),
    );
    expect(reveal.animation.value, greaterThan(0));
    expect(
      ModalRoute.of(tester.element(find.byType(DetailPage)))!.animation!.status,
      AnimationStatus.forward,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
        expect(find.byType(ReaderOpeningCover), findsOneWidget);
        await tester.runAsync(() async {
          image.complete(bytes);
          await pendingImage;
        });
        await tester.pumpAndSettle();
        expect(view.controller.ready, isTrue);
        expect(view.controller.anchor?.paragraph, 10);
        expect(find.byType(ReaderOpeningCover), findsNothing);
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
        if (find.byType(ReaderOpeningCover).evaluate().isEmpty &&
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
      expect(find.byType(ReaderOpeningCover), findsOneWidget);
      repository.directory.complete(book.chapters.take(1).toList());
      await tester.pumpAndSettle();
      expect(find.byType(ReaderPage), findsOneWidget);
      expect(find.byType(ReaderOpeningCover), findsOneWidget);
      final reader = tester.state(find.byType(ReaderPage));
      repository.text.complete('第一章\n合成测试正文，用于验证启动续读的加载交接。');
      await tester.pumpAndSettle();
      expect(find.byType(ReaderOpeningCover), findsNothing);
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
    expect(find.byType(ReaderOpeningCover), findsNothing);
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
      expect(find.byType(ReaderOpeningCover), findsNothing);
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
    expect(find.byType(ReaderOpeningCover), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'cover fills portrait width and stays inside short landscape viewport',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, scale: 2);
      expect(find.byType(ReaderOpeningCover), findsOneWidget);
      final cover = tester.widget<NovelCover>(
        find.descendant(
          of: find.byType(ReaderOpeningCover),
          matching: find.byType(NovelCover),
        ),
      );
      expect(cover.width, closeTo((280 - 32) / 1.4, .1));
      expect(cover.height, closeTo(280 - 32, .1));
      expect(cover.fit, BoxFit.contain);
      expect(find.text('正在继续阅读…'), findsNothing);
      expect(find.text('返回书库'), findsNothing);
      expect(
        find.text(book.title).evaluate().length,
        find
            .descendant(
              of: find.byType(NovelCover),
              matching: find.text(book.title),
            )
            .evaluate()
            .length,
      );
      tester.view.physicalSize = const Size(500, 983);
      await tester.pump();
      final portrait = tester.widget<NovelCover>(
        find.descendant(
          of: find.byType(ReaderOpeningCover),
          matching: find.byType(NovelCover),
        ),
      );
      expect(portrait.width, 492);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
