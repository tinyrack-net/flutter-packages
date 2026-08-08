/// Flutter web WebGL renderer lifecycle addon.
library;

export 'src/addons/webgl_stub.dart'
    if (dart.library.js_interop) 'src/addons/webgl_web.dart';
