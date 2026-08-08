import 'dart:js_interop';

import 'package:web/web.dart';

CanvasRenderingContext2D? _context;
CanvasGradient? _litmusColor;

/// Resolves any opaque CSS color accepted by the browser canvas parser.
int? parseBrowserCssColor(String source) {
  final context = _context ??= _createContext();
  final litmus = _litmusColor;
  if (context == null || litmus == null) return null;
  context
    ..fillStyle = litmus
    ..fillStyle = source.toJS;
  if (!context.fillStyle.isA<JSString>()) return null;
  context.fillRect(0, 0, 1, 1);
  final data = context.getImageData(0, 0, 1, 1).data.toDart;
  if (data[3] != 0xff) return null;
  return 0xff000000 | data[0] << 16 | data[1] << 8 | data[2];
}

CanvasRenderingContext2D? _createContext() {
  final canvas = HTMLCanvasElement()
    ..width = 1
    ..height = 1;
  final value = canvas.getContext(
    '2d',
    <String, Object?>{'willReadFrequently': true}.jsify(),
  );
  if (value == null || !value.isA<CanvasRenderingContext2D>()) return null;
  final context = value as CanvasRenderingContext2D
    ..globalCompositeOperation = 'copy';
  _litmusColor = context.createLinearGradient(0, 0, 1, 1);
  return context;
}
