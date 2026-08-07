import 'package:termworld/src/core/event.dart';

/// Terminal log levels in increasing severity order.
/// xterm-compatible `TerminalLogLevel` API.
enum TerminalLogLevel {
  /// Finest-grained internal tracing.
  trace,

  /// Debug diagnostics.
  debug,

  /// Informational diagnostics.
  info,

  /// Recoverable warning diagnostics.
  warning,

  /// Error diagnostics.
  error,

  /// Disables logging.
  off,
}

/// Cursor shape.
/// xterm-compatible `TerminalCursorStyle` API.
enum TerminalCursorStyle {
  /// A full-cell block cursor.
  block,

  /// An underline cursor.
  underline,

  /// A vertical bar cursor.
  bar,
}

/// Cursor shape used while the terminal is not focused.
/// xterm-compatible `TerminalInactiveCursorStyle` API.
enum TerminalInactiveCursorStyle {
  /// An outlined block cursor.
  outline,

  /// A full-cell block cursor.
  block,

  /// A vertical bar cursor.
  bar,

  /// An underline cursor.
  underline,

  /// No inactive cursor.
  none,
}

/// Logger used by the terminal core.
// A named interface is required for dependency injection in public options.
// ignore: one_member_abstracts
abstract interface class TerminalLogger {
  /// Emits a diagnostic message.
  void log(TerminalLogLevel level, String message, [Object? data]);
}

/// A serializable xterm color theme. Colors use CSS-compatible strings.
final class TerminalColorTheme {
  /// Creates a theme override. Null entries use the xterm defaults.
  const TerminalColorTheme({
    this.foreground,
    this.background,
    this.cursor,
    this.cursorAccent,
    this.selectionBackground,
    this.selectionForeground,
    this.selectionInactiveBackground,
    this.black,
    this.red,
    this.green,
    this.yellow,
    this.blue,
    this.magenta,
    this.cyan,
    this.white,
    this.brightBlack,
    this.brightRed,
    this.brightGreen,
    this.brightYellow,
    this.brightBlue,
    this.brightMagenta,
    this.brightCyan,
    this.brightWhite,
    this.extendedAnsi,
  });

  /// xterm-compatible `foreground` API.
  final String? foreground;

  /// xterm-compatible `background` API.
  final String? background;

  /// xterm-compatible `cursor` API.
  final String? cursor;

  /// xterm-compatible `cursorAccent` API.
  final String? cursorAccent;

  /// xterm-compatible `selectionBackground` API.
  final String? selectionBackground;

  /// xterm-compatible `selectionForeground` API.
  final String? selectionForeground;

  /// xterm-compatible `selectionInactiveBackground` API.
  final String? selectionInactiveBackground;

  /// xterm-compatible `black` API.
  final String? black;

  /// xterm-compatible `red` API.
  final String? red;

  /// xterm-compatible `green` API.
  final String? green;

  /// xterm-compatible `yellow` API.
  final String? yellow;

  /// xterm-compatible `blue` API.
  final String? blue;

  /// xterm-compatible `magenta` API.
  final String? magenta;

  /// xterm-compatible `cyan` API.
  final String? cyan;

  /// xterm-compatible `white` API.
  final String? white;

  /// xterm-compatible `brightBlack` API.
  final String? brightBlack;

  /// xterm-compatible `brightRed` API.
  final String? brightRed;

  /// xterm-compatible `brightGreen` API.
  final String? brightGreen;

  /// xterm-compatible `brightYellow` API.
  final String? brightYellow;

  /// xterm-compatible `brightBlue` API.
  final String? brightBlue;

  /// xterm-compatible `brightMagenta` API.
  final String? brightMagenta;

  /// xterm-compatible `brightCyan` API.
  final String? brightCyan;

  /// xterm-compatible `brightWhite` API.
  final String? brightWhite;

  /// xterm-compatible `extendedAnsi` API.
  final List<String>? extendedAnsi;
}

/// Mutable terminal options with the defaults and bounds used by xterm.js.
final class TerminalOptions {
  /// Creates options using xterm.js defaults.
  TerminalOptions({
    this.allowProposedApi = false,
    this.allowTransparency = false,
    this.altClickMovesCursor = true,
    this.convertEol = false,
    this.cursorBlink = false,
    int blinkIntervalDuration = 0,
    this.cursorStyle = TerminalCursorStyle.block,
    int cursorWidth = 1,
    this.cursorInactiveStyle = TerminalInactiveCursorStyle.outline,
    this.disableStdin = false,
    this.drawBoldTextInBrightColors = true,
    double fastScrollSensitivity = 5,
    this.fontSize = 15,
    this.fontFamily = 'monospace',
    this.fontWeight = 'normal',
    this.fontWeightBold = 'bold',
    this.ignoreBracketedPasteMode = false,
    this.letterSpacing = 0,
    double lineHeight = 1,
    this.logLevel = TerminalLogLevel.info,
    this.logger,
    this.macOptionIsMeta = false,
    this.macOptionClickForcesSelection = false,
    double minimumContrastRatio = 1,
    this.mouseEventsRequireAlt = false,
    this.reflowCursorLine = false,
    this.rescaleOverlappingGlyphs = false,
    this.rightClickSelectsWord = false,
    this.screenReaderMode = false,
    int scrollback = 1000,
    this.scrollOnEraseInDisplay = false,
    this.scrollOnUserInput = true,
    double scrollSensitivity = 1,
    this.smoothScrollDuration = 0,
    int tabStopWidth = 8,
    this.theme = const TerminalColorTheme(),
    this.wordSeparator = ' ()[]{}\',"`',
    this.cols = 80,
    this.rows = 24,
    this.showCursorImmediately = false,
  }) : _blinkIntervalDuration = _nonNegative(
         'blinkIntervalDuration',
         blinkIntervalDuration,
       ),
       _cursorWidth = _atLeastOne('cursorWidth', cursorWidth),
       _fastScrollSensitivity = _positive(
         'fastScrollSensitivity',
         fastScrollSensitivity,
       ),
       _lineHeight = _positive('lineHeight', lineHeight),
       _minimumContrastRatio = minimumContrastRatio.clamp(1, 21),
       _scrollback = _boundedScrollback(scrollback),
       _scrollSensitivity = _positive(
         'scrollSensitivity',
         scrollSensitivity,
       ),
       _tabStopWidth = _atLeastOne('tabStopWidth', tabStopWidth) {
    if (cols < 0 || rows < 0) {
      throw ArgumentError('cols and rows cannot be negative');
    }
    _validateFontWeight('fontWeight', fontWeight);
    _validateFontWeight('fontWeightBold', fontWeightBold);
  }

  final TerminalEventEmitter<String> _onChange = TerminalEventEmitter<String>();

  /// Fires with the Dart option name after a value changes.
  TerminalEvent<String> get onChange => _onChange.event;

  /// xterm-compatible `allowProposedApi` API.
  bool allowProposedApi;

  /// xterm-compatible `allowTransparency` API.
  bool allowTransparency;

  /// xterm-compatible `altClickMovesCursor` API.
  bool altClickMovesCursor;

  /// xterm-compatible `convertEol` API.
  bool convertEol;

  /// xterm-compatible `cursorBlink` API.
  bool cursorBlink;
  int _blinkIntervalDuration;

  /// xterm-compatible `cursorStyle` API.
  TerminalCursorStyle cursorStyle;
  int _cursorWidth;

  /// xterm-compatible `cursorInactiveStyle` API.
  TerminalInactiveCursorStyle cursorInactiveStyle;

  /// xterm-compatible `disableStdin` API.
  bool disableStdin;

  /// xterm-compatible `drawBoldTextInBrightColors` API.
  bool drawBoldTextInBrightColors;
  double _fastScrollSensitivity;

  /// xterm-compatible `fontSize` API.
  double fontSize;

  /// xterm-compatible `fontFamily` API.
  String fontFamily;

  /// xterm-compatible `fontWeight` API.
  Object fontWeight;

  /// xterm-compatible `fontWeightBold` API.
  Object fontWeightBold;

  /// xterm-compatible `ignoreBracketedPasteMode` API.
  bool ignoreBracketedPasteMode;

  /// xterm-compatible `letterSpacing` API.
  double letterSpacing;
  double _lineHeight;

  /// xterm-compatible `logLevel` API.
  TerminalLogLevel logLevel;

  /// xterm-compatible `logger` API.
  TerminalLogger? logger;

  /// xterm-compatible `macOptionIsMeta` API.
  bool macOptionIsMeta;

  /// xterm-compatible `macOptionClickForcesSelection` API.
  bool macOptionClickForcesSelection;
  double _minimumContrastRatio;

  /// xterm-compatible `mouseEventsRequireAlt` API.
  bool mouseEventsRequireAlt;

  /// xterm-compatible `reflowCursorLine` API.
  bool reflowCursorLine;

  /// xterm-compatible `rescaleOverlappingGlyphs` API.
  bool rescaleOverlappingGlyphs;

  /// xterm-compatible `rightClickSelectsWord` API.
  bool rightClickSelectsWord;

  /// xterm-compatible `screenReaderMode` API.
  bool screenReaderMode;
  int _scrollback;

  /// xterm-compatible `scrollOnEraseInDisplay` API.
  bool scrollOnEraseInDisplay;

  /// xterm-compatible `scrollOnUserInput` API.
  bool scrollOnUserInput;
  double _scrollSensitivity;

  /// xterm-compatible `smoothScrollDuration` API.
  int smoothScrollDuration;
  int _tabStopWidth;

  /// xterm-compatible `theme` API.
  TerminalColorTheme theme;

  /// xterm-compatible `wordSeparator` API.
  String wordSeparator;

  /// xterm-compatible `cols` API.
  final int cols;

  /// xterm-compatible `rows` API.
  final int rows;

  /// xterm-compatible `showCursorImmediately` API.
  final bool showCursorImmediately;

  /// xterm-compatible `blinkIntervalDuration` API.
  int get blinkIntervalDuration => _blinkIntervalDuration;

  /// xterm-compatible `blinkIntervalDuration` API.
  set blinkIntervalDuration(int value) => _set(
    'blinkIntervalDuration',
    _blinkIntervalDuration,
    _nonNegative('blinkIntervalDuration', value),
    (next) => _blinkIntervalDuration = next,
  );

  /// xterm-compatible `cursorWidth` API.
  int get cursorWidth => _cursorWidth;

  /// xterm-compatible `cursorWidth` API.
  set cursorWidth(int value) => _set(
    'cursorWidth',
    _cursorWidth,
    _atLeastOne('cursorWidth', value),
    (next) => _cursorWidth = next,
  );

  /// xterm-compatible `fastScrollSensitivity` API.
  double get fastScrollSensitivity => _fastScrollSensitivity;

  /// xterm-compatible `fastScrollSensitivity` API.
  set fastScrollSensitivity(double value) => _set(
    'fastScrollSensitivity',
    _fastScrollSensitivity,
    _positive('fastScrollSensitivity', value),
    (next) => _fastScrollSensitivity = next,
  );

  /// xterm-compatible `lineHeight` API.
  double get lineHeight => _lineHeight;

  /// xterm-compatible `lineHeight` API.
  set lineHeight(double value) => _set(
    'lineHeight',
    _lineHeight,
    _positive('lineHeight', value),
    (next) => _lineHeight = next,
  );

  /// xterm-compatible `minimumContrastRatio` API.
  double get minimumContrastRatio => _minimumContrastRatio;

  /// xterm-compatible `minimumContrastRatio` API.
  set minimumContrastRatio(double value) => _set(
    'minimumContrastRatio',
    _minimumContrastRatio,
    value.clamp(1, 21),
    (next) => _minimumContrastRatio = next.toDouble(),
  );

  /// xterm-compatible `scrollback` API.
  int get scrollback => _scrollback;

  /// xterm-compatible `scrollback` API.
  set scrollback(int value) => _set(
    'scrollback',
    _scrollback,
    _boundedScrollback(value),
    (next) => _scrollback = next,
  );

  /// xterm-compatible `scrollSensitivity` API.
  double get scrollSensitivity => _scrollSensitivity;

  /// xterm-compatible `scrollSensitivity` API.
  set scrollSensitivity(double value) => _set(
    'scrollSensitivity',
    _scrollSensitivity,
    _positive('scrollSensitivity', value),
    (next) => _scrollSensitivity = next,
  );

  /// xterm-compatible `tabStopWidth` API.
  int get tabStopWidth => _tabStopWidth;

  /// xterm-compatible `tabStopWidth` API.
  set tabStopWidth(int value) => _set(
    'tabStopWidth',
    _tabStopWidth,
    _atLeastOne('tabStopWidth', value),
    (next) => _tabStopWidth = next,
  );

  void _set<T>(String name, T oldValue, T newValue, void Function(T) assign) {
    if (oldValue == newValue) return;
    assign(newValue);
    _onChange.fire(name);
  }

  static int _nonNegative(String name, int value) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'cannot be less than 0');
    }
    return value;
  }

  static int _atLeastOne(String name, int value) {
    if (value < 1) {
      throw ArgumentError.value(value, name, 'cannot be less than 1');
    }
    return value;
  }

  static double _positive(String name, double value) {
    if (value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'cannot be less than or equal to 0',
      );
    }
    return value;
  }

  static int _boundedScrollback(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'scrollback', 'cannot be less than 0');
    }
    return value.clamp(0, 0xffffffff);
  }

  static void _validateFontWeight(String name, Object value) {
    const named = <String>{
      'normal',
      'bold',
      '100',
      '200',
      '300',
      '400',
      '500',
      '600',
      '700',
      '800',
      '900',
    };
    if (value is num && value >= 1 && value <= 1000) return;
    if (value is String && named.contains(value)) return;
    throw ArgumentError.value(value, name, 'must be a weight from 1 to 1000');
  }
}
