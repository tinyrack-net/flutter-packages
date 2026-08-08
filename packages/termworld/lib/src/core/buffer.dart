import 'package:flutter/foundation.dart';
import 'package:termworld/src/core/event.dart';
import 'package:xterm/core.dart' as xterm;

/// Terminal buffer kind.
/// xterm-compatible `TerminalBufferType` API.
enum TerminalBufferType {
  /// The normal buffer with scrollback.
  normal,

  /// The alternate screen buffer.
  alternate,
}

/// Encoded terminal color kind.
/// xterm-compatible `TerminalColorMode` API.
enum TerminalColorMode {
  /// The terminal's default color.
  defaultColor,

  /// An indexed ANSI palette color.
  palette,

  /// A 24-bit RGB color.
  rgb,
}

/// An immutable position in the backing buffer.
@immutable
final class TerminalBufferPosition {
  /// xterm-compatible `TerminalBufferPosition` API.
  const TerminalBufferPosition(this.x, this.y);

  /// xterm-compatible `x` API.
  final int x;

  /// xterm-compatible `y` API.
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TerminalBufferPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// An inclusive terminal buffer range.
final class TerminalBufferRange {
  /// xterm-compatible `TerminalBufferRange` API.
  const TerminalBufferRange({required this.start, required this.end});

  /// xterm-compatible `start` API.
  final TerminalBufferPosition start;

  /// xterm-compatible `end` API.
  final TerminalBufferPosition end;
}

/// Public read-only view of one terminal cell.
final class TerminalCell {
  TerminalCell._(xterm.BufferLine line, int index)
    : _line = line,
      _index = index;

  final xterm.BufferLine _line;
  final int _index;

  /// xterm-compatible `getWidth` API.
  int get width => _line.getWidth(_index);

  /// xterm-compatible `getText` API.
  String get chars => width == 0 ? '' : _line.getText(_index, _index + 1);

  /// xterm-compatible `getCodePoint` API.
  int get code => _line.getCodePoint(_index);

  /// xterm-compatible `getForeground` API.
  int get foreground => _line.getForeground(_index) & xterm.CellColor.valueMask;

  /// xterm-compatible `getBackground` API.
  int get background => _line.getBackground(_index) & xterm.CellColor.valueMask;

  /// xterm-compatible `_colorMode` API.
  TerminalColorMode get foregroundMode => _colorMode(
    _line.getForeground(_index),
  );

  /// xterm-compatible `_colorMode` API.
  TerminalColorMode get backgroundMode => _colorMode(
    _line.getBackground(_index),
  );

  /// xterm-compatible `_has` API.
  bool get isBold => _has(xterm.CellAttr.bold);

  /// xterm-compatible `_has` API.
  bool get isDim => _has(xterm.CellAttr.faint);

  /// xterm-compatible `_has` API.
  bool get isItalic => _has(xterm.CellAttr.italic);

  /// xterm-compatible `_has` API.
  bool get isUnderline => _has(xterm.CellAttr.underline);

  /// xterm-compatible `_has` API.
  bool get isBlink => _has(xterm.CellAttr.blink);

  /// xterm-compatible `_has` API.
  bool get isInverse => _has(xterm.CellAttr.inverse);

  /// xterm-compatible `_has` API.
  bool get isInvisible => _has(xterm.CellAttr.invisible);

  /// xterm-compatible `_has` API.
  bool get isStrikethrough => _has(xterm.CellAttr.strikethrough);

  /// xterm-compatible `isAttributeDefault` API.
  bool get isAttributeDefault =>
      _line.getForeground(_index) == 0 &&
      _line.getBackground(_index) == 0 &&
      _line.getAttributes(_index) == 0;

  /// xterm-compatible `attributesEqual` API.
  bool attributesEqual(TerminalCell other) =>
      _line.getForeground(_index) == other._line.getForeground(other._index) &&
      _line.getBackground(_index) == other._line.getBackground(other._index) &&
      _line.getAttributes(_index) == other._line.getAttributes(other._index);

  bool _has(int flag) => _line.getAttributes(_index) & flag != 0;

  static TerminalColorMode _colorMode(int value) =>
      switch (value & xterm.CellColor.typeMask) {
        xterm.CellColor.rgb => TerminalColorMode.rgb,
        xterm.CellColor.named ||
        xterm.CellColor.palette => TerminalColorMode.palette,
        _ => TerminalColorMode.defaultColor,
      };
}

/// Public read-only view of one buffer line.
final class TerminalBufferLine {
  TerminalBufferLine._(this._line);

  final xterm.BufferLine _line;

  /// xterm-compatible `isWrapped` API.
  bool get isWrapped => _line.isWrapped;

  /// xterm-compatible `length` API.
  int get length => _line.length;

  /// xterm-compatible `getCell` API.
  TerminalCell? getCell(int index) =>
      index < 0 || index >= length ? null : TerminalCell._(_line, index);

  /// xterm-compatible `translateToString` API.
  String translateToString({
    bool trimRight = false,
    int startColumn = 0,
    int? endColumn,
  }) {
    final start = startColumn.clamp(0, length);
    var end = (endColumn ?? length).clamp(start, length);
    if (trimRight) {
      while (end > start && _line.getCodePoint(end - 1) == 0) {
        end--;
      }
    }
    final result = StringBuffer();
    for (var index = start; index < end; index++) {
      final width = _line.getWidth(index);
      final codePoint = _line.getCodePoint(index);
      if (width == 0 &&
          codePoint == 0 &&
          index > 0 &&
          _line.getWidth(index - 1) == 2) {
        continue;
      }
      result.writeCharCode(codePoint == 0 ? 0x20 : codePoint);
    }
    final text = result.toString();
    return trimRight ? text.trimRight() : text;
  }
}

/// Public read-only view of an xterm buffer.
final class TerminalBuffer {
  TerminalBuffer._(this.type, this._buffer, this._viewportY);

  /// xterm-compatible `type` API.
  final TerminalBufferType type;
  final xterm.Buffer _buffer;
  final int Function() _viewportY;

  /// xterm-compatible `cursorY` API.
  int get cursorY => _buffer.cursorY;

  /// xterm-compatible `cursorX` API.
  int get cursorX => _buffer.cursorX;

  /// xterm-compatible `_viewportY` API.
  int get viewportY => _viewportY();

  /// xterm-compatible `baseY` API.
  int get baseY => _buffer.scrollBack;

  /// xterm-compatible `length` API.
  int get length => _buffer.height;

  /// xterm-compatible `getLine` API.
  TerminalBufferLine? getLine(int index) => index < 0 || index >= length
      ? null
      : TerminalBufferLine._(_buffer.lines[index]);

  /// xterm-compatible `getNullCell` API.
  TerminalCell getNullCell() => TerminalCell._(xterm.BufferLine(1), 0);
}

/// Normal, alternate, and active buffers.
final class TerminalBufferNamespace {
  /// xterm-compatible `TerminalBufferNamespace` API.
  TerminalBufferNamespace({
    required xterm.Terminal terminal,
    required int Function() viewportY,
  }) : normal = TerminalBuffer._(
         TerminalBufferType.normal,
         terminal.mainBuffer,
         viewportY,
       ),
       alternate = TerminalBuffer._(
         TerminalBufferType.alternate,
         terminal.altBuffer,
         viewportY,
       ),
       _terminal = terminal;

  final xterm.Terminal _terminal;
  final TerminalEventEmitter<TerminalBuffer> _onBufferChange =
      TerminalEventEmitter<TerminalBuffer>();
  TerminalBufferType _lastType = TerminalBufferType.normal;

  /// xterm-compatible `normal` API.
  final TerminalBuffer normal;

  /// xterm-compatible `alternate` API.
  final TerminalBuffer alternate;

  /// xterm-compatible `active` API.
  TerminalBuffer get active => _terminal.isUsingAltBuffer ? alternate : normal;

  /// xterm-compatible `onBufferChange` API.
  TerminalEvent<TerminalBuffer> get onBufferChange => _onBufferChange.event;

  /// xterm-compatible `detectChange` API.
  void detectChange() {
    final type = active.type;
    if (type == _lastType) return;
    _lastType = type;
    _onBufferChange.fire(active);
  }

  /// xterm-compatible `dispose` API.
  void dispose() => _onBufferChange.dispose();
}
