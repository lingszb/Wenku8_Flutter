// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'reading_widget_reference.dart';
import 'reading_widget_snapshot.dart';

/// Produces every PNG the native host may request for the reference face.
///
/// Desktop never publishes widgets, but the controller is shared and must keep
/// type-checking; rendering is cheap enough to reuse the same painter.
Future<Map<String, Uint8List>> renderReadingDesktopCards(
  ReadingWidgetSnapshot snapshot,
) async {
  final images = <String, Uint8List>{};
  for (final brightness in Brightness.values) {
    for (final size in ReadingDesktopSize.values) {
      images['${size.name}_${brightness.name}'] =
          await renderReadingDesktopCard(
            snapshot,
            size,
            brightness: brightness,
          );
    }
  }
  return images;
}
