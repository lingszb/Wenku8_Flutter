import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'novel_feed_controller.dart';
import 'tag_catalogue.dart';

/// One discovery region owns one ranking or tag query and cursor.
class DiscoveryShelfQuery {
  const DiscoveryShelfQuery.defaults()
    : sort = NovelSort.lastUpdate,
      tags = const [];

  factory DiscoveryShelfQuery({
    NovelSort sort = NovelSort.lastUpdate,
    Iterable<String> tags = const [],
  }) => DiscoveryShelfQuery._(
    sort,
    List.unmodifiable(tagSearchTerms(tags.join(' '))),
  );

  const DiscoveryShelfQuery._(this.sort, this.tags);

  factory DiscoveryShelfQuery.fromFeed(NovelFeedController feed) =>
      DiscoveryShelfQuery(sort: feed.sort, tags: feed.tags);

  final NovelSort sort;
  final List<String> tags;

  String get label => tags.isEmpty ? sort.label : tags.join(' · ');

  DiscoveryShelfQuery withSort(NovelSort value) =>
      DiscoveryShelfQuery(sort: value);

  DiscoveryShelfQuery withTags(Iterable<String> values) =>
      DiscoveryShelfQuery(sort: sort, tags: values);

  Map<String, Object> toJson() => {
    'version': 1,
    'sort': sort.name,
    'tags': tags,
  };

  String get record => jsonEncode(toJson());

  static DiscoveryShelfQuery? tryParse(Object? value) {
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    if (value is! Map || value['version'] != 1 || value['tags'] is! List) {
      return null;
    }
    final rawTags = value['tags'] as List;
    if (rawTags.any((tag) => tag is! String)) return null;
    final sortName = value['sort'];
    final sort = NovelSort.values
        .where((item) => item.name == sortName)
        .firstOrNull;
    if (sort == null) return null;
    if (value['publication'] != null) return null;
    return DiscoveryShelfQuery(sort: sort, tags: rawTags.cast<String>());
  }

  static DiscoveryShelfQuery parseOrDefault(Object? value) =>
      tryParse(value) ?? const DiscoveryShelfQuery.defaults();

  /// Restoring the default ranking still needs an initial request: the feed's
  /// selectSort intentionally does nothing when that ranking is already selected.
  Future<void> applyTo(NovelFeedController feed) async {
    if (tags.isNotEmpty) {
      await feed.selectTags(tags);
    } else {
      await feed.selectSort(sort);
    }
    if (!feed.hasLoaded && !feed.loading && feed.error == null) {
      await feed.loadInitial();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveryShelfQuery &&
      sort == other.sort &&
      listEquals(tags, other.tags);

  @override
  int get hashCode => Object.hash(sort, Object.hashAll(tags));
}
