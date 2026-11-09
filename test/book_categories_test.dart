import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/book_categories.dart';
import 'package:wenku8_flutter/app_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:wenku8_flutter/local_library_preferences.dart';

class _WriteControlledPreferences extends Fake implements SharedPreferences {
  _WriteControlledPreferences(this.source);
  final SharedPreferences source;
  bool failWrites = false;
  @override
  String? getString(String key) => source.getString(key);
  @override
  Future<bool> setString(String key, String value) async =>
      failWrites ? false : source.setString(key, value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late LocalLibraryPreferences settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    settings = LocalLibraryPreferences(prefs)..load();
  });
  tearDown(() => settings.dispose());

  test(
    'order survives rename, reload, backup merge, delete and append',
    () async {
      final a = await settings.addGroup('分类甲');
      final b = await settings.addGroup('分类乙');
      final c = await settings.addGroup('分类丙');
      await settings.assign(1042, c);
      await settings.select(c);
      await settings.reorderGroups([c, a, b]);
      await settings.renameGroup(a, '甲的新名称');
      expect(settings.groups.keys, [c, a, b]);
      final restored = LocalLibraryPreferences(prefs)..load();
      addTearDown(restored.dispose);
      expect(restored.groups.keys, [c, a, b]);
      expect(restored.groupOf(1042), c);
      expect(restored.selected, c);
      final backup = settings.exportOrganization();
      await restored.removeGroup(c);
      expect(restored.groupOf(1042), LocalLibraryPreferences.unfiled);
      expect(restored.selected, LocalLibraryPreferences.all);
      final d = await restored.addGroup('分类丁');
      expect(restored.groups.keys, [a, b, d]);
      final merged = LocalLibraryPreferences(prefs);
      addTearDown(merged.dispose);
      await merged.mergeOrganization(backup);
      expect(merged.groups.keys, [c, a, b]);
      expect(merged.groupOf(1042), c);
    },
  );

  test(
    'invalid and failed reorder preserve stored order and assignments',
    () async {
      final controlled = _WriteControlledPreferences(prefs);
      final library = LocalLibraryPreferences(controlled);
      addTearDown(library.dispose);
      final a = await library.addGroup('甲');
      final b = await library.addGroup('乙');
      await library.assign(1042, a);
      final before = prefs.getString(LocalLibraryPreferences.key);
      await expectLater(library.reorderGroups([a, a]), throwsFormatException);
      await expectLater(
        library.reorderGroups([LocalLibraryPreferences.all, a]),
        throwsFormatException,
      );
      controlled.failWrites = true;
      await expectLater(library.reorderGroups([b, a]), throwsFormatException);
      expect(library.groups.keys, [a, b]);
      expect(library.groupOf(1042), a);
      expect(prefs.getString(LocalLibraryPreferences.key), before);
    },
  );

  test(
    'legacy organization retains insertion order and validates optional positions',
    () async {
      final legacy = {
        'version': 1,
        'groups': {
          'g-old-b': {'name': '旧乙', 'at': 1},
          'g-old-a': {'name': '旧甲', 'at': 1},
        },
        'assignments': <String, Object>{},
      };
      await settings.mergeOrganization(legacy);
      expect(settings.groups.keys, ['g-old-b', 'g-old-a']);
      final c = await settings.addGroup('新分类');
      expect(settings.groups.keys, ['g-old-b', 'g-old-a', c]);
      for (final invalid in [-1, 1001, 1.5, null]) {
        final bad = {
          ...legacy,
          'groups': {
            'g-old-a': {'name': '甲', 'at': 1, 'order': invalid},
          },
        };
        expect(
          () => LocalLibraryPreferences.validateOrganization(bad),
          throwsFormatException,
        );
      }
    },
  );

  Future<void> openManager(
    WidgetTester tester, {
    double width = 400,
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey('open-categories'),
                onPressed: () =>
                    showBookCategories(context, settings, reduceMotion: true),
                child: const Text('打开分类'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-categories')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'long press reorders, swipe edits and confirmed deletion keeps books',
    (tester) async {
      settings.dispose();
      settings = LocalLibraryPreferences(prefs)..load();
      final a = await settings.addGroup('分类甲');
      final b = await settings.addGroup('分类乙');
      await settings.assign(1042, b);
      await openManager(tester);
      final from = find.byKey(ValueKey('custom-category-$b'));
      final target = find.byKey(ValueKey('custom-category-$a'));
      await tester.ensureVisible(from);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(from));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, -5));
      await tester.pump();
      await gesture.moveTo(tester.getTopLeft(target) - const Offset(0, 50));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(settings.groups.keys, [b, a]);
      final restored = LocalLibraryPreferences(prefs)..load();
      addTearDown(restored.dispose);
      expect(restored.groups.keys, [b, a]);
      await tester.drag(
        find.byKey(ValueKey('custom-category-$b')),
        const Offset(-220, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('category-edit-$b')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        '更名乙',
      );
      await tester.tap(find.byKey(const ValueKey('category-save')));
      await tester.pumpAndSettle();
      expect(settings.groups[b], '更名乙');
      expect(settings.groups.keys, [b, a]);
      expect(
        find.byKey(const ValueKey('custom-category-list')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('category-name')), findsNothing);
      await tester.ensureVisible(find.byKey(ValueKey('custom-category-$b')));
      await tester.drag(
        find.byKey(ValueKey('custom-category-$b')),
        const Offset(-220, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('category-delete-$b')));
      await tester.pumpAndSettle();
      expect(find.text('删除这个分类？'), findsOneWidget);
      await tester.tap(find.text('删除分类'));
      await tester.pumpAndSettle();
      expect(settings.groups.containsKey(b), isFalse);
      expect(settings.groupOf(1042), LocalLibraryPreferences.unfiled);
      expect(settings.groups.keys, [a]);
      expect(
        find.byKey(const ValueKey('custom-category-list')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new category returns to manager and every drag handle remains active',
    (tester) async {
      settings.dispose();
      settings = LocalLibraryPreferences(prefs)..load();
      final a = await settings.addGroup('甲分类');
      final b = await settings.addGroup('乙分类');
      final c = await settings.addGroup('丙分类');
      await openManager(tester);
      final create = find.byKey(const ValueKey('category-create'));
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        '新增分类',
      );
      await tester.tap(find.byKey(const ValueKey('category-save')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('custom-category-list')),
        findsOneWidget,
      );
      final d = settings.groups.entries
          .singleWhere((e) => e.value == '新增分类')
          .key;
      expect(settings.groups.keys, [a, b, c, d]);
      Future<void> move(String id, String target, {bool below = false}) async {
        await tester.ensureVisible(
          find.byKey(ValueKey('custom-category-$target')),
        );
        await tester.pumpAndSettle();
        final handle = find.byKey(ValueKey('category-drag-$id'));
        final destination = find.byKey(ValueKey('custom-category-$target'));
        final point = below
            ? tester.getBottomLeft(destination) + const Offset(0, 50)
            : tester.getTopLeft(destination) - const Offset(0, 50);
        final gesture = await tester.startGesture(tester.getCenter(handle));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
        await gesture.moveTo(point);
        await tester.pump(const Duration(milliseconds: 300));
        final proxy = find.byKey(const ValueKey('category-drag-proxy'));
        final shape = tester.widget<PhysicalShape>(proxy);
        final size = tester.getSize(proxy);
        final path = shape.clipper.getClip(size);
        expect(path.contains(const Offset(1, 5)), isFalse);
        expect(path.contains(Offset(size.width / 2, 5)), isTrue);
        expect(path.getBounds().top, 4);
        expect(path.getBounds().bottom, size.height - 4);
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await move(a, d, below: true);
      expect(settings.groups.keys, [b, c, d, a]);
      await move(d, b);
      expect(settings.groups.keys, [d, b, c, a]);
      final restored = LocalLibraryPreferences(prefs)..load();
      addTearDown(restored.dispose);
      expect(restored.groups.keys, [d, b, c, a]);
      expect(find.byTooltip('长按拖动调整分类顺序'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('swipe actions fit narrow large text on $brightness', (
      tester,
    ) async {
      settings.dispose();
      settings = LocalLibraryPreferences(prefs)..load();
      final id = await settings.addGroup('一个很长的自定义书籍分类名称');
      await openManager(tester, width: 320, scale: 2, brightness: brightness);
      final row = find.byKey(ValueKey('custom-category-$id'));
      await tester.scrollUntilVisible(
        row,
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.drag(row, const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(find.text('长按拖动排序，左滑编辑或删除'), findsNothing);
      final edit = find.byKey(ValueKey('category-edit-$id'));
      final delete = find.byKey(ValueKey('category-delete-$id'));
      expect(tester.widget<GlassIconButton>(edit).icon, CupertinoIcons.pencil);
      expect(tester.widget<GlassIconButton>(delete).icon, CupertinoIcons.trash);
      expect(
        find.descendant(of: edit, matching: find.text('编辑')),
        findsNothing,
      );
      expect(
        find.descendant(of: delete, matching: find.text('删除')),
        findsNothing,
      );
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-name')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'assignment picker reuses management and returns only an explicit selection',
    (tester) async {
      settings.dispose();
      settings = LocalLibraryPreferences(prefs)..load();
      await settings.addGroup('已有分类');
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await chooseBookCategory(
                    context,
                    settings,
                    bookId: 1042,
                    reduceMotion: true,
                  );
                },
                child: const Text('选择分类'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('选择分类'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        '已有分类',
      );
      await tester.tap(find.byKey(const ValueKey('category-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-name')), findsOneWidget);
      expect(settings.groups, hasLength(1));
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        '新自定义分类',
      );
      await tester.tap(find.byKey(const ValueKey('category-save')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.byKey(const ValueKey('custom-category-list')),
        findsOneWidget,
      );
      expect(find.text('按作者分类'), findsNothing);
      final id = settings.groups.entries
          .singleWhere((e) => e.value == '新自定义分类')
          .key;
      expect(find.byKey(ValueKey('category-drag-$id')), findsOneWidget);
      await tester.drag(
        find.byKey(ValueKey('custom-category-$id')),
        const Offset(-220, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GlassIconButton>(find.byKey(ValueKey('category-edit-$id')))
            .icon,
        CupertinoIcons.pencil,
      );
      expect(
        tester
            .widget<GlassIconButton>(
              find.byKey(ValueKey('category-delete-$id')),
            )
            .icon,
        CupertinoIcons.trash,
      );
      await tester.tap(find.byKey(ValueKey('category-edit-$id')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        '改名后的分类',
      );
      await tester.tap(find.byKey(const ValueKey('category-save')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.byKey(const ValueKey('custom-category-list')),
        findsOneWidget,
      );
      expect(settings.groups[id], '改名后的分类');
      await tester.tap(find.byKey(ValueKey('category-select-$id')));
      await tester.pumpAndSettle();
      expect(result, id);
      expect(settings.groupOf(1042), LocalLibraryPreferences.unfiled);
      expect(tester.takeException(), isNull);
    },
  );
}
