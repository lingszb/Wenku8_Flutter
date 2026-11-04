// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/foundation.dart';

enum ListeningEnhancementMode { none, clarity, warm }

@immutable
class ListeningEnhancementPreference {
  const ListeningEnhancementPreference({
    this.mode = ListeningEnhancementMode.none,
    this.gain = 0,
  });

  final ListeningEnhancementMode mode;
  final int gain;

  Map<String, Object?> toJson() => {'mode': mode.name, 'gain': gain};

  factory ListeningEnhancementPreference.fromJson(
    Map<dynamic, dynamic> value,
  ) => ListeningEnhancementPreference(
    mode: switch (value['mode']) {
      'clarity' => ListeningEnhancementMode.clarity,
      'warm' => ListeningEnhancementMode.warm,
      _ => ListeningEnhancementMode.none,
    },
    gain: value['gain'] is int ? value['gain'] as int : 0,
  );
}

/// Desktop audio is intentionally disabled in this build, so enhancement is a
/// recorded preference only. The API mirrors the mobile controller contract.
class ListeningEnhancement {
  ListeningEnhancement({ListeningEnhancementPreference? preference})
    : _preference = const ListeningEnhancementPreference();

  ListeningEnhancementPreference _preference;
  ListeningEnhancementPreference get preference => _preference;

  Future<void> configure(
    ListeningEnhancementPreference value, {
    int? audioSessionId,
  }) async {
    _preference = const ListeningEnhancementPreference();
  }

  Future<void> setPreference(ListeningEnhancementPreference value) async {
    _preference = const ListeningEnhancementPreference();
  }

  Future<void> dispose() async {}
}
