import 'package:flutter/material.dart';

/// Cursor shape rendered by the Flutter terminal view.
enum TerminalCursorType {
  /// A cursor covering the complete cell.
  block,

  /// A horizontal line at the bottom of the cell.
  underline,

  /// A vertical line at the leading edge of the cell.
  bar,
}

/// A terminal cell coordinate.
@immutable
final class TerminalCellOffset {
  /// Creates a cell coordinate from its zero-based column and row.
  const TerminalCellOffset(this.x, this.y);

  /// Zero-based column.
  final int x;

  /// Zero-based row.
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TerminalCellOffset && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Font and cursor metrics used by the Flutter renderer.
@immutable
final class TerminalStyle {
  /// Creates terminal renderer font and cursor settings.
  const TerminalStyle({
    this.fontFamily = 'monospace',
    this.fontSize = 14,
    this.height = 1.2,
    this.fontWeight = FontWeight.normal,
    this.cursorType = TerminalCursorType.block,
    this.cursorBlink = false,
  });

  /// Preferred monospace font family.
  final String fontFamily;

  /// Font size in logical pixels.
  final double fontSize;

  /// Text line-height multiplier.
  final double height;

  /// Default font weight.
  final FontWeight fontWeight;

  /// Cursor shape.
  final TerminalCursorType cursorType;

  /// Whether the cursor should blink.
  final bool cursorBlink;

  /// Converts these settings to a Flutter text style.
  TextStyle toTextStyle({Color? color, Color? backgroundColor}) => TextStyle(
    color: color,
    backgroundColor: backgroundColor,
    fontFamily: fontFamily,
    fontFamilyFallback: const <String>['monospace'],
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
  );
}

/// Renderer colors, including the complete ANSI 256-color palette.
@immutable
final class TerminalTheme {
  /// Creates a complete terminal renderer theme.
  const TerminalTheme({
    required this.foreground,
    required this.background,
    required this.cursor,
    required this.selection,
    required this.palette,
  });

  /// Default text color.
  final Color foreground;

  /// Default surface color.
  final Color background;

  /// Cursor color.
  final Color cursor;

  /// Selection overlay color.
  final Color selection;

  /// ANSI 256-color palette.
  final List<Color> palette;
}

/// Built-in terminal themes.
abstract final class TerminalThemes {
  static final List<Color> _palette = _buildPalette();

  /// Default dark terminal theme.
  static final TerminalTheme defaultTheme = TerminalTheme(
    foreground: const Color(0xfff8f8f2),
    background: const Color(0xff1e1e1e),
    cursor: const Color(0xfff8f8f2),
    selection: const Color(0x663399ff),
    palette: _palette,
  );

  static List<Color> _buildPalette() {
    final colors = <Color>[
      const Color(0xff000000),
      const Color(0xffcd0000),
      const Color(0xff00cd00),
      const Color(0xffcdcd00),
      const Color(0xff0000ee),
      const Color(0xffcd00cd),
      const Color(0xff00cdcd),
      const Color(0xffe5e5e5),
      const Color(0xff7f7f7f),
      const Color(0xffff0000),
      const Color(0xff00ff00),
      const Color(0xffffff00),
      const Color(0xff5c5cff),
      const Color(0xffff00ff),
      const Color(0xff00ffff),
      const Color(0xffffffff),
    ];
    const levels = <int>[0, 95, 135, 175, 215, 255];
    for (final red in levels) {
      for (final green in levels) {
        for (final blue in levels) {
          colors.add(Color.fromARGB(0xff, red, green, blue));
        }
      }
    }
    for (var index = 0; index < 24; index++) {
      final value = 8 + index * 10;
      colors.add(Color.fromARGB(0xff, value, value, value));
    }
    return List<Color>.unmodifiable(colors);
  }
}
