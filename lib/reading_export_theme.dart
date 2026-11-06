import 'package:flutter/painting.dart';

import 'reading_visual_theme.dart';

const readingExportBrandName = '轻小说文库';

/// Resolve artwork once for a surface's snapshot. An artwork date does not add
/// a recorded date to the content; dateless excerpts can still follow the season.
String readingExportArt(
  ReadingVisualTheme theme, {
  DateTime? at,
  bool portrait = false,
}) {
  final season = switch ((at ?? DateTime.now()).month) {
    3 || 4 || 5 => 'spring',
    6 || 7 || 8 => 'summer',
    9 || 10 || 11 => 'autumn',
    _ => 'winter',
  };
  return 'assets/report/season-$season.png';
}

/// One visual family for reports, bookmark cards and reading keepsakes.
/// Persisted identities and native home-widget presentation stay independent.
class ReadingExportTheme {
  const ReadingExportTheme({
    required this.identity,
    required this.label,
    required this.description,
    required this.backgroundValue,
    required this.foregroundValue,
    required this.mutedValue,
    required this.accentValue,
    this.previewAlignment = Alignment.center,
    this.prefersSerif = false,
  });

  final ReadingVisualTheme identity;
  final String label, description;
  final int backgroundValue, foregroundValue, mutedValue, accentValue;
  final Alignment previewAlignment;
  final bool prefersSerif;
  Color get background => Color(backgroundValue);
  Color get foreground => Color(foregroundValue);
  Color get muted => Color(mutedValue);
  Color get accent => Color(accentValue);
  Color get secondary => Color.lerp(background, accent, .3)!;
  bool get isDark => background.computeLuminance() < .15;
}

ReadingExportTheme readingExportTheme(ReadingVisualTheme theme) =>
    switch (theme) {
      ReadingVisualTheme.archive => const ReadingExportTheme(
        identity: ReadingVisualTheme.archive,
        label: '阅读档案',
        description: '四季风景 · 阅读档案',
        backgroundValue: 0xfff4f3ef,
        foregroundValue: 0xff24312e,
        mutedValue: 0xff697670,
        accentValue: 0xff2a8178,
      ),
      ReadingVisualTheme.shelf => const ReadingExportTheme(
        identity: ReadingVisualTheme.shelf,
        label: '四季书页',
        description: '四季风景 · 沉浸书页',
        backgroundValue: 0xff141e26,
        foregroundValue: 0xffe5ece9,
        mutedValue: 0xffa5b5ba,
        accentValue: 0xff8db9b0,
      ),
      ReadingVisualTheme.editorial => const ReadingExportTheme(
        identity: ReadingVisualTheme.editorial,
        label: '四季手帐',
        description: '夜樱繁星 · 满月初雪',
        backgroundValue: 0xfff2efe8,
        foregroundValue: 0xff373831,
        mutedValue: 0xff817c6d,
        accentValue: 0xff7b8d62,
        prefersSerif: true,
      ),
      ReadingVisualTheme.constellation => const ReadingExportTheme(
        identity: ReadingVisualTheme.constellation,
        label: '四季夜读',
        description: '四季风景 · 阅读时钟',
        backgroundValue: 0xff0e1116,
        foregroundValue: 0xffece5d4,
        mutedValue: 0xff969c9f,
        accentValue: 0xffd9b66f,
      ),
      ReadingVisualTheme.signal => const ReadingExportTheme(
        identity: ReadingVisualTheme.signal,
        label: '纸上回声',
        description: '四季风景 · 纸上回声',
        backgroundValue: 0xff272727,
        foregroundValue: 0xfff2efe7,
        mutedValue: 0xffb4b3aa,
        accentValue: 0xffdad5c7,
      ),
      ReadingVisualTheme.score => const ReadingExportTheme(
        identity: ReadingVisualTheme.score,
        label: '四季放映',
        description: '四季风景 · 书页放映',
        backgroundValue: 0xff0b0c0e,
        foregroundValue: 0xffeee4ce,
        mutedValue: 0xff8d939a,
        accentValue: 0xffb99a6b,
      ),
      ReadingVisualTheme.ink => const ReadingExportTheme(
        identity: ReadingVisualTheme.ink,
        label: '四季书信',
        description: '四季风景 · 暖纸留白',
        backgroundValue: 0xfff5f0e6,
        foregroundValue: 0xff303b34,
        mutedValue: 0xff6e796e,
        accentValue: 0xff9d704d,
        prefersSerif: true,
      ),
      ReadingVisualTheme.festival => const ReadingExportTheme(
        identity: ReadingVisualTheme.festival,
        label: '四季来信',
        description: '四季风景 · 阅读明信片',
        backgroundValue: 0xffeff1e9,
        foregroundValue: 0xff273e47,
        mutedValue: 0xff697776,
        accentValue: 0xffb96f44,
      ),
    };
