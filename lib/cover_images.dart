import 'package:flutter/widgets.dart';
import 'app_interactions.dart';
import 'catalog.dart';
import 'reader_illustrations.dart';

Future<void> openNovelCoverImage(
  BuildContext context,
  Novel book, {
  required bool reduceMotion,
}) async {
  final url = book.coverUrl;
  if (url == null || !url.startsWith('wenku-local:')) return;
  await pushNovelPage<void>(
    context,
    ReaderIllustrationGallery(
      urls: [url],
      initialUrl: url,
      title: '小说封面',
      fileNamePrefix: book.title,
      cache: ReaderIllustrationCache.shared,
    ),
    reduceMotion: reduceMotion,
  );
}
