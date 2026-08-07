import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:termworld/src/terminal_models.dart';
import 'package:termworld/src/terminal_view_controller.dart';

/// Stateful VT/ANSI terminal core independent of product presentation.
final class TerminalEmulator extends ChangeNotifier {
  /// Creates a terminal emulator.
  factory TerminalEmulator({
    int maxScrollbackLines = 10000,
    ValueChanged<String>? onOutput,
    ValueChanged<TerminalSize>? onResize,
    int columns = 80,
    int rows = 24,
  }) => TerminalEmulator._(
    maxScrollbackLines: maxScrollbackLines,
    onOutput: onOutput,
    onResize: onResize,
    columns: columns,
    rows: rows,
  );

  TerminalEmulator._({
    required this.maxScrollbackLines,
    required this.onOutput,
    required this.onResize,
    required this._columns,
    required this._rows,
  }) {
    _resetBuffers();
  }

  /// Maximum retained main-buffer lines.
  final int maxScrollbackLines;

  /// Receives bytes intended for the connected terminal process.
  ValueChanged<String>? onOutput;

  /// Receives viewport size changes.
  ValueChanged<TerminalSize>? onResize;

  late List<List<TerminalCell>> _main;
  late List<List<TerminalCell>> _alternate;
  bool _usingAlternate = false;
  int _columns;
  int _rows;
  int _cursorColumn = 0;
  int _cursorRow = 0;
  int _savedColumn = 0;
  int _savedRow = 0;
  int _scrollTop = 0;
  late int _scrollBottom = _rows - 1;
  bool _wraparound = true;
  bool _cursorVisible = true;
  bool _bracketedPaste = false;
  bool _applicationCursor = false;
  bool _applicationKeypad = false;
  bool _originMode = false;
  bool _sgrMouse = false;
  TerminalMouseTrackingMode _mouseTracking = TerminalMouseTrackingMode.none;
  TerminalCellStyle _style = const TerminalCellStyle();
  _ParserState _parserState = _ParserState.ground;
  final StringBuffer _sequence = StringBuffer();
  String _title = '';

  /// Visible columns.
  int get columns => _columns;

  /// Visible rows.
  int get rows => _rows;

  /// Cursor column.
  int get cursorColumn => _cursorColumn;

  /// Cursor row in the active buffer.
  int get cursorRow => _cursorRow;

  /// Whether the cursor is visible.
  bool get cursorVisible => _cursorVisible;

  /// Current terminal title reported through OSC 0/2.
  String get title => _title;

  /// Whether bracketed-paste mode is active.
  bool get bracketedPasteMode => _bracketedPaste;

  /// Mouse events currently requested by the terminal application.
  TerminalMouseTrackingMode get mouseTrackingMode => _mouseTracking;

  List<List<TerminalCell>> get _active => _usingAlternate ? _alternate : _main;

  /// Immutable view of active-buffer lines, including scrollback.
  List<List<TerminalCell>> get lines => List<List<TerminalCell>>.unmodifiable(
    _active.map(List<TerminalCell>.unmodifiable),
  );

  /// Feeds decoded terminal output into the emulator.
  void write(String data) {
    data.characters.forEach(_consume);
    notifyListeners();
  }

  /// Sends direct user input to the connected process.
  void input(String data) => onOutput?.call(data);

  /// Sends pasted text, honoring DEC bracketed-paste mode.
  void paste(String data) => input(
    _bracketedPaste ? '\u001b[200~$data\u001b[201~' : data,
  );

  /// Resizes the viewport and reports it to the process.
  void resize(int columns, int rows) {
    if (columns < 1 || rows < 1 || (columns == _columns && rows == _rows)) {
      return;
    }
    _columns = columns;
    _rows = rows;
    _resizeBuffer(_main);
    _resizeBuffer(_alternate);
    _scrollTop = 0;
    _scrollBottom = rows - 1;
    _cursorColumn = _cursorColumn.clamp(0, columns - 1);
    _cursorRow = _cursorRow.clamp(0, _active.length - 1);
    notifyListeners();
    onResize?.call(TerminalSize(columns: columns, rows: rows));
  }

  /// Selects every retained line.
  void selectAll(TerminalViewController controller) {
    final active = _active;
    controller.setSelection(
      TerminalSelection(
        const TerminalPosition(0, 0),
        TerminalPosition(_columns, math.max(0, active.length - 1)),
      ),
    );
  }

  /// Selects the whitespace-delimited word containing [position].
  void selectWordAt(
    TerminalViewController controller,
    TerminalPosition position,
  ) {
    final row = position.row.clamp(0, _active.length - 1);
    final line = _active[row];
    var start = position.column.clamp(0, _columns - 1);
    var end = start;
    bool isWord(int column) =>
        line[column].width == 0 || line[column].text.trim().isNotEmpty;
    if (!isWord(start)) return;
    while (start > 0 && isWord(start - 1)) {
      start--;
    }
    while (end < _columns && isWord(end)) {
      end++;
    }
    controller.setSelection(
      TerminalSelection(
        TerminalPosition(start, row),
        TerminalPosition(end, row),
      ),
    );
  }

  /// Selects the complete retained line containing [row].
  void selectLineAt(TerminalViewController controller, int row) {
    final safeRow = row.clamp(0, _active.length - 1);
    controller.setSelection(
      TerminalSelection(
        TerminalPosition(0, safeRow),
        TerminalPosition(_columns, safeRow),
      ),
    );
  }

  /// Returns the text in the controller's selection.
  String? selectedText(TerminalViewController controller) {
    final selection = controller.selection;
    if (selection == null) return null;
    final result = StringBuffer();
    final startRow = selection.start.row.clamp(0, _active.length - 1);
    final endRow = selection.end.row.clamp(startRow, _active.length - 1);
    for (var row = startRow; row <= endRow; row++) {
      final start = row == startRow ? selection.start.column : 0;
      final end = row == endRow ? selection.end.column : _columns;
      final text = _active[row]
          .skip(start.clamp(0, _columns))
          .take((end - start).clamp(0, _columns))
          .where((cell) => cell.width != 0)
          .map((cell) => cell.text)
          .join()
          .trimRight();
      result.write(text);
      if (row != endRow) result.writeln();
    }
    return result.toString();
  }

  void _resetBuffers() {
    _main = List<List<TerminalCell>>.generate(_rows, (_) => _blankLine());
    _alternate = List<List<TerminalCell>>.generate(
      _rows,
      (_) => _blankLine(),
    );
  }

  List<TerminalCell> _blankLine() => List<TerminalCell>.filled(
    _columns,
    const TerminalCell(''),
    growable: true,
  );

  void _resizeBuffer(List<List<TerminalCell>> buffer) {
    for (var index = 0; index < buffer.length; index++) {
      final old = buffer[index];
      buffer[index] = List<TerminalCell>.generate(
        _columns,
        (column) => column < old.length ? old[column] : const TerminalCell(''),
      );
    }
    while (buffer.length < _rows) {
      buffer.add(_blankLine());
    }
  }

  void _consume(String character) {
    switch (_parserState) {
      case _ParserState.ground:
        if (character == '\u001b') {
          _parserState = _ParserState.escape;
        } else {
          _consumeGround(character);
        }
      case _ParserState.escape:
        if (character == '[') {
          _sequence.clear();
          _parserState = _ParserState.csi;
        } else if (character == ']') {
          _sequence.clear();
          _parserState = _ParserState.osc;
        } else {
          _escape(character);
          _parserState = _ParserState.ground;
        }
      case _ParserState.csi:
        final code = character.codeUnitAt(0);
        if (code >= 0x40 && code <= 0x7e) {
          _csi(character, _sequence.toString());
          _sequence.clear();
          _parserState = _ParserState.ground;
        } else if (_sequence.length < 256) {
          _sequence.write(character);
        } else {
          _sequence.clear();
          _parserState = _ParserState.ground;
        }
      case _ParserState.osc:
        if (character == '\u0007') {
          _osc(_sequence.toString());
          _sequence.clear();
          _parserState = _ParserState.ground;
        } else if (character == '\u001b') {
          _parserState = _ParserState.oscEscape;
        } else if (_sequence.length < 4096) {
          _sequence.write(character);
        }
      case _ParserState.oscEscape:
        if (character == r'\') {
          _osc(_sequence.toString());
          _sequence.clear();
          _parserState = _ParserState.ground;
        } else {
          _sequence
            ..write('\u001b')
            ..write(character);
          _parserState = _ParserState.osc;
        }
    }
  }

  void _consumeGround(String character) {
    switch (character) {
      case '\u0000':
      case '\u0007':
        return;
      case '\b':
        _cursorColumn = math.max(0, _cursorColumn - 1);
        return;
      case '\t':
        _cursorColumn = math.min(_columns - 1, ((_cursorColumn ~/ 8) + 1) * 8);
        return;
      case '\n':
      case '\u000b':
      case '\f':
        _lineFeed();
        return;
      case '\r':
        _cursorColumn = 0;
        return;
    }
    _putGrapheme(character);
  }

  void _putGrapheme(String text) {
    final width = _cellWidth(text);
    if (_cursorColumn >= _columns ||
        (width == 2 && _cursorColumn == _columns - 1)) {
      if (!_wraparound) {
        _cursorColumn = _columns - width;
      } else {
        _cursorColumn = 0;
        _lineFeed();
      }
    }
    final line = _active[_cursorRow];
    line[_cursorColumn] = TerminalCell(text, width: width, style: _style);
    if (width == 2 && _cursorColumn + 1 < _columns) {
      line[_cursorColumn + 1] = TerminalCell('', width: 0, style: _style);
    }
    _cursorColumn += width;
  }

  int _cellWidth(String grapheme) {
    final runes = grapheme.runes;
    if (runes.isEmpty) return 1;
    if (grapheme.characters.length == 1 &&
        (grapheme.contains('\u200d') || grapheme.contains('\ufe0f'))) {
      return 2;
    }
    final rune = runes.first;
    if ((rune >= 0x1100 && rune <= 0x115f) ||
        (rune >= 0x2e80 && rune <= 0xa4cf) ||
        (rune >= 0xac00 && rune <= 0xd7a3) ||
        (rune >= 0xf900 && rune <= 0xfaff) ||
        (rune >= 0xfe10 && rune <= 0xfe6f) ||
        (rune >= 0xff00 && rune <= 0xff60) ||
        (rune >= 0x1f300 && rune <= 0x1faff) ||
        rune >= 0x20000) {
      return 2;
    }
    return 1;
  }

  void _lineFeed() {
    final viewportTop = math.max(0, _active.length - _rows);
    final bottom = viewportTop + _scrollBottom;
    if (_cursorRow < bottom) {
      _cursorRow++;
      return;
    }
    if (_usingAlternate || _scrollTop != 0) {
      final top = viewportTop + _scrollTop;
      _active
        ..removeAt(top)
        ..insert(bottom, _blankLine());
    } else {
      _main.add(_blankLine());
      if (_main.length > maxScrollbackLines + _rows) {
        _main.removeAt(0);
      }
      _cursorRow = _main.length - 1;
    }
  }

  void _escape(String finalByte) {
    switch (finalByte) {
      case '7':
        _saveCursor();
      case '8':
        _restoreCursor();
      case 'D':
        _lineFeed();
      case 'E':
        _cursorColumn = 0;
        _lineFeed();
      case 'M':
        if (_cursorRow > 0) _cursorRow--;
      case 'c':
        _cursorColumn = 0;
        _cursorRow = 0;
        _style = const TerminalCellStyle();
        _resetBuffers();
      case '=':
        _applicationKeypad = true;
      case '>':
        _applicationKeypad = false;
    }
  }

  void _csi(String finalByte, String raw) {
    final private = raw.startsWith('?');
    final body = private ? raw.substring(1) : raw;
    final params = body.isEmpty
        ? <int>[0]
        : body.split(';').map((part) => int.tryParse(part) ?? 0).toList();
    int value(int index, [int fallback = 1]) =>
        index < params.length && params[index] != 0 ? params[index] : fallback;
    final viewportTop = math.max(0, _active.length - _rows);
    switch (finalByte) {
      case 'A':
        _cursorRow = math.max(viewportTop, _cursorRow - value(0));
      case 'B':
        _cursorRow = math.min(_active.length - 1, _cursorRow + value(0));
      case 'C':
        _cursorColumn = math.min(_columns - 1, _cursorColumn + value(0));
      case 'D':
        _cursorColumn = math.max(0, _cursorColumn - value(0));
      case 'E':
        _cursorColumn = 0;
        _cursorRow = math.min(_active.length - 1, _cursorRow + value(0));
      case 'F':
        _cursorColumn = 0;
        _cursorRow = math.max(viewportTop, _cursorRow - value(0));
      case 'G':
        _cursorColumn = (value(0) - 1).clamp(0, _columns - 1);
      case 'H':
      case 'f':
        final origin = _originMode ? _scrollTop : 0;
        _cursorRow = (viewportTop + origin + value(0) - 1).clamp(
          viewportTop,
          _active.length - 1,
        );
        _cursorColumn = (value(1) - 1).clamp(0, _columns - 1);
      case 'J':
        _eraseDisplay(params.first);
      case 'K':
        _eraseLine(params.first);
      case 'L':
        for (var index = 0; index < value(0); index++) {
          _active
            ..insert(_cursorRow, _blankLine())
            ..removeAt(viewportTop + _scrollBottom + 1);
        }
      case 'M':
        for (var index = 0; index < value(0); index++) {
          _active
            ..removeAt(_cursorRow)
            ..insert(viewportTop + _scrollBottom, _blankLine());
        }
      case '@':
        final line = _active[_cursorRow];
        for (var index = 0; index < value(0); index++) {
          line
            ..insert(_cursorColumn, const TerminalCell(''))
            ..removeLast();
        }
      case 'P':
        final line = _active[_cursorRow];
        for (var index = 0; index < value(0); index++) {
          line
            ..removeAt(_cursorColumn)
            ..add(const TerminalCell(''));
        }
      case 'm':
        _sgr(params);
      case 'r':
        _scrollTop = (value(0) - 1).clamp(0, _rows - 1);
        _scrollBottom = (value(1, _rows) - 1).clamp(_scrollTop, _rows - 1);
        _cursorColumn = 0;
        _cursorRow = viewportTop + (_originMode ? _scrollTop : 0);
      case 's':
        _saveCursor();
      case 'u':
        _restoreCursor();
      case 'h':
      case 'l':
        _setMode(params, enabled: finalByte == 'h', private: private);
    }
  }

  void _eraseDisplay(int mode) {
    if (mode == 2 || mode == 3) {
      for (var row = 0; row < _active.length; row++) {
        _active[row] = _blankLine();
      }
      return;
    }
    if (mode == 0) {
      _eraseLine(0);
      for (var row = _cursorRow + 1; row < _active.length; row++) {
        _active[row] = _blankLine();
      }
    } else if (mode == 1) {
      for (var row = 0; row < _cursorRow; row++) {
        _active[row] = _blankLine();
      }
      _eraseLine(1);
    }
  }

  void _eraseLine(int mode) {
    final line = _active[_cursorRow];
    final start = mode == 0 ? _cursorColumn : 0;
    final end = mode == 1 ? _cursorColumn + 1 : _columns;
    for (var column = start; column < end; column++) {
      line[column] = const TerminalCell('');
    }
  }

  void _sgr(List<int> params) {
    final values = params.isEmpty ? <int>[0] : params;
    for (var index = 0; index < values.length; index++) {
      final param = values[index];
      if (param == 0) {
        _style = const TerminalCellStyle();
      } else if (param == 1) {
        _style = _style.copyWith(bold: true);
      } else if (param == 3) {
        _style = _style.copyWith(italic: true);
      } else if (param == 4) {
        _style = _style.copyWith(underline: true);
      } else if (param == 7) {
        _style = _style.copyWith(inverse: true);
      } else if (param == 22) {
        _style = _style.copyWith(bold: false);
      } else if (param == 23) {
        _style = _style.copyWith(italic: false);
      } else if (param == 24) {
        _style = _style.copyWith(underline: false);
      } else if (param == 27) {
        _style = _style.copyWith(inverse: false);
      } else if (param == 39) {
        _style = _style.copyWith(clearForeground: true);
      } else if (param == 49) {
        _style = _style.copyWith(clearBackground: true);
      } else if ((param >= 30 && param <= 37) || (param >= 90 && param <= 97)) {
        final paletteIndex = param >= 90 ? param - 82 : param - 30;
        _style = _style.copyWith(
          foreground: defaultTerminalPalette[paletteIndex],
        );
      } else if ((param >= 40 && param <= 47) ||
          (param >= 100 && param <= 107)) {
        final paletteIndex = param >= 100 ? param - 92 : param - 40;
        _style = _style.copyWith(
          background: defaultTerminalPalette[paletteIndex],
        );
      } else if ((param == 38 || param == 48) && index + 1 < values.length) {
        final foreground = param == 38;
        final mode = values[++index];
        Color? color;
        if (mode == 5 && index + 1 < values.length) {
          color = _indexedColor(values[++index]);
        } else if (mode == 2 && index + 3 < values.length) {
          color = Color.fromARGB(
            0xff,
            values[++index].clamp(0, 255),
            values[++index].clamp(0, 255),
            values[++index].clamp(0, 255),
          );
        }
        if (color != null) {
          _style = foreground
              ? _style.copyWith(foreground: color)
              : _style.copyWith(background: color);
        }
      }
    }
  }

  Color _indexedColor(int index) {
    final safe = index.clamp(0, 255);
    if (safe < 16) return defaultTerminalPalette[safe];
    if (safe >= 232) {
      final level = 8 + (safe - 232) * 10;
      return Color.fromARGB(0xff, level, level, level);
    }
    final cube = safe - 16;
    int component(int value) => value == 0 ? 0 : 55 + value * 40;
    return Color.fromARGB(
      0xff,
      component(cube ~/ 36),
      component((cube ~/ 6) % 6),
      component(cube % 6),
    );
  }

  void _setMode(
    List<int> params, {
    required bool enabled,
    required bool private,
  }) {
    if (!private) return;
    for (final param in params) {
      switch (param) {
        case 1:
          _applicationCursor = enabled;
        case 6:
          _originMode = enabled;
        case 7:
          _wraparound = enabled;
        case 25:
          _cursorVisible = enabled;
        case 47:
        case 1047:
        case 1049:
          _usingAlternate = enabled;
          if (enabled) {
            _alternate = List<List<TerminalCell>>.generate(
              _rows,
              (_) => _blankLine(),
            );
            _cursorColumn = 0;
            _cursorRow = 0;
          } else {
            _cursorRow = math.max(0, _main.length - _rows);
            _cursorColumn = 0;
          }
        case 2004:
          _bracketedPaste = enabled;
        case 1000:
          _mouseTracking = enabled
              ? TerminalMouseTrackingMode.press
              : TerminalMouseTrackingMode.none;
        case 1002:
          _mouseTracking = enabled
              ? TerminalMouseTrackingMode.buttonEvent
              : TerminalMouseTrackingMode.none;
        case 1003:
          _mouseTracking = enabled
              ? TerminalMouseTrackingMode.anyEvent
              : TerminalMouseTrackingMode.none;
        case 1006:
          _sgrMouse = enabled;
      }
    }
  }

  void _saveCursor() {
    _savedColumn = _cursorColumn;
    _savedRow = _cursorRow;
  }

  void _restoreCursor() {
    _cursorColumn = _savedColumn.clamp(0, _columns - 1);
    _cursorRow = _savedRow.clamp(0, _active.length - 1);
  }

  void _osc(String sequence) {
    final separator = sequence.indexOf(';');
    if (separator < 0) return;
    final command = sequence.substring(0, separator);
    if (command == '0' || command == '2') {
      _title = sequence.substring(separator + 1);
    }
  }

  /// Escape sequence for a key and its active modifiers.
  ///
  /// Printable text without Control, Alt, or Meta remains owned by the
  /// platform text-input client and therefore returns `null`.
  String? keySequence(
    LogicalKeyboardKey key, {
    String? character,
    bool shift = false,
    bool alt = false,
    bool control = false,
    bool meta = false,
  }) {
    final modifier =
        1 + (shift ? 1 : 0) + (alt || meta ? 2 : 0) + (control ? 4 : 0);
    final modified = modifier != 1;
    final applicationPrefix = _applicationCursor ? '\u001bO' : '\u001b[';
    String cursor(String finalByte) => modified
        ? '\u001b[1;$modifier$finalByte'
        : '$applicationPrefix$finalByte';
    String tilde(int code) =>
        modified ? '\u001b[$code;$modifier~' : '\u001b[$code~';
    if (key == LogicalKeyboardKey.arrowUp) return cursor('A');
    if (key == LogicalKeyboardKey.arrowDown) return cursor('B');
    if (key == LogicalKeyboardKey.arrowRight) return cursor('C');
    if (key == LogicalKeyboardKey.arrowLeft) return cursor('D');
    if (key == LogicalKeyboardKey.home) {
      return modified ? '\u001b[1;${modifier}H' : '\u001b[H';
    }
    if (key == LogicalKeyboardKey.end) {
      return modified ? '\u001b[1;${modifier}F' : '\u001b[F';
    }
    if (key == LogicalKeyboardKey.insert) return tilde(2);
    if (key == LogicalKeyboardKey.delete) return tilde(3);
    if (key == LogicalKeyboardKey.pageUp) return tilde(5);
    if (key == LogicalKeyboardKey.pageDown) return tilde(6);
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return alt || meta ? '\u001b\r' : '\r';
    }
    if (key == LogicalKeyboardKey.backspace) {
      final deletion = control ? '\b' : '\u007f';
      return alt || meta ? '\u001b$deletion' : deletion;
    }
    if (key == LogicalKeyboardKey.tab) {
      if (shift && !alt && !control && !meta) return '\u001b[Z';
      return alt || meta ? '\u001b\t' : '\t';
    }
    if (key == LogicalKeyboardKey.escape) {
      return alt || meta ? '\u001b\u001b' : '\u001b';
    }
    final functionKeys = <LogicalKeyboardKey, (String, int?)>{
      LogicalKeyboardKey.f1: ('P', null),
      LogicalKeyboardKey.f2: ('Q', null),
      LogicalKeyboardKey.f3: ('R', null),
      LogicalKeyboardKey.f4: ('S', null),
      LogicalKeyboardKey.f5: ('', 15),
      LogicalKeyboardKey.f6: ('', 17),
      LogicalKeyboardKey.f7: ('', 18),
      LogicalKeyboardKey.f8: ('', 19),
      LogicalKeyboardKey.f9: ('', 20),
      LogicalKeyboardKey.f10: ('', 21),
      LogicalKeyboardKey.f11: ('', 23),
      LogicalKeyboardKey.f12: ('', 24),
    };
    if (functionKeys[key] case (_, final code?)) {
      return tilde(code);
    } else if (functionKeys[key] case (final finalByte, null)) {
      return modified ? '\u001b[1;$modifier$finalByte' : '\u001bO$finalByte';
    }
    if (_applicationKeypad) {
      final keypad = <LogicalKeyboardKey, String>{
        LogicalKeyboardKey.numpad0: 'p',
        LogicalKeyboardKey.numpad1: 'q',
        LogicalKeyboardKey.numpad2: 'r',
        LogicalKeyboardKey.numpad3: 's',
        LogicalKeyboardKey.numpad4: 't',
        LogicalKeyboardKey.numpad5: 'u',
        LogicalKeyboardKey.numpad6: 'v',
        LogicalKeyboardKey.numpad7: 'w',
        LogicalKeyboardKey.numpad8: 'x',
        LogicalKeyboardKey.numpad9: 'y',
        LogicalKeyboardKey.numpadDecimal: 'n',
        LogicalKeyboardKey.numpadAdd: 'k',
        LogicalKeyboardKey.numpadSubtract: 'm',
        LogicalKeyboardKey.numpadMultiply: 'j',
        LogicalKeyboardKey.numpadDivide: 'o',
      };
      final finalByte = keypad[key];
      if (finalByte != null) {
        final sequence = '\u001bO$finalByte';
        return alt || meta ? '\u001b$sequence' : sequence;
      }
    }
    if (character != null && character.isNotEmpty) {
      if (control && !shift) {
        final rune = character.toLowerCase().runes.first;
        if (rune >= 0x61 && rune <= 0x7a) {
          final sequence = String.fromCharCode(rune - 0x60);
          return alt || meta ? '\u001b$sequence' : sequence;
        }
      }
      if (alt || meta) return '\u001b$character';
    }
    return null;
  }

  /// Encodes one pointer event according to the active DEC mouse modes.
  String? mouseReport({
    required int button,
    required int column,
    required int row,
    required bool pressed,
    bool motion = false,
    bool shift = false,
    bool meta = false,
    bool control = false,
  }) {
    if (_mouseTracking == TerminalMouseTrackingMode.none ||
        (motion && _mouseTracking == TerminalMouseTrackingMode.press) ||
        (motion &&
            _mouseTracking == TerminalMouseTrackingMode.buttonEvent &&
            button == 3)) {
      return null;
    }
    var code = pressed ? button.clamp(0, 2) : 3;
    if (motion) code += 32;
    if (shift) code += 4;
    if (meta) code += 8;
    if (control) code += 16;
    final x = column.clamp(0, _columns - 1) + 1;
    final y = row.clamp(0, _rows - 1) + 1;
    if (_sgrMouse) return '\u001b[<$code;$x;$y${pressed ? 'M' : 'm'}';
    return '\u001b[M${String.fromCharCode(code + 32)}'
        '${String.fromCharCode((x + 32).clamp(0, 255))}'
        '${String.fromCharCode((y + 32).clamp(0, 255))}';
  }
}

enum _ParserState { ground, escape, csi, osc, oscEscape }
