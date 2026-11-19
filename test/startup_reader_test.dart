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
import 'package:wenku8_flutter/illustration_placement.dart';
import 'package:wenku8_flutter/listening/controller.dart';
import 'package:wenku8_flutter/listening/models.dart';
import 'package:wenku8_flutter/listening/widgets.dart';
import 'package:wenku8_flutter/pages.dart';
import 'package:wenku8_flutter/local_book_media.dart';
import 'package:wenku8_flutter/reader_illustrations.dart';
import 'package:wenku8_flutter/reader_paged_view.dart';
import 'package:wenku8_flutter/reader_preferences.dart';
import 'package:wenku8_flutter/reader_selection.dart';
import 'package:wenku8_flutter/reader_tools.dart';

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

class _TestListening extends Fake implements ListeningController {
  @override
  final snapshot = ValueNotifier(const ListeningSnapshot());
  @override
  final progress = ValueNotifier(const ListeningProgress());
  final followChanges = <bool>[];
  int playbackCommands = 0;

  @override
  Future<void> setFollow(bool follow) async {
    followChanges.add(follow);
    snapshot.value = ListeningSnapshot(
      novel: snapshot.value.novel,
      phase: snapshot.value.phase,
      follow: follow,
    );
  }

  @override
  Future<void> pause() async => playbackCommands++;

  @override
  Future<void> stop() async => playbackCommands++;
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
    ListeningController? listening,
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
          child: ListeningScope(controller: listening, child: child!),
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

  for (final effect in [ReaderPageEffect.none, ReaderPageEffect.paper]) {
    testWidgets('local image fills viewport width with ${effect.name} turns', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousRoot = LocalBookMedia.root;
      final previousReader = LocalBookMedia.externalImage;
      final previousBatch = LocalBookMedia.externalImages;
      final output = Directory('.tmp/verification')
        ..createSync(recursive: true);
      final root = output.createTempSync('full-width-epub-');
      const url = 'wenku-local://1610612736/img-900.png';
      final bytes = File('assets/report/season-spring.png').readAsBytesSync();
      LocalBookMedia.root = root;
      LocalBookMedia.externalImage = (_, _) async => bytes;
      ReaderIllustrationCache.shared.clearMemory();
      addTearDown(() {
        ReaderIllustrationCache.shared.clearMemory();
        LocalBookMedia.root = previousRoot;
        LocalBookMedia.externalImage = previousReader;
        LocalBookMedia.externalImages = previousBatch;
        root.deleteSync(recursive: true);
      });
      final listening = _TestListening();
      addTearDown(listening.snapshot.dispose);
      addTearDown(listening.progress.dispose);
      await open(tester, mode: ReaderMode.paged, listening: listening);
      await state.setReaderPreferences(
        state.readerPreferencesFor(book.id).copyWith(pageEffect: effect),
        persist: false,
      );
      repository.directory.complete(book.chapters.take(1).toList());
      await tester.pumpAndSettle();
      repository.text.complete('<!--image-->$url<!--image-->');
      await tester.pump();
      await tester.runAsync(() async {
        await ReaderIllustrationCache.shared.dimensions(url);
      });
      await tester.pumpAndSettle();
      final images = find.descendant(
        of: find.byType(ReaderIllustration),
        matching: find.byType(Image),
      );
      expect(images, findsOneWidget);
      expect(tester.getRect(images).left, closeTo(0, .01));
      expect(tester.getSize(images).width, closeTo(400, .01));
      expect(tester.widget<Image>(images).fit, BoxFit.contain);

      // A full-page illustration shares the reader's centre tap, while only
      // a long press opens the gallery. Check both paper and static turns.
      final illustration = find.byType(ReaderIllustration);
      expect(tester.widget<ReaderIllustration>(illustration).onOpen, isNull);
      expect(
        tester.widget<ReaderIllustration>(illustration).onLongPress,
        isNotNull,
      );
      // Target the actual gesture surface, not Image's transient render
      // subtree: the engine can still be decoding and showing a skeleton.
      final target = find.descendant(
        of: illustration,
        matching: find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onLongPress != null,
        ),
      );
      expect(target.hitTestable(), findsOneWidget);
      final chromeWasVisible = state.readerChromeVisible;
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(ReaderIllustrationGallery), findsNothing);
      expect(state.readerChromeVisible, !chromeWasVisible);
      expect(target.hitTestable(), findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(state.readerChromeVisible, chromeWasVisible);
      expect(target.hitTestable(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('再滑动一次退出阅读'), findsOneWidget);
      final followsThisBook = effect == ReaderPageEffect.none;
      listening.snapshot.value = ListeningSnapshot(
        novel: followsThisBook
            ? book
            : demoNovels.firstWhere((novel) => novel.id != book.id),
        phase: ListeningPhase.playing,
      );
      await tester.longPress(target);
      await tester.pumpAndSettle();
      expect(find.byType(ReaderIllustrationGallery), findsOneWidget);
      expect(state.readerChromeVisible, chromeWasVisible);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ReaderIllustrationGallery), findsNothing);
      expect(target.hitTestable(), findsOneWidget);
      expect(state.readerChromeVisible, chromeWasVisible);
      expect(listening.followChanges, followsThisBook ? [false] : isEmpty);
      expect(listening.snapshot.value.follow, !followsThisBook);
      expect(listening.snapshot.value.playing, isTrue);
      expect(listening.playbackCommands, 0);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('再滑动一次退出阅读'), findsOneWidget);
      expect(target.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final (mode, effect, placed) in [
    (ReaderMode.scroll, ReaderPageEffect.none, false),
    (ReaderMode.paged, ReaderPageEffect.none, false),
    (ReaderMode.paged, ReaderPageEffect.paper, false),
    (ReaderMode.scroll, ReaderPageEffect.none, true),
  ]) {
    testWidgets(
      '${placed ? 'canceling placed image actions' : 'opening an image'} '
      'stops automatic movement in ${mode.name}/${effect.name}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(400, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previousRoot = LocalBookMedia.root;
        final previousReader = LocalBookMedia.externalImage;
        final previousBatch = LocalBookMedia.externalImages;
        final output = Directory('.tmp/verification')
          ..createSync(recursive: true);
        final root = output.createTempSync('full-width-epub-');
        final url = placed
            ? 'https://example.invalid/placed.png'
            : 'wenku-local://1610612736/img-900.png';
        final bytes = File('assets/report/season-spring.png').readAsBytesSync();
        LocalBookMedia.root = root;
        LocalBookMedia.externalImage = (_, _) async => bytes;
        final cache = ReaderIllustrationCache.shared;
        final offlineReader = cache.offlineReader;
        cache.clearMemory();
        if (placed) cache.offlineReader = (_) async => bytes;
        addTearDown(() {
          cache.clearMemory();
          cache.offlineReader = offlineReader;
          LocalBookMedia.root = previousRoot;
          LocalBookMedia.externalImage = previousReader;
          LocalBookMedia.externalImages = previousBatch;
          root.deleteSync(recursive: true);
        });
        await open(tester, mode: mode);
        await state.setReaderPreferences(
          state.readerPreferencesFor(book.id).copyWith(pageEffect: effect),
          persist: false,
        );
        const anchor = '插图之前的正文。';
        final chapter = placed
            ? const NovelChapter('插图测试章节', '', id: 1)
            : book.chapters.first;
        final placement = placed
            ? IllustrationPlacement.at(
                chapterId: chapter.id,
                chapterTitle: chapter.title,
                url: url,
                paragraphs: const [anchor],
                paragraph: 0,
              )
            : null;
        if (placement != null) {
          await state.putIllustration(book.id, placement);
        }
        repository.directory.complete([chapter]);
        await tester.pumpAndSettle();
        repository.text.complete(
          '${placed ? anchor : '<!--image-->$url<!--image-->'}\n\n'
          '${List.generate(100, (index) => '后页正文第$index段。用于确认查看插图后自动翻页已经停止。').join('\n\n')}',
        );
        await tester.pump();
        await tester.runAsync(() async {
          await ReaderIllustrationCache.shared.dimensions(url);
        });
        await tester.pumpAndSettle();
        final images = find.descendant(
          of: find.byType(ReaderIllustration),
          matching: find.byType(Image),
        );
        expect(images, findsOneWidget);

        final target = find.descendant(
          of: find.byType(ReaderIllustration),
          matching: find.byWidgetPredicate(
            (widget) => widget is GestureDetector && widget.onLongPress != null,
          ),
        );
        expect(target.hitTestable(), findsOneWidget);
        // Start automatic movement through the tools route before opening
        // the gallery. Keep the initial illustration within reach.
        if (!state.readerChromeVisible) {
          await tester.tap(target);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('reader-operations-entry')));
        await tester.pumpAndSettle();
        Navigator.of(
          tester.element(find.byType(ReaderTools)),
        ).pop(const ReaderStartAutoScroll());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        final paged = mode == ReaderMode.paged
            ? tester
                  .widget<ReaderPagedView>(find.byType(ReaderPagedView))
                  .controller
            : null;
        final scroll = mode == ReaderMode.scroll
            ? tester
                  .state<ScrollableState>(
                    find.ancestor(
                      of: target,
                      matching: find.byType(Scrollable),
                    ),
                  )
                  .position
            : null;
        if (paged != null) expect(paged.pageCount, greaterThan(1));
        if (scroll != null) {
          expect(scroll.maxScrollExtent, greaterThan(0));
          final before = scroll.pixels;
          for (var frame = 0; frame < 8; frame++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(scroll.pixels, greaterThan(before));
        }
        final pageBeforeGallery = paged?.page;
        await tester.longPress(target);
        await tester.pumpAndSettle();
        expect(state.readerChromeVisible, isFalse);
        if (placement != null) {
          expect(find.text('插图操作'), findsOneWidget);
          await tester.tap(find.text('取消'));
        } else {
          expect(find.byType(ReaderIllustrationGallery), findsOneWidget);
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byType(ReaderIllustrationGallery), findsNothing);
        expect(find.text('插图操作'), findsNothing);
        if (placement != null) {
          expect(state.illustrationsFor(book.id).map((item) => item.id), [
            placement.id,
          ]);
        }
        expect(target.hitTestable(), findsOneWidget);
        final offsetAfterGallery = scroll?.pixels;
        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        expect(paged?.page, pageBeforeGallery);
        expect(scroll?.pixels, offsetAfterGallery);
        if (placement != null) {
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(find.text('再滑动一次退出阅读'), findsOneWidget);
          await tester.longPress(find.text(anchor, findRichText: true));
          await tester.pumpAndSettle();
          final selection = tester
              .widget<ReaderSelection>(find.byType(ReaderSelection))
              .controller;
          expect(selection.value, isTrue);
          expect(find.text('再滑动一次退出阅读'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
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
      expect(navigation.destination(0), 1);
      navigation.dispose();
      final dock = tester.widget<GlassDock>(find.byType(GlassDock));
      expect(dock.items.map((item) => item.label), ['书架', '本地', '我的']);
      expect(dock.selectedIndex, 0);
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
