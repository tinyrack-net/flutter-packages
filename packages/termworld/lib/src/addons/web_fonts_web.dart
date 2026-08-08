import 'dart:async';
import 'dart:js_interop';

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/terminal.dart';
import 'package:web/web.dart' as web;

@JS('Array.from')
external JSArray<JSAny?> _arrayFrom(JSAny iterable);

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
  Future<List<Object>> loadFonts([Iterable<Object>? fonts]) async {
    await web.document.fonts.ready.toDart;
    final registered = _registeredFonts();
    final requested = List<Object>.of(fonts ?? const <Object>[]);
    final toLoad = <web.FontFace>[];
    if (requested.isEmpty) {
      toLoad.addAll(registered);
    } else {
      for (final font in requested) {
        if (font is String) {
          final matches = registered
              .where((face) => _unquote(face.family) == font)
              .toList(growable: false);
          if (matches.isEmpty) {
            throw StateError(
              'font family "$font" not registered in document.fonts',
            );
          }
          toLoad.addAll(matches);
          continue;
        }
        final jsFont = font.jsify();
        if (jsFont == null || !jsFont.isA<web.FontFace>()) {
          throw ArgumentError.value(
            font,
            'fonts',
            'must be a font family or FontFace',
          );
        }
        final face = jsFont as web.FontFace;
        final existing = registered.where((item) => _sameFace(item, face));
        if (existing.isEmpty) {
          web.document.fonts.add(face);
          registered.add(face);
          toLoad.add(face);
        } else {
          toLoad.add(existing.first);
        }
      }
    }
    final loaded = await Future.wait(toLoad.map((face) => face.load().toDart));
    return List<Object>.unmodifiable(loaded);
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
    final webFamilies = _registeredFonts()
        .map((face) => _unquote(face.family))
        .toSet();
    final dirty = families.where(webFamilies.contains).toList(growable: false);
    if (dirty.isEmpty) return;
    await loadFonts(dirty);
    if (!isActive) return;
    final clean = families.where((family) => !webFamilies.contains(family));
    terminal.options.fontFamily = clean.isEmpty
        ? 'monospace'
        : clean.map(_quote).join(', ');
    terminal.options.fontFamily = family;
  }

  void _scheduleRelayout() {
    unawaited(web.document.fonts.ready.toDart.then((_) => relayout()));
  }

  static List<String> _splitFamily(String family) => family
      .split(',')
      .map((value) => _unquote(value.trim()))
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  static List<web.FontFace> _registeredFonts() => _arrayFrom(
    web.document.fonts,
  ).toDart.map((item) => item! as web.FontFace).toList();

  static bool _sameFace(web.FontFace left, web.FontFace right) =>
      _unquote(left.family) == _unquote(right.family) &&
      left.stretch == right.stretch &&
      left.style == right.style &&
      left.unicodeRange == right.unicodeRange &&
      left.weight == right.weight;

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
