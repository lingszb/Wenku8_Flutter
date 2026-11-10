import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/archive_carousel.dart';
import 'package:wenku8_flutter/book_collection_mode.dart';
import 'package:wenku8_flutter/book_collection_grid.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/app_ui.dart';
import 'package:wenku8_flutter/glass_dock.dart';
import 'package:wenku8_flutter/home_navigation.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/library_backup.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/local_library_page.dart';
import 'package:wenku8_flutter/pages.dart';

class _Books extends LocalBookStore {
  _Books(this.items) : super(Directory('.tmp/verification/synthetic-library'));
  final List<Novel> items;
  @override
  List<Novel> get books => items;
  @override
  String? seriesName(int id) => id == _first.id ? '测试系列' : null;
}

class _Repository extends DemoNovelRepository {
  @override
  Future<List<NovelChapter>> chapters(int id) =>
      Completer<List<NovelChapter>>().future;
}

const _first = Novel(
  id: 100000001,
  title: '第一本很长很长的本地书籍',
  author: '作者',
  genre: '',
  summary: '',
  colors: [Colors.grey, Colors.blue],
  chapters: [NovelChapter('第一章', '本地测试正文', id: 1)],
);
const _second = Novel(
  id: 100000002,
  title: '第二本',
  author: '',
  genre: '',
  summary: '',
  colors: [Colors.grey, Colors.blue],
  chapters: [NovelChapter('第一章', '本地测试正文', id: 1)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LibraryState state;
  late _Books books;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = LibraryState(await SharedPreferences.getInstance());
    books = _Books([_first, _second]);
  });
  tearDown(() {
    books.dispose();
    state.dispose();
  });

  test('reading entry icons stay inside canvas through the full gesture', () {
    for (final symbol in [ArchiveSymbol.randomRead, ArchiveSymbol.recentRead]) {
      final frames = <String>{};
      for (var i = 0; i <= 24; i++) {
        final gesture = ArchiveIconMotion.frame(i / 24);
        frames.add(ArchiveIconArt.svg(symbol, gesture: gesture));
        for (final active in [false, true]) {
          for (final path in ArchiveIconArt.paths(
            symbol,
            gesture: gesture,
            active: active,
          )) {
            final bounds = path.getBounds();
            expect(bounds.left, greaterThanOrEqualTo(0));
            expect(bounds.top, greaterThanOrEqualTo(0));
            expect(bounds.right, lessThanOrEqualTo(24));
            expect(bounds.bottom, lessThanOrEqualTo(24));
          }
        }
      }
      expect(frames.length, greaterThan(5));
    }
  });

  test(
    'tab order and all start pages survive reload and backup restore',
    () async {
      final nav = HomeNavigation(state, null);
      addTearDown(nav.dispose);
      var changes = 0;
      nav.addListener(() => changes++);
      await state.setHomeTabOrder([
        AppStartPage.profile,
        AppStartPage.shelf,
        AppStartPage.local,
      ]);
      await state.setStartPage(AppStartPage.profile);
      expect(nav.tabs, [3, 1, 2]);
      expect(changes, 1);
      final backup = await state.createBackup();
      expect(backup.records['homeTabOrder'], ['profile', 'shelf', 'local']);
      final reload = LibraryState(await SharedPreferences.getInstance());
      addTearDown(reload.dispose);
      expect(reload.startPage, AppStartPage.profile);
      expect(reload.homeTabOrder, state.homeTabOrder);
      await state.setHomeTabOrder(AppStartPage.homeTabs);
      await state.setStartPage(AppStartPage.local);
      await state.restoreBackup(backup, importPreferences: true);
      expect(state.startPage, AppStartPage.profile);
      expect(nav.tabs, [3, 1, 2]);
      await expectLater(
        state.setHomeTabOrder([
          AppStartPage.shelf,
          AppStartPage.shelf,
          AppStartPage.local,
        ]),
        throwsFormatException,
      );
      await expectLater(
        LibraryBackup.fromRecords({
          'homeTabOrder': ['shelf', 'shelf', 'local'],
        }),
        throwsFormatException,
      );
      expect(AppStartPage.orderedTabs(['profile', 'unknown', 'profile']), [
        AppStartPage.profile,
        AppStartPage.shelf,
        AppStartPage.local,
      ]);
    },
  );

  testWidgets(
    'navigation settings change order and startup without device automation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: SettingsPage(state: state)));
      await tester.tap(find.byKey(const ValueKey('settings-usage-entry')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(
            const ValueKey('settings-start-page-AppStartPage.profile'),
          ),
        );
        await state.createBackup();
      });
      await tester.pumpAndSettle();
      expect(state.startPage, AppStartPage.profile);
      final down = find.byWidgetPredicate(
        (w) => w is GlassIconButton && w.label == '后移书架',
      );
      await tester.runAsync(() async {
        await tester.tap(down);
        await state.createBackup();
      });
      await tester.pumpAndSettle();
      expect(state.homeTabOrder.first, AppStartPage.local);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home shell starts on chosen page and retains it when tabs reorder',
    (tester) async {
      await tester.runAsync(() => state.setStartPage(AppStartPage.profile));
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            state: state,
            repository: const DemoNovelRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var dock = tester.widget<GlassDock>(
        find.byKey(const ValueKey('liquid-dock')),
      );
      expect(dock.items[dock.selectedIndex].label, '我的');
      await tester.runAsync(
        () => state.setHomeTabOrder([
          AppStartPage.profile,
          AppStartPage.local,
          AppStartPage.shelf,
        ]),
      );
      await tester.pumpAndSettle();
      dock = tester.widget<GlassDock>(
        find.byKey(const ValueKey('liquid-dock')),
      );
      expect(dock.items.map((item) => item.label), ['我的', '本地', '书架']);
      expect(dock.selectedIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test('navigation retains shelf and local identities', () {
    final navigation = HomeNavigation(state, null);
    addTearDown(navigation.dispose);
    expect(navigation.tabs, [1, 2, 3]);
    expect(navigation.destination(0), 1);
    expect(navigation.destination(2), 2);
  });

  Future<void> mount(
    WidgetTester tester, {
    bool showcase = true,
    Brightness brightness = Brightness.light,
    double scale = 1,
    double width = 320,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: TickerMode(
          enabled: showcase,
          child: LocalLibraryPage(
            books: books,
            state: state,
            showcase: showcase,
            repository: _Repository(),
            onOpen: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  for (final brightness in Brightness.values) {
    testWidgets('three showcase modes and local management in $brightness', (
      tester,
    ) async {
      await state.organization.setViewMode(BookCollectionMode.shelfList);
      await mount(tester, brightness: brightness);
      expect(find.byType(ArchiveFileCarousel), findsOneWidget);
      expect(find.byType(BookGridTile), findsNothing);
      expect(find.byType(NovelRow), findsNothing);
      await state.organization.setViewMode(BookCollectionMode.list);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ArchiveFileCarousel), findsNothing);
      expect(find.byType(NovelRow), findsNWidgets(2));
      await state.organization.setViewMode(BookCollectionMode.grid);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(BookGridTile), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      await mount(tester, showcase: false, brightness: brightness, scale: 1.5);
      expect(find.byType(ArchiveFileCarousel), findsNothing);
      expect(find.byType(BookGridTile), findsNWidgets(2));
      expect(find.byType(NovelRow), findsNothing);
      await state.organization.setViewMode(BookCollectionMode.list);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, showcase: false, brightness: brightness, scale: 1.5);
      expect(find.byType(NovelRow), findsNWidgets(2));
      await state.organization.setViewMode(BookCollectionMode.shelfList);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, showcase: false, brightness: brightness, scale: 1.5);
      expect(find.byType(ArchiveFileCarousel), findsOneWidget);
      expect(find.byType(NovelRow), findsNothing);
      expect(find.byKey(const ValueKey('shelf-random-read')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 1100.0]) {
    testWidgets(
      '3D shelf follows progress and series display preferences at $width',
      (tester) async {
        await state.organization.setViewMode(BookCollectionMode.shelfList);
        await mount(tester);
        expect(
          find.byKey(ValueKey('shelf-series-${_first.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('shelf-author-progress-${_first.id}')),
          findsOneWidget,
        );
        await state.organization.setShowSeries(false);
        await state.organization.setShowProgressBar(false);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(ValueKey('shelf-series-${_first.id}')), findsNothing);
        expect(
          find.byKey(ValueKey('shelf-author-progress-${_first.id}')),
          findsNothing,
        );
        await state.organization.setShowSeries(true);
        await state.organization.setShowProgressBar(true);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(
          find.byKey(ValueKey('shelf-series-${_first.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('shelf-author-progress-${_first.id}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty local library disables random reading and points to import',
    (tester) async {
      books.items.clear();
      await mount(tester);
      final button = tester.widget<GlassTextButton>(
        find.byKey(const ValueKey('shelf-random-read')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('书架还空着，请到本地页面导入书籍。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('random opens local reader and avoids immediate repeat', (
    tester,
  ) async {
    await state.organization.setViewMode(BookCollectionMode.list);
    await mount(tester);
    final random = find.byKey(const ValueKey('shelf-random-read'));
    await tester.tap(random);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final first = tester
        .widget<ReaderLoaderPage>(find.byType(ReaderLoaderPage))
        .novel
        .id;
    Navigator.of(tester.element(find.byType(ReaderLoaderPage))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(random);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<ReaderLoaderPage>(find.byType(ReaderLoaderPage)).novel.id,
      isNot(first),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent reads respect hidden history and resume through reader', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await state.savePosition(
        novel: _first,
        chapter: 0,
        offset: .5,
        maximum: 1,
        width: 390,
      );
      await state.savePosition(
        novel: _second,
        chapter: 0,
        offset: .2,
        maximum: 1,
        width: 390,
      );
    });
    await mount(tester, scale: 1.5);
    expect(find.byKey(ValueKey('shelf-recent-${_first.id}')), findsOneWidget);
    await tester.runAsync(() => state.hideReadingHistory(_first.id));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(ValueKey('shelf-recent-${_first.id}')), findsNothing);
    await tester.tap(find.byKey(ValueKey('shelf-recent-${_second.id}')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<ReaderLoaderPage>(find.byType(ReaderLoaderPage)).novel.id,
      _second.id,
    );
    expect(state.positionFor(_first.id)?.offset, .5);
    expect(tester.takeException(), isNull);
  });
}
