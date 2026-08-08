import 'package:flutter/material.dart';
import 'package:termworld/src/core/options.dart';
import 'package:termworld/src/core/terminal.dart';

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
    this.fontWeightBold = FontWeight.bold,
    this.letterSpacing = 0,
    this.cursorType = TerminalCursorType.block,
    this.cursorBlink = false,
    this.cursorWidth = 1,
  });

  /// Preferred monospace font family.
  final String fontFamily;

  /// Font size in logical pixels.
  final double fontSize;

  /// Text line-height multiplier.
  final double height;

  /// Default font weight.
  final FontWeight fontWeight;

  /// Weight used by cells carrying the bold SGR attribute.
  final FontWeight fontWeightBold;

  /// Extra logical pixels inserted between glyphs.
  final double letterSpacing;

  /// Cursor shape.
  final TerminalCursorType cursorType;

  /// Whether the cursor should blink.
  final bool cursorBlink;

  /// Width of the bar cursor in logical pixels.
  final double cursorWidth;

  /// Converts these settings to a Flutter text style.
  TextStyle toTextStyle({Color? color, Color? backgroundColor}) => TextStyle(
    color: color,
    backgroundColor: backgroundColor,
    fontFamily: fontFamily,
    fontFamilyFallback: const <String>['monospace'],
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
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
    foreground: const Color(0xffffffff),
    background: const Color(0xff000000),
    cursor: const Color(0xffffffff),
    selection: const Color(0x4dffffff),
    palette: _palette,
  );

  /// Resolves xterm's partial public theme against its browser defaults.
  static TerminalTheme resolve(
    TerminalColorTheme theme, {
    TerminalColorOverrides? overrides,
  }) {
    final palette = List<Color>.of(_palette);
    final themeOverrides = <String?>[
      theme.black,
      theme.red,
      theme.green,
      theme.yellow,
      theme.blue,
      theme.magenta,
      theme.cyan,
      theme.white,
      theme.brightBlack,
      theme.brightRed,
      theme.brightGreen,
      theme.brightYellow,
      theme.brightBlue,
      theme.brightMagenta,
      theme.brightCyan,
      theme.brightWhite,
    ];
    for (var index = 0; index < themeOverrides.length; index++) {
      palette[index] = _parse(themeOverrides[index]) ?? palette[index];
    }
    final extended = theme.extendedAnsi;
    if (extended != null) {
      for (var index = 0; index < extended.length && index < 240; index++) {
        palette[index + 16] = _parse(extended[index]) ?? palette[index + 16];
      }
    }
    if (overrides != null) {
      for (final entry in overrides.indexed.entries) {
        if (entry.key >= 0 && entry.key < palette.length) {
          palette[entry.key] = Color(0xff000000 | entry.value);
        }
      }
    }
    return TerminalTheme(
      foreground: overrides?.foreground == null
          ? _parse(theme.foreground) ?? defaultTheme.foreground
          : Color(0xff000000 | overrides!.foreground!),
      background: overrides?.background == null
          ? _parse(theme.background) ?? defaultTheme.background
          : Color(0xff000000 | overrides!.background!),
      cursor: overrides?.cursor == null
          ? _parse(theme.cursor) ?? defaultTheme.cursor
          : Color(0xff000000 | overrides!.cursor!),
      selection: _parse(theme.selectionBackground) ?? defaultTheme.selection,
      palette: List<Color>.unmodifiable(palette),
    );
  }

  static Color? _parse(String? source) {
    if (source == null) return null;
    final value = source.trim().toLowerCase();
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 3 || hex.length == 4) {
        final expanded = hex.split('').map((part) => '$part$part').join();
        return _hexColor(expanded);
      }
      return _hexColor(hex);
    }
    final match = RegExp(
      r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)$',
    ).firstMatch(value);
    if (match == null) return null;
    final red = int.parse(match.group(1)!).clamp(0, 255);
    final green = int.parse(match.group(2)!).clamp(0, 255);
    final blue = int.parse(match.group(3)!).clamp(0, 255);
    final alphaText = match.group(4);
    final alpha = alphaText == null
        ? 255
        : (double.parse(alphaText).clamp(0, 1) * 255).round();
    return Color.fromARGB(alpha, red, green, blue);
  }

  static Color? _hexColor(String hex) {
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    if (hex.length == 6) return Color(0xff000000 | parsed);
    if (hex.length == 8) {
      return Color((parsed & 0xff) << 24 | parsed >> 8);
    }
    return null;
  }

  static List<Color> _buildPalette() {
    final colors = <Color>[
      const Color(0xff2e3436),
      const Color(0xffcc0000),
      const Color(0xff4e9a06),
      const Color(0xffc4a000),
      const Color(0xff3465a4),
      const Color(0xff75507b),
      const Color(0xff06989a),
      const Color(0xffd3d7cf),
      const Color(0xff555753),
      const Color(0xffef2929),
      const Color(0xff8ae234),
      const Color(0xfffce94f),
      const Color(0xff729fcf),
      const Color(0xffad7fa8),
      const Color(0xff34e2e2),
      const Color(0xffeeeeec),
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
