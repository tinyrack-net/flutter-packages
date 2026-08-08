part of 'terminal.dart';

/// Mouse tracking protocol selected by DECSET.
enum TerminalMouseTrackingMode {
  /// Mouse reporting is disabled.
  none,

  /// Report only button presses using the legacy X10 protocol.
  x10,

  /// Report button presses and releases.
  vt200,

  /// Report button events and motion while a button is held.
  drag,

  /// Report all pointer motion and button events.
  any,
}

/// Standalone VT input handler ported from xterm.js' common input pipeline.
final class _TerminalCoreEngine {
  _TerminalCoreEngine({
    required this.options,
    required this.unicode,
    required int columns,
    required int rows,
    required int scrollback,
    this.onBell,
    this.onData,
    this.onTitle,
    this.onRequestSendFocus,
  }) : buffer = TerminalBufferNamespace(
         columns: columns,
         rows: rows,
         scrollback: scrollback,
       ),
       _columns = columns,
       _rows = rows {
    _resetTabStops();
  }

  final TerminalBufferNamespace buffer;
  final TerminalOptions options;
  final TerminalUnicodeHandling unicode;
  void Function()? onBell;
  void Function(String data)? onData;
  void Function(String title)? onTitle;
  void Function()? onRequestSendFocus;

  int _columns;
  int _rows;
  int marginTop = 0;
  late int marginBottom = _rows - 1;
  bool insertMode = false;
  bool originMode = false;
  bool autoWrapMode = true;
  bool cursorVisibleMode = true;
  bool cursorKeysMode = false;
  bool appKeypadMode = false;
  bool reportFocusMode = false;
  bool bracketedPasteMode = false;
  bool reverseWraparoundMode = false;
  bool synchronizedOutputMode = false;
  bool win32InputMode = false;
  bool lineFeedMode = false;
  bool applicationEscapeMode = false;
  TerminalMouseTrackingMode mouseMode = TerminalMouseTrackingMode.none;
  bool sgrMouseMode = false;
  bool utf8MouseMode = false;
  bool urxvtMouseMode = false;
  bool alternateScrollMode = false;
  bool sendCursorPosition = false;
  bool _pendingWrap = false;
  int _savedMarginTop = 0;
  int _savedMarginBottom = 0;
  bool _savedOriginMode = false;
  bool _savedAutoWrapMode = true;
  final Set<int> _tabStops = <int>{};
  TerminalCellAttributes _attributes = TerminalCellAttributes();
  TerminalCellAttributes _eraseAttributes = TerminalCellAttributes();
  String _charset = 'B';
  String _g0 = 'B';
  String _g1 = 'B';
  int _activeCharset = 0;
  String _precedingCharacter = '';
  int _precedingJoinState = 0;

  int get columns => _columns;
  int get rows => _rows;

  void write(String input) {
    var index = 0;
    while (index < input.length) {
      final code = input.codeUnitAt(index);
      if (code == 0x1b) {
        _precedingJoinState = 0;
        index = _escape(input, index);
        continue;
      }
      if (code == 0x9b) {
        _precedingJoinState = 0;
        index = _csi(input, index + 1);
        continue;
      }
      if (code < 0x20 || code == 0x7f) {
        _precedingJoinState = 0;
        _precedingCharacter = '';
        _control(code);
        index++;
        continue;
      }
      final rune = _runeAt(input, index);
      _print(String.fromCharCode(rune.value), rune.value);
      index += rune.length;
    }
  }

  ({int value, int length}) _runeAt(String source, int index) {
    final first = source.codeUnitAt(index);
    if (first >= 0xd800 && first <= 0xdbff && index + 1 < source.length) {
      final second = source.codeUnitAt(index + 1);
      if (second >= 0xdc00 && second <= 0xdfff) {
        return (
          value: 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00,
          length: 2,
        );
      }
    }
    return (value: first, length: 1);
  }

  int _escape(String source, int start) {
    if (start + 1 >= source.length) return source.length;
    final next = source.codeUnitAt(start + 1);
    if (next == 0x5b) return _csi(source, start + 2);
    _precedingCharacter = '';
    if (next == 0x5d) return _osc(source, start + 2);
    if (next == 0x50 || next == 0x5f || next == 0x5e) {
      return _consumeString(source, start + 2);
    }
    var cursor = start + 1;
    final intermediates = StringBuffer();
    while (cursor < source.length) {
      final code = source.codeUnitAt(cursor);
      if (code >= 0x20 && code <= 0x2f) {
        intermediates.writeCharCode(code);
        cursor++;
        continue;
      }
      final intermediate = intermediates.toString();
      final finalByte = String.fromCharCode(code);
      if ((intermediate == '(' ||
              intermediate == ')' ||
              intermediate == '*' ||
              intermediate == '+') &&
          code >= 0x30 &&
          code <= 0x7e) {
        _designateCharset(intermediate, finalByte);
      } else {
        _escDispatch(intermediate, finalByte);
      }
      return cursor + 1;
    }
    return source.length;
  }

  int _csi(String source, int start) {
    var cursor = start;
    while (cursor < source.length) {
      final code = source.codeUnitAt(cursor);
      if (code >= 0x40 && code <= 0x7e) break;
      cursor++;
    }
    if (cursor >= source.length) return source.length;
    final body = source.substring(start, cursor);
    var prefix = '';
    var offset = 0;
    if (body.isNotEmpty &&
        body.codeUnitAt(0) >= 0x3c &&
        body.codeUnitAt(0) <= 0x3f) {
      prefix = body[0];
      offset = 1;
    }
    final parameters = StringBuffer();
    final intermediates = StringBuffer();
    for (var index = offset; index < body.length; index++) {
      final code = body.codeUnitAt(index);
      if (code >= 0x30 && code <= 0x3b) {
        parameters.writeCharCode(code);
      } else if (code >= 0x20 && code <= 0x2f) {
        intermediates.writeCharCode(code);
      }
    }
    final params = _params(parameters.toString());
    _csiDispatch(prefix, intermediates.toString(), source[cursor], params);
    return cursor + 1;
  }

  int _osc(String source, int start) {
    var cursor = start;
    while (cursor < source.length) {
      final code = source.codeUnitAt(cursor);
      if (code == 0x07) break;
      if (code == 0x1b &&
          cursor + 1 < source.length &&
          source.codeUnitAt(cursor + 1) == 0x5c) {
        break;
      }
      cursor++;
    }
    final body = source.substring(start, cursor);
    final separator = body.indexOf(';');
    final command = int.tryParse(
      separator < 0 ? body : body.substring(0, separator),
    );
    final data = separator < 0 ? '' : body.substring(separator + 1);
    if (command == 0 || command == 1 || command == 2) onTitle?.call(data);
    if (cursor < source.length && source.codeUnitAt(cursor) == 0x1b) {
      return math.min(source.length, cursor + 2);
    }
    return math.min(source.length, cursor + 1);
  }

  int _consumeString(String source, int start) {
    for (var cursor = start; cursor < source.length; cursor++) {
      final code = source.codeUnitAt(cursor);
      if (code == 0x07) return cursor + 1;
      if (code == 0x1b &&
          cursor + 1 < source.length &&
          source.codeUnitAt(cursor + 1) == 0x5c) {
        return cursor + 2;
      }
    }
    return source.length;
  }

  List<List<int>> _params(String value) {
    if (value.isEmpty) {
      return <List<int>>[
        <int>[0],
      ];
    }
    return value
        .split(';')
        .map(
          (group) => group
              .split(':')
              .map((part) => int.tryParse(part) ?? 0)
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  int _param(List<List<int>> params, int index, [int fallback = 1]) {
    if (index >= params.length || params[index].isEmpty) return fallback;
    final value = params[index][0];
    return value == 0 ? fallback : value;
  }

  void _control(int code) {
    switch (code) {
      case 0x07:
        onBell?.call();
      case 0x08:
        _backspace();
      case 0x09:
        _tab();
      case 0x0a || 0x0b || 0x0c:
        if (options.convertEol) buffer.active.cursorX = 0;
        _lineFeed();
      case 0x0d:
        buffer.active.cursorX = 0;
        _pendingWrap = false;
      case 0x0e:
        _activeCharset = 1;
        _charset = _g1;
      case 0x0f:
        _activeCharset = 0;
        _charset = _g0;
    }
  }

  void _escDispatch(String intermediates, String finalByte) {
    switch ('$intermediates$finalByte') {
      case '7':
        _saveCursor();
      case '8':
        _restoreCursor();
      case 'D':
        _index();
      case 'E':
        _index();
        buffer.active.cursorX = 0;
      case 'H':
        _tabStops.add(buffer.active.cursorX);
      case 'M':
        _reverseIndex();
      case 'c':
        reset();
      case '=':
        appKeypadMode = true;
      case '>':
        appKeypadMode = false;
      case '#8':
        for (var row = 0; row < _rows; row++) {
          final line = buffer.active.getLine(buffer.active.baseY + row)!;
          for (var column = 0; column < _columns; column++) {
            line.setCell(column, 'E', 1, _attributes);
          }
        }
    }
  }

  void _csiDispatch(
    String prefix,
    String intermediates,
    String finalByte,
    List<List<int>> params,
  ) {
    if (finalByte != 'b') _precedingCharacter = '';
    final amount = _param(params, 0);
    if (intermediates == '!' && finalByte == 'p') {
      softReset();
      return;
    }
    if (intermediates == r'$' && finalByte == 'p') {
      _requestMode(prefix, params);
      return;
    }
    if (intermediates == ' ' && (finalByte == '@' || finalByte == 'A')) {
      _shiftColumns(amount, right: finalByte == 'A');
      return;
    }
    if (intermediates == "'" && (finalByte == '}' || finalByte == '~')) {
      _editColumns(amount, insert: finalByte == '}');
      return;
    }
    if (intermediates == '"' && finalByte == 'q') {
      _attributes.protected = params[0][0] == 1;
      return;
    }
    switch (finalByte) {
      case '@':
        _restrictCursor();
        buffer.active.currentLine.insertCells(
          buffer.active.cursorX,
          amount,
          _eraseAttributes,
        );
      case 'A':
        _moveY(-amount);
      case 'B' || 'e':
        _moveY(amount);
      case 'C' || 'a':
        _moveX(amount);
      case 'D':
        _moveX(-amount);
      case 'E':
        _moveY(amount);
        buffer.active.cursorX = 0;
      case 'F':
        _moveY(-amount);
        buffer.active.cursorX = 0;
      case 'G' || '`':
        _setX(amount - 1);
      case 'H' || 'f':
        _setPosition(_param(params, 1) - 1, amount - 1);
      case 'I':
        for (var count = 0; count < amount; count++) {
          _tab();
        }
      case 'J':
        _restrictCursor(maxColumn: _columns);
        _eraseDisplay(params[0][0], prefix == '?');
      case 'K':
        _restrictCursor(maxColumn: _columns);
        _eraseLine(params[0][0], prefix == '?');
      case 'L':
        _restrictCursor();
        if (_inMargins) {
          buffer.active.insertLines(
            buffer.active.cursorY,
            amount,
            bottom: marginBottom,
          );
        }
      case 'M':
        _restrictCursor();
        if (_inMargins) {
          buffer.active.deleteLines(
            buffer.active.cursorY,
            amount,
            bottom: marginBottom,
          );
        }
      case 'P':
        _restrictCursor();
        buffer.active.currentLine.deleteCells(
          buffer.active.cursorX,
          amount,
          _eraseAttributes,
        );
      case 'S':
        for (var count = 0; count < amount; count++) {
          buffer.active.scroll(
            _eraseAttributes,
            top: marginTop,
            bottom: marginBottom,
          );
        }
      case 'T' || '^':
        for (var count = 0; count < amount; count++) {
          buffer.active.reverseScroll(
            TerminalCellAttributes(),
            top: marginTop,
            bottom: marginBottom,
          );
        }
      case 'X':
        _restrictCursor();
        buffer.active.currentLine.erase(
          buffer.active.cursorX,
          buffer.active.cursorX + amount,
          _eraseAttributes,
        );
      case 'Z':
        if (buffer.active.cursorX >= _columns) return;
        for (var count = 0; count < amount; count++) {
          _backTab();
        }
      case 'b':
        if (_precedingCharacter.isNotEmpty) {
          for (var count = 0; count < amount; count++) {
            _print(_precedingCharacter, _precedingCharacter.runes.single);
          }
        }
      case 'c':
        if (prefix == '>') {
          onData?.call('\u001b[>0;276;0c');
        } else {
          onData?.call('\u001b[?1;2c');
        }
      case 'd':
        _setY(amount - 1);
      case 'g':
        if (params[0][0] == 3) {
          _tabStops.clear();
        } else {
          _tabStops.remove(buffer.active.cursorX);
        }
      case 'h' || 'l':
        _setModes(prefix, params, finalByte == 'h');
      case 'm':
        _sgr(params);
      case 'n':
        _deviceStatus(prefix, params[0][0]);
      case 'q':
        if (intermediates == ' ') _setCursorStyle(params[0][0]);
      case 'r':
        if (prefix.isEmpty) _setMargins(params);
      case 's':
        _saveCursor();
      case 'u':
        _restoreCursor();
    }
  }

  void _shiftColumns(int amount, {required bool right}) {
    if (!_inMargins) return;
    for (var row = marginTop; row <= marginBottom; row++) {
      final line = buffer.active.getLine(buffer.active.baseY + row)!;
      if (right) {
        line.insertCells(0, amount, _eraseAttributes);
      } else {
        line.deleteCells(0, amount, _eraseAttributes);
      }
      line.isWrapped = false;
    }
  }

  void _editColumns(int amount, {required bool insert}) {
    if (!_inMargins) return;
    for (var row = marginTop; row <= marginBottom; row++) {
      final line = buffer.active.getLine(buffer.active.baseY + row)!;
      if (insert) {
        line.insertCells(buffer.active.cursorX, amount, _eraseAttributes);
      } else {
        line.deleteCells(buffer.active.cursorX, amount, _eraseAttributes);
      }
      line.isWrapped = false;
    }
  }

  void _print(String value, int codePoint) {
    if (codePoint == 0x00ad) return;
    final mapped = _mapCharset(value);
    final properties = unicode.active.charProperties(
      codePoint,
      _precedingJoinState,
    );
    final width = TerminalUnicodeHandling.extractWidth(properties);
    final shouldJoin = TerminalUnicodeHandling.extractShouldJoin(properties);
    final oldWidth = shouldJoin
        ? TerminalUnicodeHandling.extractWidth(_precedingJoinState)
        : 0;
    _precedingJoinState = properties;
    if (shouldJoin && buffer.active.cursorX > 0) {
      final line = buffer.active.currentLine;
      final previous = line.getCell(buffer.active.cursorX - 1)!;
      final offset = previous.width == 0 ? 2 : 1;
      final index = math.max(0, buffer.active.cursorX - offset);
      line.joinCell(index, mapped, width);
      buffer.active.cursorX = (buffer.active.cursorX + width - oldWidth).clamp(
        0,
        _columns,
      );
      _precedingCharacter += mapped;
      return;
    }
    if (width == 0) {
      final index = _pendingWrap
          ? buffer.active.cursorX
          : math.max(0, buffer.active.cursorX - 1);
      buffer.active.currentLine.appendCombining(index, value);
      return;
    }
    if (buffer.active.cursorX + width - oldWidth > _columns) {
      if (autoWrapMode) {
        final oldLine = buffer.active.currentLine;
        var oldColumn = buffer.active.cursorX - oldWidth;
        _index();
        buffer.active.cursorX = oldWidth;
        buffer.active.currentLine.isWrapped = true;
        while (oldColumn < _columns) {
          oldLine.setCell(oldColumn++, '', 1, _attributes);
        }
      } else {
        buffer.active.cursorX = _columns - 1;
        if (width == 2) return;
      }
    }
    var column = buffer.active.cursorX;
    if (!autoWrapMode && width == 2 && column == _columns - 1) column--;
    if (insertMode) {
      buffer.active.currentLine.insertCells(column, width, _eraseAttributes);
    }
    buffer.active.currentLine.setCell(column, mapped, width, _attributes);
    _precedingCharacter = mapped;
    buffer.active.cursorX = column + width;
  }

  String _mapCharset(String value) {
    if (_charset != '0' || value.length != 1) return value;
    return const <String, String>{
          '`': '◆',
          'a': '▒',
          'f': '°',
          'g': '±',
          'j': '┘',
          'k': '┐',
          'l': '┌',
          'm': '└',
          'n': '┼',
          'q': '─',
          't': '├',
          'u': '┤',
          'v': '┴',
          'w': '┬',
          'x': '│',
        }[value] ??
        value;
  }

  void _designateCharset(String slot, String charset) {
    if (slot == '(' || slot == '*') {
      _g0 = charset;
      if (_activeCharset == 0) _charset = charset;
    } else {
      _g1 = charset;
      if (_activeCharset == 1) _charset = charset;
    }
  }

  void _backspace() {
    buffer.active.cursorX = buffer.active.cursorX.clamp(
      0,
      reverseWraparoundMode ? _columns : _columns - 1,
    );
    if (buffer.active.cursorX > 0) {
      buffer.active.cursorX--;
    } else if (reverseWraparoundMode &&
        autoWrapMode &&
        buffer.active.cursorY > marginTop &&
        buffer.active.currentLine.isWrapped) {
      buffer.active.currentLine.isWrapped = false;
      buffer.active.cursorY--;
      buffer.active.cursorX = _columns - 1;
    }
  }

  void _tab() {
    if (buffer.active.cursorX >= _columns) return;
    for (var column = buffer.active.cursorX + 1; column < _columns; column++) {
      if (_tabStops.contains(column)) {
        buffer.active.cursorX = column;
        return;
      }
    }
    buffer.active.cursorX = _columns - 1;
  }

  void _backTab() {
    for (var column = buffer.active.cursorX - 1; column >= 0; column--) {
      if (_tabStops.contains(column)) {
        buffer.active.cursorX = column;
        return;
      }
    }
    buffer.active.cursorX = 0;
  }

  void _lineFeed() {
    _index();
    if (lineFeedMode) buffer.active.cursorX = 0;
    if (buffer.active.cursorX >= _columns) buffer.active.cursorX--;
    buffer.active.currentLine.isWrapped = false;
  }

  void _index() {
    _pendingWrap = false;
    if (buffer.active.cursorY == marginBottom) {
      buffer.active.scroll(
        _eraseAttributes,
        top: marginTop,
        bottom: marginBottom,
      );
    } else if (buffer.active.cursorY < _rows - 1) {
      buffer.active.cursorY++;
    }
  }

  void _reverseIndex() {
    _pendingWrap = false;
    if (buffer.active.cursorY == marginTop) {
      buffer.active.reverseScroll(
        _eraseAttributes,
        top: marginTop,
        bottom: marginBottom,
      );
    } else if (buffer.active.cursorY > 0) {
      buffer.active.cursorY--;
    }
  }

  bool get _inMargins =>
      buffer.active.cursorY >= marginTop &&
      buffer.active.cursorY <= marginBottom;

  void _moveX(int amount) {
    _pendingWrap = false;
    final current = buffer.active.cursorX.clamp(0, _columns - 1);
    buffer.active.cursorX = (current + amount).clamp(
      0,
      _columns - 1,
    );
  }

  void _moveY(int amount) {
    _pendingWrap = false;
    _restrictCursor();
    final minimum = buffer.active.cursorY >= marginTop ? marginTop : 0;
    final maximum = buffer.active.cursorY <= marginBottom
        ? marginBottom
        : _rows - 1;
    buffer.active.cursorY = (buffer.active.cursorY + amount).clamp(
      minimum,
      maximum,
    );
  }

  void _restrictCursor({int? maxColumn}) {
    buffer.active.cursorX = buffer.active.cursorX.clamp(
      0,
      maxColumn ?? _columns - 1,
    );
    buffer.active.cursorY = buffer.active.cursorY.clamp(
      originMode ? marginTop : 0,
      originMode ? marginBottom : _rows - 1,
    );
  }

  void _setX(int column) {
    _pendingWrap = false;
    buffer.active.cursorX = column.clamp(0, _columns - 1);
  }

  void _setY(int row) {
    _pendingWrap = false;
    final adjusted = originMode ? row + marginTop : row;
    buffer.active.cursorY = adjusted.clamp(
      originMode ? marginTop : 0,
      originMode ? marginBottom : _rows - 1,
    );
  }

  void _setPosition(int column, int row) {
    _setY(row);
    _setX(column);
  }

  void _eraseDisplay(int mode, bool selective) {
    final active = buffer.active;
    switch (mode) {
      case 0:
        active.currentLine.erase(
          active.cursorX,
          _columns,
          _eraseAttributes,
          respectProtection: selective,
        );
        for (var row = active.cursorY + 1; row < _rows; row++) {
          active
              .getLine(active.baseY + row)!
              .erase(
                0,
                _columns,
                _eraseAttributes,
                respectProtection: selective,
              );
        }
      case 1:
        for (var row = 0; row < active.cursorY; row++) {
          active
              .getLine(active.baseY + row)!
              .erase(
                0,
                _columns,
                _eraseAttributes,
                respectProtection: selective,
              );
        }
        active.currentLine.erase(
          0,
          active.cursorX + 1,
          _eraseAttributes,
          respectProtection: selective,
        );
      case 2:
        for (var row = 0; row < _rows; row++) {
          active
              .getLine(active.baseY + row)!
              .erase(
                0,
                _columns,
                _eraseAttributes,
                respectProtection: selective,
              );
        }
      case 3:
        if (identical(active, buffer.normal)) {
          active.clearScrollback();
        }
    }
  }

  void _eraseLine(int mode, bool selective) {
    final line = buffer.active.currentLine;
    switch (mode) {
      case 0:
        line.erase(
          buffer.active.cursorX,
          _columns,
          _eraseAttributes,
          respectProtection: selective,
        );
      case 1:
        line.erase(
          0,
          buffer.active.cursorX + 1,
          _eraseAttributes,
          respectProtection: selective,
        );
      case 2:
        line.erase(
          0,
          _columns,
          _eraseAttributes,
          respectProtection: selective,
        );
    }
  }

  void _sgr(List<List<int>> params) {
    final values = params.isEmpty
        ? <List<int>>[
            <int>[0],
          ]
        : params;
    for (var index = 0; index < values.length; index++) {
      final group = values[index];
      final code = group[0];
      switch (code) {
        case 0:
          _attributes = TerminalCellAttributes();
        case 1:
          _attributes.bold = true;
        case 2:
          _attributes.dim = true;
        case 3:
          _attributes.italic = true;
        case 4:
          _attributes.underline = group.length > 1
              ? switch (group[1]) {
                  2 => TerminalUnderlineStyle.double,
                  3 => TerminalUnderlineStyle.curly,
                  4 => TerminalUnderlineStyle.dotted,
                  5 => TerminalUnderlineStyle.dashed,
                  _ => TerminalUnderlineStyle.single,
                }
              : TerminalUnderlineStyle.single;
        case 5 || 6:
          _attributes.blink = true;
        case 7:
          _attributes.inverse = true;
        case 8:
          _attributes.invisible = true;
        case 9:
          _attributes.strikethrough = true;
        case 21:
          _attributes.underline = TerminalUnderlineStyle.double;
        case 22:
          _attributes
            ..bold = false
            ..dim = false;
        case 221:
          if (options.vtExtensions.kittySgrBoldFaintControl) {
            _attributes.bold = false;
          }
        case 222:
          if (options.vtExtensions.kittySgrBoldFaintControl) {
            _attributes.dim = false;
          }
        case 23:
          _attributes.italic = false;
        case 24:
          _attributes.underline = TerminalUnderlineStyle.none;
        case 25:
          _attributes.blink = false;
        case 27:
          _attributes.inverse = false;
        case 28:
          _attributes.invisible = false;
        case 29:
          _attributes.strikethrough = false;
        case >= 30 && <= 37:
          _attributes.foreground = TerminalCellColor.palette(code - 30);
        case 38:
          final parsed = _extendedColor(params, index);
          _attributes.foreground = parsed.color;
          index = parsed.lastIndex;
        case 39:
          _attributes.foreground = const TerminalCellColor.defaultColor();
        case >= 40 && <= 47:
          _attributes.background = TerminalCellColor.palette(code - 40);
        case 48:
          final parsed = _extendedColor(params, index);
          _attributes.background = parsed.color;
          index = parsed.lastIndex;
        case 49:
          _attributes.background = const TerminalCellColor.defaultColor();
        case 53:
          _attributes.overline = true;
        case 55:
          _attributes.overline = false;
        case 58:
          final parsed = _extendedColor(params, index);
          _attributes.underlineColor = parsed.color;
          index = parsed.lastIndex;
        case 59:
          _attributes.underlineColor = const TerminalCellColor.defaultColor();
        case >= 90 && <= 97:
          _attributes.foreground = TerminalCellColor.palette(code - 90 + 8);
        case >= 100 && <= 107:
          _attributes.background = TerminalCellColor.palette(code - 100 + 8);
      }
    }
    _eraseAttributes = TerminalCellAttributes(
      foreground: _attributes.foreground,
      background: _attributes.background,
    );
  }

  ({TerminalCellColor color, int lastIndex}) _extendedColor(
    List<List<int>> params,
    int index,
  ) {
    final group = params[index];
    if (group.length >= 3 && group[1] == 5) {
      return (
        color: TerminalCellColor.palette(group[2].clamp(0, 255)),
        lastIndex: index,
      );
    }
    if (group.length >= 5 && group[1] == 2) {
      return (
        color: TerminalCellColor.rgb(
          group[group.length - 3].clamp(0, 255),
          group[group.length - 2].clamp(0, 255),
          group.last.clamp(0, 255),
        ),
        lastIndex: index,
      );
    }
    if (index + 2 < params.length && _param(params, index + 1, 0) == 5) {
      return (
        color: TerminalCellColor.palette(
          _param(params, index + 2, 0).clamp(0, 255),
        ),
        lastIndex: index + 2,
      );
    }
    if (index + 4 < params.length && _param(params, index + 1, 0) == 2) {
      return (
        color: TerminalCellColor.rgb(
          _param(params, index + 2, 0).clamp(0, 255),
          _param(params, index + 3, 0).clamp(0, 255),
          _param(params, index + 4, 0).clamp(0, 255),
        ),
        lastIndex: index + 4,
      );
    }
    return (
      color: const TerminalCellColor.defaultColor(),
      lastIndex: index,
    );
  }

  void _setModes(String prefix, List<List<int>> params, bool enabled) {
    for (final group in params) {
      final mode = group[0];
      if (prefix != '?') {
        if (mode == 4) insertMode = enabled;
        if (mode == 20) lineFeedMode = enabled;
        continue;
      }
      switch (mode) {
        case 1:
          cursorKeysMode = enabled;
        case 2:
          if (enabled) {
            _g0 = 'B';
            _g1 = 'B';
            _charset = 'B';
            _activeCharset = 0;
          }
        case 6:
          originMode = enabled;
          _setPosition(0, 0);
        case 7:
          autoWrapMode = enabled;
        case 9:
          mouseMode = enabled
              ? TerminalMouseTrackingMode.x10
              : TerminalMouseTrackingMode.none;
        case 12:
          if (options.quirks.allowSetCursorBlink) {
            options.cursorBlink = enabled;
          }
        case 25:
          cursorVisibleMode = enabled;
        case 45:
          reverseWraparoundMode = enabled;
        case 66:
          appKeypadMode = enabled;
        case 47 || 1047:
          if (enabled) {
            buffer.useAlternate(clear: mode == 1047);
          } else {
            buffer.useNormal();
          }
        case 1000:
          mouseMode = enabled
              ? TerminalMouseTrackingMode.vt200
              : TerminalMouseTrackingMode.none;
        case 1002:
          mouseMode = enabled
              ? TerminalMouseTrackingMode.drag
              : TerminalMouseTrackingMode.none;
        case 1003:
          mouseMode = enabled
              ? TerminalMouseTrackingMode.any
              : TerminalMouseTrackingMode.none;
        case 1004:
          reportFocusMode = enabled;
          if (enabled) onRequestSendFocus?.call();
        case 1005:
        // Removed by xterm.js; consume without changing mouse encoding.
        case 1006:
          sgrMouseMode = enabled;
        case 1015:
        // Removed by xterm.js; consume without changing mouse encoding.
        case 1007:
          alternateScrollMode = enabled;
        case 1048:
          enabled ? _saveCursor() : _restoreCursor();
        case 1049:
          if (enabled) {
            _saveCursor();
            buffer.useAlternate();
          } else {
            buffer.useNormal();
            _restoreCursor();
          }
        case 2004:
          bracketedPasteMode = enabled;
        case 2026:
          synchronizedOutputMode = enabled;
        case 9001:
          if (options.vtExtensions.win32InputMode) {
            win32InputMode = enabled;
          }
      }
    }
  }

  void _deviceStatus(String prefix, int mode) {
    if (mode == 5) {
      onData?.call(prefix == '?' ? '\u001b[?0n' : '\u001b[0n');
    } else if (mode == 6) {
      final row = buffer.active.cursorY + 1;
      final column = buffer.active.cursorX + 1;
      onData?.call(
        prefix == '?' ? '\u001b[?$row;${column}R' : '\u001b[$row;${column}R',
      );
    }
  }

  void _requestMode(String prefix, List<List<int>> params) {
    final private = prefix == '?';
    for (final group in params) {
      final mode = group[0];
      final active = private ? _privateMode(mode) : _ansiMode(mode);
      onData?.call(
        '\u001b[${private ? '?' : ''}$mode;${active ? 1 : 2}\u0024y',
      );
    }
  }

  bool _ansiMode(int mode) => switch (mode) {
    4 => insertMode,
    20 => lineFeedMode,
    _ => false,
  };

  bool _privateMode(int mode) => switch (mode) {
    1 => cursorKeysMode,
    6 => originMode,
    7 => autoWrapMode,
    25 => cursorVisibleMode,
    45 => reverseWraparoundMode,
    1004 => reportFocusMode,
    2004 => bracketedPasteMode,
    2026 => synchronizedOutputMode,
    9001 => win32InputMode,
    _ => false,
  };

  void _setMargins(List<List<int>> params) {
    final top = _param(params, 0) - 1;
    final bottom = params.length > 1 ? _param(params, 1) - 1 : _rows - 1;
    if (top < 0 || bottom <= top || bottom >= _rows) return;
    marginTop = top;
    marginBottom = bottom;
    _setPosition(0, 0);
  }

  void _setCursorStyle(int value) {
    // Cursor shape and blinking are surfaced by TerminalView state.
    sendCursorPosition = value >= 0;
  }

  void _saveCursor() {
    final active = buffer.active;
    active
      ..savedCursorX = active.cursorX
      ..savedCursorY = active.cursorY
      ..savedAttributes = _attributes.copy();
    _savedOriginMode = originMode;
    _savedAutoWrapMode = autoWrapMode;
    _savedMarginTop = marginTop;
    _savedMarginBottom = marginBottom;
  }

  void _restoreCursor() {
    final active = buffer.active;
    active
      ..cursorX = active.savedCursorX.clamp(0, _columns - 1)
      ..cursorY = active.savedCursorY.clamp(0, _rows - 1);
    _attributes = active.savedAttributes.copy();
    originMode = _savedOriginMode;
    autoWrapMode = _savedAutoWrapMode;
    marginTop = _savedMarginTop.clamp(0, _rows - 1);
    marginBottom = _savedMarginBottom.clamp(marginTop, _rows - 1);
    _pendingWrap = false;
  }

  void resize(int columns, int rows) {
    _columns = columns;
    _rows = rows;
    marginTop = 0;
    marginBottom = rows - 1;
    buffer.resize(columns, rows, _eraseAttributes);
    _resetTabStops();
  }

  void _resetTabStops() {
    _tabStops
      ..clear()
      ..addAll(<int>[
        for (
          var column = options.tabStopWidth;
          column < _columns;
          column += options.tabStopWidth
        )
          column,
      ]);
  }

  void softReset() {
    insertMode = false;
    originMode = false;
    autoWrapMode = true;
    cursorVisibleMode = true;
    cursorKeysMode = false;
    appKeypadMode = false;
    reportFocusMode = false;
    bracketedPasteMode = false;
    reverseWraparoundMode = false;
    synchronizedOutputMode = false;
    mouseMode = TerminalMouseTrackingMode.none;
    marginTop = 0;
    marginBottom = _rows - 1;
    _attributes = TerminalCellAttributes();
    _eraseAttributes = TerminalCellAttributes();
    _setPosition(0, 0);
  }

  void reset() {
    buffer
      ..useNormal()
      ..normal.clear()
      ..alternate.clear();
    _g0 = 'B';
    _g1 = 'B';
    _charset = 'B';
    _activeCharset = 0;
    _precedingCharacter = '';
    _precedingJoinState = 0;
    lineFeedMode = false;
    win32InputMode = false;
    softReset();
    _resetTabStops();
  }
}
