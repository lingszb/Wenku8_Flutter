import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'reader_tap_surface.dart';
import 'reader_underline.dart';
import 'reader_landing_highlight.dart';

/// Keeps saved colors recognizable on both custom light and night paper.
Color readerMarkInk(
  ReaderMarkColor color,
  Color foreground, {
  bool dark = false,
}) {
  final value = color.argb;
  if (value == null) return foreground;
  final ink = Color(value);
  return dark ? Color.lerp(ink, Colors.white, .2)! : ink;
}

/// Saved marks are paint-only and never alter text shaping or line breaks.
Color readerMarkTint(
  ReaderMarkColor color,
  Color foreground, {
  bool dark = false,
}) => readerMarkInk(
  color,
  foreground,
  dark: dark,
).withValues(alpha: dark ? .28 : .22);

/// Uses the already laid-out paragraph for outlines; it never shapes text twice.
class ReaderAnnotationOutlines extends SingleChildRenderObjectWidget {
  const ReaderAnnotationOutlines({
    super.key,
    required this.marks,
    required this.foreground,
    required this.dark,
    this.prefix = 0,
    required super.child,
  });
  final List<ReaderTextMark> marks;
  final Color foreground;
  final bool dark;
  final int prefix;

  @override
  RenderReaderAnnotationOutlines createRenderObject(BuildContext context) =>
      RenderReaderAnnotationOutlines(marks, foreground, dark, prefix);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderReaderAnnotationOutlines renderObject,
  ) => renderObject.update(marks, foreground, dark, prefix);
}

/// Paint-only source ranges share the bookmark landing frame and its outsets.
class RenderReaderAnnotationOutlines extends RenderProxyBox {
  RenderReaderAnnotationOutlines(
    this._marks,
    this._foreground,
    this._dark,
    this._prefix,
  );
  List<ReaderTextMark> _marks;
  Color _foreground;
  bool _dark;
  int _prefix;
  void update(
    List<ReaderTextMark> marks,
    Color foreground,
    bool dark,
    int prefix,
  ) {
    _marks = marks;
    _foreground = foreground;
    _dark = dark;
    _prefix = prefix;
    markNeedsPaint();
  }

  RenderParagraph? get _paragraph {
    RenderParagraph? found;
    void visit(RenderObject object) {
      if (found != null) return;
      if (object is RenderParagraph) {
        found = object;
        return;
      }
      object.visitChildren(visit);
    }

    visit(this);
    return found;
  }

  /// Actual render geometry is also useful when verifying paginated slices.
  List<({Rect rect, ReaderMarkColor color})> get outlineBounds {
    final paragraph = _paragraph;
    if (paragraph == null || !paragraph.hasSize) return const [];
    final transform = paragraph.getTransformTo(this);
    return [
      for (final mark in _marks)
        if (mark.style == ReaderMarkStyle.outline && mark.end > mark.start)
          ...() {
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: mark.start + _prefix,
                extentOffset: mark.end + _prefix,
              ),
            );
            if (boxes.isEmpty) return <({Rect rect, ReaderMarkColor color})>[];
            var bounds = boxes.first.toRect();
            for (final box in boxes.skip(1)) {
              bounds = bounds.expandToInclude(box.toRect());
            }
            return [
              (
                rect: readerRegistrationBounds(
                  MatrixUtils.transformRect(transform, bounds),
                ),
                color: mark.color,
              ),
            ];
          }(),
    ];
  }

  @override
  Rect get paintBounds => super.paintBounds.inflate(8);

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // Indexed marks are newest first; paint their rules last at intersections.
    for (final outline in outlineBounds.reversed) {
      paintReaderRegistrationFrame(
        context.canvas,
        outline.rect.shift(offset),
        ink: readerMarkInk(
          outline.color,
          _foreground,
          dark: _dark,
        ).withValues(alpha: _dark ? .65 : .42),
      );
    }
  }
}

/// Paints a small bookmark badge after each annotated range, like the "注"
/// marker of a printed edition. It is a paint-only overlay: shaping, selection
/// offsets and line breaks stay untouched, and only the badge claims its tap.
class ReaderAnnotationNotes extends SingleChildRenderObjectWidget {
  const ReaderAnnotationNotes({
    super.key,
    required this.marks,
    required this.foreground,
    required this.dark,
    required this.prefix,
    required this.scaler,
    required this.onTap,
    required super.child,
  });
  final List<ReaderTextMark> marks;
  final Color foreground;
  final bool dark;
  final int prefix;
  final TextScaler scaler;
  final ValueChanged<String> onTap;

  @override
  RenderReaderAnnotationNotes createRenderObject(BuildContext context) =>
      RenderReaderAnnotationNotes(this);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderReaderAnnotationNotes renderObject,
  ) => renderObject.update(this);
}

class RenderReaderAnnotationNotes extends RenderProxyBox
    implements ReaderTapPreviewPolicy {
  RenderReaderAnnotationNotes(this._config) {
    _tap.onTap = () {
      final id = _pressed;
      if (id != null) _config.onTap(id);
    };
  }
  ReaderAnnotationNotes _config;
  final _tap = TapGestureRecognizer();
  final _badges = <({Rect rect, String id})>[];
  String? _pressed;

  void update(ReaderAnnotationNotes value) {
    final changed =
        !listEquals(value.marks, _config.marks) ||
        value.foreground != _config.foreground ||
        value.dark != _config.dark ||
        value.prefix != _config.prefix ||
        value.scaler != _config.scaler;
    _config = value;
    if (changed) markNeedsLayout();
  }

  RenderParagraph? get _paragraph {
    RenderParagraph? found;
    void visit(RenderObject object) {
      if (found != null) return;
      if (object is RenderParagraph) {
        found = object;
        return;
      }
      object.visitChildren(visit);
    }

    visit(this);
    return found;
  }

  @override
  void performLayout() {
    super.performLayout();
    _badges.clear();
    final paragraph = _paragraph;
    if (paragraph == null || !paragraph.hasSize) return;
    final font = paragraph.text.style?.fontSize ?? 19;
    final size = (_config.scaler.scale(font) * .66).clamp(10.0, 16.0);
    final origin = paragraph.localToGlobal(Offset.zero, ancestor: this);
    for (final mark in _config.marks) {
      if (mark.noteId.isEmpty || mark.end <= mark.start) continue;
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: mark.end - 1 + _config.prefix,
          extentOffset: mark.end + _config.prefix,
        ),
      );
      if (boxes.isEmpty) continue;
      final box = boxes.last.toRect().shift(origin);
      _badges.add((
        rect: Rect.fromLTWH(
          box.right - size * .34,
          box.top + box.height * .05,
          size,
          size,
        ),
        id: mark.noteId,
      ));
    }
  }

  @override
  Rect get paintBounds => super.paintBounds.inflate(12);

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final canvas = context.canvas;
    final ink = _config.foreground;
    final background = Paint()
      ..color = ink.withValues(alpha: _config.dark ? .30 : .16);
    final glyph = Paint()..color = ink.withValues(alpha: .94);
    for (final badge in _badges) {
      final rect = badge.rect.shift(offset);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.width * .28)),
        background,
      );
      final inset = rect.width * .27;
      final left = rect.left + inset;
      final right = rect.right - inset;
      final top = rect.top + inset * .8;
      final bottom = rect.bottom - inset * 1.05;
      final notch = (bottom - top) * .30;
      canvas.drawPath(
        Path()
          ..moveTo(left, top)
          ..lineTo(right, top)
          ..lineTo(right, bottom)
          ..lineTo(rect.center.dx, bottom - notch)
          ..lineTo(left, bottom)
          ..close(),
        glyph,
      );
    }
  }

  @visibleForTesting
  List<Rect> get debugNoteBadges => [for (final badge in _badges) badge.rect];

  bool _hits(Offset position) =>
      _badges.any((badge) => badge.rect.inflate(6).contains(position));

  @override
  bool hitTestSelf(Offset position) => _hits(position);

  @override
  bool allowsReaderTapPreview(Offset localPosition) => !_hits(localPosition);

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      final badge = _badges
          .where((value) => value.rect.inflate(6).contains(event.localPosition))
          .firstOrNull;
      if (badge != null) {
        _pressed = badge.id;
        _tap.addPointer(event);
      }
    }
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }
}
