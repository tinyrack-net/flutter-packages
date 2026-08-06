import 'dart:typed_data';

import 'package:meta/meta.dart';

/// One file handed over by the operating system through a drop or the
/// clipboard.
///
/// Exactly one of [path] and [bytes] is set. A platform that can name a real
/// file on disk reports [path] so a consumer can stream it without buffering;
/// a platform that only owns the payload in memory, such as a pasted bitmap or
/// a browser `File`, reports [bytes].
@immutable
final class DropwellFile {
  /// Creates a file backed by an on-disk [path].
  const DropwellFile.path({
    required this.fileName,
    required String this.path,
    this.mimeType,
  }) : bytes = null;

  /// Creates a file backed by in-memory [bytes].
  const DropwellFile.bytes({
    required this.fileName,
    required Uint8List this.bytes,
    this.mimeType,
  }) : path = null;

  /// Display-only base name, never a directory component.
  final String fileName;

  /// Media type the platform reported, or `null` when it did not report one.
  ///
  /// A consumer that needs a value for every file infers one from [fileName].
  /// This package does not guess, because a wrong guess is indistinguishable
  /// from a platform answer.
  final String? mimeType;

  /// Absolute path to the file, or `null` when the payload is in memory.
  final String? path;

  /// Complete payload, or `null` when the file lives at [path].
  final Uint8List? bytes;

  @override
  String toString() =>
      'DropwellFile($fileName, mimeType: $mimeType, '
      '${path != null ? 'path: $path' : 'bytes: ${bytes!.length}'})';
}
