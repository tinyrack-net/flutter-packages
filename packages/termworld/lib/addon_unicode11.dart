/// Unicode 11 width addon.
library;

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/terminal.dart';
import 'package:termworld/src/core/unicode.dart';

/// Registers and selects xterm's Unicode 11 width provider.
final class Unicode11Addon extends ManagedTerminalAddon {
  @override
  void onActivate(Terminal terminal) {
    if (!terminal.unicode.versions.contains('11')) {
      terminal.unicode.register(const Unicode11TerminalProvider());
    }
    terminal.unicode.activeVersion = '11';
  }
}
