import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/reader_book_layout.dart';
import 'package:wenku8_flutter/reader_content.dart';
import 'package:wenku8_flutter/reader_illustrations.dart';
import 'package:wenku8_flutter/reader_paged_view.dart';
import 'package:wenku8_flutter/reader_pagination.dart';
import 'package:wenku8_flutter/reader_preferences.dart';
import 'package:wenku8_flutter/reader_rich_content.dart';
import 'package:wenku8_flutter/local_book_media.dart';

const _first = 'wenku-local://1610612736/img-1.jpg';
const _second = 'wenku-local://1610612736/img-2.jpg';

String _image(String url) => '<!--image-->$url<!--image-->';

Future<Uint8List> _pixels(
  WidgetTester tester, {
  int width = 20,
  int height = 30,
}) async => (await tester.runAsync(() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.pink,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}))!;

Future<ReaderPagination> _paginate(
  ReaderContent content, {
  required Map<String, Size> images,
  ReaderMode mode = ReaderMode.paged,
}) async {
  final pagination = await paginateReader(
    content: content,
    size: const Size(400, 800),
    style: const TextStyle(fontSize: 18, height: 1.5),
    preferences: ReaderPreferences(mode: mode, paragraphGap: 0),
    scaler: TextScaler.noScaling,
    current: () => true,
    localImageSizes: images,
  );
  expect(pagination, isNotNull);
  return pagination!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('single image leaf expands across asymmetric text margins', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final layout = ReaderBookLayout.resolve(
      viewport: const Size(340, 700),
      margin: 26,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            key: const ValueKey('page-viewport'),
            width: 400,
            height: 700,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 40),
              child: ReaderBookSpread(
                layout: layout,
                fullWidthPages: const {0},
                imageInsets: const EdgeInsets.only(left: 20, right: 40),
                pages: const [SizedBox(key: ValueKey('full-width-image'))],
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('full-width-image'))),
      tester.getRect(find.byKey(const ValueKey('page-viewport'))),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('facing image leaves retain their inner gutter', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final layout = ReaderBookLayout.resolve(
      viewport: const Size(940, 700),
      margin: 26,
    );
    expect(layout.count, 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1000,
            height: 700,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ReaderBookSpread(
                layout: layout,
                fullWidthPages: const {0, 1},
                imageInsets: const EdgeInsets.symmetric(horizontal: 30),
                pages: const [
                  SizedBox(key: ValueKey('left-image')),
                  SizedBox(key: ValueKey('right-image')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final left = tester.getRect(find.byKey(const ValueKey('left-image')));
    final right = tester.getRect(find.byKey(const ValueKey('right-image')));
    expect(left.left, 0);
    expect(right.right, 1000);
    expect(
      right.left - left.right,
      layout.pages.last.left - layout.pages.first.right,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('prefetched pixels survive remount without another source read', (
    tester,
  ) async {
    final bytes = await _pixels(tester);
    final reads = <String, int>{};
    final cache = ReaderIllustrationCache(
      offlineReader: (url) async {
        reads[url] = (reads[url] ?? 0) + 1;
        return bytes;
      },
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    const urls = ['cached-image:first', 'cached-image:next'];
    await tester.runAsync(
      () => cache.prefetch(
        urls,
        context: context,
        available: const Size(400, 800),
        current: () => true,
      ),
    );
    await tester.pump();
    for (final url in [...urls, urls.first]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderIllustration(url: url, cache: cache, fitPage: true),
        ),
      );
      await tester.pump();
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      final key = await image.image.obtainKey(ImageConfiguration.empty);
      expect(
        PaintingBinding.instance.imageCache.statusForKey(key).keepAlive,
        isTrue,
      );
      expect(find.text('正在载入插图'), findsNothing);
      expect(find.text('正在解码插图'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(reads, {for (final url in urls) url: 1});
    expect(cache.encodedBytes, lessThanOrEqualTo(cache.maxBytes));
    cache.clearMemory();
    PaintingBinding.instance.imageCache.clear();
  });

  testWidgets('page turns warm upcoming pixels and retain the previous image', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await _pixels(tester);
    final cache = ReaderIllustrationCache.shared;
    final previousReader = cache.offlineReader;
    final reads = <String, int>{};
    cache.clearMemory();
    cache.offlineReader = (url) async {
      reads[url] = (reads[url] ?? 0) + 1;
      return Uint8List.fromList(bytes);
    };
    addTearDown(() {
      cache.clearMemory();
      cache.offlineReader = previousReader;
      PaintingBinding.instance.imageCache.clear();
    });
    final urls = List.generate(4, (i) => 'https://reader.invalid/$i.png');
    final controller = ReaderPagedController();
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPagedView(
          content: ReaderContent(urls.map(_image).toList()),
          preferences: const ReaderPreferences(mode: ReaderMode.paged),
          style: const TextStyle(fontSize: 18),
          controller: controller,
          title: '合成图片章节',
          padding: const EdgeInsets.all(24),
          reduceMotion: true,
          pageBuilder: (_) => const SizedBox(),
          onReady: () {},
          onChanged: () {},
          onUserScroll: () {},
          onBoundary: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Flush actual image codecs without running device interactions.
    Future<void> finishWarmup() async {
      for (var attempt = 0; attempt < 12; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pumpAndSettle();
        if (cache.sizeOf(urls[controller.page == 0 ? 2 : 3]) != null) break;
      }
    }

    await finishWarmup();
    expect(controller.pageCount, 4);
    expect(reads.keys, containsAll(urls.take(3)));
    expect(reads.containsKey(urls.last), isFalse);
    expect(controller.pageBy(1), isTrue);
    await tester.pumpAndSettle();
    await finishWarmup();
    expect(reads, {for (final url in urls) url: 1});
    expect(controller.pageBy(-1), isTrue);
    await tester.pumpAndSettle();
    expect(reads.values, everyElement(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('encoded image cache evicts old bytes within its budget', () async {
    var reads = 0;
    final cache = ReaderIllustrationCache(
      maxBytes: 8,
      offlineReader: (_) async {
        reads++;
        return Uint8List(5);
      },
    );
    await cache.load('first');
    await cache.load('second');
    expect(cache.peek('first'), isNull);
    expect(cache.encodedBytes, 5);
    await cache.load('first');
    expect(reads, 3);
    expect(cache.encodedBytes, lessThanOrEqualTo(cache.maxBytes));
  });

  testWidgets(
    'large chapter metadata does not reread dimensions evicted mid-layout',
    (tester) async {
      final bytes = await _pixels(tester);
      final changedBytes = await _pixels(tester, width: 40, height: 50);
      var currentBytes = bytes;
      final previousRoot = LocalBookMedia.root;
      final previousReader = LocalBookMedia.externalImage;
      final previousBatch = LocalBookMedia.externalImages;
      final previousDimensions = LocalBookMedia.externalDimensions;
      final previousWarnings = LocalBookMedia.importWarnings;
      LocalBookMedia.root = Directory(
        '.tmp/verification/dimension-window-unused',
      );
      var reads = 0;
      LocalBookMedia.externalImage = (_, _) async {
        reads++;
        return currentBytes;
      };
      LocalBookMedia.externalDimensions = (_, names) async => {
        for (final name in names) name: (width: 20, height: 30),
      };
      addTearDown(() {
        LocalBookMedia.root = previousRoot;
        LocalBookMedia.externalImage = previousReader;
        LocalBookMedia.externalImages = previousBatch;
        LocalBookMedia.externalDimensions = previousDimensions;
        LocalBookMedia.importWarnings = previousWarnings;
      });
      final cache = ReaderIllustrationCache(maxBytes: 1);
      final urls = [
        for (var i = 0; i < 512; i++) 'wenku-local://1610612736/img-$i.png',
      ];
      await tester.runAsync(() async {
        for (final url in urls.take(256)) {
          await cache.dimensions(url);
        }
        reads = 0;
        final sizes = await cache.measureLocalImages(urls, current: () => true);
        expect(sizes, hasLength(512));
        expect(sizes.values, everyElement(const Size(20, 30)));
        expect(reads, 0);
        expect(cache.encodedBytes, lessThanOrEqualTo(cache.maxBytes));
        LocalBookMedia.externalDimensions = (_, names) async {
          LocalBookMedia.evict(1610612736);
          currentBytes = changedBytes;
          return {for (final name in names) name: (width: 20, height: 30)};
        };
        reads = 0;
        final replaced = await cache.measureLocalImages(
          urls,
          current: () => true,
        );
        expect(replaced.values, everyElement(const Size(40, 50)));
        expect(reads, 512);
      });
    },
  );

  test(
    'single-image comic page is vertically centered without resizing',
    () async {
      final pagination = await _paginate(
        ReaderContent([_image(_first)]),
        images: {_first: const Size(600, 900)},
      );
      expect(pagination.pages, hasLength(1));
      final fragment = pagination.pages.single.fragments.single;
      expect(fragment.image, isTrue);
      expect(fragment.rect, const Rect.fromLTWH(0, 100, 400, 600));
      expect(fragment.paragraph, 0);
      expect(pagination.pageFor(const ReaderTextAnchor(0, 0)), 0);
    },
  );

  test(
    'multiple illustrations on one leaf retain their relative positions',
    () async {
      final pagination = await _paginate(
        ReaderContent([_image(_first), _image(_second)]),
        images: {_first: const Size(200, 150), _second: const Size(200, 150)},
      );
      expect(pagination.pages, hasLength(1));
      final fragments = pagination.pages.single.fragments;
      expect(fragments, hasLength(2));
      expect(fragments.first.rect.top, 250);
      expect(fragments.last.rect.top, 400);
      expect(fragments.first.rect.left, 100);
      expect(fragments.last.rect.left, 100);
    },
  );

  test(
    'text and illustration on the same leaf keep normal top-down flow',
    () async {
      final pagination = await _paginate(
        ReaderContent(['第一段正文。', _image(_first)]),
        images: {_first: const Size(200, 150)},
      );
      expect(pagination.pages, hasLength(1));
      final fragments = pagination.pages.single.fragments;
      expect(fragments, hasLength(2));
      expect(fragments.first.image, isFalse);
      expect(fragments.first.rect.top, 0);
      expect(fragments.last.image, isTrue);
      expect(fragments.last.rect.top, greaterThan(0));
      expect(fragments.last.rect.top, lessThan(100));
    },
  );

  test(
    'publisher horizontal alignment remains unchanged after centering',
    () async {
      final pagination = await _paginate(
        ReaderContent(
          [_image(_first)],
          formats: {0: const ReaderRichParagraph(alignment: 'left')},
        ),
        images: {_first: const Size(200, 300)},
      );
      expect(
        pagination.pages.single.fragments.single.rect,
        const Rect.fromLTWH(0, 250, 200, 300),
      );
    },
  );

  test(
    'full-height images and vertical pages keep their original geometry',
    () async {
      final fullHeight = await _paginate(
        ReaderContent([_image(_first)]),
        images: {_first: const Size(600, 1200)},
      );
      expect(
        fullHeight.pages.single.fragments.single.rect,
        const Rect.fromLTWH(0, 0, 400, 800),
      );

      final vertical = await _paginate(
        ReaderContent([_image(_first)]),
        images: {_first: const Size(200, 300)},
        mode: ReaderMode.vertical,
      );
      expect(vertical.pages.single.fragments.single.rect.top, 0);
    },
  );
}
