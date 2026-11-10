import 'package:flutter/foundation.dart';

import 'library_state.dart';
import 'network_status.dart';

/// Retain page identities used by existing preferences and reader navigation.
class HomeNavigation extends ChangeNotifier {
  HomeNavigation(this.preferences, NetworkStatus? network) {
    preferences.navigationChanges.addListener(notifyListeners);
  }
  final LibraryState preferences;

  bool get cachedShelf => true;
  bool get localReader => true;
  bool get combinedShelf => false;
  bool get readableShelfOnly => true;
  List<int> get tabs => preferences.homeTabOrder
      .map((page) => page.index)
      .toList(growable: false);

  @override
  void dispose() {
    preferences.navigationChanges.removeListener(notifyListeners);
    super.dispose();
  }

  int destination(int current) => tabs.contains(current) ? current : 1;
}
