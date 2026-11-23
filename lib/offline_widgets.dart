import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'catalog.dart';
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
