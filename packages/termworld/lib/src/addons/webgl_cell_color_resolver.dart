import 'dart:math' as math;

import 'package:termworld/src/core/renderer_utils.dart';

/// xterm packed cell color masks used by the WebGL renderer.
abstract final class TerminalWebglAttributes {
  /// Low-byte palette index mask.
  static const int paletteColorMask = 0xff;

  /// Packed 24-bit RGB mask.
  static const int rgbMask = 0xffffff;

  /// Packed color-mode mask.
  static const int colorModeMask = 0x3000000;

  /// Default color mode.
  static const int colorModeDefault = 0;

  /// ANSI 16-color palette mode.
  static const int colorModePalette16 = 0x1000000;

  /// ANSI 256-color palette mode.
  static const int colorModePalette256 = 0x2000000;

  /// True-color RGB mode.
  static const int colorModeRgb = 0x3000000;

  /// Foreground inverse flag.
  static const int inverse = 0x4000000;

  /// Background dim flag.
  static const int dim = 0x8000000;

  /// Background extended-attributes flag.
  static const int hasExtended = 0x10000000;

  /// Extended-attribute glyph variant field.
  static const int variantOffset = 0xe0000000;
}

/// One packed xterm cell as consumed by the WebGL color resolver.
final class TerminalWebglPackedCell {
  /// Creates a packed cell snapshot.
  const TerminalWebglPackedCell({
    required this.code,
    required this.foreground,
    required this.background,
    this.extended = 0,
    this.underlineStyle = 0,
  });

  /// Unicode code point, or zero for a null cell.
  final int code;

  /// Packed foreground color and flags.
  final int foreground;

  /// Packed background color and flags.
  final int background;

  /// Packed extended attributes.
  final int extended;

  /// xterm underline style ordinal.
  final int underlineStyle;
}

/// Foreground/background override supplied by a terminal decoration.
final class TerminalWebglDecorationColors {
  /// Creates a decoration override.
  const TerminalWebglDecorationColors({
    this.backgroundRgba,
    this.foregroundRgba,
  });

  /// Optional RGBA32 background override.
  final int? backgroundRgba;

  /// Optional RGBA32 foreground override.
  final int? foregroundRgba;
}

/// Theme colors needed to resolve a packed WebGL cell.
final class TerminalWebglCellColorSet {
  /// Creates a color set.
  const TerminalWebglCellColorSet({
    required this.ansi,
    required this.foregroundRgba,
    required this.backgroundRgba,
    required this.selectionBackgroundOpaqueRgba,
    required this.selectionInactiveBackgroundOpaqueRgba,
    this.selectionForegroundRgba,
  });

  /// ANSI palette colors encoded as RGBA32.
  final List<int> ansi;

  /// Default terminal foreground encoded as RGBA32.
  final int foregroundRgba;

  /// Default terminal background encoded as RGBA32.
  final int backgroundRgba;

  /// Opaque focused selection background encoded as RGBA32.
  final int selectionBackgroundOpaqueRgba;

  /// Opaque unfocused selection background encoded as RGBA32.
  final int selectionInactiveBackgroundOpaqueRgba;

  /// Optional explicit selection foreground encoded as RGBA32.
  final int? selectionForegroundRgba;
}

/// Resolved packed colors and extended attributes for one WebGL cell.
final class TerminalWebglCellColorResult {
  /// Creates a result.
  const TerminalWebglCellColorResult({
    required this.foreground,
    required this.background,
    required this.extended,
  });

  /// Packed foreground.
  final int foreground;

  /// Packed background.
  final int background;

  /// Packed extended attributes.
  final int extended;
}

/// Resolves decoration, selection and inverse overrides exactly like xterm.
final class TerminalWebglCellColorResolver {
  /// Creates a resolver for a renderer frame.
  const TerminalWebglCellColorResolver({
    required this.colors,
    required this.isFocused,
    required this.fontSize,
    required this.devicePixelRatio,
    required this.isCellSelected,
    this.bottomDecorations = _noDecorations,
    this.topDecorations = _noDecorations,
  });

  /// Active terminal theme.
  final TerminalWebglCellColorSet colors;

  /// Whether the terminal currently has focus.
  final bool isFocused;

  /// Configured logical font size.
  final double fontSize;

  /// Device pixel ratio.
  final double devicePixelRatio;

  /// Selection query for a viewport cell.
  final bool Function(int x, int y) isCellSelected;

  /// Bottom-layer decorations for a viewport cell, in registration order.
  final Iterable<TerminalWebglDecorationColors> Function(int x, int y)
  bottomDecorations;

  /// Top-layer decorations for a viewport cell, in registration order.
  final Iterable<TerminalWebglDecorationColors> Function(int x, int y)
  topDecorations;

  /// Resolves [cell] for viewport position ([x], [y]).
  TerminalWebglCellColorResult resolve(
    TerminalWebglPackedCell cell,
    int x,
    int y,
    double deviceCellWidth,
    double deviceCellHeight,
  ) {
    var resultBackground = cell.background;
    var resultForeground = cell.foreground;
    var resultExtended =
        cell.background & TerminalWebglAttributes.hasExtended != 0
        ? cell.extended
        : 0;
    var background = 0;
    var foreground = 0;
    var hasBackground = false;
    var hasForeground = false;
    final selected = isCellSelected(x, y);

    var variantOffset = 0;
    if (cell.code != 0 && cell.underlineStyle == 4) {
      final lineWidth = math.max(
        1,
        (fontSize * devicePixelRatio / 15).floor(),
      );
      variantOffset = (x * deviceCellWidth).toInt() % (lineWidth * 2);
    }
    if (variantOffset == 0 &&
        terminalWebglBlockPatternCodepoints.contains(cell.code)) {
      variantOffset =
          ((x * deviceCellWidth).toInt() % 2) * 2 +
          (y * deviceCellHeight).toInt() % 2;
    }

    for (final decoration in bottomDecorations(x, y)) {
      final backgroundRgba = decoration.backgroundRgba;
      if (backgroundRgba != null) {
        background = backgroundRgba >> 8 & TerminalWebglAttributes.rgbMask;
        hasBackground = true;
      }
      final foregroundRgba = decoration.foregroundRgba;
      if (foregroundRgba != null) {
        foreground = foregroundRgba >> 8 & TerminalWebglAttributes.rgbMask;
        hasForeground = true;
      }
    }

    if (selected) {
      final selectionRgba = isFocused
          ? colors.selectionBackgroundOpaqueRgba
          : colors.selectionInactiveBackgroundOpaqueRgba;
      if (resultForeground & TerminalWebglAttributes.inverse != 0 ||
          resultBackground & TerminalWebglAttributes.colorModeMask !=
              TerminalWebglAttributes.colorModeDefault) {
        background = resultForeground & TerminalWebglAttributes.inverse != 0
            ? _resolvePackedForegroundColor(resultForeground)
            : _resolvePackedBackgroundColor(resultBackground);
        background =
            _blendRgba(
                  background,
                  selectionRgba & 0xffffff00 | 0x80,
                ) >>
                8 &
            TerminalWebglAttributes.rgbMask;
      } else {
        background = selectionRgba >> 8 & TerminalWebglAttributes.rgbMask;
      }
      hasBackground = true;

      final selectionForeground = colors.selectionForegroundRgba;
      if (selectionForeground != null) {
        foreground = selectionForeground >> 8 & TerminalWebglAttributes.rgbMask;
        hasForeground = true;
      }

      if (treatGlyphAsBackgroundColor(cell.code)) {
        if (resultForeground & TerminalWebglAttributes.inverse != 0 &&
            resultBackground & TerminalWebglAttributes.colorModeMask ==
                TerminalWebglAttributes.colorModeDefault) {
          foreground = selectionRgba >> 8 & TerminalWebglAttributes.rgbMask;
        } else {
          foreground = resultForeground & TerminalWebglAttributes.inverse != 0
              ? _resolvePackedBackgroundColor(resultBackground)
              : _resolvePackedForegroundColor(resultForeground);
          foreground =
              _blendRgba(
                    foreground,
                    selectionRgba & 0xffffff00 | 0x80,
                  ) >>
                  8 &
              TerminalWebglAttributes.rgbMask;
        }
        hasForeground = true;
      }
    }

    for (final decoration in topDecorations(x, y)) {
      final backgroundRgba = decoration.backgroundRgba;
      if (backgroundRgba != null) {
        background = backgroundRgba >> 8 & TerminalWebglAttributes.rgbMask;
        hasBackground = true;
      }
      final foregroundRgba = decoration.foregroundRgba;
      if (foregroundRgba != null) {
        foreground = foregroundRgba >> 8 & TerminalWebglAttributes.rgbMask;
        hasForeground = true;
      }
    }

    if (hasBackground) {
      background = selected
          ? cell.background &
                    ~TerminalWebglAttributes.rgbMask &
                    ~TerminalWebglAttributes.dim |
                background |
                TerminalWebglAttributes.colorModeRgb
          : cell.background & ~TerminalWebglAttributes.rgbMask |
                background |
                TerminalWebglAttributes.colorModeRgb;
    }
    if (hasForeground) {
      foreground =
          cell.foreground &
              ~TerminalWebglAttributes.rgbMask &
              ~TerminalWebglAttributes.inverse |
          foreground |
          TerminalWebglAttributes.colorModeRgb;
    }

    if (resultForeground & TerminalWebglAttributes.inverse != 0) {
      if (hasBackground && !hasForeground) {
        foreground =
            resultBackground & TerminalWebglAttributes.colorModeMask ==
                TerminalWebglAttributes.colorModeDefault
            ? resultForeground &
                      ~(TerminalWebglAttributes.rgbMask |
                          TerminalWebglAttributes.inverse |
                          TerminalWebglAttributes.colorModeMask) |
                  colors.backgroundRgba >> 8 & TerminalWebglAttributes.rgbMask |
                  TerminalWebglAttributes.colorModeRgb
            : resultForeground &
                      ~(TerminalWebglAttributes.rgbMask |
                          TerminalWebglAttributes.inverse |
                          TerminalWebglAttributes.colorModeMask) |
                  resultBackground &
                      (TerminalWebglAttributes.rgbMask |
                          TerminalWebglAttributes.colorModeMask);
        hasForeground = true;
      }
      if (!hasBackground && hasForeground) {
        background =
            resultForeground & TerminalWebglAttributes.colorModeMask ==
                TerminalWebglAttributes.colorModeDefault
            ? resultBackground &
                      ~(TerminalWebglAttributes.rgbMask |
                          TerminalWebglAttributes.colorModeMask) |
                  colors.foregroundRgba >> 8 & TerminalWebglAttributes.rgbMask |
                  TerminalWebglAttributes.colorModeRgb
            : resultBackground &
                      ~(TerminalWebglAttributes.rgbMask |
                          TerminalWebglAttributes.colorModeMask) |
                  resultForeground &
                      (TerminalWebglAttributes.rgbMask |
                          TerminalWebglAttributes.colorModeMask);
        hasBackground = true;
      }
    }

    resultBackground = hasBackground ? background : resultBackground;
    resultForeground = hasForeground ? foreground : resultForeground;
    resultExtended &= ~TerminalWebglAttributes.variantOffset;
    resultExtended |=
        variantOffset << 29 & TerminalWebglAttributes.variantOffset;
    return TerminalWebglCellColorResult(
      foreground: resultForeground,
      background: resultBackground,
      extended: resultExtended,
    );
  }

  int _resolvePackedForegroundColor(int packed) {
    return switch (packed & TerminalWebglAttributes.colorModeMask) {
      TerminalWebglAttributes.colorModePalette16 ||
      TerminalWebglAttributes.colorModePalette256 =>
        colors.ansi[packed & TerminalWebglAttributes.paletteColorMask],
      TerminalWebglAttributes.colorModeRgb =>
        (packed & TerminalWebglAttributes.rgbMask) << 8 | 0xff,
      _ => colors.foregroundRgba,
    };
  }

  int _resolvePackedBackgroundColor(int packed) {
    return switch (packed & TerminalWebglAttributes.colorModeMask) {
      TerminalWebglAttributes.colorModePalette16 ||
      TerminalWebglAttributes.colorModePalette256 =>
        colors.ansi[packed & TerminalWebglAttributes.paletteColorMask],
      TerminalWebglAttributes.colorModeRgb =>
        (packed & TerminalWebglAttributes.rgbMask) << 8 | 0xff,
      _ => colors.backgroundRgba,
    };
  }
}

/// xterm custom glyphs whose phase depends on their viewport cell position.
const Set<int> terminalWebglBlockPatternCodepoints = <int>{
  0x2591,
  0x2592,
  0x2593,
  0x1fb8c,
  0x1fb8d,
  0x1fb8e,
  0x1fb8f,
  0x1fb90,
  0x1fb91,
  0x1fb92,
  0x1fb94,
  0x1fb9c,
  0x1fb9d,
  0x1fb9e,
  0x1fb9f,
};

Iterable<TerminalWebglDecorationColors> _noDecorations(int x, int y) =>
    const <TerminalWebglDecorationColors>[];

int _blendRgba(int background, int foreground) {
  final alpha = (foreground & 0xff) / 0xff;
  if (alpha == 1) return foreground;
  final red = _jsRound(
    (background >> 24 & 0xff) +
        ((foreground >> 24 & 0xff) - (background >> 24 & 0xff)) * alpha,
  );
  final green = _jsRound(
    (background >> 16 & 0xff) +
        ((foreground >> 16 & 0xff) - (background >> 16 & 0xff)) * alpha,
  );
  final blue = _jsRound(
    (background >> 8 & 0xff) +
        ((foreground >> 8 & 0xff) - (background >> 8 & 0xff)) * alpha,
  );
  return red << 24 | green << 16 | blue << 8 | 0xff;
}

int _jsRound(double value) => (value + 0.5).floor();
