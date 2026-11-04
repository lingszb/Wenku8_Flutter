// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/material.dart';

import 'feature_pages.dart';
import 'lan_reading_sync.dart';

/// Desktop placeholder for the mobile LAN reading browser.
class LanReadingPage extends StatelessWidget {
  const LanReadingPage({
    super.key,
    required this.sync,
    required this.reduceMotion,
  });

  final LanReadingSync sync;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => ArchiveFeaturePage(
    title: '局域网续读',
    code: 'READING / NEARBY',
    child: Center(
      child: Padding(
        padding: featurePadding(context),
        child: const Text('当前源码版本不支持局域网续读，请继续使用本机书架。'),
      ),
    ),
  );
}
