import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:termworld/src/addons/font_family_parser.dart';
import 'package:termworld/src/addons/ligature_font.dart';
import 'package:web/web.dart' as web;

@JS('navigator')
external _FontNavigator get _fontNavigator;

@JS('window')
external JSObject get _window;

extension type _FontNavigator(JSObject _) implements JSObject {
  external _FontSet get fonts;
  external _PermissionSet get permissions;
}

extension type _FontSet(JSObject _) implements JSObject {
  external JSPromise<JSArray<_FontMetadata>> query();
}

extension type _PermissionSet(JSObject _) implements JSObject {
  external JSPromise<_PermissionStatus> request(JSObject descriptor);
}

extension type _PermissionStatus(JSObject _) implements JSObject {
  external String get state;
}

extension type _FontMetadata(JSObject _) implements JSObject {
  external String get family;
  external JSPromise<web.Blob> blob();
}

Future<Map<String, List<_FontMetadata>>>? _fontMetadata;

/// Resolves and parses the first accessible local font in a CSS family list.
Future<TerminalLigatureFont?> loadTerminalLigatureFont(
  String fontFamily,
  int cacheSize,
) async {
  final fonts = await (_fontMetadata ??= _queryFonts());
  for (final family in parseTerminalFontFamilies(fontFamily)) {
    if (isTerminalGenericFontFamily(family)) return null;
    final metadata = fonts[family];
    if (metadata == null || metadata.isEmpty) continue;
    final blob = await metadata.first.blob().toDart;
    final buffer = await blob.arrayBuffer().toDart;
    return TerminalLigatureFont.fromBytes(
      Uint8List.view(buffer.toDart),
      cacheSize: cacheSize,
    );
  }
  return null;
}

Future<Map<String, List<_FontMetadata>>> _queryFonts() async {
  JSArray<_FontMetadata>? metadata;
  if (_fontNavigator.hasProperty('fonts'.toJS).toDart) {
    if (_fontNavigator.hasProperty('permissions'.toJS).toDart &&
        _fontNavigator.permissions.hasProperty('request'.toJS).toDart) {
      try {
        final descriptor = <String, Object?>{'name': 'local-fonts'}.jsify()!;
        final status = await _fontNavigator.permissions
            .request(descriptor as JSObject)
            .toDart;
        if (status.state != 'granted') {
          throw StateError('Permission to access local fonts not granted.');
        }
      } on Object catch (error) {
        // Browsers may expose permissions without implementing local-fonts.
        if (error.runtimeType.toString() != 'TypeError') rethrow;
      }
    }
    try {
      metadata = await _fontNavigator.fonts.query().toDart;
    } on Object {
      metadata = null;
    }
  } else if (_window.hasProperty('queryLocalFonts'.toJS).toDart) {
    final result = _window.callMethod<JSPromise<JSArray<_FontMetadata>>>(
      'queryLocalFonts'.toJS,
    );
    metadata = await result.toDart;
  }
  final result = <String, List<_FontMetadata>>{};
  if (metadata == null) return result;
  for (final font in metadata.toDart) {
    (result[font.family] ??= <_FontMetadata>[]).add(font);
  }
  return result;
}
