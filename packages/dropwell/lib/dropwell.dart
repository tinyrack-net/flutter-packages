/// Native file drag-and-drop and clipboard file reading for Flutter.
///
/// Every platform this package declares delivers the same observable Dart
/// behavior, and every capability it cannot deliver on a platform is reported
/// as `false` rather than failing at runtime.
library;

export 'package:dropwell/src/dropwell_drag_event.dart'
    show DropwellDragEvent, DropwellDragPhase;
export 'package:dropwell/src/dropwell_file.dart' show DropwellFile;
export 'package:dropwell/src/dropwell_platform.dart' show DropwellPlatform;
export 'package:dropwell/src/dropwell_region.dart' show DropwellRegion;
