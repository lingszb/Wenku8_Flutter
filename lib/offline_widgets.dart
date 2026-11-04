import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'app_interactions.dart';
import 'catalog.dart';
import 'offline_cache.dart';
import 'offline_repository.dart';

class OfflineBookStatus extends StatelessWidget {
  const OfflineBookStatus({
    super.key,
    required this.repository,
    required this.novel,
    this.localDirectory = false,
    this.reduceMotion = false,
  });
  final OfflineNovelRepository repository;
  final Novel novel;
  final bool localDirectory, reduceMotion;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: repository.bookChanges(novel.id),
      builder: (context, _) {
        final saved = repository.cache.book(novel.id);
        final count = saved == null
            ? 0
            : identical(saved.novel.chapters, novel.chapters)
            ? saved.cachedCount
            : novel.chapters
                  .where(
                    (chapter) => saved.chapterBytes.containsKey(chapter.id),
                  )
                  .length;
        final label = novel.chapters.isEmpty
            ? '暂无章节缓存'
            : '${localDirectory ? '本地目录 · ' : ''}缓存 $count / ${novel.chapters.length} 章'
                  '${(saved?.illustrationBytes.length ?? 0) > 0 ? ' · ${saved!.illustrationBytes.length} 张插图' : ''}';
        return AppText(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
          ),
        );
      },
    );
    return reduceMotion || MediaQuery.disableAnimationsOf(context)
        ? content
        : AnimatedSize(
            duration: NovelMotion.enter,
            reverseDuration: NovelMotion.exit,
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            child: content,
          );
  }
}

class OfflineBookMenu extends StatelessWidget {
  const OfflineBookMenu({
    super.key,
    required this.repository,
    required this.novel,
    this.reduceMotion = false,
  });
  final OfflineNovelRepository repository;
  final Novel novel;
  final bool reduceMotion;
  @override
  Widget build(BuildContext context) => GlassMenuAnchor(
    child: Builder(
      builder: (anchor) => GlassIconButton(
        key: ValueKey('book-cache-action-${novel.id}'),
        icon: CupertinoIcons.trash,
        label: '清除这本缓存',
        onPressed: () async {
          if (!await _confirmClear(
            anchor,
            '清除这本缓存',
            reduceMotion: reduceMotion,
          )) {
            return;
          }
          try {
            await repository.removeCachedBook(novel.id);
          } catch (_) {
            if (anchor.mounted) _storageFailure(anchor);
          }
        },
      ),
    ),
  );
}

Future<bool> _confirmClear(
  BuildContext context,
  String label, {
  bool reduceMotion = false,
}) async =>
    await showGlassMenu<bool>(
      context: context,
      reduceMotion: reduceMotion || MediaQuery.disableAnimationsOf(context),
      builder: (menu) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassMenuItem(
            label: label,
            onPressed: () => Navigator.pop(menu, true),
          ),
          GlassMenuItem(
            order: 1,
            label: '保留缓存',
            onPressed: () => Navigator.pop(menu, false),
          ),
        ],
      ),
    ) ==
    true;

void _storageFailure(BuildContext context) =>
    showNovelFeedback(context, '缓存操作失败，请重试');

class OfflineCachePage extends StatefulWidget {
  const OfflineCachePage({
    super.key,
    required this.repository,
    required this.onOpen,
    this.reduceMotion = false,
  });
  final OfflineNovelRepository repository;
  final void Function(BuildContext context, Novel novel) onOpen;
  final bool reduceMotion;

  @override
  State<OfflineCachePage> createState() => _OfflineCachePageState();
}

class _OfflineCachePageState extends State<OfflineCachePage> {
  late Future<void> _loaded = widget.repository.loadCache();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Atmosphere(
      child: GlassHeaderLayout(
        header: ArchiveHeaderBar(
          leading: GlassIconButton(
            icon: CupertinoIcons.back,
            label: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          title: const ArchiveRouteTitle(
            title: '离线缓存',
            code: 'ARCHIVE / LOCAL STORAGE',
          ),
          actions: [
            GlassMenuAnchor(
              child: Builder(
                builder: (anchor) => GlassIconButton(
                  icon: CupertinoIcons.trash,
                  label: '清空缓存',
                  onPressed: () => _clear(anchor),
                ),
              ),
            ),
          ],
        ),
        body: FutureBuilder<void>(
          future: _loaded,
          builder: (context, snapshot) => LoadedContentSequence(
            generation:
                snapshot.connectionState == ConnectionState.done ||
                    widget.repository.cache.books.isNotEmpty
                ? 'cache-ready'
                : null,
            child: AnimatedBuilder(
              animation: widget.repository,
              builder: (context, _) {
                final books = widget.repository.cache.books;
                final count = books.length;
                final loading =
                    snapshot.connectionState != ConnectionState.done &&
                    count == 0;
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.paddingOf(context).top +
                        FrostedHeader.toolbarHeight +
                        20,
                    24,
                    MediaQuery.paddingOf(context).bottom + 28,
                  ),
                  itemCount: loading ? 4 : count + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return LoadedContentItem(
                        index: 0,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              sectionHeader(
                                context,
                                '本地存储',
                                formatCacheBytes(widget.repository.cache.bytes),
                              ),
                              const SizedBox(height: 12),
                              const AppText(
                                '已缓存正文与插图可离线阅读。清理缓存不会移出书架，也不会删除阅读进度。',
                                style: TextStyle(fontSize: 13, height: 1.7),
                              ),
                              if (snapshot.hasError ||
                                  widget.repository.cacheError != null) ...[
                                const SizedBox(height: 12),
                                const AppText('缓存读取或写入失败，请释放存储后重试。'),
                                GlassTextButton(
                                  onPressed: () => setState(
                                    () =>
                                        _loaded = widget.repository.loadCache(),
                                  ),
                                  child: const AppText('重试'),
                                ),
                              ] else if (!loading && count == 0)
                                const Padding(
                                  padding: EdgeInsets.only(top: 24),
                                  child: AppText('暂无历史缓存。'),
                                ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (loading) return const BookRowSkeleton(label: '正在读取缓存');
                    final novel = books[index - 1].novel;
                    return LoadedContentItem(
                      key: ValueKey('offline-book-${novel.id}'),
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ContentPanel(
                          onTap: novel.chapters.isEmpty
                              ? null
                              : () => widget.onOpen(context, novel),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      novel.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    OfflineBookStatus(
                                      repository: widget.repository,
                                      novel: novel,
                                      reduceMotion: widget.reduceMotion,
                                    ),
                                    const SizedBox(height: 4),
                                    AppText(
                                      formatCacheBytes(
                                        widget.repository.cache
                                                .book(novel.id)
                                                ?.bytes ??
                                            0,
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              OfflineBookMenu(
                                repository: widget.repository,
                                novel: novel,
                                reduceMotion: widget.reduceMotion,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _clear(BuildContext context) async {
    if (!await _confirmClear(
      context,
      '清空全部缓存',
      reduceMotion: widget.reduceMotion,
    )) {
      return;
    }
    try {
      await widget.repository.clearCache();
    } catch (_) {
      if (context.mounted) _storageFailure(context);
    }
  }
}
