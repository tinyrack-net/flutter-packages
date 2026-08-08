import 'package:web/web.dart' as web;

/// Whether xterm's host-platform defaults should use macOS behavior.
bool get terminalHostIsMac =>
    web.window.navigator.platform.toLowerCase().contains('mac');
