import 'dart:async';
import 'dart:js_interop';

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/terminal.dart';
import 'package:web/web.dart' as web;

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
    await web.document.fonts.ready.toDart;
    final families = List<String>.of(fontFamilies ?? const <String>[]);
    for (final family in families) {
      final loaded =
          (await web.document.fonts.load('16px ${_quote(family)}').toDart)
              .toDart;
      if (loaded.isEmpty) {
        throw StateError(
          'font family "$family" not registered in document.fonts',
        );
      }
    }
    return List<String>.unmodifiable(families);
  }

  /// Recalculates terminal layout after browser fonts settle.
  Future<void> relayout() async {
    if (!isActive) {
      throw StateError('Cannot use addon until it has been loaded');
    }
    await web.document.fonts.ready.toDart;
    final family = terminal.options.fontFamily;
    final families = _splitFamily(family);
    if (families.isEmpty) return;
    var foundWebFont = false;
    for (final candidate in families) {
      final loaded =
          (await web.document.fonts.load('16px ${_quote(candidate)}').toDart)
              .toDart;
      foundWebFont = foundWebFont || loaded.isNotEmpty;
    }
    if (!foundWebFont) return;
    if (!isActive) return;
    terminal.options.fontFamily = 'monospace';
    terminal.options.fontFamily = family;
    terminal.refresh(0, terminal.rows - 1);
  }

  void _scheduleRelayout() {
    unawaited(web.document.fonts.ready.toDart.then((_) => relayout()));
  }

  static List<String> _splitFamily(String family) => family
      .split(',')
      .map((value) => _unquote(value.trim()))
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  static String _unquote(String value) {
    if (value.length >= 2 &&
        (value.startsWith('"') && value.endsWith('"') ||
            value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static String _quote(String value) {
    final safe = RegExp(
      r'^[-_a-zA-Z\u00a0-\u{10ffff}][-_a-zA-Z0-9\u00a0-\u{10ffff}]*$',
      unicode: true,
    );
    final startsLikeNumber = RegExp(r'^(-?\d|--)').hasMatch(value);
    if (!startsLikeNumber && safe.hasMatch(value)) return value;
    return '"${value.replaceAll('"', r'\"')}"';
  }
}
