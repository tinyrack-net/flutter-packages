import 'dart:js_interop';
import 'dart:typed_data' as typed;

import 'package:termworld/src/addons/webgl_texture_atlas.dart';
import 'package:vtworld/vtworld.dart';
import 'package:web/web.dart';

WebGLShader _createShader(
  WebGL2RenderingContext context,
  int type,
  String source,
) {
  final shader = context.createShader(type);
  if (shader == null) throw StateError('WebGL shader creation failed');
  context
    ..shaderSource(shader, source)
    ..compileShader(shader);
  if (context
          .getShaderParameter(shader, WebGL2RenderingContext.COMPILE_STATUS)
          .dartify()
      case true) {
    return shader;
  }
  final message = context.getShaderInfoLog(shader);
  context.deleteShader(shader);
  throw StateError(message ?? 'WebGL shader compilation failed');
}

WebGLProgram _createProgram(WebGL2RenderingContext context) {
  final program = context.createProgram();
  if (program == null) throw StateError('WebGL program creation failed');
  final vertexShader = _createShader(
    context,
    WebGL2RenderingContext.VERTEX_SHADER,
    '#version 300 es\nin vec2 a_position;\nout vec2 v_texture;\n'
    'void main(){v_texture=vec2((a_position.x+1.0)*0.5, '
    '(1.0-a_position.y)*0.5); '
    'gl_Position=vec4(a_position,0.0,1.0);}',
  );
  final fragmentShader = _createShader(
    context,
    WebGL2RenderingContext.FRAGMENT_SHADER,
    '#version 300 es\nprecision mediump float;\n'
    'uniform sampler2D u_frame;\n'
    'in vec2 v_texture;\nout vec4 color;\n'
    'void main(){color=texture(u_frame,v_texture);}',
  );
  context
    ..attachShader(program, vertexShader)
    ..attachShader(program, fragmentShader)
    ..linkProgram(program)
    ..deleteShader(vertexShader)
    ..deleteShader(fragmentShader);
  if (context
          .getProgramParameter(program, WebGL2RenderingContext.LINK_STATUS)
          .dartify()
      case true) {
    return program;
  }
  final message = context.getProgramInfoLog(program);
  context.deleteProgram(program);
  throw StateError(message ?? 'WebGL program linking failed');
}

/// Opaque handle identifying the current renderer texture atlas generation.
final class TerminalTextureAtlas {
  /// Creates an atlas handle.
  const TerminalTextureAtlas(this.generation, [this.canvas]);

  /// Monotonically increasing atlas generation.
  final int generation;

  /// The browser canvas that owns the WebGL2 texture atlas.
  final Object? canvas;
}

/// Configuration for the browser WebGL renderer.
final class WebglAddonOptions {
  /// Creates WebGL renderer options with xterm.js defaults.
  const WebglAddonOptions({
    this.customGlyphs = true,
    this.preserveDrawingBuffer = false,
  });

  /// Whether xterm's custom box, block, braille and powerline glyphs are used.
  final bool customGlyphs;

  /// Whether the WebGL context preserves its drawing buffer.
  final bool preserveDrawingBuffer;
}

/// Exposes WebGL atlas lifecycle events on Flutter web.
final class WebglAddon extends ManagedTerminalAddon {
  /// Creates a WebGL addon.
  WebglAddon({
    bool customGlyphs = true,
    bool preserveDrawingBuffer = false,
    WebglAddonOptions? options,
  }) : customGlyphs = options?.customGlyphs ?? customGlyphs,
       preserveDrawingBuffer =
           options?.preserveDrawingBuffer ?? preserveDrawingBuffer;

  /// Whether custom glyph drawing is enabled.
  final bool customGlyphs;

  /// Whether the browser drawing buffer is preserved.
  final bool preserveDrawingBuffer;

  /// Whether this addon can run on the current platform.
  static bool get isSupported => true;

  static final Expando<WebglAddon> _active = Expando<WebglAddon>();

  /// Returns the WebGL renderer currently owning [terminal].
  static WebglAddon? activeFor(Terminal terminal) => _active[terminal];

  final TerminalEventEmitter<TerminalTextureAtlas> _onChangeTextureAtlas =
      TerminalEventEmitter<TerminalTextureAtlas>();
  final TerminalEventEmitter<TerminalTextureAtlas> _onAddTextureAtlas =
      TerminalEventEmitter<TerminalTextureAtlas>();
  final TerminalEventEmitter<TerminalTextureAtlas> _onRemoveTextureAtlas =
      TerminalEventEmitter<TerminalTextureAtlas>();
  final TerminalEventEmitter<TerminalVoid> _onContextLoss =
      TerminalEventEmitter<TerminalVoid>();
  TerminalTextureAtlas? _textureAtlas;
  HTMLCanvasElement? _canvas;
  WebGL2RenderingContext? _context;
  WebGLProgram? _program;
  WebGLBuffer? _vertexBuffer;
  WebGLTexture? _frameTexture;
  HTMLCanvasElement? _frameCanvas;
  CanvasRenderingContext2D? _frameContext;
  TerminalWebglTextureAtlas? _atlasModel;
  final List<Disposable> _terminalListeners = <Disposable>[];
  EventListener? _contextLostListener;
  EventListener? _contextRestoredListener;
  int _generation = 0;

  /// Browser canvas installed into `TerminalView` while this addon is active.
  HTMLCanvasElement? get rendererCanvas => _canvas;

  /// Stable Flutter platform-view identifier for [rendererCanvas].
  String get rendererViewType => 'termworld-webgl-${identityHashCode(this)}';

  /// Fires when atlas contents change.
  TerminalEvent<TerminalTextureAtlas> get onChangeTextureAtlas =>
      _onChangeTextureAtlas.event;

  /// Fires when an atlas is created.
  TerminalEvent<TerminalTextureAtlas> get onAddTextureAtlas =>
      _onAddTextureAtlas.event;

  /// xterm-compatible texture atlas canvas creation event.
  TerminalEvent<TerminalTextureAtlas> get onAddTextureAtlasCanvas =>
      _onAddTextureAtlas.event;

  /// Fires when an atlas is removed.
  TerminalEvent<TerminalTextureAtlas> get onRemoveTextureAtlas =>
      _onRemoveTextureAtlas.event;

  /// xterm-compatible texture atlas canvas removal event.
  TerminalEvent<TerminalTextureAtlas> get onRemoveTextureAtlasCanvas =>
      _onRemoveTextureAtlas.event;

  /// Fires when WebGL reports context loss.
  TerminalEvent<TerminalVoid> get onContextLoss => _onContextLoss.event;

  /// Current texture atlas.
  TerminalTextureAtlas? get textureAtlas => _textureAtlas;

  @override
  void onActivate(Terminal terminal) {
    _createRendererSurface();
    _active[terminal] = this;
    _terminalListeners
      ..add(terminal.onRender.listen((_) => renderFrame()))
      ..add(terminal.onResize.listen((_) => renderFrame()))
      ..add(terminal.onScroll.listen((_) => renderFrame()))
      ..add(terminal.onSelectionChange.listen((_) => renderFrame()))
      ..add(terminal.onDimensionsChange.listen((_) => renderFrame()))
      ..add(terminal.options.onChange.listen((_) => renderFrame()));
    terminal.refresh(0, terminal.rows - 1);
    renderFrame();
  }

  /// Drops the current atlas and forces a complete refresh.
  void clearTextureAtlas() {
    if (!isActive) return;
    final previous = _textureAtlas;
    if (previous != null) _onRemoveTextureAtlas.fire(previous);
    final canvas = _canvas;
    final context = _context;
    if (canvas == null || context == null) return;
    context
      ..viewport(0, 0, canvas.width, canvas.height)
      ..clearColor(0, 0, 0, 0)
      ..clear(WebGL2RenderingContext.COLOR_BUFFER_BIT);
    _textureAtlas = TerminalTextureAtlas(++_generation, canvas);
    _onAddTextureAtlas.fire(_textureAtlas!);
    _onChangeTextureAtlas.fire(_textureAtlas!);
    terminal.clearTextureAtlas();
    _atlasModel?.clearTexture();
    renderFrame();
  }

  /// Reports a renderer context loss.
  void reportContextLoss() {
    if (!isActive) return;
    _onContextLoss.fire(TerminalVoid.value);
  }

  /// Uploads the current terminal frame and draws it through WebGL2.
  void renderFrame() {
    if (!isActive) return;
    final canvas = _canvas;
    final frameCanvas = _frameCanvas;
    final frameContext = _frameContext;
    final context = _context;
    final texture = _frameTexture;
    if (canvas == null ||
        frameCanvas == null ||
        frameContext == null ||
        context == null ||
        texture == null ||
        context.isContextLost()) {
      return;
    }
    final dimensions = terminal.dimensions;
    final ratio = dimensions?.devicePixelRatio ?? window.devicePixelRatio;
    final width = ((dimensions?.width ?? terminal.cols * 8) * ratio)
        .round()
        .clamp(1, 16384);
    final height = ((dimensions?.height ?? terminal.rows * 16) * ratio)
        .round()
        .clamp(1, 16384);
    if (canvas.width != width || canvas.height != height) {
      canvas
        ..width = width
        ..height = height;
      frameCanvas
        ..width = width
        ..height = height;
      context.viewport(0, 0, width, height);
    }
    _rasterizeFrame(frameContext, width, height, ratio);
    context
      ..activeTexture(WebGL2RenderingContext.TEXTURE0)
      ..bindTexture(WebGL2RenderingContext.TEXTURE_2D, texture)
      ..pixelStorei(WebGL2RenderingContext.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1)
      ..texImage2D(
        WebGL2RenderingContext.TEXTURE_2D,
        0,
        WebGL2RenderingContext.RGBA,
        WebGL2RenderingContext.RGBA.toJS,
        WebGL2RenderingContext.UNSIGNED_BYTE.toJS,
        frameCanvas,
      )
      ..clear(WebGL2RenderingContext.COLOR_BUFFER_BIT)
      ..drawArrays(WebGL2RenderingContext.TRIANGLE_STRIP, 0, 4);
  }

  void _rasterizeFrame(
    CanvasRenderingContext2D context,
    int width,
    int height,
    double ratio,
  ) {
    final theme = terminal.options.theme;
    final overrides = terminal.colorOverrides;
    final foreground = overrides.foreground == null
        ? theme.foreground ?? '#ffffff'
        : _rgb(overrides.foreground!);
    final background = overrides.background == null
        ? theme.background ?? '#000000'
        : _rgb(overrides.background!);
    final palette = _palette(theme, overrides.indexed);
    final cellWidth = width / terminal.cols;
    final cellHeight = height / terminal.rows;
    context
      ..globalAlpha = 1
      ..fillStyle = background.toJS
      ..fillRect(0, 0, width, height)
      ..textBaseline = 'bottom'
      ..font =
          '${terminal.options.fontSize * ratio}px '
          '${terminal.options.fontFamily}';
    final selection = terminal.getSelectionPosition();
    for (var row = 0; row < terminal.rows; row++) {
      final absoluteRow = terminal.viewportY + row;
      final line = terminal.buffer.active.getLine(absoluteRow);
      if (line == null) continue;
      for (var column = 0; column < terminal.cols; column++) {
        final cell = line.getCell(column);
        if (cell == null || cell.width == 0) continue;
        var cellForeground = _cellColor(
          cell.foregroundMode,
          cell.foreground,
          foreground,
          palette,
        );
        var cellBackground = _cellColor(
          cell.backgroundMode,
          cell.background,
          background,
          palette,
        );
        if (cell.isInverse) {
          final swap = cellForeground;
          cellForeground = cellBackground;
          cellBackground = swap;
        }
        final left = column * cellWidth;
        final top = row * cellHeight;
        context
          ..globalAlpha = 1
          ..fillStyle = cellBackground.toJS
          ..fillRect(left, top, cellWidth * cell.width, cellHeight);
        if (_selected(selection, column, absoluteRow)) {
          context
            ..globalAlpha = 1
            ..fillStyle = (theme.selectionBackground ?? '#ffffff4d').toJS
            ..fillRect(left, top, cellWidth * cell.width, cellHeight);
          cellForeground = theme.selectionForeground ?? cellForeground;
        }
        if (!cell.isInvisible && cell.chars.isNotEmpty) {
          _atlasModel?.getCombinedGlyph(
            cell.chars,
            cell.background,
            cell.foreground,
            cell.copyAttributes().hashCode,
          );
          context
            ..globalAlpha = cell.isDim ? 0.5 : 1
            ..fillStyle = cellForeground.toJS
            ..font =
                '${cell.isBold ? 'bold ' : ''}'
                '${terminal.options.fontSize * ratio}px '
                '${terminal.options.fontFamily}'
            ..fillText(cell.chars, left, top + cellHeight);
        }
      }
    }
    if (terminal.rendererHasFocus) {
      final column = terminal.buffer.active.cursorX;
      final row = terminal.buffer.active.cursorY;
      context
        ..globalAlpha = 1
        ..fillStyle =
            (overrides.cursor == null
                    ? theme.cursor ?? '#ffffff'
                    : _rgb(overrides.cursor!))
                .toJS
        ..fillRect(
          column * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        );
    }
    context.globalAlpha = 1;
  }

  void _createRendererSurface() {
    final canvas = HTMLCanvasElement()
      ..width = 1024
      ..height = 1024;
    final options = <String, Object?>{
      'antialias': false,
      'depth': false,
      'preserveDrawingBuffer': preserveDrawingBuffer,
    }.jsify();
    final renderingContext = canvas.getContext('webgl2', options);
    if (renderingContext == null ||
        !renderingContext.isA<WebGL2RenderingContext>()) {
      throw UnsupportedError('WebGL2 is not available in this browser');
    }
    final context = (renderingContext as WebGL2RenderingContext)
      ..viewport(0, 0, canvas.width, canvas.height)
      ..clearColor(0, 0, 0, 0)
      ..clear(WebGL2RenderingContext.COLOR_BUFFER_BIT);
    _canvas = canvas;
    _context = context;
    _initializeGpuResources(context);
    canvas.setAttribute('data-termworld-webgl-renderer', 'active');
    _contextLostListener = ((Event event) {
      event.preventDefault();
      if (!isActive) return;
      canvas.setAttribute('data-termworld-webgl-renderer', 'lost');
      _active[terminal] = null;
      _onContextLoss.fire(TerminalVoid.value);
      terminal.refresh(0, terminal.rows - 1);
    }).toJS;
    _contextRestoredListener = ((Event event) {
      if (!isActive) return;
      _initializeGpuResources(context);
      canvas.setAttribute('data-termworld-webgl-renderer', 'active');
      _active[terminal] = this;
      clearTextureAtlas();
      terminal.refresh(0, terminal.rows - 1);
    }).toJS;
    canvas
      ..addEventListener('webglcontextlost', _contextLostListener)
      ..addEventListener('webglcontextrestored', _contextRestoredListener);
    _textureAtlas = TerminalTextureAtlas(++_generation, canvas);
    _onAddTextureAtlas.fire(_textureAtlas!);
  }

  void _initializeGpuResources(WebGL2RenderingContext context) {
    _atlasModel?.dispose();
    final program = _createProgram(context);
    final buffer = context.createBuffer();
    final texture = context.createTexture();
    if (buffer == null || texture == null) {
      context.deleteProgram(program);
      throw StateError('WebGL renderer resource creation failed');
    }
    context
      ..useProgram(program)
      ..bindBuffer(WebGL2RenderingContext.ARRAY_BUFFER, buffer)
      ..bufferData(
        WebGL2RenderingContext.ARRAY_BUFFER,
        typed.Float32List.fromList(<double>[
          -1,
          -1,
          1,
          -1,
          -1,
          1,
          1,
          1,
        ]).toJS,
        WebGL2RenderingContext.STATIC_DRAW,
      );
    final position = context.getAttribLocation(program, 'a_position');
    context
      ..enableVertexAttribArray(position)
      ..vertexAttribPointer(
        position,
        2,
        WebGL2RenderingContext.FLOAT,
        false,
        0,
        0,
      )
      ..bindTexture(WebGL2RenderingContext.TEXTURE_2D, texture)
      ..texParameteri(
        WebGL2RenderingContext.TEXTURE_2D,
        WebGL2RenderingContext.TEXTURE_MIN_FILTER,
        WebGL2RenderingContext.NEAREST,
      )
      ..texParameteri(
        WebGL2RenderingContext.TEXTURE_2D,
        WebGL2RenderingContext.TEXTURE_MAG_FILTER,
        WebGL2RenderingContext.NEAREST,
      )
      ..texParameteri(
        WebGL2RenderingContext.TEXTURE_2D,
        WebGL2RenderingContext.TEXTURE_WRAP_S,
        WebGL2RenderingContext.CLAMP_TO_EDGE,
      )
      ..texParameteri(
        WebGL2RenderingContext.TEXTURE_2D,
        WebGL2RenderingContext.TEXTURE_WRAP_T,
        WebGL2RenderingContext.CLAMP_TO_EDGE,
      );
    final frameCanvas = HTMLCanvasElement();
    final frameRenderingContext = frameCanvas.getContext('2d');
    if (frameRenderingContext == null ||
        !frameRenderingContext.isA<CanvasRenderingContext2D>()) {
      throw StateError('Canvas 2D staging context is unavailable');
    }
    _program = program;
    _vertexBuffer = buffer;
    _frameTexture = texture;
    _frameCanvas = frameCanvas;
    _frameContext = frameRenderingContext as CanvasRenderingContext2D;
    _atlasModel = TerminalWebglTextureAtlas(
      maxTextureSize:
          context
                  .getParameter(WebGL2RenderingContext.MAX_TEXTURE_SIZE)
                  .dartify()!
              as int,
    );
  }

  @override
  void dispose() {
    if (isDisposed) return;
    final activeTerminal = isActive ? terminal : null;
    if (activeTerminal != null) _active[activeTerminal] = null;
    for (final listener in _terminalListeners) {
      listener.dispose();
    }
    _terminalListeners.clear();
    final atlas = _textureAtlas;
    if (atlas != null) _onRemoveTextureAtlas.fire(atlas);
    final canvas = _canvas;
    final context = _context;
    final program = _program;
    final vertexBuffer = _vertexBuffer;
    final frameTexture = _frameTexture;
    if (context != null && vertexBuffer != null) {
      context.deleteBuffer(vertexBuffer);
    }
    if (context != null && frameTexture != null) {
      context.deleteTexture(frameTexture);
    }
    if (context != null && program != null) context.deleteProgram(program);
    if (canvas != null) {
      final contextLostListener = _contextLostListener;
      final contextRestoredListener = _contextRestoredListener;
      if (contextLostListener != null) {
        canvas.removeEventListener('webglcontextlost', contextLostListener);
      }
      if (contextRestoredListener != null) {
        canvas.removeEventListener(
          'webglcontextrestored',
          contextRestoredListener,
        );
      }
    }
    _textureAtlas = null;
    _context = null;
    _program = null;
    _vertexBuffer = null;
    _frameTexture = null;
    _frameCanvas = null;
    _frameContext = null;
    _atlasModel?.dispose();
    _atlasModel = null;
    _canvas = null;
    _contextLostListener = null;
    _contextRestoredListener = null;
    _onChangeTextureAtlas.dispose();
    _onAddTextureAtlas.dispose();
    _onRemoveTextureAtlas.dispose();
    _onContextLoss.dispose();
    if (activeTerminal != null && !activeTerminal.isDisposed) {
      activeTerminal.refresh(0, activeTerminal.rows - 1);
    }
    super.dispose();
  }
}

bool _selected(TerminalBufferRange? range, int column, int row) {
  if (range == null || row < range.start.y || row > range.end.y) return false;
  if (range.start.y == range.end.y) {
    return row == range.start.y &&
        column >= range.start.x &&
        column < range.end.x;
  }
  if (row == range.start.y) return column >= range.start.x;
  if (row == range.end.y) return column < range.end.x;
  return true;
}

String _cellColor(
  TerminalColorMode mode,
  int value,
  String fallback,
  List<String> palette,
) => switch (mode) {
  TerminalColorMode.defaultColor => fallback,
  TerminalColorMode.palette =>
    value >= 0 && value < palette.length ? palette[value] : fallback,
  TerminalColorMode.rgb => _rgb(value),
};

String _rgb(int value) =>
    '#${(value & 0xffffff).toRadixString(16).padLeft(6, '0')}';

List<String> _palette(TerminalColorTheme theme, Map<int, int> overrides) {
  final result = <String>[
    theme.black ?? '#2e3436',
    theme.red ?? '#cc0000',
    theme.green ?? '#4e9a06',
    theme.yellow ?? '#c4a000',
    theme.blue ?? '#3465a4',
    theme.magenta ?? '#75507b',
    theme.cyan ?? '#06989a',
    theme.white ?? '#d3d7cf',
    theme.brightBlack ?? '#555753',
    theme.brightRed ?? '#ef2929',
    theme.brightGreen ?? '#8ae234',
    theme.brightYellow ?? '#fce94f',
    theme.brightBlue ?? '#729fcf',
    theme.brightMagenta ?? '#ad7fa8',
    theme.brightCyan ?? '#34e2e2',
    theme.brightWhite ?? '#eeeeec',
  ];
  const levels = <int>[0, 95, 135, 175, 215, 255];
  for (final red in levels) {
    for (final green in levels) {
      for (final blue in levels) {
        result.add(_rgb(red << 16 | green << 8 | blue));
      }
    }
  }
  for (var index = 0; index < 24; index++) {
    final value = 8 + index * 10;
    result.add(_rgb(value << 16 | value << 8 | value));
  }
  final extended = theme.extendedAnsi;
  if (extended != null) {
    for (var index = 0; index < extended.length && index < 240; index++) {
      result[index + 16] = extended[index];
    }
  }
  for (final entry in overrides.entries) {
    if (entry.key >= 0 && entry.key < result.length) {
      result[entry.key] = _rgb(entry.value);
    }
  }
  return result;
}
