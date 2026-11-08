import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/reader_content.dart';
import 'package:wenku8_flutter/reader_pagination.dart';
import 'package:wenku8_flutter/reader_preferences.dart';
import 'package:wenku8_flutter/reader_rich_content.dart';

const _first = 'wenku-local://1610612736/img-1.jpg';
const _second = 'wenku-local://1610612736/img-2.jpg';

String _image(String url) => '<!--image-->$url<!--image-->';

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

  test('single-image comic page is vertically centered without resizing', () async {
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
  });

  test('multiple illustrations on one leaf retain their relative positions', () async {
    final pagination = await _paginate(
      ReaderContent([_image(_first), _image(_second)]),
      images: {
        _first: const Size(200, 150),
        _second: const Size(200, 150),
      },
    );
    expect(pagination.pages, hasLength(1));
    final fragments = pagination.pages.single.fragments;
    expect(fragments, hasLength(2));
    expect(fragments.first.rect.top, 250);
    expect(fragments.last.rect.top, 400);
    expect(fragments.first.rect.left, 100);
    expect(fragments.last.rect.left, 100);
  });

  test('text and illustration on the same leaf keep normal top-down flow', () async {
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
  });

  test('publisher horizontal alignment remains unchanged after centering', () async {
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
  });

  test('full-height images and vertical pages keep their original geometry', () async {
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
  });
}
