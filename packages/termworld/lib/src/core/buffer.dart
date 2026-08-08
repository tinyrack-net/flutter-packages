import 'package:flutter/foundation.dart';
import 'package:termworld/src/core/event.dart';

/// Terminal buffer kind.
enum TerminalBufferType {
  /// The normal buffer with scrollback history.
  normal,

  /// The alternate screen buffer without scrollback history.
  alternate,
}

/// Encoded terminal color kind.
enum TerminalColorMode {
  /// The terminal's configured default color.
  defaultColor,

  /// An indexed color from the ANSI 256-color palette.
  palette,

  /// A 24-bit red, green and blue color.
  rgb,
}

/// Underline rendering style.
enum TerminalUnderlineStyle {
  /// No underline.
  none,

  /// A single straight underline.
  single,

  /// A double straight underline.
  double,

  /// A curly underline.
  curly,

  /// A dotted underline.
  dotted,

  /// A dashed underline.
  dashed,
}

/// An immutable position in the backing buffer.
@immutable
final class TerminalBufferPosition {
  /// Creates a zero-based buffer position.
  const TerminalBufferPosition(this.x, this.y);

  /// Zero-based column.
  final int x;

  /// Zero-based absolute buffer row.
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TerminalBufferPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// An inclusive terminal buffer range.
@immutable
final class TerminalBufferRange {
  /// Creates an inclusive range from [start] through [end].
  const TerminalBufferRange({required this.start, required this.end});

  /// First selected cell.
  final TerminalBufferPosition start;

  /// Last selected cell.
  final TerminalBufferPosition end;
}

/// A color encoded exactly as xterm's default, indexed or RGB color.
@immutable
final class TerminalCellColor {
  /// Creates the configured default color.
  const TerminalCellColor.defaultColor()
    : mode = TerminalColorMode.defaultColor,
      value = 0;

  /// Creates an ANSI palette color with [index].
  const TerminalCellColor.palette(int index)
    : mode = TerminalColorMode.palette,
      value = index;

  /// Creates a 24-bit color from its component values.
  const TerminalCellColor.rgb(int red, int green, int blue)
    : mode = TerminalColorMode.rgb,
      value = red << 16 | green << 8 | blue;

  /// Encoding used by [value].
  final TerminalColorMode mode;

  /// Palette index or packed `0xRRGGBB` value.
  final int value;

  /// Red component of an RGB color.
  int get red => value >> 16 & 0xff;

  /// Green component of an RGB color.
  int get green => value >> 8 & 0xff;

  /// Blue component of an RGB color.
  int get blue => value & 0xff;

  @override
  bool operator ==(Object other) =>
      other is TerminalCellColor && other.mode == mode && other.value == value;

  @override
  int get hashCode => Object.hash(mode, value);
}

/// Mutable cell attributes used internally by the input handler.
final class TerminalCellAttributes {
  /// Creates a mutable set of terminal cell attributes.
  TerminalCellAttributes({
    this.foreground = const TerminalCellColor.defaultColor(),
    this.background = const TerminalCellColor.defaultColor(),
    this.underlineColor = const TerminalCellColor.defaultColor(),
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = TerminalUnderlineStyle.none,
    this.blink = false,
    this.inverse = false,
    this.invisible = false,
    this.strikethrough = false,
    this.overline = false,
    this.protected = false,
  });

  /// Foreground color.
  TerminalCellColor foreground;

  /// Background color.
  TerminalCellColor background;

  /// Underline color.
  TerminalCellColor underlineColor;

  /// Whether bold intensity is enabled.
  bool bold;

  /// Whether faint intensity is enabled.
  bool dim;

  /// Whether italic rendering is enabled.
  bool italic;

  /// Underline style.
  TerminalUnderlineStyle underline;

  /// Whether blinking is enabled.
  bool blink;

  /// Whether foreground and background are inverted.
  bool inverse;

  /// Whether the cell content is hidden.
  bool invisible;

  /// Whether strikethrough is enabled.
  bool strikethrough;

  /// Whether overline is enabled.
  bool overline;

  /// Whether selective erase protects the cell.
  bool protected;

  /// Returns an independent copy of these attributes.
  TerminalCellAttributes copy() => TerminalCellAttributes(
    foreground: foreground,
    background: background,
    underlineColor: underlineColor,
    bold: bold,
    dim: dim,
    italic: italic,
    underline: underline,
    blink: blink,
    inverse: inverse,
    invisible: invisible,
    strikethrough: strikethrough,
    overline: overline,
    protected: protected,
  );

  /// Whether every observable attribute equals [other].
  bool sameAs(TerminalCellAttributes other) =>
      foreground == other.foreground &&
      background == other.background &&
      underlineColor == other.underlineColor &&
      bold == other.bold &&
      dim == other.dim &&
      italic == other.italic &&
      underline == other.underline &&
      blink == other.blink &&
      inverse == other.inverse &&
      invisible == other.invisible &&
      strikethrough == other.strikethrough &&
      overline == other.overline &&
      protected == other.protected;
}

final class _CellData {
  _CellData({
    this.chars = '',
    this.width = 1,
    TerminalCellAttributes? attributes,
  }) : attributes = attributes?.copy() ?? TerminalCellAttributes();

  String chars;
  int width;
  TerminalCellAttributes attributes;

  int get code => chars.runes.lastOrNull ?? 0;

  _CellData copy() => _CellData(
    chars: chars,
    width: width,
    attributes: attributes,
  );

  void reset(TerminalCellAttributes value) {
    chars = '';
    width = 1;
    attributes = value.copy();
  }
}

extension on Iterable<int> {
  int? get lastOrNull {
    int? result;
    for (final value in this) {
      result = value;
    }
    return result;
  }
}

/// Public read-only view of one terminal cell.
final class TerminalCell {
  TerminalCell._(this._cell);

  final _CellData _cell;

  /// Display width in terminal columns.
  int get width => _cell.width;

  /// Grapheme content, empty for a wide-character continuation cell.
  String get chars => width == 0 ? '' : _cell.chars;

  /// Last Unicode code point in [chars], or zero for an empty cell.
  int get code => _cell.code;

  /// Encoded foreground palette index or RGB value.
  int get foreground => _cell.attributes.foreground.value;

  /// Encoded background palette index or RGB value.
  int get background => _cell.attributes.background.value;

  /// Foreground color encoding.
  TerminalColorMode get foregroundMode => _cell.attributes.foreground.mode;

  /// Background color encoding.
  TerminalColorMode get backgroundMode => _cell.attributes.background.mode;

  /// Color used to draw an underline.
  TerminalCellColor get underlineColor => _cell.attributes.underlineColor;

  /// Style used to draw an underline.
  TerminalUnderlineStyle get underlineStyle => _cell.attributes.underline;

  /// Whether bold intensity is enabled.
  bool get isBold => _cell.attributes.bold;

  /// Whether faint intensity is enabled.
  bool get isDim => _cell.attributes.dim;

  /// Whether italic rendering is enabled.
  bool get isItalic => _cell.attributes.italic;

  /// Whether any underline style is enabled.
  bool get isUnderline =>
      _cell.attributes.underline != TerminalUnderlineStyle.none;

  /// Whether blinking is enabled.
  bool get isBlink => _cell.attributes.blink;

  /// Whether foreground and background are inverted.
  bool get isInverse => _cell.attributes.inverse;

  /// Whether the cell content is hidden.
  bool get isInvisible => _cell.attributes.invisible;

  /// Whether strikethrough is enabled.
  bool get isStrikethrough => _cell.attributes.strikethrough;

  /// Whether overline is enabled.
  bool get isOverline => _cell.attributes.overline;

  /// Whether selective erase protects the cell.
  bool get isProtected => _cell.attributes.protected;

  /// Whether all attributes have their default values.
  bool get isAttributeDefault =>
      _cell.attributes.sameAs(TerminalCellAttributes());

  /// Whether this cell's attributes equal those of [other].
  bool attributesEqual(TerminalCell other) =>
      _cell.attributes.sameAs(other._cell.attributes);
}

/// One mutable line in a terminal buffer.
final class TerminalBufferLine {
  /// Creates an empty line containing [length] cells.
  TerminalBufferLine(
    int length, {
    this.isWrapped = false,
    TerminalCellAttributes? attributes,
  }) : _cells = List<_CellData>.generate(
         length,
         (_) => _CellData(attributes: attributes),
       );

  TerminalBufferLine._(this._cells, {required this.isWrapped});

  final List<_CellData> _cells;

  /// Whether this line continues the preceding logical line.
  bool isWrapped;

  /// Number of cells in this line.
  int get length => _cells.length;

  /// Returns the cell at [index], or `null` when out of range.
  TerminalCell? getCell(int index) =>
      index < 0 || index >= length ? null : TerminalCell._(_cells[index]);

  /// Converts a cell range into its textual representation.
  String translateToString({
    bool trimRight = false,
    int startColumn = 0,
    int? endColumn,
  }) {
    final start = startColumn.clamp(0, length);
    final end = (endColumn ?? length).clamp(start, length);
    final output = StringBuffer();
    for (var index = start; index < end; index++) {
      final cell = _cells[index];
      if (cell.width == 0) continue;
      output.write(cell.chars.isEmpty ? ' ' : cell.chars);
    }
    final value = output.toString();
    return trimRight ? value.trimRight() : value;
  }

  /// Returns an independent copy of this line.
  TerminalBufferLine copy() => TerminalBufferLine._(
    _cells.map((cell) => cell.copy()).toList(growable: false),
    isWrapped: isWrapped,
  );

  /// Resizes this line to [columns] cells.
  void resize(int columns, TerminalCellAttributes eraseAttributes) {
    if (columns < length) {
      _cells.removeRange(columns, length);
    } else {
      _cells.addAll(
        List<_CellData>.generate(
          columns - length,
          (_) => _CellData(attributes: eraseAttributes),
        ),
      );
    }
  }

  /// Replaces a cell and its wide-character continuation when needed.
  void setCell(
    int index,
    String chars,
    int width,
    TerminalCellAttributes attributes,
  ) {
    if (index < 0 || index >= length) return;
    _cells[index]
      ..chars = chars
      ..width = width
      ..attributes = attributes.copy();
    if (width == 2 && index + 1 < length) {
      _cells[index + 1]
        ..chars = ''
        ..width = 0
        ..attributes = attributes.copy();
    }
  }

  /// Appends [value] to the base cell at or before [index].
  void appendCombining(int index, String value) {
    if (index < 0 || index >= length) return;
    var target = index;
    while (target > 0 && _cells[target].width == 0) {
      target--;
    }
    _cells[target].chars += value;
  }

  /// Joins [value] into the cell at [index] and updates its display [width].
  void joinCell(int index, String value, int width) {
    if (index < 0 || index >= length) return;
    final cell = _cells[index]
      ..chars += value
      ..width = width;
    if (width == 2 && index + 1 < length) {
      _cells[index + 1]
        ..chars = ''
        ..width = 0
        ..attributes = cell.attributes.copy();
    }
  }

  /// Inserts blank cells at [index], shifting existing cells right.
  void insertCells(
    int index,
    int count,
    TerminalCellAttributes eraseAttributes,
  ) {
    if (count <= 0 || index < 0 || index >= length) return;
    final oldLength = length;
    final amount = count.clamp(0, oldLength - index);
    _cells
      ..insertAll(
        index,
        List<_CellData>.generate(
          amount,
          (_) => _CellData(attributes: eraseAttributes),
        ),
      )
      ..removeRange(oldLength, oldLength + amount);
  }

  /// Deletes cells at [index], appending blank cells at the right edge.
  void deleteCells(
    int index,
    int count,
    TerminalCellAttributes eraseAttributes,
  ) {
    if (count <= 0 || index < 0 || index >= length) return;
    final amount = count.clamp(0, length - index);
    _cells
      ..removeRange(index, index + amount)
      ..addAll(
        List<_CellData>.generate(
          amount,
          (_) => _CellData(attributes: eraseAttributes),
        ),
      );
  }

  /// Erases cells in the half-open range from [start] to [end].
  void erase(
    int start,
    int end,
    TerminalCellAttributes eraseAttributes, {
    bool respectProtection = false,
  }) {
    final first = start.clamp(0, length);
    final last = end.clamp(first, length);
    for (var index = first; index < last; index++) {
      if (respectProtection && _cells[index].attributes.protected) continue;
      _cells[index].reset(eraseAttributes);
    }
  }
}

/// A complete normal or alternate terminal buffer.
final class TerminalBuffer {
  TerminalBuffer._({
    required this.type,
    required int columns,
    required int rows,
    required this.scrollback,
  }) : _columns = columns,
       _rows = rows,
       _lines = List<TerminalBufferLine>.generate(
         rows,
         (_) => TerminalBufferLine(columns),
       );

  /// Kind of this buffer.
  final TerminalBufferType type;

  /// Maximum number of retained scrollback lines.
  final int scrollback;
  final List<TerminalBufferLine> _lines;
  int _columns;
  int _rows;

  /// Zero-based cursor column.
  int cursorX = 0;

  /// Cursor row relative to the viewport.
  int cursorY = 0;

  /// Saved cursor column.
  int savedCursorX = 0;

  /// Saved cursor row.
  int savedCursorY = 0;

  /// Attributes restored together with the saved cursor.
  TerminalCellAttributes savedAttributes = TerminalCellAttributes();

  /// ISO-2022 character sets restored with DECRC.
  List<String> savedCharsets = <String>['B', 'B', 'B', 'B'];

  /// Active saved ISO-2022 character-set level.
  int savedCharsetLevel = 0;

  /// Absolute row at the top of the live viewport.
  int get viewportY => baseY;

  /// Number of retained rows before the live viewport.
  int get baseY => type == TerminalBufferType.alternate
      ? 0
      : (_lines.length - _rows).clamp(0, _lines.length);

  /// Number of retained lines.
  int get length => _lines.length;

  /// Absolute row containing the cursor.
  int get absoluteCursorY => baseY + cursorY;

  /// Number of columns in each line.
  int get columns => _columns;

  /// Number of rows in the viewport.
  int get rows => _rows;

  /// Returns the absolute buffer line at [index].
  TerminalBufferLine? getLine(int index) =>
      index < 0 || index >= length ? null : _lines[index];

  /// Line containing the cursor.
  TerminalBufferLine get currentLine => _lines[absoluteCursorY];

  /// Returns an empty cell with default attributes.
  TerminalCell getNullCell() => TerminalCell._(_CellData());

  /// Resizes the viewport and all retained lines.
  void resize(
    int columns,
    int rows,
    TerminalCellAttributes eraseAttributes,
  ) {
    for (final line in _lines) {
      line.resize(columns, eraseAttributes);
    }
    if (rows > _rows) {
      _lines.addAll(
        List<TerminalBufferLine>.generate(
          rows - _rows,
          (_) => TerminalBufferLine(columns, attributes: eraseAttributes),
        ),
      );
    }
    _columns = columns;
    _rows = rows;
    while (_lines.length < rows) {
      _lines.add(TerminalBufferLine(columns, attributes: eraseAttributes));
    }
    _trim();
    cursorX = cursorX.clamp(0, columns - 1);
    cursorY = cursorY.clamp(0, rows - 1);
  }

  /// Replaces all content with an empty viewport.
  void clear([TerminalCellAttributes? eraseAttributes]) {
    _lines
      ..clear()
      ..addAll(
        List<TerminalBufferLine>.generate(
          _rows,
          (_) => TerminalBufferLine(_columns, attributes: eraseAttributes),
        ),
      );
    cursorX = 0;
    cursorY = 0;
  }

  /// Removes retained scrollback without changing the visible viewport.
  void clearScrollback() {
    final retained = baseY;
    if (retained > 0) _lines.removeRange(0, retained);
  }

  /// Scrolls the inclusive region from [top] through [bottom] upward.
  void scroll(
    TerminalCellAttributes eraseAttributes, {
    int top = 0,
    int? bottom,
  }) {
    final last = bottom ?? _rows - 1;
    if (top == 0 && last == _rows - 1 && type == TerminalBufferType.normal) {
      _lines.add(TerminalBufferLine(_columns, attributes: eraseAttributes));
      _trim();
      return;
    }
    final start = baseY + top;
    final end = baseY + last;
    _lines
      ..removeAt(start)
      ..insert(end, TerminalBufferLine(_columns, attributes: eraseAttributes));
  }

  /// Scrolls the inclusive region from [top] through [bottom] downward.
  void reverseScroll(
    TerminalCellAttributes eraseAttributes, {
    int top = 0,
    int? bottom,
  }) {
    final last = bottom ?? _rows - 1;
    final start = baseY + top;
    final end = baseY + last;
    _lines
      ..removeAt(end)
      ..insert(
        start,
        TerminalBufferLine(_columns, attributes: eraseAttributes),
      );
  }

  /// Inserts [count] blank lines at viewport-relative [row].
  void insertLines(
    int row,
    int count,
    TerminalCellAttributes eraseAttributes, {
    int? bottom,
  }) {
    final last = bottom ?? _rows - 1;
    final amount = count.clamp(0, last - row + 1);
    final start = baseY + row;
    final end = baseY + last + 1;
    _lines
      ..insertAll(
        start,
        List<TerminalBufferLine>.generate(
          amount,
          (_) => TerminalBufferLine(_columns, attributes: eraseAttributes),
        ),
      )
      ..removeRange(end, end + amount);
  }

  /// Deletes [count] lines at viewport-relative [row].
  void deleteLines(
    int row,
    int count,
    TerminalCellAttributes eraseAttributes, {
    int? bottom,
  }) {
    final last = bottom ?? _rows - 1;
    final amount = count.clamp(0, last - row + 1);
    final start = baseY + row;
    final insertion = baseY + last - amount + 1;
    _lines
      ..removeRange(start, start + amount)
      ..insertAll(
        insertion,
        List<TerminalBufferLine>.generate(
          amount,
          (_) => TerminalBufferLine(_columns, attributes: eraseAttributes),
        ),
      );
  }

  void _trim() {
    final maximum =
        _rows + (type == TerminalBufferType.normal ? scrollback : 0);
    if (_lines.length > maximum) {
      _lines.removeRange(0, _lines.length - maximum);
    }
  }
}

/// Normal, alternate, and active buffers.
final class TerminalBufferNamespace {
  /// Creates normal and alternate buffers with the given dimensions.
  TerminalBufferNamespace({
    required int columns,
    required int rows,
    required int scrollback,
  }) : normal = TerminalBuffer._(
         type: TerminalBufferType.normal,
         columns: columns,
         rows: rows,
         scrollback: scrollback,
       ),
       alternate = TerminalBuffer._(
         type: TerminalBufferType.alternate,
         columns: columns,
         rows: rows,
         scrollback: 0,
       ) {
    _active = normal;
  }

  /// Normal buffer with scrollback history.
  final TerminalBuffer normal;

  /// Alternate screen buffer.
  final TerminalBuffer alternate;
  late TerminalBuffer _active;
  final TerminalEventEmitter<TerminalBuffer> _onBufferChange =
      TerminalEventEmitter<TerminalBuffer>();

  /// Buffer currently receiving input and being rendered.
  TerminalBuffer get active => _active;

  /// Fires synchronously after the active buffer changes.
  TerminalEvent<TerminalBuffer> get onBufferChange => _onBufferChange.event;

  /// Activates the normal buffer.
  void useNormal() {
    if (identical(_active, normal)) return;
    normal
      ..cursorX = alternate.cursorX
      ..cursorY = alternate.cursorY;
    alternate.clear();
    _switch(normal);
  }

  /// Activates the alternate buffer, optionally clearing it first.
  void useAlternate({bool clear = true}) {
    if (identical(_active, alternate)) return;
    alternate
      ..clear()
      ..cursorX = normal.cursorX
      ..cursorY = normal.cursorY;
    _switch(alternate);
  }

  void _switch(TerminalBuffer value) {
    if (identical(_active, value)) return;
    _active = value;
    _onBufferChange.fire(value);
  }

  /// Resizes both buffers.
  void resize(
    int columns,
    int rows,
    TerminalCellAttributes eraseAttributes,
  ) {
    normal.resize(columns, rows, eraseAttributes);
    alternate.resize(columns, rows, eraseAttributes);
  }

  /// Releases buffer-change listeners.
  void dispose() => _onBufferChange.dispose();
}
