export 'platform_defaults_stub.dart'
    if (dart.library.io) 'platform_defaults_io.dart'
    if (dart.library.js_interop) 'platform_defaults_web.dart';
