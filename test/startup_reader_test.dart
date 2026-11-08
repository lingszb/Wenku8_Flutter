import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/pages.dart';

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
  }) async {
    SharedPreferences.setMockInitialValues({});
    state = await LibraryState.load();
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
    'reduced motion removes cover as soon as first article is ready',
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
