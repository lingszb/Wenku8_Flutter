import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'book_search.dart';
import 'offline_cache.dart';
import 'local_books.dart';
import 'network_status.dart';
import 'ui_notifiers.dart';
import 'tag_catalogue.dart';

/// Reads imported books and previously stored chapters without website access.
class OfflineNovelRepository extends FrameChangeNotifier
    implements NovelRepository, ProgressiveTagCatalogue {
  OfflineNovelRepository({required this.cache, this.local, this.network}) {
    cache.addListener(_cacheChanged);
    local?.addListener(_cacheChanged);
  }

  final OfflineCacheStore cache;
  final LocalBookStore? local;
  final NetworkStatus? network;
  bool get offline => network?.offline ?? false;
  bool availableOffline(int id) =>
      local?.book(id) != null || (cache.book(id)?.cachedCount ?? 0) > 0;
  final Set<int> _offlineDirectories = {};
  final Map<int, FrameChangeNotifier> _bookChanges = {};
  final Map<int, Listenable> _bookObservers = {};
  bool _disposed = false;
  Object? cacheError;

  bool isDirectoryOffline(int id) => _offlineDirectories.contains(id);
  Listenable bookChanges(int id) => _bookObservers.putIfAbsent(
    id,
    () => Listenable.merge([
      _bookChanges.putIfAbsent(id, FrameChangeNotifier.new),
      cache.bookChanges(id),
    ]),
  );

  Future<void> loadCache() async {
    try {
      await cache.load();
      cacheError = null;
      _changed();
    } catch (error) {
      cacheError = error;
      _changed();
      rethrow;
    }
  }

  void _cacheChanged() {
    if (!_disposed) notifyListeners();
  }

  void _changed([int? id]) {
    if (_disposed) return;
    if (id == null) {
      for (final observer in _bookChanges.values) {
        observer.notifyListeners();
      }
    } else {
      _bookChanges[id]?.notifyListeners();
    }
    notifyListeners();
  }

  @override
  Future<List<Novel>> list() async {
    await cache.load();
    return <int, Novel>{
      for (final entry in cache.books)
        if (entry.cachedCount > 0) entry.novel.id: entry.novel,
      for (final book in local?.books ?? const <Novel>[]) book.id: book,
    }.values.toList();
  }

  @override
  Future<List<Novel>> search(String query) async {
    final pattern = BookSearch(query);
    return (await list())
        .where(
          (book) => pattern.matches(
            title: book.title,
            author: book.author,
            tags: book.genre,
            summary: book.summary,
            id: '${book.id}',
          ),
        )
        .toList();
  }

  @override
  Future<NovelPage> browse({
    NovelSort sort = NovelSort.lastUpdate,
    int page = 1,
    bool refresh = false,
  }) async {
    final books = await list();
    return NovelPage.fromItems(
      sort == NovelSort.fullFlag
          ? books.where((book) => book.isComplete).toList()
          : books,
      page,
    );
  }

  @override
  Future<NovelPage> searchPage(
    String query, {
    int page = 1,
    bool refresh = false,
  }) => searchFilteredPage(query, page: page, refresh: refresh);

  @override
  Future<NovelPage> searchFilteredPage(
    String query, {
    BookSearchField field = BookSearchField.all,
    int page = 1,
    bool refresh = false,
  }) async {
    final pattern = BookSearch(query, field: field);
    final books = await list();
    return NovelPage.fromItems(
      books
          .where(
            (book) => pattern.matches(
              title: book.title,
              author: book.author,
              tags: book.genre,
              summary: book.summary,
              id: '${book.id}',
            ),
          )
          .toList(),
      page,
    );
  }

  @override
  Future<NovelPage> tagPage(
    String tag, {
    int page = 1,
    bool refresh = false,
    bool Function()? current,
    void Function(TagSearchProgress)? onProgress,
  }) {
    return searchFilteredPage(
      tag,
      field: BookSearchField.tags,
      page: page,
      refresh: refresh,
    );
  }

  @override
  Future<NovelPage> authorPage(
    String author, {
    int page = 1,
    bool refresh = false,
  }) async {
    final books = await list();
    return NovelPage.fromItems(
      books.where((book) => sameNovelAuthor(book.author, author)).toList(),
      page,
    );
  }

  Future<Novel?> cachedBook(int id) async {
    if (isLocalBook(id)) return local?.book(id);
    await cache.load();
    return cache.book(id)?.novel ?? await cache.readBook(id);
  }

  @override
  Future<Novel?> find(int id) => cachedBook(id);

  @override
  Future<Novel> detail(Novel novel) async {
    if (isLocalBook(novel.id)) {
      if (local == null || !local!.contains(novel.id)) {
        throw const FormatException('本地原书不存在，请重新导入');
      }
      try {
        return await local!.ensureNavigation(novel.id);
      } catch (error) {
        // Failure to enrich an old TOC does not revoke access to its existing
        // readable chapters, especially when its original was moved/deleted.
        return local!.book(novel.id)!;
      }
    }
    return await cachedBook(novel.id) ??
        (throw const FormatException('本书没有本地缓存，请导入本地文件'));
  }

  @override
  Future<List<NovelChapter>> chapters(int id) async {
    if (isLocalBook(id)) {
      return local?.book(id)?.chapters ??
          (throw const FormatException('本地原书不存在，请重新导入'));
    }
    final saved = await cachedBook(id);
    if (saved == null || saved.chapters.isEmpty) {
      throw const FormatException('本书目录未保存在本地，请导入本地文件');
    }
    _offlineDirectories.add(id);
    return saved.chapters;
  }

  @override
  Future<String> chapterContent(int novelId, NovelChapter chapter) async {
    if (isLocalBook(novelId)) return _localContent(novelId, chapter);
    // Keep source-owned inline chapters usable for demo and legacy snapshots.
    if (chapter.id <= 0 && chapter.content.trim().isNotEmpty) {
      return chapter.content;
    }
    final saved = await cache.readChapter(novelId, chapter.id);
    if (saved != null) return saved;
    throw const FormatException('这一章没有本地缓存，请导入本地文件');
  }

  Future<void> removeCachedBook(int id) async {
    await cache.removeBook(id);
    _offlineDirectories.remove(id);
    cacheError = null;
    _changed(id);
  }

  Future<void> clearCache() async {
    await cache.clear();
    _offlineDirectories.clear();
    cacheError = null;
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    cache.removeListener(_cacheChanged);
    local?.removeListener(_cacheChanged);
    for (final observer in _bookChanges.values) {
      observer.dispose();
    }
    super.dispose();
  }

  Future<String> _localContent(int id, NovelChapter chapter) async {
    if (local == null) throw const FormatException('本地书库未就绪');
    return local!.chapterContent(id, chapter);
  }
}
