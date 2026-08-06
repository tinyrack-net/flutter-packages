import 'dart:typed_data';
import 'dart:ui';

import 'package:dropwell/src/dropwell_drag_event.dart';
import 'package:dropwell/src/dropwell_file.dart';

/// Translates between platform-channel payloads and typed Dart values.
///
/// Every function here is pure so the wire contract can be tested without a
/// binary messenger, an engine, or an operating system. Platform code and
/// these functions are the only places that know the payload shape.
abstract final class DropwellCodec {
  /// Decodes a list of file maps sent by platform code.
  ///
  /// Throws a [FormatException] describing the offending entry rather than
  /// dropping it. A platform that sends a payload this package cannot read is
  /// a bug in that platform, and silently returning fewer files than the user
  /// dropped is the worst possible way to report it.
  static List<DropwellFile> decodeFiles(Object? payload) {
    if (payload == null) return const <DropwellFile>[];
    if (payload is! List) {
      throw FormatException('files payload must be a list', payload);
    }
    return List<DropwellFile>.unmodifiable(payload.map(decodeFile));
  }

  /// Decodes one file map sent by platform code.
  static DropwellFile decodeFile(Object? payload) {
    if (payload is! Map) {
      throw FormatException('file payload must be a map', payload);
    }
    final fileName = payload['fileName'];
    if (fileName is! String || fileName.isEmpty) {
      throw FormatException('file payload needs a non-empty fileName', payload);
    }
    final mimeType = payload['mimeType'];
    if (mimeType != null && mimeType is! String) {
      throw FormatException('mimeType must be a string when present', payload);
    }
    final path = payload['path'];
    final bytes = payload['bytes'];
    if (path is String && bytes == null) {
      return DropwellFile.path(
        fileName: fileName,
        path: path,
        mimeType: mimeType as String?,
      );
    }
    if (bytes is Uint8List && path == null) {
      return DropwellFile.bytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType as String?,
      );
    }
    throw FormatException(
      'file payload needs exactly one of a String path or Uint8List bytes',
      payload,
    );
  }

  /// Encodes one file for platform code, used by the Debug testing hook.
  static Map<String, Object?> encodeFile(DropwellFile file) =>
      <String, Object?>{
        'fileName': file.fileName,
        'mimeType': file.mimeType,
        if (file.path != null) 'path': file.path,
        if (file.bytes != null) 'bytes': file.bytes,
      };

  /// Decodes a drag notification sent by platform code.
  static DropwellDragEvent decodeDragEvent(Object? payload) {
    if (payload is! Map) {
      throw FormatException('drag payload must be a map', payload);
    }
    final phaseName = payload['phase'];
    final phase = DropwellDragPhase.values
        .where((value) => value.name == phaseName)
        .firstOrNull;
    if (phase == null) {
      throw FormatException('unknown drag phase $phaseName', payload);
    }
    final files = DropwellCodec.decodeFiles(payload['files']);
    if (phase != DropwellDragPhase.perform && files.isNotEmpty) {
      throw FormatException('only a perform phase carries files', payload);
    }
    return DropwellDragEvent(
      phase: phase,
      physicalPosition: _decodeOffset(payload, phase),
      files: files,
    );
  }

  /// Encodes drop regions as a flat physical-pixel `[l, t, r, b, …]` list.
  ///
  /// Flat doubles keep the payload inside the standard codec's fast path and
  /// keep every platform's parsing loop trivial; this list is republished
  /// on layout changes, so it is the one message that must stay cheap.
  static List<double> encodeRegions(List<Rect> regions) =>
      List<double>.unmodifiable(
        regions.expand(
          (rect) => <double>[rect.left, rect.top, rect.right, rect.bottom],
        ),
      );

  static Offset _decodeOffset(
    Map<Object?, Object?> payload,
    DropwellDragPhase phase,
  ) {
    if (phase == DropwellDragPhase.leave) return Offset.zero;
    final x = payload['x'];
    final y = payload['y'];
    if (x is! double || y is! double) {
      throw FormatException('drag payload needs double x and y', payload);
    }
    return Offset(x, y);
  }
}
