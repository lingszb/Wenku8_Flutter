import 'package:flutter/foundation.dart';
import 'online_component.dart';

class WenkuProfile {
  const WenkuProfile({
    required this.id,
    required this.username,
    required this.nickname,
    required this.score,
    required this.experience,
    required this.rank,
  });
  final int id, score, experience;
  final String username, nickname, rank;
  String get displayName => nickname.isEmpty ? username : nickname;
}

/// Domain-facing account state for presentation and local-library integration.
/// No requests, response parsers, service status codes or session material live here.
class WenkuAccount extends ChangeNotifier {
  WenkuAccount();
  Uint8List? avatar;
  bool authenticated = false, busy = false, signedToday = false;
  String? operation, error;
  WenkuProfile? profile;
  int get sessionRevision => 0;
  static String describeError(Object error) =>
      error is OnlineComponentUnavailable ||
          error is OnlineAuthenticationRequired
      ? error.toString()
      : error is FormatException
      ? error.message.toString()
      : '网络或本地存储暂时异常，请重试';
  Future<void> initialize() async {}
  Future<T> _unavailable<T>() async {
    error = OnlineComponentUnavailable.message;
    notifyListeners();
    throw const OnlineComponentUnavailable();
  }

  Future<void> login(String username, String password) => _unavailable();
  Future<void> refreshProfile() => _unavailable();
  Future<void> signIn() => _unavailable();
  Future<void> recommend(int id) => _unavailable();
  Future<void> postReview({
    required int bookId,
    required String title,
    required String content,
  }) => _unavailable();
  Future<void> replyReview({required int threadId, required String content}) =>
      _unavailable();
  Future<void> logout() async {
    authenticated = false;
    profile = null;
    avatar = null;
    signedToday = false;
    error = null;
    notifyListeners();
  }
}
