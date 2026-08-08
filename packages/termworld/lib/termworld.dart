/// A Flutter terminal emulator behaviorally aligned with xterm.js.
library;

export 'package:xterm/core.dart' show CellOffset;
export 'package:xterm/ui.dart'
    show TerminalCursorType, TerminalStyle, TerminalTheme, TerminalThemes;
export 'src/flutter/terminal_view.dart';
export 'src/flutter/terminal_view_controller.dart';
export 'termworld_headless.dart';
