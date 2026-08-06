import 'dart:async';
import 'dart:ui';

import 'package:dropwell/dropwell.dart';

/// Records what the registry sends and lets a test drive native events.
base class FakeDropwellPlatform extends DropwellPlatform {
  /// Creates a fake reporting the given capabilities.
  FakeDropwellPlatform({
    this.supportsDrop = true,
    this.supportsClipboardFiles = true,
    this.clipboard = const <DropwellFile>[],
  });

  @override
  final bool supportsDrop;

  @override
  final bool supportsClipboardFiles;

  /// Files [readClipboardFiles] returns.
  List<DropwellFile> clipboard;

  /// Every region list published so far, oldest first.
  final List<List<Rect>> publishes = <List<Rect>>[];

  final StreamController<DropwellDragEvent> _dragEvents =
      StreamController<DropwellDragEvent>.broadcast();

  @override
  Stream<DropwellDragEvent> get dragEvents => _dragEvents.stream;

  @override
  Future<List<DropwellFile>> readClipboardFiles() async => clipboard;

  @override
  Future<void> publishDropRegions(List<Rect> physicalRegions) async {
    publishes.add(List<Rect>.unmodifiable(physicalRegions));
  }

  /// Emits [event] as though platform code sent it.
  void emit(DropwellDragEvent event) => _dragEvents.add(event);

  /// Closes the event stream.
  Future<void> close() => _dragEvents.close();
}
