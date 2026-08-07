import 'dart:typed_data';
import 'dart:ui';

import 'package:dropwell/src/dropwell_drag_event.dart';
import 'package:dropwell/src/dropwell_file.dart';

/// Implemented by a platform that the conformance suite drives in Dart.
///
/// Every platform with a native half is driven through the `dropwell/testing`
/// method channel. The browser has no native half, so it implements the same
/// operations here instead. The conformance suite calls the same
/// `DropwellTesting` API either way and never learns which it got, which is
/// what keeps one suite honest across six platforms.
abstract interface class DropwellTestingSupport {
  /// Replaces the system clipboard with [files].
  Future<void> setSystemClipboard(
    List<DropwellFile> files, {
    required bool asBitmap,
  });

  /// Empties the system clipboard.
  Future<void> clearSystemClipboard();

  /// Delivers [phase] to this platform's own drop entry point.
  Future<void> synthesizeDrag({
    required DropwellDragPhase phase,
    required Offset physicalPosition,
    required List<DropwellFile> files,
  });

  /// Reads a file this platform reported by path.
  Future<Uint8List> readFile(String path);
}
