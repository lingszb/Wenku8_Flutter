import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'reading_artwork.dart';
import 'reading_export_theme.dart';
import 'reading_widget_design.dart';
import 'reading_widget_skin.dart';
import 'reading_widget_snapshot.dart';

/// Logical sizes shared by the preview and the published desktop image.
enum ReadingDesktopSize {
  small('小 2×2', 144, 144),
  medium('中 4×2', 300, 144),
  large('大 4×4', 300, 300);

  const ReadingDesktopSize(this.label, this.previewWidth, this.previewHeight);
  final String label;
  final double previewWidth, previewHeight;
  double get aspectRatio => previewWidth / previewHeight;
}

// At most four decoded seasonal images, shared by every card/size/appearance.
final _artwork = <String, Future<ui.Image>>{};
Future<ui.Image> _image(ReadingWidgetSnapshot data) {
  final asset = readingExportArt(data.theme, at: data.localDay);
  return _artwork.putIfAbsent(asset, () async {
    final art = await loadReadingArtwork(asset);
    final codec = await ui.instantiateImageCodec(art.bytes, targetWidth: 600);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  });
}

class ReadingDesktopCard extends StatelessWidget {
  const ReadingDesktopCard({
    super.key,
    required this.data,
    required this.size,
    required this.brightness,
    this.quoteText,
    this.quoteSource = '',
    this.quoteCount = 0,
  });
  final ReadingWidgetSnapshot data;
  final ReadingDesktopSize size;
  final Brightness brightness;
  final String? quoteText;
  final String quoteSource;
  final int quoteCount;

  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
    future: _image(data),
    builder: (context, snapshot) => Semantics(
      image: true,
      label: _description(data, quoteText),
      child: SizedBox(
        width: size.previewWidth,
        height: size.previewHeight,
        child: CustomPaint(
          painter: _DesktopPainter(
            data,
            size,
            brightness,
            snapshot.data,
            quoteText: quoteText ?? '在阅读中留下喜欢的句子',
            quoteSource: quoteSource,
            quoteCount: quoteCount,
          ),
        ),
      ),
    ),
  );
}

Future<void> warmReadingDesktopImages(ReadingWidgetSnapshot snapshot) async {
  await _image(snapshot);
}

Future<Uint8List> renderReadingDesktopCard(
  ReadingWidgetSnapshot data,
  ReadingDesktopSize size, {
  required Brightness brightness,
  bool paintQuote = false,
}) async {
  final artwork = await _image(data);
  const scale = 2.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  _DesktopPainter(
    data,
    size,
    brightness,
    artwork,
    quoteText: paintQuote ? '在阅读中留下喜欢的句子' : null,
  ).paint(canvas, Size(size.previewWidth, size.previewHeight));
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(
      (size.previewWidth * scale).round(),
      (size.previewHeight * scale).round(),
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('无法生成桌面组件预览');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

String _description(ReadingWidgetSnapshot data, String? quote) =>
    switch (data.design) {
      ReadingWidgetDesign.focus =>
        '今日阅读 ${widgetMinutes(data.verifiedTodaySeconds)} 分钟',
      ReadingWidgetDesign.calendar => '阅读日历 ${widgetDate(data.localDay)}',
      ReadingWidgetDesign.memory =>
        data.showBookDetails
            ? data.latestCompletion?.title ?? '尚无阅读纪念'
            : '阅读纪念',
      ReadingWidgetDesign.quote => quote ?? '在阅读中留下喜欢的句子',
      _ => '本周阅读 ${widgetMinutes(data.weekSeconds)} 分钟',
    };

class _DesktopPainter extends CustomPainter {
  _DesktopPainter(
    this.data,
    this.family,
    this.brightness,
    this.artwork, {
    this.quoteText,
    this.quoteSource = '',
    this.quoteCount = 0,
  });
  final ReadingWidgetSnapshot data;
  final ReadingDesktopSize family;
  final Brightness brightness;
  final ui.Image? artwork;
  final String? quoteText;
  final String quoteSource;
  final int quoteCount;

  @override
  void paint(Canvas canvas, Size size) {
    final compact = family == ReadingDesktopSize.small;
    final large = family == ReadingDesktopSize.large;
    final dark = brightness == Brightness.dark;
    final background = dark
        ? const Color(0xff191e22)
        : switch (data.skin.id) {
            'paper' => const Color(0xffecece5),
            'ink' => const Color(0xffedf2eb),
            'night' => const Color(0xffe8edf2),
            _ => const Color(0xfff4f3ef),
          };
    final ink = dark ? const Color(0xfff2efe8) : const Color(0xff202329);
    final muted = dark ? const Color(0xffbdc3c0) : const Color(0xff5c6864);
    final accent = dark ? const Color(0xffb6d6c5) : const Color(0xff356b56);
    final p = compact ? 12.0 : 16.0;
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(compact ? 16 : 22),
    );
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawColor(background, BlendMode.src);
    final illustrated =
        data.skin == ReadingWidgetSkin.seasons ||
        data.design == ReadingWidgetDesign.memory ||
        data.design == ReadingWidgetDesign.quote;
    if (illustrated && artwork != null) {
      final artRect = data.design == ReadingWidgetDesign.quote && !large
          ? rect
          : large
          ? Rect.fromLTWH(0, 0, size.width, 126)
          : compact
          ? rect
          : Rect.fromLTWH(size.width * .57, 0, size.width * .43, size.height);
      paintImage(
        canvas: canvas,
        rect: artRect,
        image: artwork!,
        fit: BoxFit.cover,
      );
      canvas.drawRect(
        artRect,
        Paint()
          ..color = background.withValues(
            alpha: compact || data.design == ReadingWidgetDesign.quote && !large
                ? .88
                : dark
                ? .25
                : .08,
          ),
      );
    }
    final textWidth = !compact && !large && illustrated
        ? size.width * .55 - p * 2
        : size.width - p * 2;
    final top = large && illustrated ? 140.0 : p;
    void text(
      String value,
      double y, {
      double font = 12,
      Color? color,
      int lines = 1,
      FontWeight weight = FontWeight.w400,
      double? width,
      double? x,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color ?? ink,
            fontSize: font,
            fontWeight: weight,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: width ?? textWidth);
      painter.paint(canvas, Offset(x ?? p, y));
      painter.dispose();
    }

    text(
      data.design == ReadingWidgetDesign.classic
          ? data.skin.label
          : data.design.label,
      top,
      color: muted,
      font: compact ? 10 : 12,
    );
    switch (data.design) {
      case ReadingWidgetDesign.focus:
        text(
          widgetMinutes(data.verifiedTodaySeconds),
          top + 22,
          font: compact ? 32 : 40,
          weight: FontWeight.w300,
        );
        text('分钟 · 今日', top + 70, font: 10, color: muted);
        if (data.dailyGoalMinutes > 0) {
          final y = math.min(size.height - 25, top + 94);
          final bar = Rect.fromLTWH(p, y, textWidth, 3);
          canvas.drawRRect(
            RRect.fromRectAndRadius(bar, const Radius.circular(2)),
            Paint()..color = muted.withValues(alpha: .2),
          );
          if (data.verifiedTodaySeconds != null) {
            final progress =
                (data.verifiedTodaySeconds! / (data.dailyGoalMinutes * 60))
                    .clamp(0.0, 1.0);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(p, y, textWidth * progress, 3),
                const Radius.circular(2),
              ),
              Paint()..color = accent,
            );
          }
          text('目标 ${data.dailyGoalMinutes} 分钟', y + 7, font: 9, color: muted);
        }
        if (large && data.showBookDetails && data.currentBook != null) {
          text('继续阅读 · ${data.currentBook!.title}', size.height - 36, font: 12);
        }
      case ReadingWidgetDesign.calendar:
        text(
          widgetDate(data.localDay).substring(0, 7).replaceAll('-', ' / '),
          top + 22,
          font: 18,
        );
        final weeks = compact
            ? 6
            : large
            ? 12
            : 10;
        final days = data.heatmap.window(weeks);
        final start = top + 51;
        final step = math.min(textWidth / weeks, (size.height - start - p) / 7);
        for (var i = 0; i < days.length; i++) {
          final level = readingWidgetHeatLevel(days[i].verifiedSeconds);
          final cell = Rect.fromLTWH(
            p + (i ~/ 7) * step,
            start + (i % 7) * step,
            math.max(1, step - 2),
            math.max(1, step - 2),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(cell, const Radius.circular(1)),
            Paint()
              ..color = level == null
                  ? muted.withValues(alpha: .08)
                  : accent.withValues(alpha: .16 + level * .2)
              ..style = level == null
                  ? PaintingStyle.stroke
                  : PaintingStyle.fill
              ..strokeWidth = .5,
          );
        }
      case ReadingWidgetDesign.memory:
        final completion = data.latestCompletion;
        text(
          completion == null
              ? '下一段故事'
              : data.showBookDetails
              ? completion.title ?? '书页留念'
              : '书页留念',
          top + 26,
          font: compact ? 18 : 21,
          lines: 2,
          weight: FontWeight.w600,
        );
        text(
          completion == null ? '从这一页开始。' : widgetDate(completion.completedAt),
          size.height - p - 16,
          font: 10,
          color: muted,
        );
      case ReadingWidgetDesign.quote:
        // Native RemoteViews overlay the selected excerpt on published images.
        if (quoteText != null) {
          final quoteTop = large
              ? 180.0
              : compact
              ? 53.0
              : 42.0;
          text(
            quoteText!.isEmpty ? '在阅读中留下喜欢的句子' : quoteText!,
            quoteTop,
            font: compact ? 13 : 15,
            lines: large ? 3 : 2,
            width: size.width - p * 2,
          );
          if (quoteSource.isNotEmpty && data.showBookDetails) {
            text(
              quoteSource,
              size.height - (large ? 58 : 32),
              font: 9,
              color: muted,
              width: size.width - p * 2,
            );
          }
          if (large && quoteCount > 0) {
            text('共 $quoteCount 条摘录', size.height - 30, font: 10, color: muted);
          }
        }
      case ReadingWidgetDesign.week:
      case ReadingWidgetDesign.classic:
        text(
          '${widgetMinutes(data.weekSeconds)} 分钟',
          top + 22,
          font: compact ? 22 : 27,
        );
        final chartTop = top + 62;
        final chartHeight = math.max(8.0, size.height - chartTop - p - 16);
        final maxSeconds = math.max(
          300,
          data.week.map((v) => v.verifiedSeconds ?? 0).reduce(math.max),
        );
        final step = textWidth / 7;
        for (var i = 0; i < 7; i++) {
          final day = data.week[i];
          final barHeight = day.verifiedSeconds == null
              ? 2.0
              : math.max(2.0, chartHeight * day.verifiedSeconds! / maxSeconds);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                p + i * step + step * .2,
                chartTop + chartHeight - barHeight,
                step * .6,
                barHeight,
              ),
              const Radius.circular(2),
            ),
            Paint()
              ..color = accent.withValues(alpha: i == 6 ? 1 : .45)
              ..style = day.verifiedSeconds == null
                  ? PaintingStyle.stroke
                  : PaintingStyle.fill
              ..strokeWidth = .7,
          );
          text(
            '${day.date.day}',
            chartTop + chartHeight + 4,
            font: 8,
            color: muted,
            x: p + i * step + step * .2,
            width: step,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DesktopPainter oldDelegate) =>
      data != oldDelegate.data ||
      family != oldDelegate.family ||
      brightness != oldDelegate.brightness ||
      artwork != oldDelegate.artwork ||
      quoteText != oldDelegate.quoteText ||
      quoteSource != oldDelegate.quoteSource ||
      quoteCount != oldDelegate.quoteCount;
}
