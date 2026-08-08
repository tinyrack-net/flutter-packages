import 'dart:math' as math;

import 'package:xterm/core.dart' as xterm;

/// Corrects observable VT behavior where xterm.dart 4 differs from xterm.js.
final class XtermParityTerminal extends xterm.Terminal {
  /// xterm-compatible `XtermParityTerminal` API.
  XtermParityTerminal({
    required super.maxLines,
    required super.reflowEnabled,
    required super.wordSeparators,
  });

  final List<bool> _tabStops = List<bool>.generate(
    1024,
    (index) => index % 8 == 0,
  );
  bool _pendingWrap = false;
  bool _savedPendingWrap = false;
  bool _reverseWraparound = false;
  int _precedingCodePoint = 0;

  void _cancelWrap() {
    if (_pendingWrap) buffer.setCursorX(viewWidth - 1);
    _pendingWrap = false;
  }

  @override
  void writeChar(int char) {
    if (char < 0x20 || char == 0x7f) return;
    _precedingCodePoint = char;
    final width = _cellWidth(char);
    if (width == 0) return;

    if (_pendingWrap || (width == 2 && buffer.cursorX == viewWidth - 1)) {
      if (autoWrapMode) {
        index();
        buffer.setCursorX(0);
        buffer.currentLine.isWrapped = true;
      }
      _pendingWrap = false;
    }

    var column = buffer.cursorX;
    if (!autoWrapMode && width == 2 && column == viewWidth - 1) {
      column--;
      buffer.setCursorX(column);
    }
    if (insertMode) buffer.currentLine.insertCells(column, width, cursor);
    buffer.currentLine.setCell(column, char, width, cursor);
    if (width == 2 && column + 1 < viewWidth) {
      buffer.currentLine.setCell(column + 1, 0, 0, cursor);
    }
    if (column + width >= viewWidth) {
      buffer
        ..setCursorX(viewWidth - 1)
        ..cursorGoForward();
      _pendingWrap = true;
    } else {
      buffer.setCursorX(column + width);
    }
  }

  static int _cellWidth(int codePoint) {
    if (codePoint == 0 ||
        codePoint >= 0x300 && codePoint <= 0x36f ||
        codePoint >= 0xfe00 && codePoint <= 0xfe0f) {
      return 0;
    }
    if (codePoint >= 0x1100 && codePoint <= 0x115f ||
        codePoint >= 0x2e80 && codePoint <= 0xa4cf ||
        codePoint >= 0xac00 && codePoint <= 0xd7a3 ||
        codePoint >= 0xf900 && codePoint <= 0xfaff ||
        codePoint >= 0xfe10 && codePoint <= 0xfe6f ||
        codePoint >= 0xff00 && codePoint <= 0xff60 ||
        codePoint >= 0x1f300 && codePoint <= 0x1faff ||
        codePoint >= 0x20000) {
      return 2;
    }
    return 1;
  }

  @override
  void repeatPreviousCharacter(int count) {
    if (_precedingCodePoint == 0) return;
    for (var index = 0; index < count; index++) {
      writeChar(_precedingCodePoint);
    }
  }

  @override
  void backspaceReturn() {
    if (_pendingWrap) {
      _pendingWrap = false;
      buffer.setCursorX(viewWidth - 1);
      if (!_reverseWraparound) buffer.moveCursorX(-1);
    } else if (buffer.cursorX == 0 &&
        _reverseWraparound &&
        autoWrapMode &&
        buffer.cursorY > buffer.marginTop &&
        buffer.cursorY <= buffer.marginBottom &&
        buffer.currentLine.isWrapped) {
      buffer.currentLine.isWrapped = false;
      buffer.setCursor(buffer.viewWidth - 1, buffer.cursorY - 1);
    } else {
      buffer.moveCursorX(-1);
    }
  }

  @override
  void tab() {
    if (_pendingWrap) return;
    final next = nextTabStop(buffer.cursorX);
    buffer.setCursorX(next);
  }

  /// xterm-compatible `nextTabStop` API.
  int nextTabStop(int column) {
    for (
      var index = column + 1;
      index < math.min(viewWidth, _tabStops.length);
      index++
    ) {
      if (_tabStops[index]) return index;
    }
    return viewWidth - 1;
  }

  /// xterm-compatible `previousTabStop` API.
  int previousTabStop(int column) {
    for (var index = column - 1; index >= 0; index--) {
      if (_tabStops[index]) return index;
    }
    return 0;
  }

  @override
  void setTapStop() {
    if (buffer.cursorX < _tabStops.length) _tabStops[buffer.cursorX] = true;
  }

  @override
  void setUnknownDecMode(int mode, bool enabled) {
    if (mode == 45) _reverseWraparound = enabled;
    super.setUnknownDecMode(mode, enabled);
  }

  @override
  void clearTabStopUnderCursor() {
    if (buffer.cursorX < _tabStops.length) _tabStops[buffer.cursorX] = false;
  }

  @override
  void clearAllTabStops() {
    _tabStops.fillRange(0, _tabStops.length, false);
  }

  @override
  void carriageReturn() {
    _cancelWrap();
    super.carriageReturn();
  }

  @override
  void lineFeed() {
    _precedingCodePoint = 0;
    index();
    if (lineFeedMode) buffer.setCursorX(0);
  }

  @override
  void index() {
    _cancelWrap();
    final fullRegion =
        buffer.marginTop == 0 && buffer.marginBottom == viewHeight - 1;
    if (buffer.isInVerticalMargin) {
      if (buffer.cursorY == buffer.marginBottom) {
        if (fullRegion) {
          super.index();
        } else {
          buffer.scrollUp(1);
        }
      } else {
        buffer.moveCursorY(1);
      }
    } else if (buffer.cursorY < viewHeight - 1) {
      buffer.moveCursorY(1);
    } else if (fullRegion) {
      super.index();
    }
  }

  @override
  void nextLine() {
    index();
    buffer.setCursorX(0);
  }

  @override
  void reverseIndex() {
    _cancelWrap();
    super.reverseIndex();
  }

  @override
  void setCursor(int x, int y) {
    _cancelWrap();
    _precedingCodePoint = 0;
    super.setCursor(x, y);
  }

  @override
  void setCursorX(int x) {
    _cancelWrap();
    _precedingCodePoint = 0;
    super.setCursorX(x);
  }

  @override
  void setCursorY(int y) {
    _cancelWrap();
    _precedingCodePoint = 0;
    super.setCursorY(y);
  }

  @override
  void moveCursorX(int offset) {
    _cancelWrap();
    _precedingCodePoint = 0;
    super.moveCursorX(offset);
  }

  @override
  void moveCursorY(int n) {
    _cancelWrap();
    _precedingCodePoint = 0;
    final current = buffer.cursorY;
    final restricted =
        buffer.marginTop != 0 || buffer.marginBottom != viewHeight - 1;
    final minimum = restricted ? buffer.marginTop : 0;
    final maximum = restricted ? buffer.marginBottom : viewHeight - 1;
    buffer.setCursorY((current + n).clamp(minimum, maximum));
  }

  /// xterm-compatible `moveCursorYUnrestricted` API.
  void moveCursorYUnrestricted(int amount) {
    _cancelWrap();
    _precedingCodePoint = 0;
    buffer.setCursorY((buffer.cursorY + amount).clamp(0, viewHeight - 1));
  }

  @override
  void cursorNextLine(int amount) {
    _cancelWrap();
    moveCursorY(math.max(amount, 1));
    buffer.setCursorX(0);
  }

  @override
  void cursorPrecedingLine(int amount) {
    _cancelWrap();
    moveCursorY(-math.max(amount, 1));
    buffer.setCursorX(0);
  }

  @override
  void setMargins(int top, [int? bottom]) {
    _cancelWrap();
    buffer
      ..setVerticalMargins(top, bottom ?? viewHeight - 1)
      ..setCursor(0, 0);
  }

  /// xterm-compatible `setScrollRegion` API.
  void setScrollRegion(String parameters) {
    final values = parameters.isEmpty
        ? const <String>[]
        : parameters.split(';');
    final parsedTop = values.isEmpty ? 0 : int.tryParse(values[0]) ?? 0;
    final top = parsedTop == 0 ? 1 : parsedTop;
    final parsedBottom = values.length < 2 ? 0 : int.tryParse(values[1]) ?? 0;
    final bottom = parsedBottom == 0 || parsedBottom > viewHeight
        ? viewHeight
        : parsedBottom;
    if (bottom <= top) return;
    buffer
      ..setVerticalMargins(top - 1, bottom - 1)
      ..setCursor(0, 0);
    _cancelWrap();
  }

  @override
  void saveCursor() {
    _cancelWrap();
    _savedPendingWrap = false;
    super.saveCursor();
  }

  @override
  void restoreCursor() {
    super.restoreCursor();
    _pendingWrap = _savedPendingWrap;
  }

  @override
  void eraseLineLeft() {
    _cancelWrap();
    buffer.currentLine.eraseRange(0, buffer.cursorX + 1, cursor);
  }

  @override
  void eraseLineRight() {
    _cancelWrap();
    super.eraseLineRight();
  }

  @override
  void eraseLine() {
    _cancelWrap();
    super.eraseLine();
  }

  @override
  void eraseDisplayBelow() {
    _cancelWrap();
    super.eraseDisplayBelow();
  }

  @override
  void eraseDisplayAbove() {
    _cancelWrap();
    super.eraseDisplayAbove();
  }

  @override
  void eraseDisplay() {
    _cancelWrap();
    super.eraseDisplay();
  }

  @override
  void eraseChars(int amount) {
    _cancelWrap();
    final count = math.min(math.max(amount, 1), viewWidth - buffer.cursorX);
    buffer.currentLine.eraseRange(
      buffer.cursorX,
      buffer.cursorX + count,
      cursor,
    );
  }

  @override
  void deleteChars(int amount) {
    _cancelWrap();
    final count = math.min(math.max(amount, 1), viewWidth - buffer.cursorX);
    if (count > 0) {
      buffer.currentLine.removeCells(buffer.cursorX, count, cursor);
    }
  }

  @override
  void insertBlankChars(int amount) {
    _cancelWrap();
    final count = math.min(math.max(amount, 1), viewWidth - buffer.cursorX);
    if (count > 0) {
      buffer.currentLine.insertCells(buffer.cursorX, count, cursor);
    }
  }

  @override
  void insertLines(int amount) {
    _cancelWrap();
    super.insertLines(math.max(amount, 1));
  }

  @override
  void deleteLines(int amount) {
    _cancelWrap();
    super.deleteLines(math.max(amount, 1));
  }

  @override
  void scrollUp(int amount) {
    super.scrollUp(math.max(amount, 1));
  }

  @override
  void scrollDown(int amount) {
    super.scrollDown(math.max(amount, 1));
  }

  /// xterm-compatible `cursorForwardTab` API.
  void cursorForwardTab(int amount) {
    if (_pendingWrap) return;
    for (var index = 0; index < math.max(amount, 1); index++) {
      buffer.setCursorX(nextTabStop(buffer.cursorX));
    }
  }

  /// xterm-compatible `cursorBackwardTab` API.
  void cursorBackwardTab(int amount) {
    _cancelWrap();
    for (var index = 0; index < math.max(amount, 1); index++) {
      buffer.setCursorX(previousTabStop(buffer.cursorX));
    }
  }

  /// xterm-compatible `scrollLeft` API.
  void scrollLeft(int amount) {
    if (!buffer.isInVerticalMargin) return;
    final count = math.min(math.max(amount, 1), viewWidth);
    for (
      var row = buffer.absoluteMarginTop;
      row <= buffer.absoluteMarginBottom;
      row++
    ) {
      buffer.lines[row].removeCells(0, count, cursor);
    }
  }

  /// xterm-compatible `scrollRight` API.
  void scrollRight(int amount) {
    if (!buffer.isInVerticalMargin) return;
    final count = math.min(math.max(amount, 1), viewWidth);
    for (
      var row = buffer.absoluteMarginTop;
      row <= buffer.absoluteMarginBottom;
      row++
    ) {
      buffer.lines[row].insertCells(0, count, cursor);
    }
  }

  /// xterm-compatible `insertColumns` API.
  void insertColumns(int amount) {
    if (!buffer.isInVerticalMargin) return;
    final count = math.min(math.max(amount, 1), viewWidth - buffer.cursorX);
    for (
      var row = buffer.absoluteMarginTop;
      row <= buffer.absoluteMarginBottom;
      row++
    ) {
      buffer.lines[row].insertCells(buffer.cursorX, count, cursor);
    }
  }

  /// xterm-compatible `deleteColumns` API.
  void deleteColumns(int amount) {
    if (!buffer.isInVerticalMargin) return;
    final count = math.min(math.max(amount, 1), viewWidth - buffer.cursorX);
    for (
      var row = buffer.absoluteMarginTop;
      row <= buffer.absoluteMarginBottom;
      row++
    ) {
      buffer.lines[row].removeCells(buffer.cursorX, count, cursor);
    }
  }

  @override
  void useAltBuffer() {
    final x = buffer.cursorX;
    final y = buffer.cursorY;
    final pending = _pendingWrap;
    super.useAltBuffer();
    buffer.setCursor(x, y);
    if (pending) buffer.cursorGoForward();
    _pendingWrap = pending;
  }

  @override
  void useMainBuffer() {
    final x = buffer.cursorX;
    final y = buffer.cursorY;
    final pending = _pendingWrap;
    super.useMainBuffer();
    buffer.setCursor(x, y);
    if (pending) buffer.cursorGoForward();
    _pendingWrap = pending;
  }

  void _enterAlt1049() {
    saveCursor();
    super.clearAltBuffer();
    useAltBuffer();
  }

  void _exitAlt1049() {
    super.useMainBuffer();
    restoreCursor();
  }

  /// Parses sequences absent from xterm.dart at their exact stream position.
  void writeWithParity(String data) {
    var chunkStart = 0;
    var index = 0;
    while (index < data.length) {
      if (data.codeUnitAt(index) != 0x1b ||
          index + 1 >= data.length ||
          data.codeUnitAt(index + 1) != 0x5b) {
        index++;
        continue;
      }
      var finalIndex = index + 2;
      while (finalIndex < data.length) {
        final code = data.codeUnitAt(finalIndex);
        if (code >= 0x40 && code <= 0x7e) break;
        finalIndex++;
      }
      if (finalIndex >= data.length) break;
      final body = data.substring(index + 2, finalIndex);
      final finalByte = data[finalIndex];
      final operation = _parityOperation(body, finalByte);
      if (operation == null) {
        index = finalIndex + 1;
        continue;
      }
      if (chunkStart < index) super.write(data.substring(chunkStart, index));
      operation();
      index = finalIndex + 1;
      chunkStart = index;
    }
    if (chunkStart < data.length) super.write(data.substring(chunkStart));
  }

  void Function()? _parityOperation(String body, String finalByte) {
    if (body == '?1049' && finalByte == 'h') return _enterAlt1049;
    if (body == '?1049' && finalByte == 'l') return _exitAlt1049;
    var parameters = body;
    var intermediates = '';
    var intermediateIndex = -1;
    for (var index = 0; index < body.length; index++) {
      final code = body.codeUnitAt(index);
      if (code >= 0x20 && code <= 0x2f) {
        intermediateIndex = index;
        break;
      }
    }
    if (intermediateIndex >= 0) {
      parameters = body.substring(0, intermediateIndex);
      intermediates = body.substring(intermediateIndex);
    }
    final first = int.tryParse(parameters.split(';').firstOrNull ?? '') ?? 1;
    final amount = math.max(first, 1);
    if (intermediates.isEmpty && finalByte == 'a') {
      return () => moveCursorX(amount);
    }
    if (intermediates.isEmpty && finalByte == 'e') {
      return () => moveCursorYUnrestricted(amount);
    }
    if (intermediates.isEmpty && finalByte == 'I') {
      return () => cursorForwardTab(amount);
    }
    if (intermediates.isEmpty && finalByte == 'Z') {
      return () => cursorBackwardTab(amount);
    }
    if (intermediates.isEmpty && (finalByte == 'H' || finalByte == 'f')) {
      final values = parameters.split(';');
      final row = math.max(int.tryParse(values.firstOrNull ?? '') ?? 1, 1);
      final column = math.max(
        int.tryParse(values.length > 1 ? values[1] : '') ?? 1,
        1,
      );
      return () => setCursor(column - 1, row - 1);
    }
    if (intermediates.isEmpty && parameters.isEmpty && finalByte == 's') {
      return saveCursor;
    }
    if (intermediates.isEmpty && parameters.isEmpty && finalByte == 'u') {
      return restoreCursor;
    }
    if (intermediates.isEmpty && finalByte == 'r') {
      return () => setScrollRegion(parameters);
    }
    if (intermediates == ' ' && finalByte == '@') {
      return () => scrollLeft(amount);
    }
    if (intermediates == ' ' && finalByte == 'A') {
      return () => scrollRight(amount);
    }
    if (intermediates == "'" && finalByte == '}') {
      return () => insertColumns(amount);
    }
    if (intermediates == "'" && finalByte == '~') {
      return () => deleteColumns(amount);
    }
    return null;
  }
}
