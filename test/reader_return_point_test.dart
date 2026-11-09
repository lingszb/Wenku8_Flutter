import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/app_ui.dart';
import 'package:wenku8_flutter/local_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:wenku8_flutter/library_backup.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/pages.dart';
import 'package:wenku8_flutter/reader_catalogue.dart';
import 'package:wenku8_flutter/reader_preferences.dart';
import 'package:wenku8_flutter/reader_tools.dart';

const book = Novel(
  id: 1042,
  title: '阅读点回归样本',
  author: '测试',
  genre: '',
  summary: '',
  colors: [Colors.brown, Colors.grey],
  chapters: [
    NovelChapter('第一章', '第一段测试正文。\n第二段测试正文。', id: 11),
    NovelChapter('第二章', '另一章正文。', id: 22),
    NovelChapter('第三章', '最后一章正文。', id: 33),
  ],
);

class _FailingPreferences extends Fake implements SharedPreferences {
  _FailingPreferences(this.source);
  final SharedPreferences source;
  String? failKey;
  @override
  Object? get(String key) => source.get(key);
  @override
  Set<String> getKeys() => source.getKeys();
  @override
  String? getString(String key) => source.getString(key);
  @override
  List<String>? getStringList(String key) => source.getStringList(key);
  @override
  bool containsKey(String key) => source.containsKey(key);
  @override
  Future<void> reload() => source.reload();
  @override
  Future<bool> remove(String key) => source.remove(key);
  @override
  Future<bool> setInt(String key, int value) => source.setInt(key, value);
  @override
  Future<bool> setStringList(String key, List<String> value) =>
      source.setStringList(key, value);
  @override
  Future<bool> setString(String key, String value) {
    if (failKey == key) {
      failKey = null;
      return Future.value(false);
    }
    return source.setString(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late LibraryState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    state = LibraryState(prefs);
  });
  tearDown(() => state.dispose());

  Future<void> save(int chapter, {int paragraph = 0}) => state.savePosition(
    novel: book,
    chapter: chapter,
    offset: .37,
    maximum: 1,
    width: 390,
    paragraphIndex: paragraph,
    textOffset: 7,
  );

  test(
    'chapter thresholds catch long-chapter jumps and persist separately',
    () async {
      final large = Novel(
        id: book.id,
        title: book.title,
        author: book.author,
        genre: '',
        summary: '',
        colors: book.colors,
        chapters: List.generate(
          2000,
          (i) => NovelChapter('第$i章', '正文', id: i + 1),
        ),
      );
      Future<void> position(int chapter, double fraction) => state.savePosition(
        novel: large,
        chapter: chapter,
        offset: fraction,
        maximum: 1,
        width: 390,
      );
      await position(0, .1);
      await state.beginReadingJump(
        large,
        state.positionFor(large.id)!,
        targetProgress: .6 / 2000,
      );
      await position(0, .6);
      expect(state.shouldRemindReadingJump(large), isFalse);
      await state.setReadingJumpReminderPercent(15);
      await state.setReadingJumpReminderScope(ReadingJumpReminderScope.chapter);
      expect(state.readingJumpReminderPercent, 10);
      expect(state.shouldRemindReadingJump(large), isTrue);
      await state.setReadingJumpReminderPercent(60);
      expect(state.shouldRemindReadingJump(large), isFalse);
      await state.beginReadingJump(
        large,
        state.positionFor(large.id)!,
        targetProgress: 1 / 2000,
      );
      await position(1, 0);
      expect(state.shouldRemindReadingJump(large), isTrue);
      final reloaded = LibraryState(prefs);
      addTearDown(reloaded.dispose);
      expect(
        reloaded.readingJumpReminderScope,
        ReadingJumpReminderScope.chapter,
      );
      expect(reloaded.readingJumpReminderPercent, 60);
      expect(reloaded.positionFor(large.id)!.jumpChapterDistance, 100);
      await state.setReadingJumpReminderScope(ReadingJumpReminderScope.book);
      expect(state.readingJumpReminderPercent, 15);
      await state.resolveReadingJump(large, restore: false);
      expect(state.positionFor(large.id)!.jumpChapterDistance, isNull);
    },
  );

  test('backup validates and restores both reminder modes', () async {
    final backup = await LibraryBackup.fromRecords({
      'readingJumpReminderScope': 'chapter',
      'readingJumpReminderPercent': 15,
      'readingJumpChapterReminderPercent': 25,
    });
    await state.restoreBackup(
      await LibraryBackup.parse(await backup.encode()),
      importPreferences: true,
    );
    expect(state.readingJumpReminderScope, ReadingJumpReminderScope.chapter);
    expect(state.readingJumpReminderPercent, 25);
    expect(state.readingJumpBookReminderPercent, 15);
    for (final invalid in [0, 101, 1.5]) {
      await expectLater(
        LibraryBackup.fromRecords({
          'readingJumpChapterReminderPercent': invalid,
        }),
        throwsFormatException,
      );
    }
    await expectLater(
      LibraryBackup.fromRecords({'readingJumpReminderScope': 'invalid'}),
      throwsFormatException,
    );
  });

  test(
    'small chapter adjustments do not become warnings during natural reading',
    () async {
      await state.setReadingJumpReminderScope(ReadingJumpReminderScope.chapter);
      await save(0);
      await state.beginReadingJump(
        book,
        state.positionFor(book.id)!,
        targetProgress: .39 / 3,
      );
      await state.savePosition(
        novel: book,
        chapter: 0,
        offset: .39,
        maximum: 1,
        width: 390,
      );
      expect(state.shouldRemindReadingJump(book), isFalse);
      await save(2);
      expect(state.shouldRemindReadingJump(book), isFalse);
      expect(state.positionFor(book.id)!.returnPoint, isNotNull);
    },
  );

  test(
    'first origin survives repeated jumps, autosave, reload and backup',
    () async {
      await save(0, paragraph: 42);
      final origin = state.positionFor(book.id)!;
      await Future.wait([state.beginReadingJump(book, origin), save(1)]);
      await state.beginReadingJump(book, state.positionFor(book.id)!);
      await save(2, paragraph: 8);
      final restored = LibraryState(prefs);
      addTearDown(restored.dispose);
      expect(restored.positionFor(book.id)!.chapterId, 33);
      expect(restored.positionFor(book.id)!.returnPoint!.chapterId, 11);
      expect(restored.positionFor(book.id)!.returnPoint!.paragraphIndex, 42);
      final backup = await LibraryBackup.fromRecords({
        'reading_position_${book.id}': prefs.getString(
          'reading_position_${book.id}',
        )!,
      });
      final roundTrip = await LibraryBackup.parse(await backup.encode());
      final position = ReadingPosition.fromJson(
        jsonDecode(roundTrip.records['reading_position_${book.id}'] as String),
      );
      expect(position.returnPoint!.textOffset, 7);
      await restored.resolveReadingJump(book, restore: true);
      expect(restored.positionFor(book.id)!.chapterId, 11);
      expect(restored.positionFor(book.id)!.paragraphIndex, 42);
      expect(restored.positionFor(book.id)!.returnPoint, isNull);
    },
  );

  test(
    'keeping new progress clears only the origin; legacy records remain valid',
    () async {
      await save(0);
      await state.beginReadingJump(book, state.positionFor(book.id)!);
      await save(1);
      await state.resolveReadingJump(book, restore: false);
      final restored = LibraryState(prefs);
      addTearDown(restored.dispose);
      expect(restored.positionFor(book.id)!.chapterId, 22);
      expect(restored.positionFor(book.id)!.returnPoint, isNull);
      expect(
        ReadingPosition.fromJson(
          state.positionFor(book.id)!.toJson(),
        ).returnPoint,
        isNull,
      );
    },
  );

  test(
    'failed decisions retain the saved origin and recover the journal',
    () async {
      await save(0, paragraph: 12);
      final controlled = _FailingPreferences(prefs);
      state.dispose();
      state = LibraryState(controlled);
      controlled.failKey = 'reading_position_${book.id}';
      await expectLater(
        state.beginReadingJump(book, state.positionFor(book.id)!),
        throwsA(anything),
      );
      expect(state.positionFor(book.id)!.returnPoint, isNull);
      await state.beginReadingJump(book, state.positionFor(book.id)!);
      await save(2);
      controlled.failKey = 'reading_position_${book.id}';
      await expectLater(
        state.resolveReadingJump(book, restore: true),
        throwsA(anything),
      );
      expect(state.positionFor(book.id)!.chapterId, 33);
      expect(state.positionFor(book.id)!.returnPoint!.chapterId, 11);
      final restored = LibraryState(prefs);
      addTearDown(restored.dispose);
      expect(restored.positionFor(book.id)!.returnPoint!.paragraphIndex, 12);
      expect(prefs.containsKey(restoreJournalKey), isFalse);
    },
  );

  test('backup rejects recursive or malformed return anchors', () async {
    await save(0);
    final record = state.positionFor(book.id)!.toJson();
    await expectLater(
      LibraryBackup.fromRecords({
        'reading_position_${book.id}': jsonEncode({
          ...record,
          'returnPoint': {...record, 'returnPoint': record},
        }),
      }),
      throwsFormatException,
    );
    await expectLater(
      LibraryBackup.fromRecords({
        'reading_position_${book.id}': jsonEncode({
          ...record,
          'returnPoint': {'chapter': 'bad'},
        }),
      }),
      throwsFormatException,
    );
  });

  test(
    'whole-book reminder threshold persists, restores and enforces its minimum',
    () async {
      expect(state.readingJumpReminderPercent, 5);
      await state.savePosition(
        novel: book,
        chapter: 0,
        offset: 0,
        maximum: 1,
        width: 390,
      );
      await state.beginReadingJump(
        book,
        state.positionFor(book.id)!,
        targetProgress: .05,
      );
      await state.savePosition(
        novel: book,
        chapter: 0,
        offset: .15,
        maximum: 1,
        width: 390,
      );
      expect(state.shouldRemindReadingJump(book), isTrue);
      await state.setReadingJumpReminderPercent(6);
      expect(state.shouldRemindReadingJump(book), isFalse);
      await state.setReadingJumpReminderPercent(1);
      await expectLater(
        state.setReadingJumpReminderPercent(0),
        throwsFormatException,
      );
      await expectLater(
        state.setReadingJumpReminderPercent(101),
        throwsFormatException,
      );
      final restored = LibraryState(prefs);
      addTearDown(restored.dispose);
      expect(restored.readingJumpReminderPercent, 1);
      final backup = await LibraryBackup.fromRecords({
        'readingJumpReminderPercent': 12,
      });
      await state.restoreBackup(
        await LibraryBackup.parse(await backup.encode()),
        importPreferences: true,
      );
      expect(state.readingJumpReminderPercent, 12);
      await expectLater(
        LibraryBackup.fromRecords({'readingJumpReminderPercent': 0}),
        throwsFormatException,
      );
      await expectLater(
        LibraryBackup.fromRecords({'readingJumpReminderPercent': 1.5}),
        throwsFormatException,
      );
    },
  );

  test(
    'small manual jumps retain an anchor without a later natural-reading reminder',
    () async {
      await state.savePosition(
        novel: book,
        chapter: 0,
        offset: 0,
        maximum: 1,
        width: 390,
      );
      await state.beginReadingJump(
        book,
        state.positionFor(book.id)!,
        targetProgress: .02,
      );
      await state.savePosition(
        novel: book,
        chapter: 0,
        offset: .06,
        maximum: 1,
        width: 390,
      );
      expect(state.positionFor(book.id)!.returnPoint, isNotNull);
      expect(state.shouldRemindReadingJump(book), isFalse);
      await state.savePosition(
        novel: book,
        chapter: 2,
        offset: .9,
        maximum: 1,
        width: 390,
      );
      expect(state.shouldRemindReadingJump(book), isFalse);
      await state.setReadingJumpReminderPercent(1);
      expect(state.shouldRemindReadingJump(book), isTrue);
    },
  );

  testWidgets('usage settings adjust the whole-book reminder line', (
    tester,
  ) async {
    state.dispose();
    state = LibraryState(prefs);
    await tester.pumpWidget(MaterialApp(home: SettingsPage(state: state)));
    final entry = find.byKey(const ValueKey('settings-usage-entry'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final slider = find.byWidgetPredicate(
      (widget) =>
          widget is ReaderValueSlider &&
          widget.sliderKey == const ValueKey('settings-reading-jump-threshold'),
    );
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    tester.widget<ReaderValueSlider>(slider).onCommitted!(15);
    await tester.pumpAndSettle();
    expect(state.readingJumpReminderPercent, 15);
    final chapterMode = find.byKey(
      const ValueKey('settings-jump-scope-chapter'),
    );
    await tester.ensureVisible(chapterMode);
    await tester.tap(chapterMode);
    await tester.pumpAndSettle();
    expect(state.readingJumpReminderPercent, 10);
    await tester.ensureVisible(slider);
    tester.widget<ReaderValueSlider>(slider).onCommitted!(25);
    await tester.pumpAndSettle();
    final bookMode = find.byKey(const ValueKey('settings-jump-scope-book'));
    await tester.ensureVisible(bookMode);
    await tester.tap(bookMode);
    await tester.pumpAndSettle();
    expect(state.readingJumpReminderPercent, 15);
    expect(find.textContaining('最低 1%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'catalogue locates an earlier anchor lazily after search and reversal',
    (tester) async {
      final big = book.withChapters(
        List.generate(20000, (i) => NovelChapter('章节 ${i + 1}', '', id: i + 1)),
      );
      final origin = ReadingPosition(
        chapter: 12,
        chapterId: 13,
        offset: 0,
        fraction: .3,
        fontSize: 19,
        width: 390,
        updatedAt: 1,
      );
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Object? action;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  action = await showModalBottomSheet<Object>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ReaderCatalogue(
                      novel: big,
                      currentChapter: 19000,
                      returnPoint: origin,
                      initialReversed: true,
                      reduceMotion: true,
                    ),
                  );
                },
                child: const Text('目录'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('目录'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('reader-catalogue-search-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reader-chapter-search')),
        '不存在',
      );
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的章节'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('reader-locate-reading-point')),
      );
      await tester.pumpAndSettle();
      expect(find.text('跳转前阅读点'), findsOneWidget);
      expect(find.byKey(const ValueKey('reader-chapter-12')), findsOneWidget);
      expect(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key as ValueKey<String>).value.startsWith(
                    'reader-chapter-',
                  ),
            )
            .evaluate()
            .length,
        inInclusiveRange(1, 50),
      );
      await tester.tap(find.byKey(const ValueKey('reader-return-point')));
      await tester.pumpAndSettle();
      expect(action, ReaderCatalogueAction.returnToReadingPoint);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [ReaderMode.scroll, ReaderMode.paged]) {
    testWidgets(
      'bottom progress dragging retains the pre-preview anchor in ${mode.name}',
      (tester) async {
        state.dispose();
        state = LibraryState(prefs);
        await state.setReaderChromeVisible(true);
        await state.setReaderPreferences(
          state.readerPreferencesFor(book.id).copyWith(mode: mode),
          persist: false,
        );
        final longBook = book.withChapters([
          NovelChapter(
            '长章节',
            List.generate(
              90,
              (i) => '第$i段正文，检验拖动之前的阅读位置和进度恢复。' * 3,
            ).join('\n\n'),
            id: 11,
          ),
        ]);
        tester.view.physicalSize = const Size(390, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: ReaderPage(
              novel: longBook,
              state: state,
              repository: const DemoNovelRepository(),
              initialChapter: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final restoreButton = find.byKey(
          const ValueKey('reader-restore-chapter-progress'),
        );
        expect(
          tester.widget<GlassIconButton>(restoreButton).icon,
          CupertinoIcons.refresh,
        );
        expect(tester.widget<GlassIconButton>(restoreButton).onPressed, isNull);
        final original = state.positionFor(book.id)!;
        final progress = find.byType(ReaderChapterProgress);
        tester.widget<ReaderChapterProgress>(progress).onCommitted!(.02);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        expect(state.positionFor(book.id)!.returnPoint, isNotNull);
        expect(state.shouldRemindReadingJump(longBook), isFalse);
        for (final direction in [1, -1]) {
          tester.widget<ReaderChapterProgress>(progress).onCommitted!(.5);
          await tester.pumpAndSettle();
          expect(
            tester.widget<GlassIconButton>(restoreButton).onPressed,
            isNotNull,
          );
          tester
              .widget<ReaderScreenBinding>(find.byType(ReaderScreenBinding))
              .onPage!(direction);
          await tester.pumpAndSettle();
          expect(
            tester.widget<GlassIconButton>(restoreButton).onPressed,
            isNull,
          );
        }
        // Reactivation captures the newly accepted location, not the original one.
        await tester.pump(const Duration(milliseconds: 200));
        final newOrigin = state.positionFor(book.id)!;
        tester.widget<ReaderChapterProgress>(progress).onCommitted!(.7);
        await tester.pumpAndSettle();
        await tester.tap(restoreButton);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          state.positionFor(book.id)!.paragraphIndex,
          newOrigin.paragraphIndex,
        );
        expect(state.positionFor(book.id)!.textOffset, newOrigin.textOffset);
        final before = original;
        final slider = find.byKey(
          const ValueKey('reader-chrome-progress-slider'),
        );
        final scrubOrigin = state.positionFor(book.id)!;
        await tester.drag(
          slider,
          Offset(tester.getSize(slider).width * .75, 0),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        final after = state.positionFor(book.id)!;
        expect(after.returnPoint, isNotNull);
        expect(after.returnPoint!.chapterId, before.chapterId);
        expect(after.returnPoint!.paragraphIndex, before.paragraphIndex);
        expect(after.returnPoint!.textOffset, before.textOffset);
        expect(after.fraction, greaterThan(before.fraction));
        expect(
          tester.widget<GlassIconButton>(restoreButton).onPressed,
          isNotNull,
        );
        await tester.tap(restoreButton);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          state.positionFor(book.id)!.paragraphIndex,
          scrubOrigin.paragraphIndex,
        );
        expect(state.positionFor(book.id)!.textOffset, scrubOrigin.textOffset);
        expect(tester.widget<GlassIconButton>(restoreButton).onPressed, isNull);
        await tester.drag(
          slider,
          Offset(tester.getSize(slider).width * .75, 0),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('当前阅读位置与之前跨度较大，已为你保留原阅读点。'), findsOneWidget);
        expect(find.textContaining('你通过目录跳转'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('reader-detour-restore')));
        await tester.pumpAndSettle();
        expect(state.positionFor(book.id)!.returnPoint, isNull);
        expect(
          state.positionFor(book.id)!.paragraphIndex,
          before.paragraphIndex,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'reader back offers original versus new progress after catalogue jump',
    (tester) async {
      state.dispose();
      state = LibraryState(prefs);
      await state.setReaderChromeVisible(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ReaderPage(
                      novel: book,
                      state: state,
                      repository: const DemoNovelRepository(),
                      initialChapter: 0,
                    ),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reader-catalogue-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reader-chapter-1')));
      await tester.pumpAndSettle();
      expect(state.positionFor(book.id)!.returnPoint!.chapterId, 11);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('保留哪一个阅读点？'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reader-detour-restore')));
      await tester.pumpAndSettle();
      expect(state.positionFor(book.id)!.chapterId, 11);
      expect(state.positionFor(book.id)!.returnPoint, isNull);
      expect(find.byType(ReaderPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reader-catalogue-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reader-chapter-2')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reader-detour-keep')));
      await tester.pumpAndSettle();
      expect(state.positionFor(book.id)!.chapterId, 33);
      expect(state.positionFor(book.id)!.returnPoint, isNull);
      expect(find.byType(ReaderPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
