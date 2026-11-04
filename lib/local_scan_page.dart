// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/material.dart';

import 'book_documents.dart';
import 'local_import_batch.dart';

/// Shows the folder-scan state and starts a scan.
class LocalScanPage extends StatelessWidget {
  const LocalScanPage({
    super.key,
    required this.documents,
    required this.changes,
    required this.isBusy,
    required this.progress,
    required this.result,
    required this.failure,
    required this.onScan,
  });

  final BookDocuments documents;
  final Listenable changes;
  final bool Function() isBusy;
  final (int, int)? Function() progress;
  final LocalScanResult? Function() result;
  final String? Function() failure;
  final Future<void> Function(BuildContext page) onScan;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('扫描本地文件夹')),
    body: ListenableBuilder(
      listenable: changes,
      builder: (context, _) {
        final busy = isBusy();
        final current = progress();
        final scan = result();
        final error = failure();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '当前源码版本暂不支持文件夹扫描，请返回文库直接选择 TXT 或 EPUB 文件导入。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (busy) ...[
              LinearProgressIndicator(
                value: current == null || current.$2 == 0
                    ? null
                    : current.$1 / current.$2,
              ),
              const SizedBox(height: 8),
              Text(
                current == null ? '正在扫描…' : '已完成 ${current.$1}/${current.$2}',
              ),
              const SizedBox(height: 20),
            ],
            if (error != null) ...[
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (scan != null) ...[
              Text(
                scan.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final warning in scan.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('· $warning'),
                ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择文件夹'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: null, child: const Text('按上次设置扫描')),
          ],
        );
      },
    ),
  );
}
