import 'package:flutter/widgets.dart';
import 'package:termworld/src/flutter/terminal_theme.dart';
import 'package:vtworld/vtworld.dart';

/// Renderer color override attached to one terminal cell.
@immutable
final class TerminalCellDecorationColors {
  /// Creates a foreground/background override.
  const TerminalCellDecorationColors({this.foreground, this.background});

  /// Optional foreground override.
  final Color? foreground;

  /// Optional background override.
  final Color? background;
}

/// Fully resolved colors for one Flutter renderer cell.
@immutable
final class TerminalResolvedCellColors {
  /// Creates a resolved cell color pair.
  const TerminalResolvedCellColors({
    required this.foreground,
    required this.background,
    required this.cellBackground,
    required this.paintBackground,
    required this.backgroundOverlays,
  });

  /// Effective glyph color.
  final Color foreground;

  /// Effective cell background after selection and decorations.
  final Color background;

  /// Background below image cells and selection/top decorations.
  final Color cellBackground;

  /// Whether the cell needs a background rectangle over the terminal surface.
  final bool paintBackground;

  /// Background layers painted above image cells, in xterm paint order.
  final List<Color> backgroundOverlays;
}

/// Resolves xterm's inverse, decoration and selection color precedence.
///
/// The order is deliberately shared with xterm's DOM and WebGL renderers:
/// inverse, bottom decoration, selection and finally top decoration.
final class TerminalCellColorResolver {
  /// Creates a resolver for one renderer frame.
  const TerminalCellColorResolver({
    required this.theme,
    required this.focused,
    required this.drawBoldTextInBrightColors,
    required this.minimumContrastRatio,
  });

  /// Active renderer theme.
  final TerminalTheme theme;

  /// Whether active rather than inactive selection colors are used.
  final bool focused;

  /// Whether bold ANSI 0-7 foregrounds are promoted to 8-15.
  final bool drawBoldTextInBrightColors;

  /// Requested WCAG contrast ratio.
  final double minimumContrastRatio;

  /// Resolves [cell] using decorations in registration order.
  TerminalResolvedCellColors resolve(
    TerminalCell cell, {
    required bool selected,
    Iterable<TerminalCellDecorationColors> bottomDecorations = const [],
    Iterable<TerminalCellDecorationColors> topDecorations = const [],
  }) {
    var foregroundMode = cell.foregroundMode;
    var foregroundValue = cell.foreground;
    var backgroundMode = cell.backgroundMode;
    var backgroundValue = cell.background;
    if (cell.isInverse) {
      final swappedMode = foregroundMode;
      final swappedValue = foregroundValue;
      foregroundMode = backgroundMode;
      foregroundValue = backgroundValue;
      backgroundMode = swappedMode;
      backgroundValue = swappedValue;
    }
    if (drawBoldTextInBrightColors &&
        cell.isBold &&
        foregroundMode == TerminalColorMode.palette &&
        foregroundValue < 8) {
      foregroundValue += 8;
    }

    var foreground = _color(
      foregroundMode,
      foregroundValue,
      cell.isInverse ? theme.background : theme.foreground,
    );
    // xterm's inverted default foreground uses `color.opaque(background)`.
    // A transparent terminal surface must not make inverse glyphs transparent.
    if (cell.isInverse &&
        foregroundMode == TerminalColorMode.defaultColor &&
        foreground.a != 1) {
      foreground = foreground.withValues(alpha: 1);
    }
    var background = _color(
      backgroundMode,
      backgroundValue,
      cell.isInverse ? theme.foreground : theme.background,
    );
    var hasBackground =
        backgroundMode != TerminalColorMode.defaultColor || cell.isInverse;
    var foregroundOverridden = false;

    void apply(Iterable<TerminalCellDecorationColors> decorations) {
      for (final decoration in decorations) {
        final decorationBackground = decoration.background;
        if (decorationBackground != null) {
          background = decorationBackground;
          hasBackground = true;
        }
        final decorationForeground = decoration.foreground;
        if (decorationForeground != null) {
          foreground = decorationForeground;
          foregroundOverridden = true;
        }
      }
    }

    apply(bottomDecorations);
    final cellBackground = background;
    final paintCellBackground = hasBackground;
    final backgroundOverlays = <Color>[];
    if (selected) {
      final selection = focused
          ? theme.selectionOpaque ??
                TerminalThemes.blend(theme.background, theme.selection)
          : theme.selectionInactiveOpaque ??
                TerminalThemes.blend(
                  theme.background,
                  theme.selectionInactive,
                );
      final hasOriginalBackground =
          cell.isInverse ||
          cell.backgroundMode != TerminalColorMode.defaultColor;
      final selectionLayer = hasOriginalBackground
          ? selection.withValues(alpha: 0x80 / 0xff)
          : selection;
      backgroundOverlays.add(selectionLayer);
      background = TerminalThemes.blend(background, selectionLayer);
      final selectionForeground = theme.selectionForeground;
      if (selectionForeground != null) {
        foreground = selectionForeground;
        foregroundOverridden = true;
      }
    }
    for (final decoration in topDecorations) {
      final decorationBackground = decoration.background;
      if (decorationBackground != null) {
        backgroundOverlays.add(decorationBackground);
        background = TerminalThemes.blend(background, decorationBackground);
      }
      final decorationForeground = decoration.foreground;
      if (decorationForeground != null) {
        foreground = decorationForeground;
        foregroundOverridden = true;
      }
    }
    var contrastOverridden = false;
    if (cell.code != 0 &&
        !treatGlyphAsBackground(cell.code) &&
        minimumContrastRatio != 1) {
      final adjusted = TerminalThemes.ensureContrast(
        background,
        foreground,
        minimumContrastRatio / (cell.isDim ? 2 : 1),
      );
      contrastOverridden = adjusted != foreground;
      foreground = adjusted;
    }
    if (cell.isDim && !foregroundOverridden && !contrastOverridden) {
      foreground = foreground.withValues(alpha: foreground.a * 0.5);
    }
    return TerminalResolvedCellColors(
      foreground: foreground,
      background: background,
      cellBackground: cellBackground,
      paintBackground: paintCellBackground,
      backgroundOverlays: List<Color>.unmodifiable(backgroundOverlays),
    );
  }

  Color _color(TerminalColorMode mode, int value, Color fallback) =>
      switch (mode) {
        TerminalColorMode.defaultColor => fallback,
        TerminalColorMode.palette =>
          value >= 0 && value < theme.palette.length
              ? theme.palette[value]
              : fallback,
        TerminalColorMode.rgb => Color(0xff000000 | value),
      };

  /// Whether xterm treats a glyph as a colored background shape.
  static bool treatGlyphAsBackground(int codePoint) =>
      codePoint >= 0xe0a4 && codePoint <= 0xe0d6 ||
      codePoint >= 0x2500 && codePoint <= 0x259f;
}
