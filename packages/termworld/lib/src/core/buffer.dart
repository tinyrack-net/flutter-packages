import 'package:flutter/foundation.dart';
import 'package:termworld/src/core/buffer_line_string_cache.dart';
import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/marker.dart';

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

  @override
  bool operator ==(Object other) =>
      other is TerminalBufferRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// A structural change to the buffer's logical line collection.
final class TerminalBufferLineChange {
  /// Creates a line change at [index] affecting [amount] lines.
  const TerminalBufferLineChange({required this.index, required this.amount});

  /// Absolute buffer line where the change begins.
  final int index;

  /// Number of inserted or deleted lines.
  final int amount;
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
    this.hyperlinkId = 0,
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

  /// Internal numeric identity assigned to an OSC 8 hyperlink.
  int hyperlinkId;

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
    hyperlinkId: hyperlinkId,
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
      protected == other.protected &&
      hyperlinkId == other.hyperlinkId;
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

  int get code {
    final units = chars.codeUnits;
    if (units.isEmpty) return 0;
    if (units.length == 2 &&
        units[0] >= 0xd800 &&
        units[0] <= 0xdbff &&
        units[1] >= 0xdc00 &&
        units[1] <= 0xdfff) {
      return (units[0] - 0xd800) * 0x400 + units[1] - 0xdc00 + 0x10000;
    }
    return units.last;
  }

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

  /// Numeric OSC 8 hyperlink identity, or zero outside a hyperlink.
  int get hyperlinkId => _cell.attributes.hyperlinkId;

  /// Whether all attributes have their default values.
  bool get isAttributeDefault =>
      _cell.attributes.sameAs(TerminalCellAttributes());

  /// Whether this cell's attributes equal those of [other].
  bool attributesEqual(TerminalCell other) {
    final left = _cell.attributes;
    final right = other._cell.attributes;
    return left.foreground == right.foreground &&
        left.background == right.background &&
        left.bold == right.bold &&
        left.dim == right.dim &&
        left.italic == right.italic &&
        left.underline == right.underline &&
        (left.underline == TerminalUnderlineStyle.none ||
            left.underlineColor == right.underlineColor) &&
        left.blink == right.blink &&
        left.inverse == right.inverse &&
        left.invisible == right.invisible &&
        left.strikethrough == right.strikethrough &&
        left.overline == right.overline;
  }
}

/// One mutable line in a terminal buffer.
final class TerminalBufferLine {
  /// Creates an empty line containing [length] cells.
  TerminalBufferLine(
    int length, {
    this.isWrapped = false,
    TerminalCellAttributes? attributes,
    this.stringCache,
  }) : _cells = List<_CellData>.generate(
         length,
         (_) => _CellData(attributes: attributes),
       );

  TerminalBufferLine._(
    this._cells, {
    required this.isWrapped,
    this.stringCache,
  });

  final List<_CellData> _cells;

  /// Shared canonical translation cache, when this line belongs to a buffer.
  final BufferLineStringCache? stringCache;
  BufferLineStringCacheEntry? _stringCacheEntry;

  /// Whether this line continues the preceding logical line.
  bool isWrapped;

  /// Number of cells in this line.
  int get length => _cells.length;

  /// Returns the cell at [index], or `null` when out of range.
  TerminalCell? getCell(int index, [TerminalCell? destination]) {
    if (index < 0 || index >= length) return null;
    final source = _cells[index];
    if (destination == null) return TerminalCell._(source);
    destination._cell
      ..chars = source.chars
      ..width = source.width
      ..attributes = source.attributes.copy();
    return destination;
  }

  /// Converts a cell range into its textual representation.
  String translateToString({
    bool trimRight = false,
    int startColumn = 0,
    int? endColumn,
  }) {
    final isCanonicalRequest = startColumn == 0 && endColumn == null;
    final cache = isCanonicalRequest ? stringCache : null;
    cache?.touch();
    final cachedEntry = cache == null ? null : _getStringCacheEntry(false);
    final cachedValue = cachedEntry?.value;
    if (cachedValue != null) {
      if (trimRight) {
        return cachedEntry!.isTrimmed ? cachedValue : cachedValue.trimRight();
      }
      if (!cachedEntry!.isTrimmed) return cachedValue;
    }
    final start = startColumn.clamp(0, length);
    final end = (endColumn ?? length).clamp(start, length);
    final output = StringBuffer();
    for (var index = start; index < end; index++) {
      final cell = _cells[index];
      if (cell.width == 0) continue;
      output.write(cell.chars.isEmpty ? ' ' : cell.chars);
    }
    final value = output.toString();
    final result = trimRight ? value.trimRight() : value;
    if (cache != null) {
      _getStringCacheEntry(true)!.setValue(result, isTrimmed: trimRight);
    }
    return result;
  }

  /// Returns an independent copy of this line.
  TerminalBufferLine copy() => TerminalBufferLine._(
    _cells.map((cell) => cell.copy()).toList(growable: false),
    isWrapped: isWrapped,
    stringCache: stringCache,
  );

  /// Resizes this line to [columns] cells.
  void resize(int columns, TerminalCellAttributes eraseAttributes) {
    _invalidateStringCache();
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
    _invalidateStringCache();
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
    _invalidateStringCache();
    var target = index;
    while (target > 0 && _cells[target].width == 0) {
      target--;
    }
    _cells[target].chars += value;
  }

  /// Joins [value] into the cell at [index] and updates its display [width].
  void joinCell(int index, String value, int width) {
    if (index < 0 || index >= length) return;
    _invalidateStringCache();
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
    _invalidateStringCache();
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
    _invalidateStringCache();
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
    _invalidateStringCache();
    final first = start.clamp(0, length);
    final last = end.clamp(first, length);
    for (var index = first; index < last; index++) {
      if (respectProtection && _cells[index].attributes.protected) continue;
      _cells[index].reset(eraseAttributes);
    }
  }

  BufferLineStringCacheEntry? _getStringCacheEntry(bool createIfNeeded) {
    final cache = stringCache;
    if (cache == null) return null;
    final entry = _stringCacheEntry;
    if (entry != null && entry.generation == cache.generation) return entry;
    if (!createIfNeeded) return null;
    return _stringCacheEntry = cache.allocateEntry();
  }

  void _invalidateStringCache() {
    final entry = _getStringCacheEntry(false);
    if (entry == null) return;
    entry
      ..value = null
      ..isTrimmed = false;
  }
}

/// A complete normal or alternate terminal buffer.
final class TerminalBuffer implements Disposable {
  TerminalBuffer._({
    required this.type,
    required int columns,
    required int rows,
    required int scrollback,
    void Function(int amount)? onTrim,
    void Function(int index, int amount)? onInsert,
    void Function(int index, int amount)? onDelete,
  }) : _columns = columns,
       _rows = rows,
       _scrollback = _initialScrollback(scrollback),
       _onTrim = _initialCallback(onTrim),
       _onInsert = _initialCallback(onInsert),
       _onDelete = _initialCallback(onDelete) {
    _lines.addAll(
      List<TerminalBufferLine>.generate(rows, (_) => _blankLine(columns, null)),
    );
  }

  /// Kind of this buffer.
  final TerminalBufferType type;

  /// Maximum number of retained scrollback lines.
  int get scrollback => _scrollback;
  int _scrollback;
  final List<TerminalBufferLine> _lines = <TerminalBufferLine>[];
  final BufferLineStringCache _stringCache = BufferLineStringCache();
  int _columns;
  int _rows;
  final void Function(int amount)? _onTrim;
  final void Function(int index, int amount)? _onInsert;
  final void Function(int index, int amount)? _onDelete;
  final List<TerminalMarker> _markers = <TerminalMarker>[];
  final TerminalMarkerFactory _markerFactory = TerminalMarkerFactory();
  final TerminalEventEmitter<int> _onTrimEmitter = TerminalEventEmitter<int>();
  final TerminalEventEmitter<TerminalBufferLineChange> _onInsertEmitter =
      TerminalEventEmitter<TerminalBufferLineChange>();
  final TerminalEventEmitter<TerminalBufferLineChange> _onDeleteEmitter =
      TerminalEventEmitter<TerminalBufferLineChange>();
  bool _isDisposed = false;

  /// Fires after lines are trimmed from the start of the buffer.
  TerminalEvent<int> get onTrim => _onTrimEmitter.event;

  /// Fires after logical lines are inserted.
  TerminalEvent<TerminalBufferLineChange> get onInsert =>
      _onInsertEmitter.event;

  /// Fires after logical lines are deleted.
  TerminalEvent<TerminalBufferLineChange> get onDelete =>
      _onDeleteEmitter.event;

  /// Markers currently anchored in this buffer.
  List<TerminalMarker> get markers =>
      List<TerminalMarker>.unmodifiable(_markers);

  /// Adds a marker at an absolute buffer line.
  TerminalMarker addMarker(int line) {
    if (_isDisposed) throw StateError('Buffer has been disposed');
    final marker = _markerFactory.create(line);
    _markers.add(marker);
    marker.onDispose.listen((_) => _markers.remove(marker));
    return marker;
  }

  /// Disposes every marker owned by this buffer.
  void clearAllMarkers() {
    for (final marker in List<TerminalMarker>.of(_markers)) {
      marker.dispose();
    }
  }

  @override
  bool get isDisposed => _isDisposed;

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

  /// Absolute row currently displayed at the top of the viewport.
  int get viewportY => displayY;

  /// Mutable display offset managed by the owning terminal or buffer service.
  int displayY = 0;

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

  /// Translates one absolute buffer line, returning an empty string if absent.
  String translateBufferLineToString(
    int lineIndex, {
    bool trimRight = false,
    int startColumn = 0,
    int? endColumn,
  }) =>
      getLine(lineIndex)?.translateToString(
        trimRight: trimRight,
        startColumn: startColumn,
        endColumn: endColumn,
      ) ??
      '';

  /// Shared canonical line-string cache owned by this buffer.
  BufferLineStringCache get stringCache => _stringCache;

  /// Resizes the viewport and all retained lines.
  void resize(
    int columns,
    int rows,
    TerminalCellAttributes eraseAttributes, {
    bool reflowCursorLine = false,
  }) {
    _stringCache.clear();
    if (type == TerminalBufferType.normal && columns != _columns) {
      _reflow(columns, eraseAttributes, reflowCursorLine);
    }
    final oldRows = _rows;
    final oldBase = baseY;
    final absoluteCursor = oldBase + cursorY;
    for (final line in _lines) {
      line.resize(columns, eraseAttributes);
    }
    if (rows > oldRows) {
      final growth = rows - oldRows;
      final canRevealHistory =
          oldBase > 0 && _lines.length <= absoluteCursor + 1;
      final linesToAdd = canRevealHistory
          ? growth > oldBase
                ? growth - oldBase
                : 0
          : growth;
      _lines.addAll(
        List<TerminalBufferLine>.generate(
          linesToAdd,
          (_) => _blankLine(columns, eraseAttributes),
        ),
      );
    } else if (rows < oldRows) {
      final minimumLength = rows + oldBase;
      while (_lines.length > minimumLength &&
          _lines.length > absoluteCursor + 1) {
        _deleteLines(_lines.length - 1, 1);
        _lines.removeLast();
      }
    }
    _columns = columns;
    _rows = rows;
    while (_lines.length < rows) {
      _lines.add(_blankLine(columns, eraseAttributes));
    }
    _trim();
    cursorX = cursorX.clamp(0, columns - 1);
    cursorY = (absoluteCursor - baseY).clamp(0, rows - 1);
    savedCursorY = savedCursorY.clamp(0, rows - 1);
    displayY = displayY.clamp(0, baseY);
  }

  /// Replaces all content with an empty viewport.
  void clear([TerminalCellAttributes? eraseAttributes]) {
    _stringCache.clear();
    _deleteLines(0, _lines.length);
    _lines
      ..clear()
      ..addAll(
        List<TerminalBufferLine>.generate(
          _rows,
          (_) => _blankLine(_columns, eraseAttributes),
        ),
      );
    cursorX = 0;
    cursorY = 0;
    displayY = 0;
  }

  /// Discards history while retaining the cursor line as the first line.
  ///
  /// This is the buffer mutation used by xterm's public `Terminal.clear` API.
  /// The retained line is not serialized and written again, so its cells,
  /// attributes, wrapping state and the cursor column stay intact.
  void clearKeepingCursorLine([TerminalCellAttributes? eraseAttributes]) {
    final promptLine = currentLine;
    _deleteLines(0, _lines.length);
    _lines
      ..clear()
      ..add(promptLine)
      ..addAll(
        List<TerminalBufferLine>.generate(
          _rows - 1,
          (_) => _blankLine(_columns, eraseAttributes),
        ),
      );
    cursorY = 0;
    displayY = 0;
  }

  /// Removes retained scrollback without changing the visible viewport.
  void clearScrollback() {
    final retained = baseY;
    if (retained > 0) {
      _lines.removeRange(0, retained);
      _trimLines(retained);
      displayY = 0;
    }
  }

  /// Updates the retained history limit and immediately removes excess lines.
  void updateScrollback(int value) {
    if (type == TerminalBufferType.alternate || _scrollback == value) return;
    _scrollback = value;
    _trim();
  }

  /// Scrolls the inclusive region from [top] through [bottom] upward.
  void scroll(
    TerminalCellAttributes eraseAttributes, {
    int top = 0,
    int? bottom,
  }) {
    final last = bottom ?? _rows - 1;
    if (top == 0 && last == _rows - 1 && type == TerminalBufferType.normal) {
      _lines.add(_blankLine(_columns, eraseAttributes));
      _trim();
      return;
    }
    final start = baseY + top;
    final end = baseY + last;
    _deleteLines(start, 1);
    _insertLines(end, 1);
    _lines
      ..removeAt(start)
      ..insert(end, _blankLine(_columns, eraseAttributes));
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
    _deleteLines(end, 1);
    _insertLines(start, 1);
    _lines
      ..removeAt(end)
      ..insert(
        start,
        _blankLine(_columns, eraseAttributes),
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
    _insertLines(start, amount);
    _deleteLines(end, amount);
    _lines
      ..insertAll(
        start,
        List<TerminalBufferLine>.generate(
          amount,
          (_) => _blankLine(_columns, eraseAttributes),
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
    _deleteLines(start, amount);
    _insertLines(insertion, amount);
    _lines
      ..removeRange(start, start + amount)
      ..insertAll(
        insertion,
        List<TerminalBufferLine>.generate(
          amount,
          (_) => _blankLine(_columns, eraseAttributes),
        ),
      );
  }

  void _reflow(
    int newColumns,
    TerminalCellAttributes eraseAttributes,
    bool reflowCursorLine,
  ) {
    final oldColumns = _columns;
    final oldLength = _lines.length;
    final oldBaseY = baseY;
    final oldCursorY = cursorY;
    var cursorAbsolute = absoluteCursorY;
    var groupStart = 0;
    while (groupStart < _lines.length) {
      var groupEnd = groupStart;
      while (groupEnd + 1 < _lines.length && _lines[groupEnd + 1].isWrapped) {
        groupEnd++;
      }
      final containsCursor =
          cursorAbsolute >= groupStart && cursorAbsolute <= groupEnd;
      final lastLength = _trimmedLength(_lines[groupEnd]);
      final needsReflow =
          groupEnd > groupStart ||
          (newColumns < oldColumns && lastLength > newColumns);
      if (!needsReflow || containsCursor && !reflowCursorLine) {
        groupStart = groupEnd + 1;
        continue;
      }

      final firstWasWrapped = _lines[groupStart].isWrapped;
      final cells = <_CellData>[];
      var cursorOffset = 0;
      for (var row = groupStart; row <= groupEnd; row++) {
        final line = _lines[row];
        var used = row == groupEnd ? lastLength : oldColumns;
        if (row < groupEnd &&
            used > 0 &&
            line._cells[used - 1].chars.isEmpty &&
            line._cells[used - 1].width == 1 &&
            _lines[row + 1]._cells.first.width == 2) {
          used--;
        }
        if (containsCursor && row < cursorAbsolute) cursorOffset += used;
        if (containsCursor && row == cursorAbsolute) {
          cursorOffset += cursorX.clamp(0, used);
        }
        for (var column = 0; column < used; column++) {
          final cell = line._cells[column];
          if (cell.width == 0) continue;
          cells.add(
            _CellData(
              chars: cell.chars,
              width: cell.width,
              attributes: cell.attributes,
            ),
          );
        }
      }

      final layout = _layoutReflowedCells(
        cells,
        newColumns,
        eraseAttributes,
        firstWasWrapped,
        containsCursor ? cursorOffset : null,
      );
      final oldCount = groupEnd - groupStart + 1;
      _lines.replaceRange(groupStart, groupEnd + 1, layout.lines);
      final delta = layout.lines.length - oldCount;
      if (delta > 0) {
        _insertLines(groupEnd + 1, delta);
      } else if (delta < 0) {
        _deleteLines(groupStart + layout.lines.length, -delta);
      }
      if (containsCursor) {
        cursorAbsolute = groupStart + layout.cursorRow;
        cursorX = layout.cursorColumn;
      } else if (groupEnd < cursorAbsolute) {
        cursorAbsolute += delta;
      }
      groupStart += layout.lines.length;
    }
    if (newColumns < oldColumns && oldBaseY == 0) {
      // xterm consumes unused viewport rows from the bottom before newly
      // reflowed rows are allowed to create scrollback. CircularList.pop does
      // not emit a deletion event, so markers shifted by the insertions above
      // remain attached to their reflowed logical lines.
      final addedLines = (_lines.length - oldLength).clamp(0, _lines.length);
      final unusedViewportRows = (_rows - oldCursorY - 1).clamp(0, _rows);
      final rowsToPop = addedLines < unusedViewportRows
          ? addedLines
          : unusedViewportRows;
      if (rowsToPop > 0) {
        _lines.removeRange(_lines.length - rowsToPop, _lines.length);
      }
    }
    cursorY = (cursorAbsolute - baseY).clamp(0, _rows - 1);
  }

  _ReflowLayout _layoutReflowedCells(
    List<_CellData> cells,
    int columns,
    TerminalCellAttributes eraseAttributes,
    bool firstWasWrapped,
    int? cursorOffset,
  ) {
    final lines = <TerminalBufferLine>[
      _blankLine(columns, eraseAttributes, isWrapped: firstWasWrapped),
    ];
    var row = 0;
    var column = 0;
    var consumed = 0;
    var cursorRow = 0;
    var cursorColumn = 0;
    var cursorCaptured = cursorOffset == null;

    void captureCursor() {
      if (cursorCaptured || consumed < cursorOffset!) return;
      cursorRow = row;
      cursorColumn = column;
      cursorCaptured = true;
    }

    for (final cell in cells) {
      captureCursor();
      final width = cell.width == 2 ? 2 : 1;
      if (column + width > columns) {
        lines.add(
          _blankLine(columns, eraseAttributes, isWrapped: true),
        );
        row++;
        column = 0;
        captureCursor();
      }
      lines[row].setCell(column, cell.chars, width, cell.attributes);
      column += width;
      consumed += width;
    }
    captureCursor();
    if (!cursorCaptured) {
      cursorRow = row;
      cursorColumn = column;
    }
    return _ReflowLayout(lines, cursorRow, cursorColumn);
  }

  int _trimmedLength(TerminalBufferLine line) {
    var result = line.length;
    while (result > 0) {
      final cell = line._cells[result - 1];
      if (cell.width == 0 || cell.chars.isNotEmpty) break;
      result--;
    }
    return result;
  }

  TerminalBufferLine _blankLine(
    int columns,
    TerminalCellAttributes? attributes, {
    bool isWrapped = false,
  }) => TerminalBufferLine(
    columns,
    attributes: attributes,
    isWrapped: isWrapped,
    stringCache: _stringCache,
  );

  void _trim() {
    final maximum =
        _rows + (type == TerminalBufferType.normal ? scrollback : 0);
    if (_lines.length > maximum) {
      final amount = _lines.length - maximum;
      _lines.removeRange(0, amount);
      _trimLines(amount);
    }
  }

  void _trimLines(int amount) {
    for (final marker in List<TerminalMarker>.of(_markers)) {
      marker.move(-amount);
    }
    _onTrim?.call(amount);
    _onTrimEmitter.fire(amount);
  }

  void _insertLines(int index, int amount) {
    for (final marker in _markers) {
      if (marker.line >= index) marker.move(amount);
    }
    _onInsert?.call(index, amount);
    _onInsertEmitter.fire(
      TerminalBufferLineChange(index: index, amount: amount),
    );
  }

  void _deleteLines(int index, int amount) {
    final end = index + amount;
    for (final marker in List<TerminalMarker>.of(_markers)) {
      if (marker.line >= index && marker.line < end) {
        marker.dispose();
      } else if (marker.line >= end) {
        marker.move(-amount);
      }
    }
    _onDelete?.call(index, amount);
    _onDeleteEmitter.fire(
      TerminalBufferLineChange(index: index, amount: amount),
    );
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    clearAllMarkers();
    _stringCache.dispose();
    _onTrimEmitter.dispose();
    _onInsertEmitter.dispose();
    _onDeleteEmitter.dispose();
    _lines.clear();
  }

  static int _initialScrollback(int value) => value;
  static T _initialCallback<T>(T value) => value;
}

final class _ReflowLayout {
  const _ReflowLayout(this.lines, this.cursorRow, this.cursorColumn);

  final List<TerminalBufferLine> lines;
  final int cursorRow;
  final int cursorColumn;
}

/// Normal, alternate, and active buffers.
final class TerminalBufferActivation {
  /// Creates a buffer activation event.
  const TerminalBufferActivation({
    required this.activeBuffer,
    required this.inactiveBuffer,
  });

  /// Buffer that became active.
  final TerminalBuffer activeBuffer;

  /// Buffer that became inactive.
  final TerminalBuffer inactiveBuffer;
}

/// Normal, alternate, and active buffers.
final class TerminalBufferNamespace implements Disposable {
  /// Creates normal and alternate buffers with the given dimensions.
  TerminalBufferNamespace({
    required int columns,
    required int rows,
    required int scrollback,
    void Function(int amount)? onTrim,
    void Function(int index, int amount)? onInsert,
    void Function(int index, int amount)? onDelete,
  }) : this._(
         columns,
         rows,
         scrollback,
         onTrim,
         onInsert,
         onDelete,
       );

  TerminalBufferNamespace._(
    this._columns,
    this._rows,
    this._scrollback,
    this._onTrim,
    this._onInsert,
    this._onDelete,
  ) {
    reset();
  }

  /// Normal buffer with scrollback history.
  TerminalBuffer get normal => _normal;
  late TerminalBuffer _normal;

  /// Alternate screen buffer.
  TerminalBuffer get alternate => _alternate;
  late TerminalBuffer _alternate;
  late TerminalBuffer _active;
  int _columns;
  int _rows;
  final int _scrollback;
  final void Function(int amount)? _onTrim;
  final void Function(int index, int amount)? _onInsert;
  final void Function(int index, int amount)? _onDelete;
  bool _initialized = false;
  bool _isDisposed = false;
  final TerminalEventEmitter<TerminalBuffer> _onBufferChange =
      TerminalEventEmitter<TerminalBuffer>();
  final TerminalEventEmitter<TerminalBufferActivation> _onBufferActivate =
      TerminalEventEmitter<TerminalBufferActivation>();

  /// Buffer currently receiving input and being rendered.
  TerminalBuffer get active => _active;

  /// Fires synchronously after the active buffer changes.
  TerminalEvent<TerminalBuffer> get onBufferChange => _onBufferChange.event;

  /// Fires synchronously with both sides of an xterm buffer activation.
  TerminalEvent<TerminalBufferActivation> get onBufferActivate =>
      _onBufferActivate.event;

  /// Replaces both buffers and activates a fresh normal buffer.
  void reset() {
    if (_isDisposed) throw StateError('Buffer set has been disposed');
    if (_initialized) {
      _normal.dispose();
      _alternate.dispose();
    }
    _normal = TerminalBuffer._(
      type: TerminalBufferType.normal,
      columns: _columns,
      rows: _rows,
      scrollback: _scrollback,
      onTrim: _onTrim,
      onInsert: _onInsert,
      onDelete: _onDelete,
    );
    _alternate = TerminalBuffer._(
      type: TerminalBufferType.alternate,
      columns: _columns,
      rows: _rows,
      scrollback: 0,
    );
    _active = _normal;
    _initialized = true;
    _fireActivation(_normal, _alternate);
  }

  /// Activates the normal buffer.
  void useNormal() {
    if (identical(_active, normal)) return;
    normal
      ..cursorX = alternate.cursorX
      ..cursorY = alternate.cursorY;
    alternate
      ..clearAllMarkers()
      ..clear();
    _switch(normal);
  }

  /// Activates the alternate buffer, optionally clearing it first.
  void useAlternate({bool clear = true}) {
    if (identical(_active, alternate)) return;
    if (clear) alternate.clear();
    alternate
      ..cursorX = normal.cursorX
      ..cursorY = normal.cursorY;
    _switch(alternate);
  }

  void _switch(TerminalBuffer value) {
    if (identical(_active, value)) return;
    final inactive = _active;
    _active = value;
    _fireActivation(value, inactive);
  }

  void _fireActivation(TerminalBuffer active, TerminalBuffer inactive) {
    _onBufferChange.fire(active);
    _onBufferActivate.fire(
      TerminalBufferActivation(
        activeBuffer: active,
        inactiveBuffer: inactive,
      ),
    );
  }

  /// Resizes both buffers.
  void resize(
    int columns,
    int rows,
    TerminalCellAttributes eraseAttributes, {
    bool reflowCursorLine = false,
  }) {
    _columns = columns;
    _rows = rows;
    normal.resize(
      columns,
      rows,
      eraseAttributes,
      reflowCursorLine: reflowCursorLine,
    );
    alternate.resize(columns, rows, eraseAttributes);
  }

  @override
  bool get isDisposed => _isDisposed;

  /// Releases both buffers and buffer-change listeners.
  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    normal.dispose();
    alternate.dispose();
    _onBufferChange.dispose();
    _onBufferActivate.dispose();
  }
}
