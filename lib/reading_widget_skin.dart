// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/foundation.dart';

/// Visual skins shared by the home-screen widget host and the desktop preview.
///
/// The identifiers are persisted (`skin.name`), so they must stay stable.
@immutable
class ReadingWidgetSkin {
  const ReadingWidgetSkin._(this.id, this.label);

  final String id;
  final String label;

  String get name => id;

  static const original = ReadingWidgetSkin._('original', '默认');
  static const seasons = ReadingWidgetSkin._('seasons', '四时');
  static const paper = ReadingWidgetSkin._('paper', '纸页');
  static const night = ReadingWidgetSkin._('night', '夜读');
  static const ink = ReadingWidgetSkin._('ink', '水墨');

  static const values = <ReadingWidgetSkin>[
    original,
    seasons,
    paper,
    night,
    ink,
  ];

  static ReadingWidgetSkin fromId(String? id) {
    if (id == null || id.isEmpty) return original;
    for (final skin in values) {
      if (skin.id == id) return skin;
    }
    return original;
  }

  Map<String, Object?> toJson() => {'id': id, 'label': label};

  @override
  bool operator ==(Object other) =>
      other is ReadingWidgetSkin && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ReadingWidgetSkin($id)';
}

/// Shared minute-goal clamp used by the widget snapshot and its settings.
int readingDailyGoal(int? minutes) => (minutes ?? 0).clamp(0, 1440).toInt();

String readingGoalCaption(int minutes, [int? todaySeconds = 0]) {
  if (minutes <= 0) return '未设置每日目标';
  final progress = todaySeconds == null || todaySeconds <= 0
      ? ''
      : ' · 今日 ${(todaySeconds / 60).floor()} 分钟';
  return '每日目标 $minutes 分钟$progress';
}
