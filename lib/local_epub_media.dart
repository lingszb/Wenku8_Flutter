import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'local_book_archive.dart';
import 'local_document_input.dart';

typedef LocalBookImageDimensions = ({int width, int height});

/// Header-only hints, never an image validator. Unusual/EXIF images retain the
/// platform codec path. PNG IHDR and JPEG SOF follow W3C PNG / ITU-T T.81.
LocalBookImageDimensions? localEpubImageHeaderDimensions(Uint8List bytes) {
  bool matches(int at, List<int> value) =>
      at + value.length <= bytes.length &&
      Iterable<int>.generate(
        value.length,
      ).every((i) => bytes[at + i] == value[i]);
  LocalBookImageDimensions? dimensions(int width, int height) =>
      width > 0 && height > 0 && width * height <= 80000000
      ? (width: width, height: height)
      : null;
  final data = ByteData.sublistView(bytes);
  if (bytes.length >= 33 &&
      matches(0, const [137, 80, 78, 71, 13, 10, 26, 10]) &&
      data.getUint32(8) == 13 &&
      matches(12, const [73, 72, 68, 82])) {
    // EXIF orientation may change the codec's display geometry.
    for (var at = 8; at + 12 <= bytes.length;) {
      final length = data.getUint32(at);
      if (length > bytes.length - at - 12) return null;
      if (matches(at + 4, const [101, 88, 73, 102])) return null;
      at += length + 12;
    }
    return dimensions(data.getUint32(16), data.getUint32(20));
  }
  if (!matches(0, const [255, 216])) return null;
  LocalBookImageDimensions? result;
  for (var at = 2; at < bytes.length;) {
    if (bytes[at++] != 255) return null;
    while (at < bytes.length && bytes[at] == 255) {
      at++;
    }
    if (at >= bytes.length) return null;
    final marker = bytes[at++];
    if (marker == 0xda || marker == 0xd9) return result;
    if (marker == 0x01 || marker >= 0xd0 && marker <= 0xd7) continue;
    if (at + 2 > bytes.length) return null;
    final length = data.getUint16(at);
    if (length < 2 || length > bytes.length - at) return null;
    if (marker == 0xe1 && matches(at + 2, const [69, 120, 105, 102, 0, 0])) {
      return null;
    }
    if (const {0xc0, 0xc1, 0xc2}.contains(marker)) {
      if (length < 8) return null;
      result = dimensions(data.getUint16(at + 5), data.getUint16(at + 3));
    }
    at += length;
  }
  return null;
}

/// One bounded worker/ZIP session measures a chapter without returning all its
/// encoded bytes to the UI isolate. The small disk cache is derived data only.
Map<String, LocalBookImageDimensions> readLocalEpubImageDimensionsFromInput(
  ({
    String directory,
    List<String> names,
    LocalDocumentInput original,
    String identity,
  })
  request,
) {
  if (request.names.length > 12000) throw const FormatException('插图数量过多');
  final indexFile = File('${request.directory}/media.json');
  if (indexFile.lengthSync() > 1024 * 1024) {
    throw const FormatException('本地插图索引过大');
  }
  final text = indexFile.readAsStringSync();
  final value = jsonDecode(text);
  if (value is! Map || value['version'] != 1 || value['entries'] is! Map) {
    throw const FormatException('本地插图索引无效');
  }
  final originalStat = request.original.path == null
      ? null
      : File(request.original.path!).statSync();
  final identity =
      '${request.identity}|${request.original.length}|${originalStat?.modified.microsecondsSinceEpoch}|${sha256.convert(utf8.encode(text))}';
  final sizes = <String, LocalBookImageDimensions>{};
  void adopt(dynamic values) {
    if (values is! Map || values.length > 12000) return;
    for (final entry in values.entries) {
      final pair = entry.value;
      if (entry.key is String &&
          pair is List &&
          pair.length == 2 &&
          pair[0] is int &&
          pair[1] is int &&
          pair[0] > 0 &&
          pair[1] > 0 &&
          pair[0] * pair[1] <= 80000000 &&
          value['entries'][entry.key] is String) {
        sizes[entry.key] = (width: pair[0], height: pair[1]);
      }
    }
  }

  if (request.identity.isNotEmpty &&
      value['dimensionSource'] == request.identity &&
      (originalStat == null ||
          value['dimensionOriginalModified'] ==
              originalStat.modified.microsecondsSinceEpoch)) {
    adopt(value['dimensions']);
  }
  final cached = File('${request.directory}/.image-dimensions.json');
  try {
    if (cached.existsSync() && cached.lengthSync() <= 1024 * 1024) {
      final stored = jsonDecode(cached.readAsStringSync());
      if (stored is Map && stored['identity'] == identity) {
        adopt(stored['dimensions']);
      }
    }
  } on FileSystemException {
    // Optional derived metadata never prevents reading the original.
  } on FormatException {
    // An incomplete/old cache is rebuilt from verified archive entries.
  }
  final missing = request.names
      .toSet()
      .where(
        (name) => !sizes.containsKey(name) && value['entries'][name] is String,
      )
      .toList();
  if (missing.isNotEmpty) {
    final buffer = request.original.open();
    try {
      final archive = value['recoverDamagedEpub'] == true
          ? readLocalBookArchiveForRecovery(
              buffer.stream,
              maxSize: 1024 * 1024 * 1024,
            ).archive
          : readLocalBookArchive(buffer.stream, maxSize: 1024 * 1024 * 1024);
      for (final name in missing) {
        final image = archive.findFile(value['entries'][name]);
        if (image == null || !image.isFile || image.size > 8 * 1024 * 1024) {
          continue;
        }
        try {
          final size = localEpubImageHeaderDimensions(
            readLocalBookArchiveEntry(image),
          );
          if (size != null) sizes[name] = size;
        } on FormatException {
          // Broken/unusual images retain the existing per-image codec/retry.
        }
      }
    } finally {
      buffer.close();
    }
    final temporary = File(
      '${cached.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.next',
    );
    try {
      final encoded = jsonEncode({
        'identity': identity,
        'dimensions': {
          for (final entry in sizes.entries)
            entry.key: [entry.value.width, entry.value.height],
        },
      });
      if (utf8.encode(encoded).length <= 1024 * 1024 &&
          indexFile.readAsStringSync() == text) {
        temporary.writeAsStringSync(encoded, flush: true);
        temporary.renameSync(cached.path);
      }
    } on FileSystemException {
      // Read-only/full storage still allows reading, without durable hints.
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
  }
  return {
    for (final name in request.names)
      if (sizes.containsKey(name)) name: sizes[name]!,
  };
}

/// A damaged/missing image does not discard the other images read under the
/// same original-file lease. Failures remain retryable by the caller.
class LocalBookImageResult {
  const LocalBookImageResult.success(this.bytes) : error = null;
  const LocalBookImageResult.failure(this.error) : bytes = null;

  final Uint8List? bytes;
  final String? error;
}

/// Runs off the UI isolate. The index points only into this book's retained
/// original, never to external paths or remote resources.
Uint8List readLocalEpubImage(({String directory, String name}) request) {
  return readLocalEpubImageFromFile((
    directory: request.directory,
    name: request.name,
    original: '${request.directory}/original',
  ));
}

Uint8List readLocalEpubImageFromFile(
  ({String directory, String name, String original}) request,
) => readLocalEpubImageFromInput((
  directory: request.directory,
  name: request.name,
  original: LocalDocumentInput.file(request.original),
));

Uint8List readLocalEpubImageFromInput(
  ({String directory, String name, LocalDocumentInput original}) request,
) {
  final result = readLocalEpubImagesFromInput((
    directory: request.directory,
    names: [request.name],
    original: request.original,
  ))[request.name]!;
  if (result.bytes case final bytes?) return bytes;
  throw FormatException(result.error ?? '原书插图无法读取');
}

/// Reads at most four cold images with one index read and archive open. Owned
/// encoded bytes leave the worker before the input mapping/lease is released.
Map<String, LocalBookImageResult> readLocalEpubImagesFromInput(
  ({String directory, List<String> names, LocalDocumentInput original}) request,
) {
  if (request.names.isEmpty) return {};
  if (request.names.length > 4) {
    throw const FormatException('本地插图批次过大');
  }
  final index = File('${request.directory}/media.json');
  if (index.lengthSync() > 1024 * 1024) {
    throw const FormatException('本地插图索引过大');
  }
  final value = jsonDecode(index.readAsStringSync());
  if (value is! Map || value['version'] != 1 || value['entries'] is! Map) {
    throw const FormatException('本地插图索引无效');
  }
  final entries = value['entries'] as Map;
  final results = <String, LocalBookImageResult>{};
  final paths = <String, String>{};
  for (final name in request.names) {
    final path = entries[name];
    if (path is String) {
      paths[name] = path;
    } else {
      results[name] = const LocalBookImageResult.failure('原书中没有这张插图');
    }
  }
  if (paths.isEmpty) return results;
  final buffer = request.original.open();
  try {
    final archive = value['recoverDamagedEpub'] == true
        ? readLocalBookArchiveForRecovery(
            buffer.stream,
            maxSize: 1024 * 1024 * 1024,
          ).archive
        : readLocalBookArchive(buffer.stream, maxSize: 1024 * 1024 * 1024);
    for (final entry in paths.entries) {
      final name = entry.key, path = entry.value;
      try {
        final image = archive.findFile(path);
        if (image == null || !image.isFile || image.size > 8 * 1024 * 1024) {
          results[name] = const LocalBookImageResult.failure('原书插图无效或超过 8 MiB');
          continue;
        }
        // Stored ZIP entries can be views into the leased mapping.
        final bytes = readLocalBookArchiveEntry(image);
        results[name] = LocalBookImageResult.success(Uint8List.fromList(bytes));
      } on ArchiveException {
        results[name] = const LocalBookImageResult.failure(
          '原书插图无法读取，请重新导入完整原书',
        );
      } on FormatException {
        results[name] = const LocalBookImageResult.failure(
          '原书插图无法读取，请重新导入完整原书',
        );
      }
    }
    return results;
  } on ArchiveException {
    throw const FormatException('原书插图无法读取，请重新导入完整原书');
  } finally {
    buffer.close();
  }
}
