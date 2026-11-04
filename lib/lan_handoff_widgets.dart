// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/material.dart';

import 'catalog.dart';
import 'lan_reading_sync.dart';
import 'library_state.dart';

/// A small placeholder for the handoff notice used by the shared shell.
class LanHandoffNotice extends StatelessWidget {
  const LanHandoffNotice({super.key, required this.receipt, this.onContinue});
  final LanHandoffReceipt receipt;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The mobile app offers to send the current book to another device. Desktop
/// keeps the entry point invisible (the LAN scope is null), so this sheet is a
/// compile-compatible stub.
class LanSendBookSheet extends StatelessWidget {
  const LanSendBookSheet({
    super.key,
    required this.sync,
    required this.book,
    required this.position,
    required this.reduceMotion,
  });

  final LanReadingSync sync;
  final Novel book;
  final ReadingPosition position;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Desktop has no repository dependency here; the original page used it to
/// resolve nearby books.
typedef LanReadingRepository = NovelRepository;
