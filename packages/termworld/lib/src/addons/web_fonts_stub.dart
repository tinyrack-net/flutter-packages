import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/terminal.dart';

/// Coordinates browser font readiness with terminal relayout.
final class WebFontsAddon extends ManagedTerminalAddon {
  /// Creates a web fonts addon.
  WebFontsAddon({this.initialRelayout = true});

  /// Whether activation triggers an initial relayout.
  final bool initialRelayout;

  /// Whether this browser-only addon can run on the current platform.
  static bool get isSupported => false;

  @override
  void onActivate(Terminal terminal) {
    throw UnsupportedError('WebFontsAddon is only supported on Flutter web');
  }

  /// Waits for requested font families and then refreshes the renderer.
  Future<List<String>> loadFonts([Iterable<String>? fontFamilies]) {
    throw UnsupportedError('WebFontsAddon is only supported on Flutter web');
  }

  /// Recalculates terminal layout after browser fonts settle.
  Future<void> relayout() {
    throw UnsupportedError('WebFontsAddon is only supported on Flutter web');
  }
}
