import 'local_books.dart';
import 'network_status.dart';
import 'offline_cache.dart';
import 'offline_repository.dart';

/// Persistence belongs to the app, not to the Android transport. Every host
/// opens the same local library and reading-position contracts.
Future<OfflineNovelRepository> openApplicationLibrary({
  NetworkStatus? network,
}) async => OfflineNovelRepository(
  cache: await OfflineCacheStore.forApp(),
  local: await LocalBookStore.forApp(),
  network: network,
);
