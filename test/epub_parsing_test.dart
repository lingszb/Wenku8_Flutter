import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/epub_image_styles.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/offline_cache.dart';
import 'package:wenku8_flutter/offline_repository.dart';
import 'package:wenku8_flutter/pages.dart';
import 'package:wenku8_flutter/reader_content.dart';
import 'package:wenku8_flutter/reader_pagination.dart';
import 'package:wenku8_flutter/reader_preferences.dart';
import 'package:wenku8_flutter/reader_rich_content.dart';

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Map<String, String> _sampleFiles() => {
  'META-INF/container.xml': '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
  'OEBPS/content.opf': '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf"
         xmlns:opf="http://www.idpf.org/2007/opf"
         version="3.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="id">sample</dc:identifier>
    <dc:title id="t1">原名</dc:title>
    <dc:title id="t2">主标题</dc:title>
    <dc:title id="t3">副标题</dc:title>
    <meta refines="#t2" property="title-type">main</meta>
    <meta refines="#t3" property="title-type">subtitle</meta>
    <dc:creator id="c1" opf:role="ill">插画师</dc:creator>
    <dc:creator id="c2" opf:role="aut">作者</dc:creator>
    <dc:creator id="c3">译者</dc:creator>
    <meta refines="#c3" property="role">trl</meta>
    <dc:subject>喜剧</dc:subject>
    <dc:subject>轻小说</dc:subject>
    <dc:description>&lt;p&gt;第一段&lt;/p&gt;&lt;p&gt;第二段 &amp;amp; 说明&lt;/p&gt;</dc:description>
    <dc:publisher>测试出版社</dc:publisher>
    <dc:date>2024-05-06T00:00:00Z</dc:date>
    <dc:language>zh</dc:language>
  </metadata>
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
  </spine>
</package>''',
  'OEBPS/ch1.xhtml': '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>sample</title></head>
<body>
  <h5>小标题</h5>
  <ol>
    <li>First<ol><li>Inner</li></ol></li>
    <li value="5">Fifth</li>
  </ol>
  <ul>
    <li>Bullet</li>
    <li style="list-style-type: square">Squared</li>
  </ul>
  <p>H<sub>2</sub>O and x<sup>2</sup> and <del>old</del></p>
  <pre>  line1

line2</pre>
after   pre
  <figure><figcaption>图注</figcaption></figure>
</body>
</html>''',
};

ImportedBook _sample() =>
    parseLocalBook(LocalBookInput('sample.epub', _zip(_sampleFiles())));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'applies screen and supports rules while ignoring print-only styles',
    () {
      final document = html.parse('''
<html><head><style>
  p { text-align: center; color: red; }
  @media screen { p { text-align: right; } }
  @media print { p { text-align: left; } }
  @supports (display: grid) { p { font-weight: bold; } }
  @media screen and (max-width: 600px) { p { opacity: .5; } }
  @supports not (display: grid) { p { text-align: left; } }
</style></head><body><p>x</p></body></html>
''');
      final styles = epubStyleProperties(document, (_) => null);
      final paragraph = document.querySelector('p')!;
      expect(styles[paragraph]!['text-align'], 'right');
      expect(styles[paragraph]!['font-weight'], 'bold');
      expect(styles[paragraph]!['opacity'], '.5');
    },
  );

  test('keeps text when a CSS visibility condition is unknown on import', () {
    final files = _sampleFiles()
      ..['OEBPS/ch1.xhtml'] = '''
<html><head><style>
@media screen and (max-width: 600px) { #narrow { display: none; } }
@supports (display: grid) {
  @media screen { #grid { display: none; } }
}
@media screen { #screen { display: none; } }
#always { display: none; }
</style></head><body>
<p id="narrow">Keep narrow text</p><p id="grid">Keep grid text</p>
<p id="screen">Hide screen text</p><p id="always">Hide unconditional text</p>
</body></html>
''';
    final book = parseLocalBook(LocalBookInput('sample.epub', _zip(files)));
    final body = ReaderRichBody.decode(book.bodies.first);
    expect(body.paragraphs, ['Keep narrow text', 'Keep grid text']);
  });

  test('preserves preformatted scope across an image and an empty pre', () {
    final files = _sampleFiles()
      ..['OEBPS/ch1.xhtml'] = '''
<html><body><pre>First<img />  Second</pre><pre></pre>   Normal   text
<ol reversed><li>Third</li><li>Second item</li><li value="10">Reset</li></ol>
</body></html>
''';
    final book = parseLocalBook(LocalBookInput('sample.epub', _zip(files)));
    final body = ReaderRichBody.decode(book.bodies.first);
    final pre = body.paragraphs.indexOf('  Second');
    expect(pre, isNonNegative);
    expect(body.formats[pre]?.preformatted, isTrue);
    final normal = body.paragraphs.indexOf('Normal text');
    expect(normal, isNonNegative);
    expect(body.formats[normal]?.preformatted ?? false, isFalse);
    for (final (text, marker) in [
      ('Third', '3.'),
      ('Second item', '2.'),
      ('Reset', '10.'),
    ]) {
      expect(
        body.formats[body.paragraphs.indexOf(text)]?.marker,
        '$marker\u00a0',
      );
    }
  });

  test('advances ordered list counters for nested-only items', () {
    final files = _sampleFiles()
      ..['OEBPS/ch1.xhtml'] = '''
<html><body>
<ol><li value="5"><ul><li>Nested</li></ul></li><li>Next</li></ol>
</body></html>
''';
    final book = parseLocalBook(LocalBookInput('sample.epub', _zip(files)));
    final body = ReaderRichBody.decode(book.bodies.first);

    expect(body.formats[body.paragraphs.indexOf('Nested')]?.marker, '• ');
    expect(body.formats[body.paragraphs.indexOf('Next')]?.marker, '6. ');
  });

  test('reads list style type from declarations and shorthand', () {
    final document = html.parse('''
<html><head><style>
  ol { list-style: upper-roman inside; }
  ul { list-style-type: none; }
</style></head><body>
  <ol><li>a</li></ol>
  <ul><li>b</li></ul>
</body></html>
''');
    final styles = epubStyleProperties(document, (_) => null);
    expect(
      styles[document.querySelector('ol')]!['list-style-type'],
      'upper-roman',
    );
    expect(styles[document.querySelector('ul')]!['list-style-type'], 'none');
  });

  test('imports package metadata without mistaking contributors', () {
    final book = _sample();
    expect(book.novel.title, '主标题');
    expect(book.novel.subtitle, '副标题');
    expect(book.novel.author, '作者');
    expect(book.novel.illustrator, '插画师');
    expect(book.novel.publisher, '测试出版社');
    expect(book.novel.publishedDate, '2024-05-06');
    expect(book.novel.summary, contains('第一段'));
    expect(book.novel.summary, contains('第二段 & 说明'));
    expect(book.novel.summary, isNot(contains('<p>')));
    expect(book.novel.tags, contains('喜剧'));
    expect(book.novel.tags, isNot(contains('轻小说')));

    final snapshot = Novel.fromSnapshot(book.novel.toSnapshot());
    expect(snapshot.subtitle, '副标题');
    expect(snapshot.illustrator, '插画师');
    expect(snapshot.publisher, '测试出版社');
    expect(snapshot.publishedDate, '2024-05-06');
  });

  test('keeps list markers, sup/sub, line-through and preformatted text', () {
    final body = ReaderRichBody.decode(_sample().bodies.first);
    int index(String text) =>
        body.paragraphs.indexWhere((paragraph) => paragraph == text);

    final first = index('First');
    expect(first, isNot(-1));
    expect(body.formats[first]!.marker, '1. ');
    final inner = index('Inner');
    expect(inner, isNot(-1));
    expect(body.formats[inner]!.marker, '1. ');
    final fifth = index('Fifth');
    expect(body.formats[fifth]!.marker, '5. ');
    final bullet = index('Bullet');
    expect(body.formats[bullet]!.marker, '• ');
    final squared = index('Squared');
    expect(body.formats[squared]!.marker, '▪ ');

    final heading = index('小标题');
    expect(body.formats[heading]!.emphasisAt(0) & 1, 1);

    final chemistry = body.paragraphs.indexWhere(
      (paragraph) => paragraph.startsWith('H2O'),
    );
    final format = body.formats[chemistry]!;
    expect(format.emphasisAt(1) & 32, 32);
    expect(
      format.emphasisAt(body.paragraphs[chemistry].indexOf('x2') + 1) & 16,
      16,
    );
    expect(format.emphasisAt(body.paragraphs[chemistry].indexOf('old')) & 8, 8);

    final pre = body.paragraphs.indexWhere(
      (paragraph) => paragraph.contains('line1'),
    );
    expect(pre, isNot(-1));
    expect(body.formats[pre]!.preformatted, isTrue);
    expect(body.paragraphs[pre], contains('  line1\n\nline2'));

    final afterPre = index('after pre');
    expect(afterPre, isNot(-1));
    expect(body.formats[afterPre]?.preformatted ?? false, isFalse);

    expect(body.paragraphs, contains('图注'));
  });

  test(
    'horizontal pagination keeps list markers outside source offsets',
    () async {
      const text = 'One two three four five six seven eight nine ten.';
      final pagination = await paginateReader(
        content: const ReaderContent(
          [text],
          formats: {0: ReaderRichParagraph(marker: '12.\u00a0')},
        ),
        size: const Size(96, 48),
        style: const TextStyle(fontSize: 16, height: 1.5),
        preferences: const ReaderPreferences(mode: ReaderMode.paged),
        scaler: TextScaler.noScaling,
        current: () => true,
      );
      final fragments = pagination!.pages
          .expand((page) => page.fragments)
          .toList();
      expect(fragments.length, greaterThan(1));
      expect(fragments.map((fragment) => fragment.text).join(), text);
      var offset = 0;
      for (final fragment in fragments) {
        expect(fragment.start, offset);
        expect(fragment.text, text.substring(fragment.start, fragment.end));
        offset = fragment.end;
      }
      expect(offset, text.length);
    },
  );

  test('backfills new metadata for an already imported book', () async {
    final root = await Directory.systemTemp.createTemp('epub-metadata-');
    LocalBookStore? store;
    try {
      store = LocalBookStore(root);
      final imported = await store.import(
        LocalBookInput('sample.epub', _zip(_sampleFiles())),
      );
      final bookFile = File('${root.path}/${imported.id}/book.json');
      final record =
          jsonDecode(await bookFile.readAsString()) as Map<String, dynamic>;
      final novel = Map<String, dynamic>.from(record['novel'] as Map);
      novel
        ..remove('subtitle')
        ..remove('illustrator')
        ..remove('publisher')
        ..remove('publishedDate')
        ..['title'] = '我的自定义书名'
        ..['author'] = '插画师'
        ..['genre'] = '本地导入'
        ..['summary'] = '已保存到本地书库，可离线阅读。';
      final source = Map<String, dynamic>.from(record['source'] as Map)
        ..['metadata'] = 1
        ..['userMetadata'] = {'title': '我的自定义书名'};
      await bookFile.writeAsString(
        jsonEncode({...record, 'novel': novel, 'source': source}),
      );
      store.dispose();
      store = LocalBookStore(root);
      await store.load();

      final deadline = DateTime.now().add(const Duration(seconds: 10));
      Novel? updated;
      while (DateTime.now().isBefore(deadline)) {
        updated = store.book(imported.id);
        if (updated?.publisher == '测试出版社') break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(updated?.title, '我的自定义书名');
      expect(updated?.author, '作者');
      expect(updated?.tags, contains('喜剧'));
      expect(updated?.subtitle, '副标题');
      expect(updated?.illustrator, '插画师');
      expect(updated?.publisher, '测试出版社');
      expect(updated?.publishedDate, '2024-05-06');
      expect(updated?.summary, contains('第一段'));
      final restored =
          jsonDecode(await bookFile.readAsString()) as Map<String, dynamic>;
      expect((restored['source'] as Map)['metadata'], epubMetadataVersion);
    } finally {
      store?.dispose();
      await root.delete(recursive: true);
    }
  });

  test(
    'keeps a near-limit book record readable after metadata backfill',
    () async {
      final root = await Directory.systemTemp.createTemp('epub-record-limit-');
      var store = LocalBookStore(root);
      addTearDown(() async {
        store.dispose();
        await root.delete(recursive: true);
      });
      final imported = await store.import(
        LocalBookInput('sample.epub', _zip(_sampleFiles())),
      );
      final file = File('${root.path}/${imported.id}/book.json');
      final record = jsonDecode(await file.readAsString()) as Map;
      (record['source'] as Map).remove('metadata');
      (record['novel'] as Map).remove('publisher');
      record['padding'] = '';
      final remaining =
          4 * 1024 * 1024 - utf8.encode(jsonEncode(record)).length;
      record['padding'] = 'x' * remaining;
      final saved = jsonEncode(record);
      await file.writeAsString(saved);
      store.dispose();
      store = LocalBookStore(root);
      await store.load();
      expect(store.book(imported.id), isNotNull);
      // Navigation waits behind the queued metadata backfill.
      await store.ensureNavigation(imported.id);
      expect(await file.readAsString(), saved);
      store.dispose();
      store = LocalBookStore(root);
      await store.load();
      expect(store.book(imported.id), isNotNull);
      await store.ensureNavigation(imported.id);
    },
  );

  test(
    'upgrades v2 reading coordinates and keeps internal link targets',
    () async {
      final root = await Directory.systemTemp.createTemp('epub-layout-');
      final files = _sampleFiles()
        ..['OEBPS/ch1.xhtml'] =
            '<html><body>'
            '<p><a href="#target">Jump</a></p>'
            '<pre>  First\nSecond</pre><h5 id="target">Target</h5>'
            '<p>End</p></body></html>';
      final bytes = _zip(files);
      var store = LocalBookStore(root);
      addTearDown(() async {
        store.dispose();
        await root.delete(recursive: true);
      });
      final imported = await store.import(LocalBookInput('sample.epub', bytes));
      final chapter = imported.chapters.single;
      final folder = Directory('${root.path}/${imported.id}');
      final metadata = File('${folder.path}/book.json');
      final record = jsonDecode(await metadata.readAsString()) as Map;
      final source = record['source'] as Map;
      source['richText'] = 2;
      final chapterFile = File('${folder.path}/c${chapter.id}.txt');
      await chapterFile.writeAsString(
        const ReaderRichBody([
          'Jump',
          'First SecondTarget',
          'End',
        ], revision: 'epub-rich-v2').encode(),
      );
      await metadata.writeAsString(jsonEncode(record));
      store.dispose();
      store = LocalBookStore(root);
      await store.load();

      final result = await store.maintain(
        imported.id,
        LocalMaintenanceTask.layout,
      );
      expect(result.changed, isTrue);
      final book = await store.ensureNavigation(imported.id);
      expect(book.chapters.single.id, chapter.id);
      final body = ReaderRichBody.decode(
        await store.chapterContent(book.id, chapter),
      );
      final resolved = await store.resolveReadingCoordinates(book.id, {
        'chapterId': chapter.id,
        'paragraphIndex': 1,
        'textOffset': 13,
        'contentRevision': 'epub-rich-v2',
      });
      expect(resolved['contentRevision'], 'epub-rich-v3');
      expect(body.paragraphs[resolved['paragraphIndex'] as int], 'Target');
      expect(resolved['textOffset'], 1);
      final reference = body.formats[0]!.references.single.id;
      final target = store.navigationTarget(
        book.id,
        chapter.id,
        reference.substring('epub-link:'.length),
      )!;
      expect(body.paragraphs[target.paragraph], 'Target');
      expect(target.offset, 0);
      expect(await File('${folder.path}/original').readAsBytes(), bytes);
    },
  );

  testWidgets('detail page shows imported package metadata', (tester) async {
    late final Directory root;
    late final LocalBookStore store;
    late final Novel imported;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('epub-detail-');
      store = LocalBookStore(root);
      imported = await store.import(
        LocalBookInput('sample.epub', _zip(_sampleFiles())),
      );
    });
    addTearDown(() async {
      store.dispose();
      await root.delete(recursive: true);
    });
    SharedPreferences.setMockInitialValues({});
    final library = LibraryState(await SharedPreferences.getInstance());
    addTearDown(library.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(
          novel: store.book(imported.id)!,
          state: library,
          repository: OfflineNovelRepository(
            cache: OfflineCacheStore(root),
            local: store,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('副标题'), findsOneWidget);
    expect(find.text('插画 · 插画师'), findsOneWidget);
    expect(find.text('测试出版社 · 2024-05-06'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
