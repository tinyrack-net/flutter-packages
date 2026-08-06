/// Debug-only hooks that let the conformance suite drive real platform code.
///
/// The suite has to put a payload on the real system clipboard and start a
/// real drag session; nothing else proves a platform works. Those two actions
/// are the only things this library exposes, and platform code registers the
/// channel behind them **only in Debug builds** so a release binary cannot be
/// driven from outside.
library;

import 'package:dropwell/src/dropwell_codec.dart';
import 'package:dropwell/src/dropwell_drag_event.dart';
import 'package:dropwell/src/dropwell_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Channel shared with the Debug-only half of every platform implementation.
const MethodChannel kDropwellTestingChannel = MethodChannel('dropwell/testing');

/// Drives real platform code from the conformance suite.
abstract final class DropwellTesting {
  /// Replaces the system clipboard with [files].
  ///
  /// A file carrying a path is offered to the operating system as a file
  /// reference; a file carrying bytes is offered as raw data of its declared
  /// media type, which is how a pasted screenshot arrives in practice.
  static Future<void> setSystemClipboard(List<DropwellFile> files) async {
    _assertDebug();
    await kDropwellTestingChannel.invokeMethod<void>(
      'setSystemClipboard',
      files.map(DropwellCodec.encodeFile).toList(growable: false),
    );
  }

  /// Empties the system clipboard.
  static Future<void> clearSystemClipboard() async {
    _assertDebug();
    await kDropwellTestingChannel.invokeMethod<void>('clearSystemClipboard');
  }

  /// Delivers [phase] to the platform's own drop entry point.
  ///
  /// This calls the operating system callback the plugin registered — not a
  /// Dart shortcut around it — so the payload travels the same code path a
  /// user's drag would. Synthesizing at that boundary keeps the suite
  /// deterministic on headless runners, where no real pointer exists.
  static Future<void> synthesizeDrag({
    required DropwellDragPhase phase,
    Offset physicalPosition = Offset.zero,
    List<DropwellFile> files = const <DropwellFile>[],
  }) async {
    _assertDebug();
    await kDropwellTestingChannel.invokeMethod<void>(
      'synthesizeDrag',
      <String, Object?>{
        'phase': phase.name,
        'x': physicalPosition.dx,
        'y': physicalPosition.dy,
        'files': files.map(DropwellCodec.encodeFile).toList(growable: false),
      },
    );
  }

  /// Reads a file the platform reported by path.
  ///
  /// The suite has to verify that a reported path really holds the payload,
  /// and it cannot use `dart:io` to do so without losing the web. Platform
  /// code reads the file instead, which also proves the path it handed out is
  /// valid in its own process.
  static Future<Uint8List> readFile(String path) async {
    _assertDebug();
    final bytes = await kDropwellTestingChannel.invokeMethod<Uint8List>(
      'readFile',
      path,
    );
    if (bytes == null) throw StateError('platform could not read $path');
    return bytes;
  }

  static void _assertDebug() {
    if (kDebugMode) return;
    throw StateError(
      'dropwell testing hooks are registered in Debug builds only',
    );
  }
}
