import 'dart:ui';

import 'package:dropwell/src/dropwell_file.dart';
import 'package:meta/meta.dart';

/// Stage of a native drag session.
enum DropwellDragPhase {
  /// The pointer carrying a drag payload entered the Flutter view.
  enter,

  /// The pointer moved while still inside the Flutter view.
  over,

  /// The pointer left the Flutter view, or the session was cancelled.
  leave,

  /// The payload was released and its files are available.
  perform,
}

/// One native drag notification.
@immutable
final class DropwellDragEvent {
  /// Creates a drag event.
  const DropwellDragEvent({
    required this.phase,
    required this.physicalPosition,
    this.files = const <DropwellFile>[],
  });

  /// Stage this event reports.
  final DropwellDragPhase phase;

  /// Pointer position in physical pixels relative to the Flutter view origin.
  ///
  /// [DropwellDragPhase.leave] carries [Offset.zero] because no platform
  /// reports a meaningful position once the pointer has gone.
  final Offset physicalPosition;

  /// Files carried by the payload; empty for every phase but
  /// [DropwellDragPhase.perform].
  ///
  /// No desktop platform exposes payload contents before the drop completes,
  /// so this package does not pretend to either.
  final List<DropwellFile> files;

  @override
  String toString() =>
      'DropwellDragEvent(${phase.name}, $physicalPosition, '
      '${files.length} files)';
}
