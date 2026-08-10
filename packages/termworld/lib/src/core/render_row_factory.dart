import 'package:vtworld/vtworld.dart';

/// Cursor decoration attached to a renderer-neutral row span.
enum TerminalRowCursorStyle {
  /// Filled cell cursor.
  block,

  /// Cell outline cursor.
  outline,

  /// Vertical bar cursor.
  bar,

  /// Horizontal underline cursor.
  underline,

  /// No cursor decoration.
  none,
}

/// Immutable renderer attributes shared by Flutter and web renderers.
final class TerminalRowStyle {
  /// Creates resolved renderer attributes.
  const TerminalRowStyle({
    required this.foreground,
    required this.background,
    required this.underlineColor,
    required this.bold,
    required this.dim,
    required this.italic,
    required this.underline,
    required this.overline,
    required this.strikethrough,
    required this.blinkHidden,
    required this.invisible,
    required this.selectionTop,
    required this.linkUnderline,
  });

  /// Effective foreground after inverse and bold-bright resolution.
  final TerminalCellColor foreground;

  /// Effective background after inverse resolution.
  final TerminalCellColor background;

  /// Effective underline color.
  final TerminalCellColor underlineColor;

  /// Whether the text uses the bold font variant.
  final bool bold;

  /// Whether the colors render at faint intensity.
  final bool dim;

  /// Whether the text uses the italic font variant.
  final bool italic;

  /// Underline shape.
  final TerminalUnderlineStyle underline;

  /// Whether an overline is drawn.
  final bool overline;

  /// Whether a strike is drawn.
  final bool strikethrough;

  /// Whether blink phase hides this span.
  final bool blinkHidden;

  /// Whether glyph contents are replaced by whitespace.
  final bool invisible;

  /// Whether selection is composited below this span.
  final bool selectionTop;

  /// Whether link hover adds an underline.
  final bool linkUnderline;

  @override
  // This immutable internal value has complete structural equality.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      other is TerminalRowStyle &&
      other.foreground == foreground &&
      other.background == background &&
      other.underlineColor == underlineColor &&
      other.bold == bold &&
      other.dim == dim &&
      other.italic == italic &&
      other.underline == underline &&
      other.overline == overline &&
      other.strikethrough == strikethrough &&
      other.blinkHidden == blinkHidden &&
      other.invisible == invisible &&
      other.selectionTop == selectionTop &&
      other.linkUnderline == linkUnderline;

  @override
  // This immutable internal value has complete structural equality.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hash(
    foreground,
    background,
    underlineColor,
    bold,
    dim,
    italic,
    underline,
    overline,
    strikethrough,
    blinkHidden,
    invisible,
    selectionTop,
    linkUnderline,
  );
}

/// A maximal run of cells with identical observable renderer state.
final class TerminalRowSpan {
  /// Creates one shaped row span.
  const TerminalRowSpan({
    required this.startColumn,
    required this.endColumn,
    required this.text,
    required this.letterSpacing,
    required this.style,
    required this.cursor,
    required this.cursorBlink,
  });

  /// Inclusive buffer start column.
  final int startColumn;

  /// Exclusive buffer end column.
  final int endColumn;

  /// Glyph contents, with empty cells represented by spaces.
  final String text;

  /// Per-glyph correction in logical pixels.
  final double letterSpacing;

  /// Resolved cell attributes.
  final TerminalRowStyle style;

  /// Cursor decoration for this span.
  final TerminalRowCursorStyle cursor;

  /// Whether the focused cursor uses its blink animation.
  final bool cursorBlink;
}

/// Mutable diagnostic populated while a row is shaped.
final class TerminalRowInfo {
  /// Whether the shaped row contains at least one blinking cell.
  bool hasBlinkingCells = false;
}

/// Renderer-neutral port of xterm's `DomRendererRowFactory` state machine.
final class TerminalRenderRowFactory {
  /// Creates a row factory with xterm's bold-bright default.
  TerminalRenderRowFactory({
    this.drawBoldTextInBrightColors = true,
    this.defaultSpacing = 0,
  });

  /// Whether palette colors 0-7 become 8-15 on bold cells.
  final bool drawBoldTextInBrightColors;

  /// Spacing that does not require a renderer correction.
  final double defaultSpacing;

  int? _selectionStartX;
  int? _selectionStartY;
  int? _selectionEndX;
  int? _selectionEndY;
  bool _columnSelection = false;

  /// Updates the selection used by subsequent [createRow] calls.
  void handleSelectionChanged({
    int? startX,
    int? startY,
    int? endX,
    int? endY,
    bool columnSelection = false,
  }) {
    _selectionStartX = startX;
    _selectionStartY = startY;
    _selectionEndX = endX;
    _selectionEndY = endY;
    _columnSelection = columnSelection;
  }

  /// Shapes one buffer line into maximal renderer runs.
  List<TerminalRowSpan> createRow(
    TerminalBufferLine line, {
    required int row,
    required double cellWidth,
    required double Function(
      String text, {
      required bool bold,
      required bool italic,
    })
    measure,
    bool isCursorRow = false,
    int cursorX = 0,
    TerminalRowCursorStyle cursorStyle = TerminalRowCursorStyle.block,
    TerminalRowCursorStyle cursorInactiveStyle = TerminalRowCursorStyle.outline,
    bool cursorBlink = false,
    bool blinkOn = true,
    bool focused = true,
    bool cursorInitialized = true,
    bool cursorHidden = false,
    int linkStart = -1,
    int linkEnd = -1,
    TerminalRowInfo? rowInfo,
    bool Function(int column, int row)? isDecorated,
  }) {
    rowInfo?.hasBlinkingCells = false;
    var lineLength = line.getNoBackgroundTrimmedLength();
    if (isCursorRow && lineLength < cursorX + 1) lineLength = cursorX + 1;
    if (lineLength == 0) return const <TerminalRowSpan>[];

    final result = <TerminalRowSpan>[];
    _PendingSpan? pending;
    for (var column = 0; column < lineLength; column++) {
      final cell = line.getCell(column);
      if (cell == null || cell.width == 0) continue;
      if (cell.isBlink) rowInfo?.hasBlinkingCells = true;
      final selected = _isSelected(column, row);
      final linked =
          linkStart != -1 &&
          linkEnd != -1 &&
          column >= linkStart &&
          column <= linkEnd;
      var foreground = _color(
        cell.foregroundMode,
        cell.foreground,
      );
      var background = _color(
        cell.backgroundMode,
        cell.background,
      );
      if (cell.isInverse) {
        final swap = foreground;
        foreground = background;
        background = swap;
        if (background.mode == TerminalColorMode.defaultColor) {
          background = const TerminalCellColor.palette(257);
        }
        if (foreground.mode == TerminalColorMode.defaultColor) {
          foreground = const TerminalCellColor.palette(257);
        }
      }
      if (drawBoldTextInBrightColors &&
          cell.isBold &&
          foreground.mode == TerminalColorMode.palette &&
          foreground.value < 8) {
        foreground = TerminalCellColor.palette(foreground.value + 8);
      }
      var underlineColor = cell.underlineColor;
      if (drawBoldTextInBrightColors &&
          cell.isBold &&
          underlineColor.mode == TerminalColorMode.palette &&
          underlineColor.value < 8) {
        underlineColor = TerminalCellColor.palette(underlineColor.value + 8);
      }
      final style = TerminalRowStyle(
        foreground: foreground,
        background: background,
        underlineColor: underlineColor,
        bold: cell.isBold,
        dim: cell.isDim,
        italic: cell.isItalic,
        underline: cell.underlineStyle,
        overline: cell.isOverline,
        strikethrough: cell.isStrikethrough,
        blinkHidden: cell.isBlink && !blinkOn,
        invisible: cell.isInvisible,
        selectionTop: selected,
        linkUnderline: linked,
      );
      var text = cell.isInvisible || cell.chars.isEmpty ? ' ' : cell.chars;
      if (text == ' ' && (cell.isUnderline || cell.isOverline)) text = '\u00a0';
      final spacing =
          cell.width * cellWidth -
          measure(text, bold: cell.isBold, italic: cell.isItalic);
      final isCursor = isCursorRow && column == cursorX;
      final cursor = !isCursor || cursorHidden || !cursorInitialized
          ? TerminalRowCursorStyle.none
          : focused
          ? cursorStyle
          : cursorInactiveStyle;
      final mergeable = !isCursor && !(isDecorated?.call(column, row) ?? false);
      if (pending != null &&
          mergeable &&
          pending.mergeable &&
          pending.style == style &&
          pending.letterSpacing == spacing) {
        pending
          ..text.write(text)
          ..endColumn = column + cell.width;
        continue;
      }
      if (pending != null) result.add(pending.toSpan());
      pending = _PendingSpan(
        startColumn: column,
        endColumn: column + cell.width,
        text: StringBuffer(text),
        letterSpacing: spacing,
        style: style,
        cursor: cursor,
        cursorBlink: isCursor && focused && cursorBlink,
        mergeable: mergeable,
      );
    }
    if (pending != null) result.add(pending.toSpan());
    return result;
  }

  bool _isSelected(int column, int row) {
    final startX = _selectionStartX;
    final startY = _selectionStartY;
    final endX = _selectionEndX;
    final endY = _selectionEndY;
    if (startX == null || startY == null || endX == null || endY == null) {
      return false;
    }
    if (_columnSelection) {
      final left = startX < endX ? startX : endX;
      final right = startX < endX ? endX : startX;
      final top = startY < endY ? startY : endY;
      final bottom = startY < endY ? endY : startY;
      return row >= top && row <= bottom && column >= left && column < right;
    }
    if (row < startY || row > endY) return false;
    if (startY == endY) return column >= startX && column < endX;
    if (row == startY) return column >= startX;
    if (row == endY) return column < endX;
    return true;
  }

  TerminalCellColor _color(TerminalColorMode mode, int value) => switch (mode) {
    TerminalColorMode.defaultColor => const TerminalCellColor.defaultColor(),
    TerminalColorMode.palette => TerminalCellColor.palette(value),
    TerminalColorMode.rgb => TerminalCellColor.rgb(
      value >> 16 & 0xff,
      value >> 8 & 0xff,
      value & 0xff,
    ),
  };
}

final class _PendingSpan {
  _PendingSpan({
    required this.startColumn,
    required this.endColumn,
    required this.text,
    required this.letterSpacing,
    required this.style,
    required this.cursor,
    required this.cursorBlink,
    required this.mergeable,
  });

  final int startColumn;
  int endColumn;
  final StringBuffer text;
  final double letterSpacing;
  final TerminalRowStyle style;
  final TerminalRowCursorStyle cursor;
  final bool cursorBlink;
  final bool mergeable;

  TerminalRowSpan toSpan() => TerminalRowSpan(
    startColumn: startColumn,
    endColumn: endColumn,
    text: text.toString(),
    letterSpacing: letterSpacing,
    style: style,
    cursor: cursor,
    cursorBlink: cursorBlink,
  );
}
