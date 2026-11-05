import 'catalog.dart';
import 'book_tag_catalog.dart';
import 'local_book_series.dart';
import 'local_books.dart';
import 'local_library_preferences.dart';

typedef BookCategoryCount = ({String label, int count});

/// Read-only categories built from visible book metadata. These never alter
/// the user's named groups or per-book classification assignments.
abstract final class BookDynamicCategories {
  static void _add(
    Map<String, BookCategoryCount> groups,
    String id,
    String label,
  ) {
    final previous = groups[id];
    groups[id] = (
      label: previous?.label ?? label,
      count: (previous?.count ?? 0) + 1,
    );
  }

  static Map<String, BookCategoryCount> _sorted(
    Map<String, BookCategoryCount> groups,
  ) {
    final entries = groups.entries.toList()
      ..sort((a, b) => a.value.label.compareTo(b.value.label));
    return {for (final entry in entries) entry.key: entry.value};
  }

  static Map<String, BookCategoryCount> authors(
    Iterable<Novel> books, {
    int unknownCount = 0,
  }) {
    final groups = <String, BookCategoryCount>{};
    for (final book in books) {
      final name = LocalLibraryPreferences.authorName(book.author);
      _add(groups, LocalLibraryPreferences.authorCategory(name), name);
    }
    for (var i = 0; i < unknownCount; i++) {
      _add(
        groups,
        LocalLibraryPreferences.authorCategory('未知作者'),
        '未知作者',
      );
    }
    return _sorted(groups);
  }

  static Map<String, BookCategoryCount> tags(Iterable<Novel> books) {
    final groups = <String, BookCategoryCount>{};
    for (final book in books) {
      // The normalizer removes local-import / combined-volume markers.
      final tags = normalizeBookTags([book.genre]);
      if (tags.isEmpty) {
        _add(groups, LocalLibraryPreferences.noTag, '未标注标签');
        continue;
      }
      for (final tag in tags) {
        _add(groups, LocalLibraryPreferences.tagCategory(tag), tag);
      }
    }
    return _sorted(groups);
  }

  static String? seriesKey(Novel book, LocalBookStore? local) {
    if (local?.seriesFor(book.id) case final series?) {
      return seriesTitleKey(series.title);
    }
    return (local?.seriesHint(book.id) ?? inferLocalSeries(book.title))?.key;
  }

  static String? seriesName(Novel book, LocalBookStore? local) {
    if (local?.seriesFor(book.id) case final series?) return series.title;
    return (local?.seriesHint(book.id) ?? inferLocalSeries(book.title))?.title;
  }

  static Map<String, BookCategoryCount> series(
    Iterable<Novel> books, {
    LocalBookStore? local,
  }) {
    final groups = <String, BookCategoryCount>{};
    for (final book in books) {
      final key = seriesKey(book, local);
      if (key == null || key.isEmpty) {
        _add(groups, LocalLibraryPreferences.noSeries, '未归入系列');
      } else {
        final title = seriesName(book, local) ?? book.title;
        _add(groups, LocalLibraryPreferences.seriesCategory(key), title);
      }
    }
    return _sorted(groups);
  }
}
