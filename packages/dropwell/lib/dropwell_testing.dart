/// Debug-only hooks that let the conformance suite drive real platform code.
///
/// The suite has to put a payload where the platform really looks for it and
/// start a real drag session; nothing else proves a platform works. Those are
/// the only operations this library exposes, and every platform with a native
/// half registers the channel behind them **only in Debug builds** so a
/// release binary cannot be driven from outside.
library;

import 'package:dropwell/src/dropwell_codec.dart';
import 'package:dropwell/src/dropwell_drag_event.dart';
import 'package:dropwell/src/dropwell_file.dart';
import 'package:dropwell/src/dropwell_platform.dart';
import 'package:dropwell/src/dropwell_testing_support.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Channel shared with the Debug-only half of every native implementation.
const MethodChannel kDropwellTestingChannel = MethodChannel('dropwell/testing');

/// Drives real platform code from the conformance suite.
abstract final class DropwellTesting {
  /// Replaces the system clipboard with [files].
  ///
  /// Files are offered as real file references, which is what a copy from a
  /// file manager produces. Set [asBitmap] to offer the single file's bytes as
  /// a raw image instead, which is how a pasted screenshot arrives: no name,
  /// no path, just pixels. Both shapes exist on every desktop platform and a
  /// suite that only exercised one would miss half the reader.
  static Future<void> setSystemClipboard(
    List<DropwellFile> files, {
    bool asBitmap = false,
  }) async {
    _assertDebug();
    final dart = _dartSupport;
    if (dart != null) {
      return dart.setSystemClipboard(files, asBitmap: asBitmap);
    }
    await kDropwellTestingChannel.invokeMethod<void>(
      'setSystemClipboard',
      <String, Object?>{
        'files': files.map(DropwellCodec.encodeFile).toList(growable: false),
        'asBitmap': asBitmap,
      },
    );
  }

  /// Empties the system clipboard.
  static Future<void> clearSystemClipboard() async {
    _assertDebug();
    final dart = _dartSupport;
    if (dart != null) return dart.clearSystemClipboard();
    await kDropwellTestingChannel.invokeMethod<void>('clearSystemClipboard');
  }

  /// Delivers [phase] to the platform's own drop entry point.
  ///
  /// This reaches the code the operating system itself would call — not a Dart
  /// shortcut around it — so the payload travels the same path a user's drag
  /// would. Synthesizing at that boundary keeps the suite deterministic on
  /// headless runners, where no real pointer exists.
  static Future<void> synthesizeDrag({
    required DropwellDragPhase phase,
    Offset physicalPosition = Offset.zero,
    List<DropwellFile> files = const <DropwellFile>[],
  }) async {
    _assertDebug();
    final dart = _dartSupport;
    if (dart != null) {
      return dart.synthesizeDrag(
        phase: phase,
        physicalPosition: physicalPosition,
        files: files,
      );
    }
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
    final dart = _dartSupport;
    if (dart != null) return dart.readFile(path);
    final bytes = await kDropwellTestingChannel.invokeMethod<Uint8List>(
      'readFile',
      path,
    );
    if (bytes == null) throw StateError('platform could not read $path');
    return bytes;
  }

  static DropwellTestingSupport? get _dartSupport {
    final platform = DropwellPlatform.instance;
    return platform is DropwellTestingSupport
        ? platform as DropwellTestingSupport
        : null;
  }

  static void _assertDebug() {
    if (kDebugMode) return;
    throw StateError(
      'dropwell testing hooks are registered in Debug builds only',
    );
  }
}
