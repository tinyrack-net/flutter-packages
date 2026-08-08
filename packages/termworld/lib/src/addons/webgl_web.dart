import 'dart:js_interop';

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/terminal.dart';
import 'package:web/web.dart';

/// Opaque handle identifying the current renderer texture atlas generation.
final class TerminalTextureAtlas {
  /// Creates an atlas handle.
  const TerminalTextureAtlas(this.generation, [this.canvas]);

  /// Monotonically increasing atlas generation.
  final int generation;

  /// The browser canvas that owns the WebGL2 texture atlas.
  final Object? canvas;
}

/// Exposes WebGL atlas lifecycle events on Flutter web.
final class WebglAddon extends ManagedTerminalAddon {
  /// Creates a WebGL addon.
  WebglAddon({this.customGlyphs = true, this.preserveDrawingBuffer = false});

  /// Whether custom glyph drawing is enabled.
  final bool customGlyphs;

  /// Whether the browser drawing buffer is preserved.
  final bool preserveDrawingBuffer;

  /// Whether this addon can run on the current platform.
  static bool get isSupported => true;

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
  EventListener? _contextLostListener;
  EventListener? _contextRestoredListener;
  int _generation = 0;

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
  }

  /// Reports a renderer context loss.
  void reportContextLoss() {
    if (!isActive) return;
    _onContextLoss.fire(TerminalVoid.value);
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
    _contextLostListener = ((Event event) {
      event.preventDefault();
      if (isActive) _onContextLoss.fire(TerminalVoid.value);
    }).toJS;
    _contextRestoredListener = ((Event event) {
      if (isActive) clearTextureAtlas();
    }).toJS;
    canvas
      ..addEventListener('webglcontextlost', _contextLostListener)
      ..addEventListener('webglcontextrestored', _contextRestoredListener);
    _canvas = canvas;
    _context = context;
    _textureAtlas = TerminalTextureAtlas(++_generation, canvas);
    _onAddTextureAtlas.fire(_textureAtlas!);
  }

  @override
  void dispose() {
    final atlas = _textureAtlas;
    if (atlas != null) _onRemoveTextureAtlas.fire(atlas);
    final canvas = _canvas;
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
    _canvas = null;
    _contextLostListener = null;
    _contextRestoredListener = null;
    _onChangeTextureAtlas.dispose();
    _onAddTextureAtlas.dispose();
    _onRemoveTextureAtlas.dispose();
    _onContextLoss.dispose();
    super.dispose();
  }
}
