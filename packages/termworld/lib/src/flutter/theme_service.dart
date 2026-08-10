import 'package:flutter/material.dart';
import 'package:termworld/src/flutter/terminal_theme.dart';
import 'package:vtworld/vtworld.dart';

/// Two-color-key cache used by xterm's contrast calculation path.
final class ColorContrastCache {
  final Map<(int, int), Color?> _colors = <(int, int), Color?>{};
  final Map<(int, int), String?> _css = <(int, int), String?>{};

  /// Associates a rendered CSS result with background and foreground RGBA.
  void setCss(int background, int foreground, String? value) {
    _css[(background, foreground)] = value;
  }

  /// Returns a cached CSS result, including a cached `null` result.
  String? getCss(int background, int foreground) =>
      _css[(background, foreground)];

  /// Whether a CSS result has been cached for this pair.
  bool hasCss(int background, int foreground) =>
      _css.containsKey((background, foreground));

  /// Associates a color result with background and foreground RGBA.
  void setColor(int background, int foreground, Color? value) {
    _colors[(background, foreground)] = value;
  }

  /// Returns a cached color result, including a cached `null` result.
  Color? getColor(int background, int foreground) =>
      _colors[(background, foreground)];

  /// Whether a color result has been cached for this pair.
  bool hasColor(int background, int foreground) =>
      _colors.containsKey((background, foreground));

  /// Clears both representations.
  void clear() {
    _colors.clear();
    _css.clear();
  }
}

/// Mutable renderer color set owned by [TerminalThemeService].
final class TerminalColorSet {
  /// Creates a complete renderer color set.
  TerminalColorSet({
    required this.foreground,
    required this.background,
    required this.cursor,
    required this.cursorAccent,
    required this.selectionBackgroundTransparent,
    required this.selectionBackgroundOpaque,
    required this.selectionInactiveBackgroundTransparent,
    required this.selectionInactiveBackgroundOpaque,
    required this.scrollbarSliderBackground,
    required this.scrollbarSliderHoverBackground,
    required this.scrollbarSliderActiveBackground,
    required this.overviewRulerBorder,
    required this.ansi,
    required this.contrastCache,
    required this.halfContrastCache,
    this.selectionForeground,
  });

  /// Default text color.
  Color foreground;

  /// Default surface color.
  Color background;

  /// Cursor fill color.
  Color cursor;

  /// Text color inside a block cursor.
  Color cursorAccent;

  /// Optional selected-text foreground.
  Color? selectionForeground;

  /// Active selection overlay before compositing.
  Color selectionBackgroundTransparent;

  /// Active selection composited over the background.
  Color selectionBackgroundOpaque;

  /// Inactive selection overlay before compositing.
  Color selectionInactiveBackgroundTransparent;

  /// Inactive selection composited over the background.
  Color selectionInactiveBackgroundOpaque;

  /// Scrollbar slider color.
  Color scrollbarSliderBackground;

  /// Hovered scrollbar slider color.
  Color scrollbarSliderHoverBackground;

  /// Active scrollbar slider color.
  Color scrollbarSliderActiveBackground;

  /// Overview-ruler border color.
  Color overviewRulerBorder;

  /// Mutable ANSI 256-color palette.
  List<Color> ansi;

  /// Full contrast result cache.
  final ColorContrastCache contrastCache;

  /// Half-contrast result cache.
  final ColorContrastCache halfContrastCache;
}

/// Resolves live terminal options into xterm-compatible renderer colors.
final class TerminalThemeService extends DisposableStore {
  /// Creates a service that follows [terminalOptions] theme changes.
  TerminalThemeService(TerminalOptions terminalOptions)
    : _options = terminalOptions {
    _colors = _resolve(_options.theme);
    _updateRestoreColors();
    add(
      _options.onSpecificOptionChange('minimumContrastRatio', (_) {
        _contrastCache.clear();
      }),
    );
    add(
      _options.onSpecificOptionChange('theme', (_) {
        _setTheme(_options.theme);
      }),
    );
  }

  final TerminalOptions _options;
  final ColorContrastCache _contrastCache = ColorContrastCache();
  final ColorContrastCache _halfContrastCache = ColorContrastCache();
  final TerminalEventEmitter<TerminalColorSet> _onChangeColors =
      TerminalEventEmitter<TerminalColorSet>();
  late TerminalColorSet _colors;
  late _RestoreColorSet _restoreColors;

  /// Current mutable color set.
  TerminalColorSet get colors => _colors;

  /// Fires synchronously after any color-set mutation.
  TerminalEvent<TerminalColorSet> get onChangeColors => _onChangeColors.event;

  /// Restores all ANSI colors, or the requested special/indexed [slot].
  ///
  /// Special slots -1, -2 and -3 represent foreground, background and cursor.
  void restoreColor([int? slot]) {
    if (slot == null) {
      _colors.ansi = List<Color>.of(_restoreColors.ansi);
    } else if (slot == -1) {
      _colors.foreground = _restoreColors.foreground;
    } else if (slot == -2) {
      _colors.background = _restoreColors.background;
    } else if (slot == -3) {
      _colors.cursor = _restoreColors.cursor;
    } else if (slot >= 0 && slot < _colors.ansi.length) {
      _colors.ansi[slot] = _restoreColors.ansi[slot];
    }
    _onChangeColors.fire(_colors);
  }

  /// Applies an in-place color mutation and announces it.
  void modifyColors(void Function(TerminalColorSet colors) callback) {
    callback(_colors);
    _onChangeColors.fire(_colors);
  }

  void _setTheme(TerminalColorTheme theme) {
    _colors = _resolve(theme);
    _contrastCache.clear();
    _halfContrastCache.clear();
    _updateRestoreColors();
    _onChangeColors.fire(_colors);
  }

  TerminalColorSet _resolve(TerminalColorTheme theme) {
    final resolved = TerminalThemes.resolve(theme);
    Color parsed(String? source, Color fallback) =>
        TerminalThemes.parseColor(source) ?? fallback;
    final selectionOpaque =
        resolved.selectionOpaque ??
        TerminalThemes.blend(resolved.background, resolved.selection);
    final inactiveOpaque =
        resolved.selectionInactiveOpaque ??
        TerminalThemes.blend(
          resolved.background,
          resolved.selectionInactive,
        );
    return TerminalColorSet(
      foreground: resolved.foreground,
      background: resolved.background,
      cursor: resolved.cursor,
      cursorAccent: resolved.cursorAccent,
      selectionForeground: resolved.selectionForeground,
      selectionBackgroundTransparent: resolved.selection,
      selectionBackgroundOpaque: selectionOpaque,
      selectionInactiveBackgroundTransparent: resolved.selectionInactive,
      selectionInactiveBackgroundOpaque: inactiveOpaque,
      scrollbarSliderBackground: parsed(
        theme.scrollbarSliderBackground,
        resolved.foreground.withValues(alpha: 0.2),
      ),
      scrollbarSliderHoverBackground: parsed(
        theme.scrollbarSliderHoverBackground,
        resolved.foreground.withValues(alpha: 0.4),
      ),
      scrollbarSliderActiveBackground: parsed(
        theme.scrollbarSliderActiveBackground,
        resolved.foreground.withValues(alpha: 0.5),
      ),
      overviewRulerBorder: parsed(
        theme.overviewRulerBorder,
        TerminalThemes.defaultTheme.foreground,
      ),
      ansi: List<Color>.of(resolved.palette),
      contrastCache: _contrastCache,
      halfContrastCache: _halfContrastCache,
    );
  }

  void _updateRestoreColors() {
    _restoreColors = _RestoreColorSet(
      foreground: _colors.foreground,
      background: _colors.background,
      cursor: _colors.cursor,
      ansi: List<Color>.of(_colors.ansi),
    );
  }

  @override
  void dispose() {
    if (isDisposed) return;
    _onChangeColors.dispose();
    super.dispose();
  }
}

final class _RestoreColorSet {
  const _RestoreColorSet({
    required this.foreground,
    required this.background,
    required this.cursor,
    required this.ansi,
  });

  final Color foreground;
  final Color background;
  final Color cursor;
  final List<Color> ansi;
}
