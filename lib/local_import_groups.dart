import 'catalog.dart';
import 'local_books.dart';
import 'local_book_series.dart';
import 'local_import_batch.dart' show LocalImportGroup;

/// Suggestions are limited to selected originals and their existing collection.
/// Ambiguous targets require the user to choose in the series editor.
List<LocalImportGroup> suggestLocalImportGroups(
  LocalBookStore books,
  List<int> bookIds,
) {
  final selected = bookIds.toSet();
  final candidates = <String, List<Novel>>{};
  for (final book in books.originals) {
    if (!selected.contains(book.id) ||
        books.seriesFor(book.id) != null ||
        books.isOmnibus(book.id)) {
      continue;
    }
    final name = books.seriesName(book.id);
    if (name == null) continue;
    final author = book.author == '本地书籍' ? '' : seriesTitleKey(book.author);
    (candidates['${seriesTitleKey(name)}\u0000$author'] ??= []).add(book);
  }
  final result = <LocalImportGroup>[];
  for (final originals in candidates.values) {
    final name = books.seriesName(originals.first.id)!;
    final author = originals.first.author;
    final targets = books.series
        .where(
          (series) =>
              seriesTitleKey(books.seriesName(series.id) ?? '') ==
                  seriesTitleKey(name) &&
              (author == '本地书籍' ||
                  series.author == '本地书籍' ||
                  seriesTitleKey(series.author) == seriesTitleKey(author)),
        )
        .toList();
    if (originals.length < 2 && targets.isEmpty) continue;
    final target = targets.length == 1 ? targets.single : null;
    final volumes = <({int bookId, String title})>[
      ...?target?.volumes.map(
        (volume) => (bookId: volume.bookId, title: volume.title),
      ),
      for (final book in originals)
        (
          bookId: book.id,
          title: books.seriesHint(book.id)?.volumeTitle ?? book.title,
        ),
    ];
    // Preserve existing order on ties and unknown volume numbers.
    final positions = {
      for (final (index, volume) in volumes.indexed) volume.bookId: index,
    };
    volumes.sort((a, b) {
      final order = (books.seriesHint(a.bookId)?.number ?? double.infinity)
          .compareTo(books.seriesHint(b.bookId)?.number ?? double.infinity);
      return order != 0
          ? order
          : positions[a.bookId]!.compareTo(positions[b.bookId]!);
    });
    result.add(
      LocalImportGroup(
        seed: originals.first.id,
        title: target?.title ?? name,
        needsTarget: targets.length > 1,
        targetId: target?.id,
        volumes: volumes,
      ),
    );
  }
  return result;
}
