// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'library_state.dart';
import 'local_books.dart';

/// LAN reading is a mobile-only capability in this source snapshot.
///
/// The desktop build keeps the same public surface so shared widgets compile,
/// but the scope stays null and no sockets are opened.
class LanReadingSync {
  LanReadingSync({
    required this.state,
    required this.preferences,
    required this.books,
    required this.repository,
  });

  final LibraryState state;
  final SharedPreferences preferences;
  final LocalBookStore? books;
  final NovelRepository repository;
  final _handoff = LanHandoff();

  LanHandoff get handoff => _handoff;

  Future<void> initialize() async {}

  void dispose() {}
}

class LanHandoff {
  LanHandoffReceipt? get received => null;

  Future<({Novel book, ReadingPosition position})> resolveReceipt(
    LanHandoffReceipt receipt,
  ) async {
    throw const FormatException('当前源码版本不支持局域网续读');
  }

  void dismissReceipt() {}
}

class LanHandoffReceipt {
  const LanHandoffReceipt({this.online, this.title = '', this.author = ''});
  final String? online;
  final String title, author;
}

class LanSyncScope extends InheritedWidget {
  const LanSyncScope({super.key, required this.sync, required super.child});

  final LanReadingSync? sync;

  static LanReadingSync? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanSyncScope>()?.sync;

  static LanReadingSync of(BuildContext context) {
    final value = maybeOf(context);
    assert(value != null, 'LanSyncScope is not available');
    return value!;
  }

  @override
  bool updateShouldNotify(LanSyncScope oldWidget) => oldWidget.sync != sync;
}

class LanHandoffMonitor extends StatelessWidget {
  const LanHandoffMonitor({
    super.key,
    required this.handoff,
    required this.onContinue,
    required this.reduceMotion,
    required this.noticeWrapper,
    required this.child,
  });

  final LanHandoff? handoff;
  final Future<void> Function(LanHandoffReceipt receipt) onContinue;
  final bool reduceMotion;
  final Widget Function(Widget notice) noticeWrapper;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
