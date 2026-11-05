import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_ui.dart';
import 'book_documents.dart';
import 'feature_pages.dart';
import 'local_import_batch.dart';
import 'local_platform.dart';

/// Shows the folder-scan state and starts a scan.
class LocalScanPage extends StatefulWidget {
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
  State<LocalScanPage> createState() => _LocalScanPageState();
}

class _LocalScanPageState extends State<LocalScanPage>
    with WidgetsBindingObserver {
  BookScanFolder? _folder;
  Set<String> _formats = {'txt', 'epub'};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _perform(_reload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && !widget.isBusy()) {
      _perform(_reload);
    }
  }

  Future<void> _reload() async {
    if (!LocalPlatform.android) return;
    final folder = await widget.documents.scanFolderInfo();
    final formats = await widget.documents.scanFormats();
    if (!mounted) return;
    setState(() {
      _folder = folder;
      _formats = formats.intersection({'txt', 'epub'});
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PlatformException
              ? error.message ?? '文件操作未完成，请重试'
              : '扫描设置未保存，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choose({bool all = false}) => _perform(() async {
    final folder = all
        ? await widget.documents.selectAllScan()
        : await widget.documents.selectScanFolder();
    if (folder != null && mounted) setState(() => _folder = folder);
  });

  Future<void> _format(String format, bool enabled) => _perform(() async {
    final selected = {..._formats};
    enabled ? selected.add(format) : selected.remove(format);
    await widget.documents.setScanFormats(selected);
    if (mounted) setState(() => _formats = selected);
  });

  @override
  Widget build(BuildContext context) => ArchiveFeaturePage(
    title: '扫描本地文件夹',
    code: 'LOCAL / SCAN',
    child: ListenableBuilder(
      listenable: widget.changes,
      builder: (context, _) {
        if (!LocalPlatform.android) {
          return ListView(
            padding: featurePadding(context),
            children: const [AppText('当前版本仅支持 Android 文件夹扫描，请使用手动导入。')],
          );
        }
        final busy = _loading || widget.isBusy();
        final current = widget.progress();
        final scan = widget.result();
        final error = _error ?? widget.failure();
        return ListView(
          padding: featurePadding(context),
          children: [
            const AppText('扫描 TXT、EPUB 后勾选导入。扫描不会移动或删除原文件，保存方式沿用导入设置。'),
            const SizedBox(height: 20),
            AppText(
              _folder == null ? '尚未选择扫描位置' : '扫描位置：${_folder!.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_folder != null && !_folder!.readable)
              AppText(
                '读取授权已失效，请重新选择文件夹或授权共享存储。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            GlassTextButton(
              key: const ValueKey('scan-select-folder'),
              onPressed: busy ? null : _choose,
              child: AppText(_folder == null ? '选择文件夹' : '更换文件夹'),
            ),
            if (LocalPlatform.android) ...[
              const SizedBox(height: 8),
              GlassTextButton(
                key: const ValueKey('scan-select-shared'),
                onPressed: busy ? null : () => _choose(all: true),
                child: const AppText('扫描共享存储'),
              ),
              const SizedBox(height: 8),
              const AppText(
                '共享存储扫描需要系统授权；不扫描隐藏目录和 Android 目录。只需扫描某个目录时，优先选择文件夹。',
              ),
            ],
            const SizedBox(height: 20),
            const AppText('扫描格式'),
            for (final format in const ['txt', 'epub'])
              CheckboxListTile(
                title: AppText(format.toUpperCase()),
                value: _formats.contains(format),
                contentPadding: EdgeInsets.zero,
                onChanged:
                    busy || _formats.length == 1 && _formats.contains(format)
                    ? null
                    : (value) => _format(format, value == true),
              ),
            SwitchListTile(
              key: const ValueKey('scan-automatic'),
              title: const AppText('进入书库时自动检查'),
              subtitle: const AppText('仅在前台检查新文件，导入前仍需手动扫描并勾选。'),
              contentPadding: EdgeInsets.zero,
              value: _folder?.automatic ?? false,
              onChanged: busy || _folder?.readable != true
                  ? null
                  : (value) => _perform(() async {
                      await widget.documents.setScanAutomatic(value);
                      await _reload();
                    }),
            ),
            const SizedBox(height: 16),
            GlassTextButton(
              key: const ValueKey('scan-start'),
              onPressed: busy || _folder?.readable != true || _formats.isEmpty
                  ? null
                  : () => widget.onScan(context),
              child: const AppText('扫描并选择书籍'),
            ),
            if (_folder != null) ...[
              const SizedBox(height: 8),
              GlassTextButton(
                key: const ValueKey('scan-disconnect'),
                onPressed: busy
                    ? null
                    : () => _perform(() async {
                        await widget.documents.disconnectScanFolder();
                        await _reload();
                      }),
                child: const AppText('断开扫描位置'),
              ),
              const SizedBox(height: 8),
              const AppText('断开后保留已导入书籍；关联原文件的书籍继续保留所需的目录授权。'),
            ],
            const SizedBox(height: 20),
            if (widget.isBusy()) ...[
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
            if (_loading) const LinearProgressIndicator(),
          ],
        );
      },
    ),
  );
}
