import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ReadingArtwork = ({Uint8List bytes, bool fallback});

/// One optional-art decision shared by previews and image exports.
Future<ReadingArtwork> loadReadingArtwork(
  String asset, {
  AssetBundle? bundle,
}) async {
  try {
    final data = await (bundle ?? rootBundle).load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.isEmpty || bytes.length > 16 * 1024 * 1024) {
      throw const FormatException('背景图片大小无效');
    }
    // Decode a tiny sample so corrupt bytes use the same fallback everywhere.
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 4);
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    return (bytes: bytes, fallback: false);
  } catch (_) {
    return (bytes: await _paperFallback(asset), fallback: true);
  }
}

/// A deliberately simple paper landscape, not a replacement photograph.
Future<Uint8List> _paperFallback(String asset) async {
  final tint = switch (asset) {
    final value when value.contains('summer') => const Color(0xff677e89),
    final value when value.contains('autumn') => const Color(0xff9a8869),
    final value when value.contains('winter') => const Color(0xff8b989b),
    _ => const Color(0xffa4868e),
  };
  const width = 960, height = 640;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const paper = Color(0xfff2efe8);
  canvas.drawColor(paper, BlendMode.src);
  canvas.drawRect(
    const Rect.fromLTWH(0, 384, 960, 256),
    Paint()..color = tint.withValues(alpha: .12),
  );
  canvas.drawCircle(
    const Offset(width * .55, height * .34),
    53,
    Paint()..color = tint.withValues(alpha: .16),
  );
  final horizon = Path()
    ..moveTo(0, height * .72)
    ..quadraticBezierTo(width * .23, height * .53, width * .48, height * .72)
    ..quadraticBezierTo(
      width * .76,
      height * .52,
      width.toDouble(),
      height * .69,
    );
  canvas.drawPath(
    horizon,
    Paint()
      ..color = tint.withValues(alpha: .38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width, height);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const FormatException('备用背景未能生成');
      return png.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

class ReadingArtworkImage extends StatefulWidget {
  const ReadingArtworkImage({
    super.key,
    required this.asset,
    this.artwork,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
  });

  final String asset;
  final ReadingArtwork? artwork;
  final double? width, height;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;

  @override
  State<ReadingArtworkImage> createState() => _ReadingArtworkImageState();
}

class _ReadingArtworkImageState extends State<ReadingArtworkImage> {
  AssetBundle? _bundle;
  Future<ReadingArtwork>? _loading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (!identical(bundle, _bundle)) {
      _bundle = bundle;
      _load();
    }
  }

  @override
  void didUpdateWidget(ReadingArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.asset != oldWidget.asset ||
        !identical(widget.artwork, oldWidget.artwork)) {
      _load();
    }
  }

  void _load() {
    _loading = widget.artwork == null
        ? loadReadingArtwork(widget.asset, bundle: _bundle)
        : Future.value(widget.artwork!);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ReadingArtwork>(
    future: _loading,
    initialData: widget.artwork,
    builder: (context, snapshot) {
      final artwork = snapshot.data;
      if (artwork == null) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: ColoredBox(
            color: const Color(0xfff2efe8),
            child: snapshot.hasError
                ? const Icon(
                    Icons.image_not_supported_outlined,
                    semanticLabel: '背景暂不可用',
                    color: Color(0xff817c6d),
                  )
                : null,
          ),
        );
      }
      return Image.memory(
        artwork.bytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        cacheWidth: widget.cacheWidth,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.medium,
      );
    },
  );
}
