import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/quote_card.dart';
import 'package:wenku8_flutter/reading_artwork.dart';
import 'package:wenku8_flutter/reading_export_theme.dart';
import 'package:wenku8_flutter/reading_moment_content.dart';
import 'package:wenku8_flutter/reading_moment_export.dart';
import 'package:wenku8_flutter/reading_moments.dart';
import 'package:wenku8_flutter/reading_visual_theme.dart';
import 'package:wenku8_flutter/reading_widget_reference.dart';
import 'package:wenku8_flutter/reading_widget_snapshot.dart';
import 'package:wenku8_flutter/reading_widget_design.dart';
import 'package:wenku8_flutter/reading_widget_skin.dart';

class _ArtworkBundle extends CachingAssetBundle {
  _ArtworkBundle(this.bytes);
  final Uint8List? bytes;
  final requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    if (!key.startsWith('assets/report/')) return rootBundle.load(key);
    requested.add(key);
    final value = bytes;
    if (value == null) throw FlutterError('Missing optional artwork');
    return ByteData.sublistView(value);
  }
}

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(const Color(0xff8b9b8c), BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(12, 8);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'desktop designs export distinct seasonal faces and appearances',
    () async {
      final day = DateTime(2026, 11, 7);
      final base = ReadingWidgetSnapshot(
        generatedAt: day,
        localDay: day,
        verifiedTotalSeconds: 7200,
        verifiedTodaySeconds: 600,
        qualifiedStreakDays: 2,
        week: [
          for (var i = 0; i < 7; i++)
            ReadingWidgetDay(
              date: DateTime(2026, 11, 1 + i),
              verifiedSeconds: i * 100,
            ),
        ],
        dailyGoalMinutes: 30,
        latestCompletion: ReadingWidgetCompletion(
          completedAt: day,
          title: 'Private book',
        ),
      );
      final designs = <String>{};
      for (final design in ReadingWidgetDesign.values.where(
        (v) => v != ReadingWidgetDesign.classic,
      )) {
        final data = base.styled(
          design: design,
          skin: ReadingWidgetSkin.seasons,
          showBookDetails: false,
        );
        final light = await renderReadingDesktopCard(
          data,
          ReadingDesktopSize.medium,
          brightness: Brightness.light,
        );
        final dark = await renderReadingDesktopCard(
          data,
          ReadingDesktopSize.medium,
          brightness: Brightness.dark,
        );
        expect(light, isNot(orderedEquals(dark)));
        designs.add(light.join(','));
        final codec = await ui.instantiateImageCodec(light);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 600);
        expect(frame.image.height, 288);
        frame.image.dispose();
        codec.dispose();
      }
      expect(designs.length, 5);
    },
  );

  testWidgets(
    'desktop preview fits every family and redacts private book details',
    (tester) async {
      final day = DateTime(2026, 11, 7);
      final base = ReadingWidgetSnapshot(
        generatedAt: day,
        localDay: day,
        verifiedTotalSeconds: null,
        verifiedTodaySeconds: null,
        qualifiedStreakDays: null,
        week: [
          for (var i = 0; i < 7; i++)
            ReadingWidgetDay(
              date: DateTime(2026, 11, 1 + i),
              verifiedSeconds: null,
            ),
        ],
        latestCompletion: ReadingWidgetCompletion(
          completedAt: day,
          title: 'Private book',
        ),
      );
      final semantics = tester.ensureSemantics();
      for (final size in ReadingDesktopSize.values) {
        for (final design in ReadingWidgetDesign.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: ReadingDesktopCard(
                    data: base.styled(
                      design: design,
                      skin: ReadingWidgetSkin.seasons,
                      showBookDetails: false,
                    ),
                    size: size,
                    brightness: Brightness.light,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Private book'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
      semantics.dispose();
    },
  );

  test(
    'all persisted themes resolve each recorded month to the same season',
    () {
      for (final theme in ReadingVisualTheme.values) {
        for (var month = 1; month <= 12; month++) {
          final season = switch (month) {
            3 || 4 || 5 => 'spring',
            6 || 7 || 8 => 'summer',
            9 || 10 || 11 => 'autumn',
            _ => 'winter',
          };
          final expected = 'assets/report/season-$season.png';
          expect(readingExportArt(theme, at: DateTime(2020, month)), expected);
          expect(
            readingExportArt(theme, at: DateTime(2020, month), portrait: true),
            expected,
          );
        }
      }
      expect(ReadingVisualTheme.fromId('paper'), ReadingVisualTheme.editorial);
      expect(ReadingVisualTheme.fromId('cream'), ReadingVisualTheme.editorial);
      expect(
        ReadingVisualTheme.fromId('night'),
        ReadingVisualTheme.constellation,
      );
      for (final theme in ReadingVisualTheme.values) {
        final preferences = ReadingMomentsPreferences(themeId: theme.id);
        expect(
          ReadingMomentsPreferences.fromJson(preferences.toJson()).themeId,
          theme.id,
        );
      }
    },
  );

  test(
    'valid art keeps the exact bytes; missing and corrupt art use one PNG fallback',
    () async {
      const asset = 'assets/report/season-winter.png';
      final original = await _png();
      final actual = await loadReadingArtwork(
        asset,
        bundle: _ArtworkBundle(original),
      );
      expect(actual.fallback, isFalse);
      expect(actual.bytes, orderedEquals(original));
      final missing = await loadReadingArtwork(
        asset,
        bundle: _ArtworkBundle(null),
      );
      final corrupt = await loadReadingArtwork(
        asset,
        bundle: _ArtworkBundle(Uint8List.fromList([1, 2, 3])),
      );
      expect(missing.fallback, isTrue);
      expect(corrupt.fallback, isTrue);
      expect(corrupt.bytes, orderedEquals(missing.bytes));
      final codec = await ui.instantiateImageCodec(missing.bytes);
      try {
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 960);
        expect(frame.image.height, 640);
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    },
  );

  test('excerpt art decoding uses the same missing-asset fallback', () async {
    final bundle = _ArtworkBundle(null);
    final art = await loadQuoteThemeArt(
      ReadingVisualTheme.constellation,
      recordedAt: DateTime(2021, 7),
      bundle: bundle,
    );
    try {
      expect(art.width, 1080);
      expect(bundle.requested, ['assets/report/season-summer.png']);
    } finally {
      art.dispose();
    }
  });

  test(
    'all four selected PNG masters are bundled and decode without fallback',
    () async {
      for (final month in [4, 7, 10, 1]) {
        final art = await loadReadingArtwork(
          readingExportArt(
            ReadingVisualTheme.editorial,
            at: DateTime(2020, month),
          ),
        );
        expect(art.fallback, isFalse);
        final header = ByteData.sublistView(art.bytes);
        expect(header.getUint32(16), 1536);
        expect(header.getUint32(20), 1024);
      }
    },
  );

  testWidgets(
    'every legacy moment layout exports a complete PNG with missing optional art',
    (tester) async {
      final bundle = _ArtworkBundle(null);
      late BuildContext context;
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: MaterialApp(
            home: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      for (final theme in ReadingVisualTheme.values) {
        final bytes = await tester.runAsync(
          () => renderReadingMomentPresentationPng(
            context,
            ReadingMomentPresentation.preview(theme),
          ),
        );
        expect(bytes, isNotNull);
        final header = ByteData.sublistView(bytes!);
        expect(header.getUint32(16), lessThanOrEqualTo(1080));
        expect(header.getUint32(20), inInclusiveRange(1, 8192));
        expect(tester.takeException(), isNull, reason: theme.id);
      }
      expect(bundle.requested, isNotEmpty);
      expect(bundle.requested.toSet(), {'assets/report/season-winter.png'});
    },
  );

  testWidgets(
    'an undecodable optional book cover does not prevent keepsake export',
    (tester) async {
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
      final sample = ReadingMomentPresentation.preview(
        ReadingVisualTheme.archive,
      );
      final validCover = await tester.runAsync(_png);
      for (final cover in [
        validCover!,
        Uint8List.fromList([1, 2, 3]),
      ]) {
        final bytes = await tester.runAsync(
          () => renderReadingMomentPresentationPng(
            context,
            ReadingMomentPresentation(moment: sample.moment, coverBytes: cover),
          ),
        );
        expect(bytes, isNotNull);
        expect(ByteData.sublistView(bytes!).getUint32(16), 1080);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'selected season backgrounds export in light and dark moment and excerpt layouts',
    (tester) async {
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
      for (final (month, theme) in [
        (4, ReadingVisualTheme.editorial),
        (7, ReadingVisualTheme.constellation),
        (10, ReadingVisualTheme.shelf),
        (1, ReadingVisualTheme.ink),
      ]) {
        final date = DateTime(2020, month, 15);
        final moment = ReadingMoment(
          id: 'sample:$month',
          kind: ReadingMomentKind.firstDay,
          earnedAt: date,
        );
        final bytes = await tester.runAsync(
          () => renderReadingMomentPresentationPng(
            context,
            ReadingMomentPresentation(moment: moment, theme: theme),
          ),
        );
        expect(bytes!.length, greaterThan(10000));
        final cards = QuoteCardLayout.prepare(
          QuoteCardData(
            text: '季节更替，阅读的文字仍被认真留存。',
            book: '四季背景验证',
            chapter: '示例章节',
            recordedAt: date,
          ),
          readingExportTheme(theme).isDark
              ? QuoteCardStyle.night
              : QuoteCardStyle.paper,
          theme: theme,
        );
        try {
          final quote = await tester.runAsync(() => cards.single.png());
          expect(quote!.length, greaterThan(10000));
          expect(
            ByteData.sublistView(quote).getUint32(16),
            lessThanOrEqualTo(1080),
          );
        } finally {
          for (final card in cards) {
            card.dispose();
          }
        }
        expect(tester.takeException(), isNull, reason: theme.id);
      }
    },
  );
}
