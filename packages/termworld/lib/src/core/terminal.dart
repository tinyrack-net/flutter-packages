import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:termworld/src/core/addon.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/marker.dart';
import 'package:termworld/src/core/options.dart';
import 'package:termworld/src/core/parser.dart';
import 'package:termworld/src/core/unicode.dart';

part 'engine.dart';

/// Terminal viewport size.
final class TerminalResizeEvent {
  /// xterm-compatible `TerminalResizeEvent` API.
  const TerminalResizeEvent({required this.cols, required this.rows});

  /// xterm-compatible `cols` API.
  final int cols;

  /// xterm-compatible `rows` API.
  final int rows;
}

/// Inclusive set of rows that were rendered.
final class TerminalRenderEvent {
  /// xterm-compatible `TerminalRenderEvent` API.
  const TerminalRenderEvent({required this.start, required this.end});

  /// xterm-compatible `start` API.
  final int start;

  /// xterm-compatible `end` API.
  final int end;
}

/// Physical and logical renderer dimensions.
final class TerminalRenderDimensions {
  /// xterm-compatible `TerminalRenderDimensions` API.
  const TerminalRenderDimensions({
    required this.width,
    required this.height,
    required this.cellWidth,
    required this.cellHeight,
    required this.devicePixelRatio,
  });

  /// xterm-compatible `width` API.
  final double width;

  /// xterm-compatible `height` API.
  final double height;

  /// xterm-compatible `cellWidth` API.
  final double cellWidth;

  /// xterm-compatible `cellHeight` API.
  final double cellHeight;

  /// xterm-compatible `devicePixelRatio` API.
  final double devicePixelRatio;
}

/// A renderer-independent keyboard event.
final class TerminalKeyEvent {
  /// xterm-compatible `TerminalKeyEvent` API.
  const TerminalKeyEvent({
    required this.key,
    this.shift = false,
    this.alt = false,
    this.control = false,
    this.meta = false,
  });

  /// xterm-compatible `key` API.
  final String key;

  /// xterm-compatible `shift` API.
  final bool shift;

  /// xterm-compatible `alt` API.
  final bool alt;

  /// xterm-compatible `control` API.
  final bool control;

  /// xterm-compatible `meta` API.
  final bool meta;
}

/// A renderer-independent wheel event.
final class TerminalWheelEvent {
  /// xterm-compatible `TerminalWheelEvent` API.
  const TerminalWheelEvent({
    required this.deltaX,
    required this.deltaY,
    this.shift = false,
    this.alt = false,
    this.control = false,
    this.meta = false,
  });

  /// xterm-compatible `deltaX` API.
  final double deltaX;

  /// xterm-compatible `deltaY` API.
  final double deltaY;

  /// xterm-compatible `shift` API.
  final bool shift;

  /// xterm-compatible `alt` API.
  final bool alt;

  /// xterm-compatible `control` API.
  final bool control;

  /// xterm-compatible `meta` API.
  final bool meta;
}

/// Character join range, inclusive at [start] and exclusive at [end].
final class TerminalCharacterJoin {
  /// xterm-compatible `TerminalCharacterJoin` API.
  const TerminalCharacterJoin(this.start, this.end);

  /// xterm-compatible `start` API.
  final int start;

  /// xterm-compatible `end` API.
  final int end;
}

/// xterm-compatible `TerminalCharacterJoiner` API.
typedef TerminalCharacterJoiner =
    List<TerminalCharacterJoin> Function(
      String text,
    );

/// Link returned by a terminal link provider.
final class TerminalLink {
  /// xterm-compatible `TerminalLink` API.
  const TerminalLink({
    required this.range,
    required this.text,
    required this.activate,
  });

  /// xterm-compatible `range` API.
  final TerminalBufferRange range;

  /// xterm-compatible `text` API.
  final String text;

  /// xterm-compatible `Function` API.
  final void Function(String text) activate;
}

/// Resolves links for one 0-based buffer line.
// A named interface allows providers to retain lifecycle-specific state.
// ignore: one_member_abstracts
abstract interface class TerminalLinkProvider {
  /// xterm-compatible `provideLinks` API.
  FutureOr<List<TerminalLink>> provideLinks(int bufferLineNumber);
}

/// Read-only mode state set by terminal escape sequences.
final class TerminalModes {
  TerminalModes._(this._terminal);

  final Terminal _terminal;

  /// xterm-compatible `applicationCursorKeysMode` API.
  bool get applicationCursorKeysMode => _terminal._engine.cursorKeysMode;

  /// xterm-compatible `applicationKeypadMode` API.
  bool get applicationKeypadMode => _terminal._engine.appKeypadMode;

  /// xterm-compatible `bracketedPasteMode` API.
  bool get bracketedPasteMode => _terminal._engine.bracketedPasteMode;

  /// xterm-compatible `insertMode` API.
  bool get insertMode => _terminal._engine.insertMode;

  /// xterm-compatible `originMode` API.
  bool get originMode => _terminal._engine.originMode;

  /// xterm-compatible `sendFocusMode` API.
  bool get sendFocusMode => _terminal._engine.reportFocusMode;

  /// xterm-compatible `showCursor` API.
  bool get showCursor => _terminal._engine.cursorVisibleMode;

  /// xterm-compatible `wraparoundMode` API.
  bool get wraparoundMode => _terminal._engine.autoWrapMode;

  /// xterm-compatible `reverseWraparoundMode` API.
  bool get reverseWraparoundMode => _terminal._engine.reverseWraparoundMode;

  /// xterm-compatible `synchronizedOutputMode` API.
  bool get synchronizedOutputMode => _terminal._engine.synchronizedOutputMode;

  /// xterm-compatible `win32InputMode` API.
  bool get win32InputMode => _terminal._engine.win32InputMode;

  /// xterm-compatible `switch` API.
  String get mouseTrackingMode => switch (_terminal._engine.mouseMode) {
    TerminalMouseTrackingMode.none => 'none',
    TerminalMouseTrackingMode.x10 => 'x10',
    TerminalMouseTrackingMode.vt200 => 'vt200',
    TerminalMouseTrackingMode.drag => 'drag',
    TerminalMouseTrackingMode.any => 'any',
  };
}

/// Standalone terminal core ported from the pinned xterm.js behavior.
final class Terminal extends DisposableStore {
  /// Creates a terminal with xterm.js defaults.
  Terminal({TerminalOptions? options})
    : options = options ?? TerminalOptions() {
    unicode = TerminalUnicodeHandling();
    _engine = _TerminalCoreEngine(
      options: this.options,
      unicode: unicode,
      columns: this.options.cols,
      rows: this.options.rows,
      scrollback: this.options.scrollback,
      onBell: () {
        _onBell.fire(TerminalVoid.value);
      },
      onTitle: _onTitleChange.fire,
      onData: _triggerData,
      onRequestSendFocus: _reportCurrentFocus,
    );
    buffer = _engine.buffer;
    parser = own(TerminalParser());
    modes = TerminalModes._(this);
    own(this.options.onChange.listen(_handleOptionChange));
  }

  late _TerminalCoreEngine _engine;

  /// xterm-compatible `options` API.
  final TerminalOptions options;

  /// xterm-compatible `buffer` API.
  late final TerminalBufferNamespace buffer;

  /// xterm-compatible `parser` API.
  late final TerminalParser parser;

  /// xterm-compatible `unicode` API.
  late final TerminalUnicodeHandling unicode;

  /// xterm-compatible `modes` API.
  late final TerminalModes modes;

  final TerminalEventEmitter<TerminalVoid> _onBell =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<String> _onBinary = TerminalEventEmitter<String>();
  final TerminalEventEmitter<TerminalVoid> _onCursorMove =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<String> _onData = TerminalEventEmitter<String>();
  final TerminalEventEmitter<TerminalKeyEvent> _onKey =
      TerminalEventEmitter<TerminalKeyEvent>();
  final TerminalEventEmitter<TerminalVoid> _onLineFeed =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<TerminalRenderEvent> _onRender =
      TerminalEventEmitter<TerminalRenderEvent>();
  final TerminalEventEmitter<TerminalVoid> _onWriteParsed =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<TerminalResizeEvent> _onResize =
      TerminalEventEmitter<TerminalResizeEvent>();
  final TerminalEventEmitter<int> _onScroll = TerminalEventEmitter<int>();
  final TerminalEventEmitter<TerminalVoid> _onSelectionChange =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<String> _onTitleChange =
      TerminalEventEmitter<String>();
  final TerminalEventEmitter<TerminalRenderDimensions> _onDimensionsChange =
      TerminalEventEmitter<TerminalRenderDimensions>();

  /// xterm-compatible `onBell` API.
  TerminalEvent<TerminalVoid> get onBell => _onBell.event;

  /// xterm-compatible `onBinary` API.
  TerminalEvent<String> get onBinary => _onBinary.event;

  /// xterm-compatible `onCursorMove` API.
  TerminalEvent<TerminalVoid> get onCursorMove => _onCursorMove.event;

  /// xterm-compatible `onData` API.
  TerminalEvent<String> get onData => _onData.event;

  /// xterm-compatible `onKey` API.
  TerminalEvent<TerminalKeyEvent> get onKey => _onKey.event;

  /// xterm-compatible `onLineFeed` API.
  TerminalEvent<TerminalVoid> get onLineFeed => _onLineFeed.event;

  /// xterm-compatible `onRender` API.
  TerminalEvent<TerminalRenderEvent> get onRender => _onRender.event;

  /// xterm-compatible `onWriteParsed` API.
  TerminalEvent<TerminalVoid> get onWriteParsed => _onWriteParsed.event;

  /// xterm-compatible `onResize` API.
  TerminalEvent<TerminalResizeEvent> get onResize => _onResize.event;

  /// xterm-compatible `onScroll` API.
  TerminalEvent<int> get onScroll => _onScroll.event;

  /// xterm-compatible `onSelectionChange` API.
  TerminalEvent<TerminalVoid> get onSelectionChange => _onSelectionChange.event;

  /// xterm-compatible `onTitleChange` API.
  TerminalEvent<String> get onTitleChange => _onTitleChange.event;

  /// xterm-compatible `onDimensionsChange` API.
  TerminalEvent<TerminalRenderDimensions> get onDimensionsChange =>
      _onDimensionsChange.event;

  /// xterm-compatible `rows` API.
  int get rows => _engine.rows;

  /// xterm-compatible `cols` API.
  int get cols => _engine.columns;

  /// xterm-compatible `unmodifiable` API.
  List<TerminalMarker> get markers => List<TerminalMarker>.unmodifiable(
    _markers.where((item) => !item.isDisposed),
  );

  /// xterm-compatible `dimensions` API.
  TerminalRenderDimensions? get dimensions => _dimensions;

  final List<_WriteRequest> _writeQueue = <_WriteRequest>[];
  final _Utf8ChunkDecoder _decoder = _Utf8ChunkDecoder();
  bool _writeScheduled = false;
  bool _draining = false;
  int _viewportY = 0;
  TerminalBufferRange? _selection;
  TerminalRenderDimensions? _dimensions;
  final List<TerminalMarker> _markers = <TerminalMarker>[];
  final List<TerminalDecoration> _decorations = <TerminalDecoration>[];
  bool _isDisposing = false;
  final TerminalMarkerFactory _markerFactory = TerminalMarkerFactory();
  final List<TerminalAddon> _addons = <TerminalAddon>[];
  final List<TerminalLinkProvider> _linkProviders = <TerminalLinkProvider>[];
  final Map<int, TerminalCharacterJoiner> _characterJoiners =
      <int, TerminalCharacterJoiner>{};
  int _nextCharacterJoinerId = 1;
  bool Function(TerminalKeyEvent event)? _customKeyHandler;
  bool Function(TerminalWheelEvent event)? _customWheelHandler;
  void Function()? _focus;
  void Function()? _blur;
  bool _hasFocus = false;

  void _handleOptionChange(String name) {
    _engine.handleOptionChange(name);
    final nextViewport = _viewportY.clamp(0, buffer.normal.baseY);
    if (nextViewport != _viewportY) {
      _viewportY = nextViewport;
      _onScroll.fire(_viewportY);
    }
    _onRender.fire(TerminalRenderEvent(start: 0, end: rows - 1));
  }

  /// Queues text or UTF-8 bytes for ordered parsing.
  void write(Object data, {void Function()? onParsed}) {
    _checkData(data);
    if (isDisposed) throw StateError('Terminal has been disposed');
    _writeQueue.add(_WriteRequest(data, onParsed, null));
    _scheduleDrain();
  }

  /// Queues text followed by CRLF.
  void writeln(Object data, {void Function()? onParsed}) {
    _checkData(data);
    if (data is String) {
      write('$data\r\n', onParsed: onParsed);
    } else {
      final bytes = data as Uint8List;
      write(
        Uint8List.fromList(<int>[...bytes, 0x0d, 0x0a]),
        onParsed: onParsed,
      );
    }
  }

  /// Queues data and completes after its parser callback fires.
  Future<void> writeAndWait(Object data) {
    _checkData(data);
    if (isDisposed) throw StateError('Terminal has been disposed');
    final completer = Completer<void>();
    _writeQueue.add(
      _WriteRequest(data, completer.complete, completer.completeError),
    );
    _scheduleDrain();
    return completer.future;
  }

  static void _checkData(Object data) {
    if (data is! String && data is! Uint8List) {
      throw ArgumentError.value(data, 'data', 'must be String or Uint8List');
    }
  }

  void _scheduleDrain() {
    if (_writeScheduled) return;
    _writeScheduled = true;
    scheduleMicrotask(_drainWrites);
  }

  Future<void> _drainWrites() async {
    if (_draining || isDisposed) return;
    _writeScheduled = false;
    _draining = true;
    while (_writeQueue.isNotEmpty && !isDisposed) {
      final request = _writeQueue.removeAt(0);
      try {
        final text = request.data is String
            ? request.data as String
            : _decoder.convert(request.data as Uint8List);
        await _parse(text);
        request.onParsed?.call();
        // Every parser failure must reach the queued write error callback.
        // ignore: avoid_catches_without_on_clauses
      } catch (error, stackTrace) {
        options.logger?.log(TerminalLogLevel.error, 'write failed', error);
        request.onError?.call(error, stackTrace);
      }
    }
    try {
      _onWriteParsed.fire(TerminalVoid.value);
    } finally {
      _draining = false;
      if (_writeQueue.isNotEmpty) _scheduleDrain();
    }
  }

  Future<void> _parse(String text) async {
    final cursorX = buffer.active.cursorX;
    final cursorY = buffer.active.cursorY;
    final height = buffer.active.length;
    await parser.process(text, (filtered) {
      if (filtered.isNotEmpty) _engine.write(filtered);
    });
    _viewportY = _viewportY.clamp(0, buffer.active.baseY);
    if (buffer.active.cursorX != cursorX || buffer.active.cursorY != cursorY) {
      _onCursorMove.fire(TerminalVoid.value);
    }
    if (buffer.active.length > height || text.contains('\n')) {
      _onLineFeed.fire(TerminalVoid.value);
    }
    if (!_engine.synchronizedOutputMode) {
      _onRender.fire(TerminalRenderEvent(start: 0, end: rows - 1));
    }
  }

  /// Sends application-side input exactly as typed input would.
  void input(String data, {bool wasUserInput = true}) {
    if (options.disableStdin || isDisposed) return;
    if (wasUserInput && options.scrollOnUserInput) scrollToBottom();
    _triggerData(data);
  }

  /// Normalizes, sanitizes, and optionally brackets pasted text.
  void paste(String data) {
    var prepared = data.replaceAll(RegExp(r'\r?\n'), '\r');
    if (_engine.bracketedPasteMode && !options.ignoreBracketedPasteMode) {
      prepared = prepared.replaceAll('\u001b', '\u241b');
      prepared = '\u001b[200~$prepared\u001b[201~';
    }
    input(prepared);
  }

  void _triggerData(String data) {
    if (options.disableStdin || isDisposed) return;
    _onData.fire(data);
  }

  /// Resizes both normal and alternate buffers.
  void resize(int columns, int rowCount) {
    if (columns < 1) {
      throw ArgumentError.value(columns, 'columns', 'must be at least 1');
    }
    if (rowCount < 1) {
      throw ArgumentError.value(rowCount, 'rows', 'must be at least 1');
    }
    if (columns == cols && rowCount == rows) return;
    _engine.resize(columns, rowCount);
    _onResize.fire(TerminalResizeEvent(cols: columns, rows: rowCount));
    _viewportY = _viewportY.clamp(0, buffer.active.baseY);
  }

  /// xterm-compatible `focus` API.
  void focus() => _focus?.call();

  /// xterm-compatible `blur` API.
  void blur() => _blur?.call();

  /// Installs focus callbacks for the active Flutter view.
  void attachFocusHandlers({void Function()? focus, void Function()? blur}) {
    _focus = focus;
    _blur = blur;
  }

  /// Reports a renderer focus transition to the terminal input service.
  ///
  /// Renderer adapters call this after their native focus state has actually
  /// changed. When DECSET 1004 is active this emits the same focus-in or
  /// focus-out sequence as xterm.js' textarea boundary.
  void reportFocus({required bool focused}) {
    if (_hasFocus == focused) return;
    _hasFocus = focused;
    if (_engine.reportFocusMode) _reportCurrentFocus();
  }

  void _reportCurrentFocus() => _triggerData(
    _hasFocus ? '\u001b[I' : '\u001b[O',
  );

  /// xterm-compatible `attachCustomKeyEventHandler` API.
  // This method name is fixed by xterm's public API.
  // ignore: use_setters_to_change_properties
  void attachCustomKeyEventHandler(
    bool Function(TerminalKeyEvent event) handler,
  ) {
    _customKeyHandler = handler;
  }

  /// xterm-compatible `attachCustomWheelEventHandler` API.
  // This method name is fixed by xterm's public API.
  // ignore: use_setters_to_change_properties
  void attachCustomWheelEventHandler(
    bool Function(TerminalWheelEvent event) handler,
  ) {
    _customWheelHandler = handler;
  }

  /// xterm-compatible `handleKeyEvent` API.
  bool handleKeyEvent(TerminalKeyEvent event) {
    _onKey.fire(event);
    return _customKeyHandler?.call(event) ?? true;
  }

  /// xterm-compatible `handleWheelEvent` API.
  bool handleWheelEvent(TerminalWheelEvent event) =>
      _customWheelHandler?.call(event) ?? true;

  /// xterm-compatible `registerLinkProvider` API.
  Disposable registerLinkProvider(TerminalLinkProvider provider) {
    _linkProviders.add(provider);
    return CallbackDisposable(() => _linkProviders.remove(provider));
  }

  /// xterm-compatible `linkProviders` API.
  List<TerminalLinkProvider> get linkProviders =>
      List<TerminalLinkProvider>.unmodifiable(_linkProviders);

  /// xterm-compatible `registerCharacterJoiner` API.
  int registerCharacterJoiner(TerminalCharacterJoiner handler) {
    final id = _nextCharacterJoinerId++;
    _characterJoiners[id] = handler;
    return id;
  }

  /// xterm-compatible `deregisterCharacterJoiner` API.
  void deregisterCharacterJoiner(int joinerId) {
    if (_characterJoiners.remove(joinerId) == null) {
      throw ArgumentError.value(joinerId, 'joinerId', 'is not registered');
    }
  }

  /// xterm-compatible `characterJoins` API.
  List<TerminalCharacterJoin> characterJoins(String text) {
    final joins = <TerminalCharacterJoin>[
      for (final joiner in _characterJoiners.values) ...joiner(text),
    ]..sort((left, right) => left.start.compareTo(right.start));
    if (joins.length < 2) return joins;
    final merged = <TerminalCharacterJoin>[];
    for (final join in joins) {
      if (join.start < 0 || join.end <= join.start || join.end > text.length) {
        throw RangeError('Character join is outside the input text');
      }
      if (merged.isEmpty || join.start > merged.last.end) {
        merged.add(join);
      } else {
        final previous = merged.removeLast();
        merged.add(
          TerminalCharacterJoin(
            previous.start,
            previous.end > join.end ? previous.end : join.end,
          ),
        );
      }
    }
    return merged;
  }

  /// xterm-compatible `registerMarker` API.
  TerminalMarker? registerMarker({int cursorYOffset = 0}) {
    if (identical(buffer.active, buffer.alternate)) return null;
    final y = buffer.normal.absoluteCursorY + cursorYOffset;
    if (y < 0 || y >= buffer.normal.length) return null;
    final marker = _markerFactory.create(y);
    _markers.add(marker);
    marker.onDispose.listen((_) => _markers.remove(marker));
    return marker;
  }

  /// xterm-compatible `registerDecoration` API.
  TerminalDecoration? registerDecoration({
    required TerminalMarker marker,
    TerminalDecorationAnchor anchor = TerminalDecorationAnchor.left,
    int x = 0,
    int width = 1,
    int height = 1,
    String? backgroundColor,
    String? foregroundColor,
    String? borderColor,
    String? overviewRulerColor,
    TerminalDecorationLayer layer = TerminalDecorationLayer.bottom,
  }) {
    if (marker.isDisposed || marker.line < 0) return null;
    final decoration = TerminalDecoration(
      marker: marker,
      anchor: anchor,
      x: x,
      width: width,
      height: height,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor,
      overviewRulerColor: overviewRulerColor,
      layer: layer,
    );
    _decorations.add(decoration);
    late final Disposable markerListener;
    markerListener = marker.onDispose.listen((_) => decoration.dispose());
    decoration.onDispose.listen((_) {
      markerListener.dispose();
      _decorations.remove(decoration);
      if (!_isDisposing) refresh(0, rows - 1);
    });
    refresh(0, rows - 1);
    return decoration;
  }

  /// xterm-compatible `decorations` API.
  List<TerminalDecoration> get decorations =>
      List<TerminalDecoration>.unmodifiable(_decorations);

  /// xterm-compatible `hasSelection` API.
  bool hasSelection() => _selection != null;

  /// xterm-compatible `getSelection` API.
  String getSelection() {
    final selection = _selection;
    if (selection == null) return '';
    final output = StringBuffer();
    for (var y = selection.start.y; y <= selection.end.y; y++) {
      final line = buffer.active.getLine(y);
      if (line == null) continue;
      final start = y == selection.start.y ? selection.start.x : 0;
      final end = y == selection.end.y ? selection.end.x : line.length;
      output.write(
        line.translateToString(
          trimRight: true,
          startColumn: start,
          endColumn: end,
        ),
      );
      if (y != selection.end.y &&
          !(buffer.active.getLine(y + 1)?.isWrapped ?? false)) {
        output.write('\n');
      }
    }
    return output.toString();
  }

  /// xterm-compatible `getSelectionPosition` API.
  TerminalBufferRange? getSelectionPosition() => _selection;

  /// xterm-compatible `clearSelection` API.
  void clearSelection() {
    if (_selection == null) return;
    _selection = null;
    _onSelectionChange.fire(TerminalVoid.value);
  }

  /// xterm-compatible `select` API.
  void select(int column, int row, int length) {
    if (column < 0 || row < 0 || length < 0) {
      throw ArgumentError('column, row and length cannot be negative');
    }
    final lastLine = buffer.active.length - 1;
    if (row > lastLine) throw RangeError.range(row, 0, lastLine, 'row');
    var endRow = row;
    var endColumn = column + length;
    while (endColumn > cols && endRow < lastLine) {
      endColumn -= cols;
      endRow++;
    }
    _selection = TerminalBufferRange(
      start: TerminalBufferPosition(column.clamp(0, cols), row),
      end: TerminalBufferPosition(endColumn.clamp(0, cols), endRow),
    );
    _onSelectionChange.fire(TerminalVoid.value);
  }

  /// xterm-compatible `selectAll` API.
  void selectAll() => select(0, 0, buffer.active.length * cols);

  /// xterm-compatible `selectLines` API.
  void selectLines(int start, int end) {
    if (start < 0 || end < start || end >= buffer.active.length) {
      throw RangeError('Invalid selection line range');
    }
    _selection = TerminalBufferRange(
      start: TerminalBufferPosition(0, start),
      end: TerminalBufferPosition(cols, end),
    );
    _onSelectionChange.fire(TerminalVoid.value);
  }

  /// xterm-compatible `scrollLines` API.
  void scrollLines(int amount) => scrollToLine(_viewportY + amount);

  /// xterm-compatible `scrollPages` API.
  void scrollPages(int pageCount) => scrollLines(pageCount * rows);

  /// xterm-compatible `scrollToTop` API.
  void scrollToTop() => scrollToLine(0);

  /// xterm-compatible `scrollToBottom` API.
  void scrollToBottom() => scrollToLine(buffer.active.baseY);

  /// xterm-compatible `scrollToLine` API.
  void scrollToLine(int line) {
    final next = line.clamp(0, buffer.active.baseY);
    if (next == _viewportY) return;
    _viewportY = next;
    _onScroll.fire(next);
  }

  /// xterm-compatible `viewportY` API.
  int get viewportY => _viewportY;

  /// Clears scrollback while preserving the current prompt line.
  void clear() {
    final current = buffer.active.currentLine.translateToString(
      trimRight: true,
    );
    buffer.active.clear();
    if (current.isNotEmpty) _engine.write(current);
    _viewportY = 0;
    _onScroll.fire(0);
    refresh(0, rows - 1);
  }

  /// xterm-compatible `refresh` API.
  void refresh(int start, int end) {
    if (start < 0 || end < start || end >= rows) {
      throw RangeError('Refresh range must be within the viewport');
    }
    _onRender.fire(TerminalRenderEvent(start: start, end: end));
  }

  /// xterm-compatible `clearTextureAtlas` API.
  void clearTextureAtlas() => refresh(0, rows - 1);

  /// Performs a full RIS reset.
  void reset() {
    _engine.reset();
    _viewportY = 0;
    clearSelection();
    refresh(0, rows - 1);
  }

  /// xterm-compatible `loadAddon` API.
  void loadAddon(TerminalAddon addon) {
    if (_addons.contains(addon)) {
      throw StateError('Addon is already loaded');
    }
    _addons.add(addon);
    try {
      addon.activate(this);
    } catch (_) {
      _addons.remove(addon);
      rethrow;
    }
  }

  /// Called by the Flutter view after measuring its render surface.
  void updateDimensions(TerminalRenderDimensions value) {
    if (_dimensions == value) return;
    _dimensions = value;
    _onDimensionsChange.fire(value);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    _isDisposing = true;
    for (final addon in _addons.reversed) {
      addon.dispose();
    }
    for (final decoration in List<TerminalDecoration>.of(_decorations)) {
      decoration.dispose();
    }
    for (final marker in List<TerminalMarker>.of(_markers)) {
      marker.dispose();
    }
    buffer.dispose();
    for (final emitter in <Disposable>[
      _onBell,
      _onBinary,
      _onCursorMove,
      _onData,
      _onKey,
      _onLineFeed,
      _onRender,
      _onWriteParsed,
      _onResize,
      _onScroll,
      _onSelectionChange,
      _onTitleChange,
      _onDimensionsChange,
    ]) {
      emitter.dispose();
    }
    _writeQueue.clear();
    super.dispose();
  }
}

final class _WriteRequest {
  const _WriteRequest(this.data, this.onParsed, this.onError);

  final Object data;
  final void Function()? onParsed;
  final void Function(Object error, StackTrace stackTrace)? onError;
}

final class _Utf8ChunkDecoder {
  Uint8List _pending = Uint8List(0);

  String convert(Uint8List bytes) {
    final source = Uint8List.fromList(<int>[..._pending, ...bytes]);
    var completeLength = source.length;
    if (source.isNotEmpty) {
      var lead = source.length - 1;
      while (lead >= 0 && source[lead] & 0xc0 == 0x80) {
        lead--;
      }
      if (lead >= 0) {
        final first = source[lead];
        final expected = first & 0x80 == 0
            ? 1
            : first & 0xe0 == 0xc0
            ? 2
            : first & 0xf0 == 0xe0
            ? 3
            : first & 0xf8 == 0xf0
            ? 4
            : 1;
        if (source.length - lead < expected) completeLength = lead;
      }
    }
    _pending = Uint8List.fromList(source.sublist(completeLength));
    return utf8.decode(source.sublist(0, completeLength), allowMalformed: true);
  }
}
