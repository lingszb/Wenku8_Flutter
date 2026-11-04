import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Flat page projection used when the original curved-sheet solver is absent.
/// Keeps the existing snapshot painter and page ownership contract intact.
class ReaderPaperGeometry {
  ReaderPaperGeometry({
    required this.size,
    required this.gap,
    required double progress,
    required double touchY,
  }) {
    final angle = progress.clamp(0.0, 1.0) * math.pi;
    final projection = math.cos(angle);
    lift = math.sin(angle).clamp(0.0, 1.0);
    front = ReaderPaperMesh(
      size,
      math.max(0.0, projection) * size.width,
      projection.abs(),
    );
    back = ReaderPaperMesh(
      size,
      math.min(0.0, projection) * size.width,
      projection.abs(),
    );
    frontInk = front;
    backInk = back;
    sheet = Path()
      ..addPath(front.outline, Offset.zero)
      ..addPath(back.outline, Offset.zero);
  }
  final Size size;
  final double gap;
  late final double lift;
  late final ReaderPaperMesh front, back, frontInk, backInk;
  late final Path sheet;
}

class ReaderPaperMesh {
  ReaderPaperMesh(Size size, double projectedWidth, double normal)
    : positions = Float32List.fromList([
        0,
        0,
        projectedWidth,
        0,
        projectedWidth,
        size.height,
        0,
        size.height,
      ]),
      uv = Float32List.fromList([
        0,
        0,
        size.width,
        0,
        size.width,
        size.height,
        0,
        size.height,
      ]),
      normals = List<double>.filled(4, normal),
      indices = Uint16List.fromList([0, 1, 2, 0, 2, 3]),
      outline = (Path()
        ..addRect(
          Rect.fromLTRB(
            math.min(0.0, projectedWidth),
            0,
            math.max(0.0, projectedWidth),
            size.height,
          ),
        ));
  final Float32List positions, uv;
  final List<double> normals;
  final Uint16List indices;
  final Path outline;
}
