import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/local_library_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local shelf restores history beside import and opens it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final state = LibraryState(await SharedPreferences.getInstance());
    // Widget tests use fake async; real asynchronous I/O cannot complete there.
    final output = Directory('.tmp/verification')..createSync(recursive: true);
    final root = output.createTempSync('local-header-history-');
    final books = LocalBookStore(root);
    addTearDown(() {
      books.dispose();
      state.dispose();
      root.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: LocalLibraryPage(
              books: books,
              state: state,
              repository: const DemoNovelRepository(),
              onOpen: (_, _) {},
            ).buildHeader(context),
          ),
        ),
      ),
    );

    final import = find.byKey(const ValueKey('local-import-book'));
    final history = find.byKey(const ValueKey('local-reading-history'));
    final search = find.byKey(const ValueKey('local-search'));
    expect(import, findsOneWidget);
    expect(history, findsOneWidget);
    expect(search, findsOneWidget);
    expect(
      tester.getTopLeft(import).dx,
      lessThan(tester.getTopLeft(history).dx),
    );
    expect(
      tester.getTopLeft(history).dx,
      lessThan(tester.getTopLeft(search).dx),
    );

    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('暂无阅读历史'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
