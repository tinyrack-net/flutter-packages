/// Browser implementation of [DropwellPlatform].
///
/// A browser has no plugin registrar to hand out a native window, so this
/// implementation is written in Dart against the DOM instead of in a platform
/// language behind a method channel.
library;

import 'dart:async';
import 'dart:ui';

import 'package:dropwell/src/dropwell_drag_event.dart';
import 'package:dropwell/src/dropwell_file.dart';
import 'package:dropwell/src/dropwell_platform.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web implementation of the dropwell platform boundary.
base class DropwellWeb extends DropwellPlatform {
  /// Registers this implementation with the web plugin registrar.
  static void registerWith(Registrar registrar) {
    DropwellPlatform.instance = DropwellWeb();
  }

  final StreamController<DropwellDragEvent> _dragEvents =
      StreamController<DropwellDragEvent>.broadcast();

  @override
  bool get supportsDrop => false;

  @override
  bool get supportsClipboardFiles => false;

  @override
  Stream<DropwellDragEvent> get dragEvents => _dragEvents.stream;

  @override
  Future<List<DropwellFile>> readClipboardFiles() async =>
      const <DropwellFile>[];

  @override
  Future<void> publishDropRegions(List<Rect> physicalRegions) async {}
}
