/// Browser implementation of [DropwellPlatform].
///
/// A browser has no plugin registrar to hand out a native window, so this
/// implementation is written in Dart against the DOM rather than in a platform
/// language behind a method channel.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui';

import 'package:dropwell/src/dropwell_drag_event.dart';
import 'package:dropwell/src/dropwell_file.dart';
import 'package:dropwell/src/dropwell_geometry.dart';
import 'package:dropwell/src/dropwell_platform.dart';
import 'package:dropwell/src/dropwell_reader_web.dart';
import 'package:dropwell/src/dropwell_testing_support.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// Web implementation of the dropwell platform boundary.
base class DropwellWeb extends DropwellPlatform
    implements DropwellTestingSupport {
  /// Creates the implementation and starts listening to the document.
  DropwellWeb({@visibleForTesting web.EventTarget? target})
    : _target = target ?? web.document {
    _listen('dragenter', _onDragEnter);
    _listen('dragover', _onDragOver);
    _listen('dragleave', _onDragLeave);
    _listen('drop', _onDrop);
    _listen('paste', _onPaste);
  }

  /// Registers this implementation with the web plugin registrar.
  static void registerWith(Registrar registrar) {
    DropwellPlatform.instance = DropwellWeb();
  }

  final web.EventTarget _target;
  final StreamController<DropwellDragEvent> _dragEvents =
      StreamController<DropwellDragEvent>.broadcast();

  List<Rect> _regions = const <Rect>[];

  /// The in-flight read of the most recent paste.
  ///
  /// Reading a browser `File` is asynchronous, so storing the future rather
  /// than its result means a consumer that calls readClipboardFiles the
  /// instant its paste shortcut fires waits for the payload instead of
  /// racing it to an empty list.
  Future<List<DropwellFile>> _pasted = Future<List<DropwellFile>>.value(
    const <DropwellFile>[],
  );

  @override
  bool get supportsDrop => true;

  @override
  bool get supportsClipboardFiles => true;

  @override
  Stream<DropwellDragEvent> get dragEvents => _dragEvents.stream;

  /// Files carried by the most recent paste.
  ///
  /// A browser refuses to hand over the clipboard on demand without a
  /// permission prompt, but it always delivers a `paste` event to the focused
  /// document. Reading that event is therefore the only mechanism that works
  /// for every user, so this returns what the last paste carried. A consumer
  /// calls this from its own paste shortcut, which is exactly when the event
  /// has just fired.
  @override
  Future<List<DropwellFile>> readClipboardFiles() => _pasted;

  @override
  Future<void> publishDropRegions(List<Rect> physicalRegions) async {
    _regions = List<Rect>.unmodifiable(physicalRegions);
  }

  @override
  Future<void> clearSystemClipboard() async {
    _pasted = Future<List<DropwellFile>>.value(const <DropwellFile>[]);
  }

  @override
  Future<void> setSystemClipboard(
    List<DropwellFile> files, {
    required bool asBitmap,
  }) async {
    // A browser cannot write the system clipboard without a permission prompt,
    // so the suite delivers the same `paste` event a user would. A bitmap is a
    // file with an image type and no name the browser will surface, which is
    // exactly how a pasted screenshot already arrives here.
    _target.dispatchEvent(
      web.ClipboardEvent(
        'paste',
        web.ClipboardEventInit(clipboardData: _transferFor(files)),
      ),
    );
    await _pasted;
  }

  @override
  Future<void> synthesizeDrag({
    required DropwellDragPhase phase,
    required Offset physicalPosition,
    required List<DropwellFile> files,
  }) async {
    final ratio = _devicePixelRatio;
    final init = web.DragEventInit(
      clientX: (physicalPosition.dx / ratio).round(),
      clientY: (physicalPosition.dy / ratio).round(),
      dataTransfer: _transferFor(files),
      bubbles: true,
      cancelable: true,
    );
    _target.dispatchEvent(web.DragEvent(_domEventName(phase), init));
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<Uint8List> readFile(String path) async =>
      throw UnsupportedError('a browser never reports a file by path');

  void _listen(String type, void Function(web.Event) handler) {
    _target.addEventListener(type, handler.toJS);
  }

  static String _domEventName(DropwellDragPhase phase) => switch (phase) {
    DropwellDragPhase.enter => 'dragenter',
    DropwellDragPhase.over => 'dragover',
    DropwellDragPhase.leave => 'dragleave',
    DropwellDragPhase.perform => 'drop',
  };

  web.DataTransfer _transferFor(List<DropwellFile> files) {
    final transfer = web.DataTransfer();
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      transfer.items.add(
        web.File(
          <JSAny>[bytes.toJS].toJS,
          file.fileName,
          web.FilePropertyBag(type: file.mimeType ?? ''),
        ),
      );
    }
    return transfer;
  }

  double get _devicePixelRatio => web.window.devicePixelRatio;

  Offset _physicalPosition(web.MouseEvent event) => Offset(
    event.clientX.toDouble() * _devicePixelRatio,
    event.clientY.toDouble() * _devicePixelRatio,
  );

  bool _accepts(Offset point) =>
      DropwellGeometry.topmostRegionAt(_regions, point) != null;

  void _onDragEnter(web.Event event) {
    event.preventDefault();
    _emit(DropwellDragPhase.enter, _physicalPosition(event as web.DragEvent));
  }

  void _onDragOver(web.Event event) {
    final drag = event as web.DragEvent;
    final point = _physicalPosition(drag);
    // Without preventDefault the browser refuses the drop and navigates to the
    // dropped file instead, so consent has to be given on every dragover.
    if (_accepts(point)) {
      event.preventDefault();
      drag.dataTransfer?.dropEffect = 'copy';
    }
    _emit(DropwellDragPhase.over, point);
  }

  void _onDragLeave(web.Event event) {
    _emit(DropwellDragPhase.leave, Offset.zero);
  }

  Future<void> _onDrop(web.Event event) async {
    final drag = event as web.DragEvent;
    event.preventDefault();
    final point = _physicalPosition(drag);
    _emit(
      DropwellDragPhase.perform,
      point,
      await readDataTransfer(drag.dataTransfer),
    );
  }

  void _onPaste(web.Event event) {
    _pasted = readDataTransfer((event as web.ClipboardEvent).clipboardData);
  }

  void _emit(
    DropwellDragPhase phase,
    Offset position, [
    List<DropwellFile> files = const <DropwellFile>[],
  ]) {
    _dragEvents.add(
      DropwellDragEvent(
        phase: phase,
        physicalPosition: position,
        files: files,
      ),
    );
  }
}
