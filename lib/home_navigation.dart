import 'package:flutter/foundation.dart';

import 'library_state.dart';
import 'network_status.dart';

/// Retain page identities used by existing preferences and reader navigation.
class HomeNavigation extends ChangeNotifier {
  HomeNavigation(LibraryState preferences, NetworkStatus? network);

  bool get cachedShelf => true;
  bool get localReader => true;
  bool get combinedShelf => false;
  bool get readableShelfOnly => true;
  List<int> get tabs => const [1, 2, 3];

  int destination(int current) => tabs.contains(current) ? current : 2;
}
