import 'package:termworld/src/addons/webgl_render_layer.dart';
import 'package:vtworld/vtworld.dart';

/// Canvas operations used by xterm's base render layer.
abstract interface class TerminalWebglLayerCanvasContext {
  /// Current fill style.
  String get fillStyle;
  set fillStyle(String value);

  /// Current font shorthand.
  String get font;
  set font(String value);

  /// Current text baseline.
  String get textBaseline;
  set textBaseline(String value);

  /// Clears a device-pixel rectangle.
  void clearRect(double x, double y, double width, double height);

  /// Fills a device-pixel rectangle.
  void fillRect(double x, double y, double width, double height);

  /// Begins a clipping path.
  void beginPath();

  /// Adds a clipping rectangle.
  void rect(double x, double y, double width, double height);

  /// Applies the current clipping path.
  void clip();

  /// Draws text at a device-pixel position.
  void fillText(String text, double x, double y);
}

/// Canvas surface lifecycle needed by a WebGL render layer.
abstract interface class TerminalWebglLayerCanvas {
  /// Backing width in device pixels.
  int get width;
  set width(int value);

  /// Backing height in device pixels.
  int get height;
  set height(int value);

  /// CSS width in logical pixels.
  double get cssWidth;
  set cssWidth(double value);

  /// CSS height in logical pixels.
  double get cssHeight;
  set cssHeight(double value);

  /// Creates a 2D drawing context with the requested alpha mode.
  TerminalWebglLayerCanvasContext createContext({required bool alpha});

  /// Clones surface properties for a transparency-mode replacement.
  TerminalWebglLayerCanvas clone();

  /// Removes the surface from its host.
  void remove();
}

/// Shared canvas lifecycle and geometry from xterm's `BaseRenderLayer`.
abstract class TerminalWebglBaseRenderLayer extends DisposableStore
    implements TerminalWebglRenderLayer {
  /// Creates a base layer around [canvas].
  TerminalWebglBaseRenderLayer({
    required this.terminal,
    required this.canvas,
    required this.alpha,
    required this.devicePixelRatio,
    required this.backgroundCss,
    required this.replaceCanvas,
    required this.refreshAtlas,
  }) {
    _context = canvas.createContext(alpha: alpha);
    if (!alpha) clearAll();
    add(toDisposable(() => canvas.remove()));
  }

  /// Terminal rendered by this layer.
  final Terminal terminal;

  /// Current hosted canvas.
  TerminalWebglLayerCanvas canvas;
  late TerminalWebglLayerCanvasContext _context;

  /// Whether clearing preserves transparent pixels.
  bool alpha;

  /// Device pixel ratio used for line and font geometry.
  double devicePixelRatio;

  /// Current CSS background color.
  String backgroundCss;

  /// Replaces a hosted canvas after its alpha mode changes.
  final void Function(
    TerminalWebglLayerCanvas oldCanvas,
    TerminalWebglLayerCanvas newCanvas,
  )
  replaceCanvas;

  /// Rebuilds and warms the character atlas for current metrics.
  final void Function() refreshAtlas;

  double _deviceCharacterWidth = 0;
  double _deviceCharacterHeight = 0;
  double _deviceCellWidth = 0;
  double _deviceCellHeight = 0;
  double _deviceCharacterLeft = 0;
  double _deviceCharacterTop = 0;

  /// Current 2D canvas adapter.
  TerminalWebglLayerCanvasContext get context => _context;

  @override
  void handleBlur(Terminal terminal) {}

  @override
  void handleFocus(Terminal terminal) {}

  @override
  void handleCursorMove(Terminal terminal) {}

  @override
  void handleGridChanged(Terminal terminal, int startRow, int endRow) {}

  @override
  void handleSelectionChanged(
    Terminal terminal,
    (int, int)? start,
    (int, int)? end, {
    bool columnSelectMode = false,
  }) {}

  /// Recreates the canvas when the requested alpha mode changes.
  void setTransparency({required bool value}) {
    if (value == alpha) return;
    final oldCanvas = canvas;
    alpha = value;
    canvas = oldCanvas.clone();
    _context = canvas.createContext(alpha: value);
    if (!value) clearAll();
    replaceCanvas(oldCanvas, canvas);
    refreshAtlas();
    handleGridChanged(terminal, 0, terminal.rows - 1);
  }

  /// Refreshes atlas and layer state after a theme change.
  void handleThemeChanged(String background) {
    backgroundCss = background;
    refreshAtlas();
    reset(terminal);
  }

  @override
  void resize(Terminal terminal, TerminalRenderDimensions dimensions) {
    final device = dimensions.device;
    _deviceCellWidth = device.cell.width;
    _deviceCellHeight = device.cell.height;
    _deviceCharacterWidth = device.char.width;
    _deviceCharacterHeight = device.char.height;
    _deviceCharacterLeft = device.char.left;
    _deviceCharacterTop = device.char.top;
    canvas
      ..width = device.canvas.width.toInt()
      ..height = device.canvas.height.toInt()
      ..cssWidth = dimensions.css.canvas.width
      ..cssHeight = dimensions.css.canvas.height;
    if (!alpha) clearAll();
    if (_deviceCharacterWidth > 0 || _deviceCharacterHeight > 0) {
      refreshAtlas();
    }
  }

  /// Fills xterm's DPR-wide bottom line inside one or more cells.
  void fillBottomLineAtCells(int x, int y, {int width = 1}) {
    _context.fillRect(
      x * _deviceCellWidth,
      (y + 1) * _deviceCellHeight - devicePixelRatio - 1,
      width * _deviceCellWidth,
      devicePixelRatio,
    );
  }

  /// Clears the entire layer according to its alpha mode.
  void clearAll() {
    if (alpha) {
      _context.clearRect(
        0,
        0,
        canvas.width.toDouble(),
        canvas.height.toDouble(),
      );
    } else {
      _context.fillStyle = backgroundCss;
      _context.fillRect(
        0,
        0,
        canvas.width.toDouble(),
        canvas.height.toDouble(),
      );
    }
  }

  /// Clears a rectangular cell region according to the layer alpha mode.
  void clearCells(int x, int y, int width, int height) {
    final left = x * _deviceCellWidth;
    final top = y * _deviceCellHeight;
    final pixelWidth = width * _deviceCellWidth;
    final pixelHeight = height * _deviceCellHeight;
    if (alpha) {
      _context.clearRect(left, top, pixelWidth, pixelHeight);
    } else {
      _context.fillStyle = backgroundCss;
      _context.fillRect(left, top, pixelWidth, pixelHeight);
    }
  }

  /// Clips and draws one true-color cell string.
  void fillCharacterTrueColor({
    required String characters,
    required int width,
    required int x,
    required int y,
  }) {
    _context
      ..font = font(isBold: false, isItalic: false)
      ..textBaseline = 'bottom'
      ..beginPath()
      ..rect(
        x * _deviceCellWidth,
        y * _deviceCellHeight,
        width * _deviceCellWidth,
        _deviceCellHeight,
      )
      ..clip()
      ..fillText(
        characters,
        x * _deviceCellWidth + _deviceCharacterLeft,
        y * _deviceCellHeight + _deviceCharacterTop + _deviceCharacterHeight,
      );
  }

  /// Returns xterm's CSS font shorthand for this layer.
  String font({required bool isBold, required bool isItalic}) {
    final weight = isBold
        ? terminal.options.fontWeightBold
        : terminal.options.fontWeight;
    final style = isItalic ? 'italic' : '';
    return '$style $weight '
        '${terminal.options.fontSize * devicePixelRatio}px '
        '${terminal.options.fontFamily}';
  }
}
