import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/platform_defaults.dart';

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

/// Callbacks for links emitted by OSC 8 or custom providers.
final class TerminalLinkHandler {
  /// Creates platform-neutral link interaction callbacks.
  const TerminalLinkHandler({
    required this.activate,
    this.hover,
    this.leave,
    this.allowNonHttpProtocols = false,
  });

  /// Invoked when a user activates a link.
  final void Function(Object? event, String text, TerminalBufferRange range)
  activate;

  /// Invoked when a pointer enters a link.
  final void Function(Object? event, String text, TerminalBufferRange range)?
  hover;

  /// Invoked when a pointer leaves a link.
  final void Function(Object? event, String text, TerminalBufferRange range)?
  leave;

  /// Whether schemes other than HTTP and HTTPS may be delivered.
  final bool allowNonHttpProtocols;
}

/// Windows pseudoterminal compatibility information.
final class TerminalWindowsPtyOptions {
  /// Creates Windows PTY compatibility settings.
  const TerminalWindowsPtyOptions({this.backend, this.buildNumber});

  /// PTY backend name, either `conpty` or `winpty`.
  final String? backend;

  /// Windows build number reported by the PTY host.
  final int? buildNumber;
}

/// Optional VT protocol extensions.
final class TerminalVtExtensions {
  /// Creates VT extension settings.
  const TerminalVtExtensions({
    this.kittyKeyboard = false,
    this.kittySgrBoldFaintControl = true,
    this.win32InputMode = false,
    this.colorSchemeQuery = true,
  });

  /// Enables the Kitty keyboard protocol.
  final bool kittyKeyboard;

  /// Enables Kitty's independent bold and faint resets.
  final bool kittySgrBoldFaintControl;

  /// Enables DECSET 9001 win32 input mode.
  final bool win32InputMode;

  /// Enables color-scheme query and notification sequences.
  final bool colorSchemeQuery;
}

/// Compatibility switches for rejected or non-standard terminal behavior.
final class TerminalQuirks {
  /// Creates terminal quirk settings.
  const TerminalQuirks({this.allowSetCursorBlink = false});

  /// Allows DECSET and DECRST 12 to change cursor blinking.
  final bool allowSetCursorBlink;
}

/// Overview ruler border visibility.
final class TerminalOverviewRulerOptions {
  /// Creates overview ruler settings.
  const TerminalOverviewRulerOptions({
    this.showTopBorder = false,
    this.showBottomBorder = false,
  });

  /// Whether the top border is visible.
  final bool showTopBorder;

  /// Whether the bottom border is visible.
  final bool showBottomBorder;
}

/// Scrollbar and overview ruler configuration.
final class TerminalScrollbarOptions {
  /// Creates scrollbar settings.
  const TerminalScrollbarOptions({
    this.showScrollbar = true,
    this.showArrows = false,
    this.width,
    this.overviewRuler,
  });

  /// Whether the scrollbar is visible.
  final bool showScrollbar;

  /// Whether arrow buttons are visible.
  final bool showArrows;

  /// Scrollbar width in logical pixels.
  final double? width;

  /// Optional overview ruler border settings.
  final TerminalOverviewRulerOptions? overviewRuler;
}

/// Security gates for CSI window manipulation and reporting commands.
final class TerminalWindowOptions {
  /// Creates window operation permissions, all disabled by default.
  const TerminalWindowOptions({
    this.restoreWin = false,
    this.minimizeWin = false,
    this.setWinPosition = false,
    this.setWinSizePixels = false,
    this.raiseWin = false,
    this.lowerWin = false,
    this.refreshWin = false,
    this.setWinSizeChars = false,
    this.maximizeWin = false,
    this.fullscreenWin = false,
    this.getWinState = false,
    this.getWinPosition = false,
    this.getWinSizePixels = false,
    this.getScreenSizePixels = false,
    this.getCellSizePixels = false,
    this.getWinSizeChars = false,
    this.getScreenSizeChars = false,
    this.getIconTitle = false,
    this.getWinTitle = false,
    this.pushTitle = false,
    this.popTitle = false,
    this.setWinLines = false,
  });

  /// Allows de-iconifying the window.
  final bool restoreWin;

  /// Allows iconifying the window.
  final bool minimizeWin;

  /// Allows moving the window.
  final bool setWinPosition;

  /// Allows pixel-based resizing.
  final bool setWinSizePixels;

  /// Allows raising the window.
  final bool raiseWin;

  /// Allows lowering the window.
  final bool lowerWin;

  /// Allows explicit window refresh.
  final bool refreshWin;

  /// Allows character-cell resizing.
  final bool setWinSizeChars;

  /// Allows maximizing the window.
  final bool maximizeWin;

  /// Allows changing fullscreen state.
  final bool fullscreenWin;

  /// Allows reporting window state.
  final bool getWinState;

  /// Allows reporting window position.
  final bool getWinPosition;

  /// Allows reporting window pixel dimensions.
  final bool getWinSizePixels;

  /// Allows reporting screen pixel dimensions.
  final bool getScreenSizePixels;

  /// Allows reporting cell pixel dimensions.
  final bool getCellSizePixels;

  /// Allows reporting window dimensions in cells.
  final bool getWinSizeChars;

  /// Allows reporting screen dimensions in cells.
  final bool getScreenSizeChars;

  /// Allows reporting the icon title.
  final bool getIconTitle;

  /// Allows reporting the window title.
  final bool getWinTitle;

  /// Allows pushing a title onto the title stack.
  final bool pushTitle;

  /// Allows popping a title from the title stack.
  final bool popTitle;

  /// Allows changing the number of window lines.
  final bool setWinLines;
}

/// Strings exposed by terminal accessibility surfaces.
final class TerminalLocalizableStrings {
  /// Creates localizable accessibility strings.
  const TerminalLocalizableStrings({
    this.promptLabel = 'Terminal input',
    this.tooMuchOutput =
        'Too much output to announce, navigate to rows manually',
  });

  /// Label for the hidden text input.
  final String promptLabel;

  /// Announcement used when screen-reader output is suppressed.
  final String tooMuchOutput;
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
    this.scrollbarSliderBackground,
    this.scrollbarSliderHoverBackground,
    this.scrollbarSliderActiveBackground,
    this.overviewRulerBorder,
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

  /// xterm-compatible scrollbar slider color.
  final String? scrollbarSliderBackground;

  /// xterm-compatible hovered scrollbar slider color.
  final String? scrollbarSliderHoverBackground;

  /// xterm-compatible active scrollbar slider color.
  final String? scrollbarSliderActiveBackground;

  /// xterm-compatible overview ruler border color.
  final String? overviewRulerBorder;

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
    Object fontWeight = 'normal',
    Object fontWeightBold = 'bold',
    this.ignoreBracketedPasteMode = false,
    this.letterSpacing = 0,
    double lineHeight = 1,
    this.linkHandler,
    this.logLevel = TerminalLogLevel.info,
    this.logger,
    this.macOptionIsMeta = false,
    this.macOptionClickForcesSelection = false,
    double minimumContrastRatio = 1,
    this.mouseEventsRequireAlt = false,
    this.quirks = const TerminalQuirks(),
    this.reflowCursorLine = false,
    this.rescaleOverlappingGlyphs = false,
    bool? rightClickSelectsWord,
    this.screenReaderMode = false,
    int scrollback = 1000,
    this.scrollOnEraseInDisplay = false,
    this.scrollOnUserInput = true,
    double scrollSensitivity = 1,
    this.scrollbar = const TerminalScrollbarOptions(),
    this.smoothScrollDuration = 0,
    int tabStopWidth = 8,
    this.theme = const TerminalColorTheme(),
    this.vtExtensions = const TerminalVtExtensions(),
    this.windowsPty = const TerminalWindowsPtyOptions(),
    String wordSeparator = ' ()[]{}\',"`',
    this.windowOptions = const TerminalWindowOptions(),
    int cols = 80,
    int rows = 24,
    this.showCursorImmediately = false,
  }) : _fontWeight = _constructorFontWeight(fontWeight, 'normal'),
       _fontWeightBold = _constructorFontWeight(fontWeightBold, 'bold'),
       _wordSeparator = wordSeparator.isEmpty ? ' ()[]{}\',"`' : wordSeparator,
       cols = cols < 0 ? 80 : cols,
       rows = rows < 0 ? 24 : rows,
       _blinkIntervalDuration = blinkIntervalDuration < 0
           ? 0
           : blinkIntervalDuration,
       _cursorWidth = cursorWidth < 1 ? 1 : cursorWidth,
       _fastScrollSensitivity = fastScrollSensitivity <= 0
           ? 5
           : fastScrollSensitivity,
       _lineHeight = lineHeight <= 0 ? 1 : lineHeight,
       _minimumContrastRatio = _contrastRatio(minimumContrastRatio),
       rightClickSelectsWord = rightClickSelectsWord ?? terminalHostIsMac,
       _scrollback = scrollback < 0 ? 1000 : scrollback.clamp(0, 0xffffffff),
       _scrollSensitivity = scrollSensitivity <= 0 ? 1 : scrollSensitivity,
       _tabStopWidth = tabStopWidth < 1 ? 8 : tabStopWidth;

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
  Object _fontWeight;

  /// xterm-compatible `fontWeightBold` API.
  Object _fontWeightBold;

  /// xterm-compatible `ignoreBracketedPasteMode` API.
  bool ignoreBracketedPasteMode;

  /// xterm-compatible `letterSpacing` API.
  double letterSpacing;
  double _lineHeight;

  /// xterm-compatible `linkHandler` API.
  TerminalLinkHandler? linkHandler;

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

  /// xterm-compatible `quirks` API.
  TerminalQuirks quirks;

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

  /// xterm-compatible `scrollbar` API.
  TerminalScrollbarOptions scrollbar;

  /// xterm-compatible `smoothScrollDuration` API.
  int smoothScrollDuration;
  int _tabStopWidth;

  /// xterm-compatible `theme` API.
  TerminalColorTheme theme;

  /// xterm-compatible `vtExtensions` API.
  TerminalVtExtensions vtExtensions;

  /// xterm-compatible `windowsPty` API.
  TerminalWindowsPtyOptions windowsPty;

  /// xterm-compatible `wordSeparator` API.
  String _wordSeparator;

  /// xterm-compatible `windowOptions` API.
  TerminalWindowOptions windowOptions;

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
    _contrastRatio(value),
    (next) => _minimumContrastRatio = next,
  );

  /// xterm-compatible `fontWeight` API.
  Object get fontWeight => _fontWeight;

  /// xterm-compatible `fontWeight` API.
  set fontWeight(Object value) => _set(
    'fontWeight',
    _fontWeight,
    _constructorFontWeight(value, 'normal'),
    (next) => _fontWeight = next,
  );

  /// xterm-compatible `fontWeightBold` API.
  Object get fontWeightBold => _fontWeightBold;

  /// xterm-compatible `fontWeightBold` API.
  set fontWeightBold(Object value) => _set(
    'fontWeightBold',
    _fontWeightBold,
    _constructorFontWeight(value, 'bold'),
    (next) => _fontWeightBold = next,
  );

  /// xterm-compatible `wordSeparator` API.
  String get wordSeparator => _wordSeparator;

  /// xterm-compatible `wordSeparator` API.
  set wordSeparator(String value) => _set(
    'wordSeparator',
    _wordSeparator,
    value.isEmpty ? ' ()[]{}\',"`' : value,
    (next) => _wordSeparator = next,
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

  static bool _isValidFontWeight(Object value) {
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
    return (value is num && value >= 1 && value <= 1000) ||
        (value is String && named.contains(value));
  }

  static Object _constructorFontWeight(Object value, Object fallback) {
    return _isValidFontWeight(value) ? value : fallback;
  }

  static double _contrastRatio(double value) =>
      (value.clamp(1, 21) * 10).round() / 10;
}
