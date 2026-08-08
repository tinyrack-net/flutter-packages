import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/terminal.dart';

/// Coordinates browser font readiness with terminal relayout.
final class WebFontsAddon extends ManagedTerminalAddon {
  /// Creates a web fonts addon.
  WebFontsAddon({this.initialRelayout = true});

  /// Whether activation triggers an initial relayout.
  final bool initialRelayout;

  /// Whether this browser-only addon can run on the current platform.
  static bool get isSupported => true;

  @override
  void onActivate(Terminal terminal) {
    if (initialRelayout) _scheduleRelayout();
  }

  /// Waits for requested font families and then refreshes the renderer.
  Future<List<String>> loadFonts([Iterable<String>? fontFamilies]) async {
    await Future<void>.delayed(Duration.zero);
    await relayout();
    return List<String>.unmodifiable(fontFamilies ?? const <String>[]);
  }

  /// Recalculates terminal layout after browser fonts settle.
  Future<void> relayout() async {
    if (!isActive) {
      throw StateError('Cannot use addon until it has been loaded');
    }
    await Future<void>.delayed(Duration.zero);
    terminal.refresh(0, terminal.rows - 1);
  }

  void _scheduleRelayout() {
    Future<void>.delayed(Duration.zero, relayout);
  }
}
