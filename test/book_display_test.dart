import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenku8_flutter/book_collection_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/book_collection_grid.dart';
import 'package:wenku8_flutter/archive_wave.dart';
import 'package:wenku8_flutter/book_collection_mode.dart';
import 'package:wenku8_flutter/book_collection_view_options.dart';
import 'package:wenku8_flutter/book_grid_density.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/local_library_preferences.dart';
import 'package:wenku8_flutter/pages.dart';

const book = Novel(
  id: 1042,
  title: '星空旅人与没有尽头的漫长旅途',
  author: '拥有非常漫长名字的作者',
  genre: '',
  summary: '',
  colors: [Colors.blue, Colors.grey],
  chapters: [
    NovelChapter('出发', '正文', id: 11),
    NovelChapter('归来', '正文', id: 12),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy display defaults and independent preferences survive reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = LocalLibraryPreferences(prefs)..load();
      addTearDown(settings.dispose);
      expect(settings.showSeries, isTrue);
      expect(settings.showProgressBar, isTrue);
      expect(settings.progressDisplay, BookProgressDisplay.percentage);
      await settings.setShowSeries(false);
      await settings.setShowProgressBar(false);
      await settings.setProgressDisplay(BookProgressDisplay.pages);
      final restored = LocalLibraryPreferences(prefs)..load();
      addTearDown(restored.dispose);
      expect(restored.showSeries, isFalse);
      expect(restored.showProgressBar, isFalse);
      expect(restored.progressDisplay, BookProgressDisplay.pages);
    },
  );

  test(
    'measured chapter pages are optional display data and scroll clears them',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = LibraryState(prefs);
      addTearDown(state.dispose);
      expect(state.readingProgressLabel(book), '未读');
      await state.savePosition(
        novel: book,
        chapter: 0,
        offset: .5,
        maximum: 1,
        width: 320,
        paragraphIndex: 3,
        textOffset: 9,
        chapterPage: 3,
        chapterPages: 5,
      );
      expect(state.readingFractionForNovel(book), .25);
      expect(state.readingProgressLabel(book), '25.0%');
      expect(state.readingProgressLabel(book, pages: true), '第 1/2 章 · 3/5 页');
      final copy = ReadingPosition.fromJson(
        state.positionFor(book.id)!.toJson(),
      );
      expect(copy.chapterPage, 3);
      expect(copy.chapterPages, 5);
      expect(copy.paragraphIndex, 3);
      expect(copy.textOffset, 9);
      final invalid = ReadingPosition.fromJson({
        ...copy.toJson(),
        'chapterPage': 10,
      });
      expect(invalid.chapterPage, isNull);
      await state.savePosition(
        novel: book,
        chapter: 1,
        offset: 10,
        maximum: 100,
        width: 320,
        paragraphIndex: 2,
        textOffset: 7,
      );
      expect(state.positionFor(book.id)!.chapterPage, isNull);
      expect(state.readingProgressLabel(book, pages: true), '第 2/2 章 · 页码待分页');
      await state.savePosition(
        novel: book,
        chapter: 1,
        offset: 1,
        maximum: 1,
        width: 320,
        chapterPage: 5,
        chapterPages: 5,
      );
      expect(state.readingFractionForNovel(book), 1);
      expect(state.readingProgressLabel(book), '已读完');
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'resume information and footer open the same saved chapter on $brightness',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final state = await LibraryState.load();
        addTearDown(state.dispose);
        await state.savePosition(
          novel: book,
          chapter: 1,
          offset: .11,
          maximum: 1,
          width: 390,
        );
        final opened = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: DetailPage(
              novel: book,
              state: state,
              repository: const DemoNovelRepository(),
              onRead: opened.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final information = find.byKey(
          const ValueKey('detail-resume-information'),
        );
        await tester.ensureVisible(information);
        await tester.pumpAndSettle();
        await tester.tap(information);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('detail-read-button')));
        await tester.pumpAndSettle();
        expect(opened, [1, 1]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'grid and list retain series and progress at large text in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final geometry = BookGridViewport(
          width: 272,
          height: 780,
          textScaler: TextScaler.linear(2),
          showSeries: true,
          showProgressBar: true,
        ).resolve(const BookGridDensity.sized(BookGridSize.small));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      BookGridScope(
                        geometry: geometry,
                        child: SizedBox(
                          width: geometry.cellWidth,
                          child: BookGridTile(
                            book: book,
                            onTap: () {},
                            trailing: const SizedBox(width: 48),
                            progress: '第 1/2 章 · 3/5 页',
                            progressValue: .25,
                            seriesLabel: '系列 · 星空旅人',
                          ),
                        ),
                      ),
                      NovelRow(
                        novel: book,
                        onTap: () {},
                        progress: '25.0%',
                        progressValue: .25,
                        seriesLabel: '系列 · 星空旅人',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('系列 · 星空旅人'), findsNWidgets(2));
        expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 1100.0]) {
    testWidgets(
      'shelf author progress updates from real history at width $width',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final state = LibraryState(await SharedPreferences.getInstance());
        addTearDown(state.dispose);
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ArchiveFileCarousel(
                  books: const [book],
                  library: state,
                  reduceMotion: true,
                  repeatFill: false,
                  onOpen: (_, _) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final progress = find.byKey(
          const ValueKey('shelf-author-progress-1042'),
        );
        expect(tester.widget<LinearProgressIndicator>(progress).value, 0);
        expect(
          find.byKey(const ValueKey('shelf-author-percentage-1042')),
          findsOneWidget,
        );
        expect(find.text('0%'), findsWidgets);
        await state.savePosition(
          novel: book,
          chapter: 0,
          offset: .5,
          maximum: 1,
          width: width,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<LinearProgressIndicator>(progress).value, .25);
        expect(find.text('25%'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('pure grid reserves real font metrics at width $width', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final loader = FontLoader('GridMetricsRegression')
          ..addFont(
            rootBundle.load('assets/fonts/ReadingSerifDisplay-Bold.ttf'),
          );
        await loader.load();
      });
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              fontFamily: 'GridMetricsRegression',
              brightness: scale == 1 ? Brightness.light : Brightness.dark,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: BookCollectionSliver(
                      grid: true,
                      gridShowSeries: true,
                      gridShowProgressBar: true,
                      gridDensity: const BookGridDensity.sized(
                        BookGridSize.small,
                      ),
                      itemCount: 1,
                      itemBuilder: (context, index) => BookGridTile(
                        book: book,
                        onTap: () {},
                        trailing: const SizedBox(width: 48),
                        seriesLabel: '系列 · 链锯人',
                        progress: '96.3%',
                        progressValue: .963,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final metadata = tester.getRect(
          find.byKey(const ValueKey('grid-metadata-1042')),
        );
        final bar = tester.getRect(find.byType(LinearProgressIndicator));
        expect(bar.bottom, lessThanOrEqualTo(metadata.bottom + .1));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'collection options expose independent progress and series controls',
    (tester) async {
      var bar = true, series = true;
      var display = BookProgressDisplay.percentage;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: BookCollectionViewOptions(
                    target: BookCollectionViewTarget.collection,
                    mode: BookCollectionMode.list,
                    onModeChanged: (_) {},
                    gridDensity: const BookGridDensity.auto(),
                    onGridDensityChanged: (_) {},
                    showProgressBar: bar,
                    showSeries: series,
                    progressDisplay: display,
                    onShowProgressBarChanged: (v) => setState(() => bar = v),
                    onShowSeriesChanged: (v) => setState(() => series = v),
                    onProgressDisplayChanged: (v) =>
                        setState(() => display = v),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('显示阅读进度条'), findsOneWidget);
      expect(find.text('显示系列信息'), findsOneWidget);
      await tester.tap(find.text('页码'));
      await tester.pumpAndSettle();
      expect(display, BookProgressDisplay.pages);
      expect(tester.takeException(), isNull);
    },
  );
}
