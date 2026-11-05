import 'package:flutter_test/flutter_test.dart';

import 'package:wenku8_flutter/book_search.dart';

void main() {
  bool matches(
    String query, {
    BookSearchField field = BookSearchField.all,
    String title = '星空旅人',
    String author = '测试作者',
    String tags = '奇幻 冒险',
    String classification = '已读',
    String id = '12345',
  }) => BookSearch(query, field: field).matches(
    title: title,
    author: author,
    tags: tags,
    classification: classification,
    id: id,
  );

  test('empty query includes local books', () {
    expect(matches('  '), isTrue);
  });

  test('multiple terms must all match book metadata', () {
    expect(matches('星空 测试作者'), isTrue);
    expect(matches('星空 不存在'), isFalse);
  });

  test('field selection excludes matches from other fields', () {
    expect(matches('测试作者', field: BookSearchField.title), isFalse);
    expect(matches('测试作者', field: BookSearchField.author), isTrue);
    expect(matches('星空', field: BookSearchField.author), isFalse);
  });

  test('hash terms only match tags or local classification', () {
    expect(matches('#奇幻'), isTrue);
    expect(matches('#已读'), isTrue);
    expect(matches('#星空'), isFalse);
    expect(matches('#'), isFalse);
  });

  test('book IDs require an exact match in ID mode', () {
    expect(matches('12345', field: BookSearchField.id), isTrue);
    expect(matches('123', field: BookSearchField.id), isFalse);
    expect(matches('１２３４５', field: BookSearchField.id), isTrue);
  });

  test('full-width letters, spaces and punctuation normalize consistently', () {
    expect(matches('ｓｋｙ　旅人', title: 'Sky－旅人'), isTrue);
    expect(matches('SKY', title: 'sky'), isTrue);
  });
}
