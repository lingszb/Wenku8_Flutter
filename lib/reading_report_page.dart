// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'feature_pages.dart';
import 'library_state.dart';
import 'catalog.dart';
import 'reading_report_options.dart';
import 'reading_report_range.dart';
import 'reading_statistics_data.dart';

/// Desktop-friendly reading report.
///
/// The original snapshot exposed a highly visual report editor whose source is
/// not part of this repository. This page keeps the useful totals and the
/// shared date-range picker without depending on native image export.
class ReadingReportPage extends StatefulWidget {
  const ReadingReportPage({
    super.key,
    required this.state,
    required this.repository,
    required this.now,
    required this.initialRange,
  });

  final LibraryState state;
  final NovelRepository repository;
  final DateTime? now;
  final ReadingReportRange? initialRange;

  @override
  State<ReadingReportPage> createState() => _ReadingReportPageState();
}

class _ReadingReportPageState extends State<ReadingReportPage> {
  late ReadingReportRange _range =
      widget.initialRange ?? const ReadingReportRange();

  DateTime get _now => widget.now ?? DateTime.now();

  ReadingStatisticsData get _data => ReadingStatisticsData(
    state: widget.state,
    repository: widget.repository,
    now: _now,
    period: _range.daysAt(_now),
  );

  String _date(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.'
      '${value.day.toString().padLeft(2, '0')}';

  String get _rangeLabel {
    final end = _range.endAt(_now);
    final start = _range.custom
        ? _range.from!
        : end.subtract(Duration(days: _range.daysAt(_now) - 1));
    return '${_date(start)} — ${_date(end)}';
  }

  Future<void> _pickRange() async {
    final picked = await pickReadingReportRange(
      context,
      now: _now,
      range: _range,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = ReadingReportRange(
        period: _range.period,
        from: picked.start,
        until: picked.end,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final items = <(String, String)>[
      ('阅读时长', _duration(data.periodSeconds)),
      ('有记录天数', '${data.observedDays} 天'),
      ('阅读书目', '${data.periodBooks} 本'),
      ('书签与摘录', '${data.bookmarks}'),
      ('活跃天数', '${data.activeDays} 天'),
      ('平均每日', _duration(data.averageSeconds)),
    ];
    return ArchiveFeaturePage(
      title: '阅读报告',
      code: 'READING / REPORT',
      child: ListView(
        padding: featurePadding(context),
        children: [
          ArchiveSection(
            title: _rangeLabel,
            code: 'PERIOD / ${_range.daysAt(_now)} DAYS',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassTextButton(
                key: const ValueKey('reading-report-range'),
                onPressed: _pickRange,
                child: const Text('选择日期范围'),
              ),
              for (final module in ReadingReportModule.statisticsValues)
                Chip(label: Text(_moduleLabel(module))),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 620 ? 3 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.65,
                children: [
                  for (final item in items)
                    _MetricCard(label: item.$1, value: item.$2),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          if (data.dates.isNotEmpty) ...[
            const ArchiveSection(title: '每日记录', code: 'DAILY / SECONDS'),
            const SizedBox(height: 12),
            for (var i = data.dates.length - 1; i >= 0; i--)
              if (data.seconds[i] != null && data.seconds[i]! > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(_date(data.dates[i]))),
                      Text(_duration(data.seconds[i]!)),
                    ],
                  ),
                ),
          ],
          const SizedBox(height: 32),
          Text(
            '报告图片导出在当前源码版本暂未开放。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _moduleLabel(ReadingReportModule module) => switch (module) {
    ReadingReportModule.rhythm => '节奏',
    ReadingReportModule.days => '日历',
    ReadingReportModule.calendar => '热力',
    ReadingReportModule.books => '书目',
    ReadingReportModule.progress => '进度',
    ReadingReportModule.collection => '收藏',
    ReadingReportModule.excerpts => '摘录',
  };

  String _duration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    return '$hours 小时 ${minutes % 60} 分';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}
