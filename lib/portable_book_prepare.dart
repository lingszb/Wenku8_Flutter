import 'dart:io';

typedef PreparedBookDocument = ({String name, String? path, String? error});

/// Uses the host converter already supplied by BookDocuments. It never opens
/// arbitrary external paths or replaces the Android import policy.
class PortableBookPreparer {
  PortableBookPreparer({
    required this.directory,
    this.textCodecToken,
    this.decodeNames,
    this.convert,
    this.extractKindle,
    this.extractPdf,
  });
  final Directory directory;
  final Object? textCodecToken;
  final Future<List<String>> Function(List<String>)? decodeNames;
  final Future<List<PreparedBookDocument>> Function(String, String)? convert;
  final Future<int> Function(String, String)? extractKindle;
  final Future<void> Function(String, String, String)? extractPdf;

  static Future<void> clearPreviousRuns(Directory directory) async {
    // Retain existing files rather than deleting an injected directory.
    await directory.create(recursive: true);
  }

  Future<List<PreparedBookDocument>> prepare(String name, String path) async {
    if (convert case final converter?) return converter(name, path);
    return [(name: name, path: null, error: '当前平台暂不支持此格式转换')];
  }

  Future<void> releasePaths(Iterable<String> paths) async {
    // Host-owned conversions are released by BookDocuments.releaseBooks.
    // This adapter creates no files of its own and must not delete source books.
  }
}
