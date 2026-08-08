/// Browser font loading and relayout addon.
library;

export 'src/addons/web_fonts_stub.dart'
    if (dart.library.js_interop) 'src/addons/web_fonts_web.dart';
