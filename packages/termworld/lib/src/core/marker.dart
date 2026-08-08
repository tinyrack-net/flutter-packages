import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/event.dart';

/// A tracked location in the normal buffer.
final class TerminalMarker implements Disposable {
  TerminalMarker._(this.id, this._line);

  /// xterm-compatible `id` API.
  final int id;
  int _line;
  final TerminalEventEmitter<TerminalVoid> _onDispose =
      TerminalEventEmitter<TerminalVoid>();
  bool _isDisposed = false;

  /// xterm-compatible `line` API.
  int get line => _isDisposed ? -1 : _line;

  /// xterm-compatible `onDispose` API.
  TerminalEvent<TerminalVoid> get onDispose => _onDispose.event;

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _onDispose
      ..fire(TerminalVoid.value)
      ..dispose();
  }

  /// Moves this marker when buffer lines are inserted or removed.
  void move(int amount) {
    if (_isDisposed) return;
    _line += amount;
    if (_line < 0) dispose();
  }
}

/// Decoration anchoring edge.
/// xterm-compatible `TerminalDecorationAnchor` API.
enum TerminalDecorationAnchor {
  /// Anchor to the marker's left edge.
  left,

  /// Anchor to the marker's right edge.
  right,
}

/// Decoration paint layer.
/// xterm-compatible `TerminalDecorationLayer` API.
enum TerminalDecorationLayer {
  /// Paint below terminal text.
  bottom,

  /// Paint above terminal text.
  top,
}

/// A marker-backed decoration.
final class TerminalDecoration implements Disposable {
  /// xterm-compatible `TerminalDecoration` API.
  TerminalDecoration({
    required this.marker,
    this.anchor = TerminalDecorationAnchor.left,
    this.x = 0,
    this.width = 1,
    this.height = 1,
    this.backgroundColor,
    this.foregroundColor,
    this.layer = TerminalDecorationLayer.bottom,
  }) {
    if (x < 0) throw ArgumentError.value(x, 'x', 'cannot be negative');
    if (width < 1 || height < 1) {
      throw ArgumentError('width and height must be at least 1');
    }
  }

  /// xterm-compatible `marker` API.
  final TerminalMarker marker;

  /// xterm-compatible `anchor` API.
  final TerminalDecorationAnchor anchor;

  /// xterm-compatible `x` API.
  final int x;

  /// xterm-compatible `width` API.
  final int width;

  /// xterm-compatible `height` API.
  final int height;

  /// xterm-compatible `backgroundColor` API.
  final String? backgroundColor;

  /// xterm-compatible `foregroundColor` API.
  final String? foregroundColor;

  /// xterm-compatible `layer` API.
  final TerminalDecorationLayer layer;
  final TerminalEventEmitter<TerminalDecoration> _onRender =
      TerminalEventEmitter<TerminalDecoration>();
  final TerminalEventEmitter<TerminalVoid> _onDispose =
      TerminalEventEmitter<TerminalVoid>();
  bool _isDisposed = false;

  /// xterm-compatible `onRender` API.
  TerminalEvent<TerminalDecoration> get onRender => _onRender.event;

  /// xterm-compatible `onDispose` API.
  TerminalEvent<TerminalVoid> get onDispose => _onDispose.event;

  /// xterm-compatible `rendered` API.
  void rendered() {
    if (!_isDisposed) _onRender.fire(this);
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _onDispose.fire(TerminalVoid.value);
    _onRender.dispose();
    _onDispose.dispose();
  }
}

/// Creates markers while keeping their identifiers monotonic per terminal.
final class TerminalMarkerFactory {
  int _nextId = 1;

  /// xterm-compatible `create` API.
  TerminalMarker create(int line) => TerminalMarker._(_nextId++, line);
}
