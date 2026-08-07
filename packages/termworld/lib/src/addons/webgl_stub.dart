import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/terminal.dart';

/// Opaque handle identifying the current renderer texture atlas generation.
final class TerminalTextureAtlas {
  /// Creates an atlas handle.
  const TerminalTextureAtlas(this.generation);

  /// Monotonically increasing atlas generation.
  final int generation;
}

/// Explicitly unsupported WebGL capability on non-web platforms.
final class WebglAddon extends ManagedTerminalAddon {
  /// Creates a WebGL addon capability object.
  WebglAddon({this.customGlyphs = true, this.preserveDrawingBuffer = false});

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

  /// Atlas removal events; never emitted on unsupported platforms.
  TerminalEvent<TerminalTextureAtlas> get onRemoveTextureAtlas =>
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
    throw StateError('Cannot use addon until it has been loaded');
  }

  /// Ignores context loss because no WebGL context exists.
  void reportContextLoss() {}

  @override
  void dispose() {
    _atlasEvents.dispose();
    _contextEvents.dispose();
    super.dispose();
  }
}
