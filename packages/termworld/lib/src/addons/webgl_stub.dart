import 'package:vtworld/vtworld.dart';

/// Opaque handle identifying the current renderer texture atlas generation.
final class TerminalTextureAtlas {
  /// Creates an atlas handle.
  const TerminalTextureAtlas(this.generation, [this.canvas]);

  /// Monotonically increasing atlas generation.
  final int generation;

  /// Platform atlas canvas. This is never created off the web.
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

/// Explicitly unsupported WebGL capability on non-web platforms.
final class WebglAddon extends ManagedTerminalAddon {
  /// Creates a WebGL addon capability object.
  WebglAddon({
    bool customGlyphs = true,
    bool preserveDrawingBuffer = false,
    WebglAddonOptions? options,
  }) : customGlyphs = options?.customGlyphs ?? customGlyphs,
       preserveDrawingBuffer =
           options?.preserveDrawingBuffer ?? preserveDrawingBuffer;

  /// Whether custom glyph drawing is requested.
  final bool customGlyphs;

  /// Whether the browser drawing buffer should be preserved.
  final bool preserveDrawingBuffer;

  /// Whether this addon can run on the current platform.
  static bool get isSupported => false;

  final TerminalEventEmitter<TerminalTextureAtlas> _atlasEvents =
      TerminalEventEmitter<TerminalTextureAtlas>();
  final TerminalEventEmitter<TerminalVoid> _contextEvents =
      TerminalEventEmitter<TerminalVoid>();

  /// Atlas change events; never emitted on unsupported platforms.
  TerminalEvent<TerminalTextureAtlas> get onChangeTextureAtlas =>
      _atlasEvents.event;

  /// Atlas creation events; never emitted on unsupported platforms.
  TerminalEvent<TerminalTextureAtlas> get onAddTextureAtlas =>
      _atlasEvents.event;

  /// xterm-compatible texture atlas canvas creation event.
  TerminalEvent<TerminalTextureAtlas> get onAddTextureAtlasCanvas =>
      _atlasEvents.event;

  /// Atlas removal events; never emitted on unsupported platforms.
  TerminalEvent<TerminalTextureAtlas> get onRemoveTextureAtlas =>
      _atlasEvents.event;

  /// xterm-compatible texture atlas canvas removal event.
  TerminalEvent<TerminalTextureAtlas> get onRemoveTextureAtlasCanvas =>
      _atlasEvents.event;

  /// Context-loss events; never emitted on unsupported platforms.
  TerminalEvent<TerminalVoid> get onContextLoss => _contextEvents.event;

  /// The active atlas, which is always null off web.
  TerminalTextureAtlas? get textureAtlas => null;

  @override
  void onActivate(Terminal terminal) {
    throw UnsupportedError('WebglAddon is only supported on Flutter web');
  }

  /// Rejects atlas clearing on unsupported platforms.
  void clearTextureAtlas() {
    throw UnsupportedError('WebglAddon is only supported on Flutter web');
  }

  /// Ignores context loss because no WebGL context exists.
  void reportContextLoss() {}

  @override
  void dispose() {
    if (isDisposed) return;
    _atlasEvents.dispose();
    _contextEvents.dispose();
    super.dispose();
  }
}
