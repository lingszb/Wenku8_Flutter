// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'reading_visual_theme.dart';
import 'reading_widget_snapshot.dart';

/// Sizes used by the native widget host and the in-app desktop preview.
enum ReadingDesktopSize {
  small('小 2×2', 144, 144),
  medium('中 4×2', 300, 144),
  large('大 4×4', 300, 300);

  const ReadingDesktopSize(this.label, this.previewWidth, this.previewHeight);
  final String label;
  final double previewWidth;
  final double previewHeight;

  double get aspectRatio => previewWidth / previewHeight;
}

/// A lightweight Flutter rendering of the Android/iOS home-screen widget.
///
/// The real host paints this natively; this widget exists so the settings page
/// can preview every skin on desktop without a platform channel.
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

  ReadingVisualTheme get _theme => data.theme;
  Color get _background => Color(_theme.backgroundValue);
  Color get _ink => Color(_theme.inkValue);
  Color get _muted => Color(_theme.mutedValue);
  Color get _accent => Color(_theme.accentValue);

  @override
  Widget build(BuildContext context) {
    final compact = size == ReadingDesktopSize.small;
    final week = data.weekSeconds;
    final total = data.verifiedTotalSeconds;
    final streak = data.qualifiedStreakDays;
    return Container(
      width: size.previewWidth,
      height: size.previewHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(compact ? 16 : 22),
        border: Border.all(color: _accent.withValues(alpha: 0.35)),
      ),
      padding: EdgeInsets.all(compact ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.skin.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink,
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                '阅读',
                style: TextStyle(color: _accent, fontSize: compact ? 9 : 11),
              ),
            ],
          ),
          const Spacer(),
          Text(
            week == null ? '—' : widgetMinutes(week),
            style: TextStyle(
              color: _ink,
              fontSize: compact ? 26 : 40,
              height: 1.0,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            '本周阅读分钟',
            style: TextStyle(color: _muted, fontSize: compact ? 9 : 11),
          ),
          const Spacer(),
          if (quoteText != null && quoteText!.isNotEmpty && !compact)
            Text(
              quoteText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _ink, fontSize: 11, height: 1.45),
            ),
          if (quoteText != null && quoteText!.isNotEmpty && !compact)
            const SizedBox(height: 4),
          Text(
            [
              if (total != null) '累计 ${widgetMinutes(total)} 分钟',
              if (streak != null) '连续 $streak 天',
              if (quoteCount > 0) '摘录 $quoteCount',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _muted, fontSize: compact ? 8 : 10),
          ),
        ],
      ),
    );
  }
}

Future<void> warmReadingDesktopImages(ReadingWidgetSnapshot snapshot) async {
  // Desktop previews paint immediately; the native host warms its own assets.
}

Future<Uint8List> renderReadingDesktopCard(
  ReadingWidgetSnapshot data,
  ReadingDesktopSize size, {
  required Brightness brightness,
  bool paintQuote = false,
}) async {
  const scale = 2.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final width = size.previewWidth * scale;
  final height = size.previewHeight * scale;
  canvas.scale(scale);
  final theme = data.theme;
  final background = Color(theme.backgroundValue);
  final ink = Color(theme.inkValue);
  final muted = Color(theme.mutedValue);
  final accent = Color(theme.accentValue);
  final radius = size == ReadingDesktopSize.small ? 16.0 : 22.0;
  final bounds = Rect.fromLTWH(0, 0, size.previewWidth, size.previewHeight);
  canvas.drawRRect(
    RRect.fromRectAndRadius(bounds, Radius.circular(radius)),
    Paint()..color = background,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(bounds.deflate(0.5), Radius.circular(radius)),
    Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke,
  );
  final padding = size == ReadingDesktopSize.small ? 10.0 : 16.0;
  _paintText(
    canvas,
    data.skin.label,
    Offset(padding, padding),
    maxWidth: size.previewWidth - padding * 2,
    color: ink,
    fontSize: size == ReadingDesktopSize.small ? 11 : 13,
    weight: FontWeight.w600,
  );
  final week = data.weekSeconds;
  _paintText(
    canvas,
    week == null ? '—' : widgetMinutes(week),
    Offset(padding, size.previewHeight - padding - 58),
    maxWidth: size.previewWidth - padding * 2,
    color: ink,
    fontSize: size == ReadingDesktopSize.small ? 26 : 40,
    weight: FontWeight.w300,
  );
  _paintText(
    canvas,
    '本周阅读分钟',
    Offset(padding, size.previewHeight - padding - 18),
    maxWidth: size.previewWidth - padding * 2,
    color: muted,
    fontSize: size == ReadingDesktopSize.small ? 9 : 11,
  );
  final image = await recorder.endRecording().toImage(
    width.round(),
    height.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) {
    throw StateError('无法生成桌面组件预览');
  }
  return bytes.buffer.asUint8List();
}

void _paintText(
  Canvas canvas,
  String text,
  Offset offset, {
  required double maxWidth,
  required Color color,
  required double fontSize,
  FontWeight weight = FontWeight.w400,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  painter.paint(canvas, offset);
  painter.dispose();
}
