import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/book_collection_region_toolbar.dart';
import 'package:wenku8_flutter/book_collection_view_options.dart';
import 'package:wenku8_flutter/book_shelf_content_preferences.dart';
import 'package:wenku8_flutter/local_library_preferences.dart';

void main() {
  final authorA = LocalLibraryPreferences.authorCategory('作者甲');
  final authorB = LocalLibraryPreferences.authorCategory('作者乙');
  final series = LocalLibraryPreferences.seriesCategory('星空旅人');
  final tag = LocalLibraryPreferences.tagCategory('奇幻');
  late List<String?> results;

  Future<void> open(
    WidgetTester tester, {
    Map<String, String>? options,
    String selected = LocalLibraryPreferences.all,
    Size size = const Size(390, 800),
    double scale = 1,
    bool reduced = false,
    Brightness brightness = Brightness.light,
  }) async {
    results = [];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                results.add(
                  await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: SafeArea(
                          child: SizedBox(
                            height: size.height * .72,
                            child: BookShelfCategoryPicker(
                              selected: selected,
                              options:
                                  options ??
                                  {
                                    '_all': '全部书籍',
                                    '_unfiled': '未分类',
                                    'manual': '我的自定义分类',
                                    authorA: '作者 · 作者甲',
                                    authorB: '作者 · 作者乙',
                                    series: '系列 · 星空旅人',
                                    tag: '标签 · 奇幻',
                                    LocalLibraryPreferences.noTag: '未标注标签',
                                    LocalLibraryPreferences.noSeries: '未归入系列',
                                  },
                              reduceMotion: reduced,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('打开分类'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开分类'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'primary menu has exactly four families and opens details on right',
    (tester) async {
      await open(tester);
      final primary = find.byKey(const ValueKey('shelf-category-primary'));
      expect(
        find.descendant(of: primary, matching: find.text('全部书籍')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: primary, matching: find.text('按作者分类')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: primary, matching: find.text('按系列分类')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: primary, matching: find.text('按标签分类')),
        findsOneWidget,
      );
      expect(find.text('我的自定义分类'), findsNothing);
      expect(find.byType(CupertinoPicker), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('shelf-category-family-authors')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsOneWidget);
      expect(
        tester.getCenter(find.byType(CupertinoPicker)).dx,
        greaterThan(tester.getCenter(primary).dx),
      );
      expect(find.text('作者甲'), findsWidgets);
      expect(find.text('奇幻'), findsNothing);
      expect(results, isEmpty);
      await tester.tap(find.byKey(const ValueKey('shelf-category-confirm')));
      await tester.pumpAndSettle();
      expect(results, [authorA]);
    },
  );

  testWidgets(
    'wheel scroll is tentative until confirmed and keeps category ID',
    (tester) async {
      final authors = {
        for (var i = 0; i < 30; i++)
          LocalLibraryPreferences.authorCategory('作者$i'): '作者 · 作者$i',
      };
      await open(tester, options: {'_all': '全部书籍', ...authors});
      await tester.tap(
        find.byKey(const ValueKey('shelf-category-family-authors')),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -130));
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoPicker>(
        find.byType(CupertinoPicker),
      );
      final index = picker.scrollController!.selectedItem;
      expect(index, greaterThan(0));
      expect(results, isEmpty);
      await tester.tap(find.byKey(const ValueKey('shelf-category-confirm')));
      await tester.pumpAndSettle();
      expect(results, [authors.keys.elementAt(index)]);
    },
  );

  testWidgets('cancel preserves a selected manual category without migration', (
    tester,
  ) async {
    await open(tester, selected: 'manual');
    expect(find.text('当前：我的自定义分类'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shelf-category-family-tags')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-category-cancel')));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('no-series and no-tag views retain their persisted identities', (
    tester,
  ) async {
    await open(tester, selected: LocalLibraryPreferences.noSeries);
    expect(find.text('已选：未归入系列'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shelf-category-family-tags')));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.scrollController!.jumpToItem(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-category-confirm')));
    await tester.pumpAndSettle();
    expect(results, [LocalLibraryPreferences.noTag]);
  });

  testWidgets(
    'empty family has an honest empty state and cannot be confirmed',
    (tester) async {
      await open(tester, options: const {'_all': '全部书籍'});
      await tester.tap(
        find.byKey(const ValueKey('shelf-category-family-series')),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前书库暂无系列信息'), findsOneWidget);
      expect(find.byType(CupertinoPicker), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shelf-category-confirm')));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      await tester.tap(find.byKey(const ValueKey('shelf-category-family-all')));
      await tester.pumpAndSettle();
      expect(results, ['_all']);
    },
  );

  testWidgets(
    'narrow dark large-text picker handles long labels without overflow',
    (tester) async {
      const longName = '这是一个很长的中文作者名称与日文名字あいうえお';
      await open(
        tester,
        size: const Size(320, 568),
        scale: 1.5,
        reduced: true,
        brightness: Brightness.dark,
        options: {
          '_all': '全部书籍',
          LocalLibraryPreferences.authorCategory(longName): '作者 · $longName',
        },
      );
      await tester.tap(
        find.byKey(const ValueKey('shelf-category-family-authors')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey('shelf-category-family-series')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shelf-category-family-tags')),
        70,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('shelf-category-primary')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('shelf-category-family-tags')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shelf-category-family-tags')),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前书库暂无标签'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filter settings reuse the cascade and preserve other shelf filters',
    (tester) async {
      final preferences = ValueNotifier(
        const BookShelfContentPreferences(
          followCollection: false,
          readingFilter: 'unread',
          sort: BookShelfContentSort.title,
        ),
      );
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<BookShelfContentPreferences>(
                valueListenable: preferences,
                builder: (context, value, _) => BookShelfContentOptions(
                  value: value,
                  showFollow: false,
                  reduceMotion: true,
                  categoryOptions: {'_all': '全部书籍', series: '系列 · 星空旅人'},
                  onChanged: (value) => preferences.value = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('shelf-content-category')));
      await tester.pumpAndSettle();
      expect(find.byType(BookShelfCategoryPicker), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('shelf-category-family-series')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-category-confirm')));
      await tester.pumpAndSettle();
      expect(preferences.value.category, series);
      expect(preferences.value.readingFilter, 'unread');
      expect(preferences.value.sort, BookShelfContentSort.title);
      expect(preferences.value.followCollection, isFalse);
      expect(find.byType(BookShelfCategoryPicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
