import 'dart:ui';

import 'package:dropwell/src/dropwell_drag_event.dart';
import 'package:dropwell/src/dropwell_file.dart';
import 'package:dropwell/src/method_channel_dropwell.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Platform boundary for native drag-and-drop and clipboard file reading.
///
/// Capabilities are declared synchronously so a consumer can decide what to
/// build before any asynchronous call resolves, and so the conformance suite
/// can branch on a declared capability instead of on the host platform. A
/// platform reports `false` until its native implementation actually works;
/// there is no state in which this package claims a capability it cannot
/// deliver.
abstract base class DropwellPlatform extends PlatformInterface {
  /// Creates the platform boundary.
  DropwellPlatform() : super(token: _token);

  static final Object _token = Object();

  static DropwellPlatform _instance = MethodChannelDropwell();

  /// The implementation registered for the running platform.
  static DropwellPlatform get instance => _instance;

  /// Replaces the implementation; platform packages call this from
  /// `registerWith`.
  static set instance(DropwellPlatform value) {
    PlatformInterface.verify(value, _token);
    _instance = value;
  }

  /// Whether this platform delivers native drag-and-drop.
  bool get supportsDrop;

  /// Whether this platform reads files and images from the system clipboard.
  bool get supportsClipboardFiles;

  /// Reads file and image items currently on the system clipboard.
  ///
  /// Returns an empty list when the clipboard holds nothing this package can
  /// represent as a file, including when [supportsClipboardFiles] is `false`.
  Future<List<DropwellFile>> readClipboardFiles();

  /// Publishes the physical-pixel rectangles that currently accept a drop.
  ///
  /// Native code answers the operating system's synchronous "will you accept
  /// this?" question from this list alone. A round trip to Dart cannot happen
  /// inside that callback, so the list must be published ahead of the drag.
  Future<void> publishDropRegions(List<Rect> physicalRegions);

  /// Native drag notifications for the Flutter view.
  Stream<DropwellDragEvent> get dragEvents;
}
