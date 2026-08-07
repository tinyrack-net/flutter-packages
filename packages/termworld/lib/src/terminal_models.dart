import 'package:flutter/material.dart';

/// Character-cell dimensions of a terminal viewport.
@immutable
final class TerminalSize {
  /// Creates a terminal size.
  const TerminalSize({required this.columns, required this.rows});

  /// Visible character columns.
  final int columns;

  /// Visible character rows.
  final int rows;

  @override
  bool operator ==(Object other) =>
      other is TerminalSize && columns == other.columns && rows == other.rows;

  @override
  int get hashCode => Object.hash(columns, rows);
}

/// One terminal text style produced by SGR sequences.
@immutable
final class TerminalCellStyle {
  /// Creates a cell style.
  const TerminalCellStyle({
    this.foreground,
    this.background,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.inverse = false,
  });

  /// Explicit foreground, or `null` for the theme foreground.
  final Color? foreground;

  /// Explicit background, or `null` for the theme background.
  final Color? background;

  /// Whether glyphs use a bold weight.
  final bool bold;

  /// Whether glyphs are italic.
  final bool italic;

  /// Whether glyphs are underlined.
  final bool underline;

  /// Whether foreground and background are exchanged.
  final bool inverse;

  /// Returns a copy with selected attributes replaced.
  TerminalCellStyle copyWith({
    Color? foreground,
    bool clearForeground = false,
    Color? background,
    bool clearBackground = false,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? inverse,
  }) => TerminalCellStyle(
    foreground: clearForeground ? null : foreground ?? this.foreground,
    background: clearBackground ? null : background ?? this.background,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    inverse: inverse ?? this.inverse,
  );
}

/// One rendered terminal grapheme.
@immutable
final class TerminalCell {
  /// Creates a cell.
  const TerminalCell(
    this.text, {
    this.width = 1,
    this.style = const TerminalCellStyle(),
  });

  /// Grapheme stored in this cell. An empty string is a blank cell.
  final String text;

  /// Display width: zero for a continuation, one or two for a glyph.
  final int width;

  /// SGR style active when the cell was written.
  final TerminalCellStyle style;
}

/// Visual configuration supplied by a product design system.
@immutable
final class TerminalTheme {
  /// Creates a terminal theme.
  const TerminalTheme({
    required this.background,
    required this.foreground,
    required this.cursor,
    required this.selection,
    this.palette = defaultTerminalPalette,
  });

  /// Surface color.
  final Color background;

  /// Default text color.
  final Color foreground;

  /// Cursor and composing underline color.
  final Color cursor;

  /// Selected-cell color.
  final Color selection;

  /// ANSI colors zero through fifteen.
  final List<Color> palette;
}

/// Default ANSI terminal palette.
const List<Color> defaultTerminalPalette = <Color>[
  Color(0xFF000000),
  Color(0xFFCD3131),
  Color(0xFF0DBC79),
  Color(0xFFE5E510),
  Color(0xFF2472C8),
  Color(0xFFBC3FBC),
  Color(0xFF11A8CD),
  Color(0xFFE5E5E5),
  Color(0xFF666666),
  Color(0xFFF14C4C),
  Color(0xFF23D18B),
  Color(0xFFF5F543),
  Color(0xFF3B8EEA),
  Color(0xFFD670D6),
  Color(0xFF29B8DB),
  Color(0xFFFFFFFF),
];

/// Typography and geometry for a terminal viewport.
@immutable
final class TerminalStyle {
  /// Creates a terminal style.
  const TerminalStyle({required this.textStyle, required this.padding});

  /// Monospace glyph style.
  final TextStyle textStyle;

  /// Insets between the viewport and character grid.
  final EdgeInsets padding;
}

/// A cell coordinate in the active buffer.
@immutable
final class TerminalPosition {
  /// Creates a terminal position.
  const TerminalPosition(this.column, this.row);

  /// Zero-based column.
  final int column;

  /// Zero-based row, including scrollback.
  final int row;
}

/// A normalized terminal selection.
@immutable
final class TerminalSelection {
  /// Creates a selection.
  const TerminalSelection(this.start, this.end);

  /// Inclusive start.
  final TerminalPosition start;

  /// Exclusive end.
  final TerminalPosition end;
}

/// DEC mouse-tracking policy requested by the terminal application.
enum TerminalMouseTrackingMode {
  /// Pointer input belongs to local selection and scrolling.
  none,

  /// Report button press and release events.
  press,

  /// Also report motion while a button is held.
  buttonEvent,

  /// Report every pointer motion event.
  anyEvent,
}
