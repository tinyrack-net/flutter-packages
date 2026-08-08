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
  int _generation = 0;

  /// Fires when atlas contents change.
  TerminalEvent<TerminalTextureAtlas> get onChangeTextureAtlas =>
      _onChangeTextureAtlas.event;

  /// Fires when an atlas is created.
  TerminalEvent<TerminalTextureAtlas> get onAddTextureAtlas =>
      _onAddTextureAtlas.event;

  /// Fires when an atlas is removed.
  TerminalEvent<TerminalTextureAtlas> get onRemoveTextureAtlas =>
      _onRemoveTextureAtlas.event;

  /// Fires when WebGL reports context loss.
  TerminalEvent<TerminalVoid> get onContextLoss => _onContextLoss.event;

  /// Current texture atlas.
  TerminalTextureAtlas? get textureAtlas => _textureAtlas;

  @override
  void onActivate(Terminal terminal) {
    _textureAtlas = TerminalTextureAtlas(++_generation);
    _onAddTextureAtlas.fire(_textureAtlas!);
  }

  /// Drops the current atlas and forces a complete refresh.
  void clearTextureAtlas() {
    if (!isActive) {
      throw StateError('Cannot use addon until it has been loaded');
    }
    final previous = _textureAtlas;
    if (previous != null) _onRemoveTextureAtlas.fire(previous);
    _textureAtlas = TerminalTextureAtlas(++_generation);
    _onAddTextureAtlas.fire(_textureAtlas!);
    _onChangeTextureAtlas.fire(_textureAtlas!);
    terminal.clearTextureAtlas();
  }

  /// Reports a renderer context loss.
  void reportContextLoss() {
    if (!isActive) return;
    _onContextLoss.fire(TerminalVoid.value);
  }

  @override
  void dispose() {
    final atlas = _textureAtlas;
    if (atlas != null) _onRemoveTextureAtlas.fire(atlas);
    _textureAtlas = null;
    _onChangeTextureAtlas.dispose();
    _onAddTextureAtlas.dispose();
    _onRemoveTextureAtlas.dispose();
    _onContextLoss.dispose();
    super.dispose();
  }
}
