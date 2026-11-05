import 'library_state.dart';
import 'offline_repository.dart';
import 'local_library_preferences.dart';
import 'catalog.dart';
import 'local_books.dart';
import 'book_dynamic_categories.dart';

/// The shelf contains saved books and, when merged, imported originals.
/// Cached trial chapters provide offline availability, never membership.
Set<int> bookshelfIds(
  LibraryState state,
  OfflineNovelRepository? offline, {
  bool readableOnly = false,
  bool filterSource = true,
  bool filterCategory = true,
}) =>
    {
          for (final id in state.shelf)
            if (!readableOnly || offline?.availableOffline(id) == true) id,
          if (state.combinedShelf)
            ...?offline?.local?.books.map((book) => book.id),
        }
        .where(
          (id) =>
              state.localBookVisible(id) &&
              (!filterSource || bookshelfMatchesSource(id, state, offline)) &&
              (!filterCategory ||
                  bookshelfMatchesCategory(
                    id,
                    state,
                    book:
                        offline?.local?.book(id) ??
                        offline?.cache.book(id)?.novel,
                    localBooks: offline?.local,
                  )),
        )
        .toSet();

bool bookshelfMatchesCategory(
  int id,
  LibraryState state, {
  Novel? book,
  String? category,
  LocalBookStore? localBooks,
}) {
  final selected = category ?? state.organization.shelfSelected;
  final resolved = book ?? state.cachedNovel(id);
  // A missing legacy snapshot cannot satisfy metadata-based categories.
  if (resolved == null) {
    // Keep the original unknown-author fallback for unresolved saved books.
    if (LocalLibraryPreferences.categoryAuthor(selected) case final author?) {
      return author == '未知作者';
    }
    return selected == LocalLibraryPreferences.all ||
        (selected == LocalLibraryPreferences.unfiled ||
            state.organization.groups.containsKey(selected)) &&
            state.organization.groupOf(id) == selected;
  }
  return state.organization.matchesCategory(
    resolved,
    selected,
    seriesKey: BookDynamicCategories.seriesKey(resolved, localBooks),
  );
}

bool bookshelfMatchesSource(
  int id,
  LibraryState state,
  OfflineNovelRepository? offline, {
  String? source,
}) {
  if (!state.combinedShelf) return true;
  final local = offline?.local?.book(id) != null;
  return switch (source ?? state.shelfSourceFilter) {
    'local' => local,
    'cached' => !local && offline?.availableOffline(id) == true,
    'online' => !local && state.contains(id),
    _ => true,
  };
}

String bookshelfSourceLabel(String source) => switch (source) {
  'local' => '本地导入',
  'cached' => '已缓存',
  'online' => '在线收藏',
  _ => '全部来源',
};

String bookshelfSource(int id, OfflineNovelRepository? offline) {
  if (offline?.local?.book(id) != null) return '本地';
  return offline?.availableOffline(id) == true ? '缓存' : '在线';
}
