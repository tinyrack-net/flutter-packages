import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/options.dart';

/// Whether xterm's legacy ConPTY wrapped-line heuristic is required.
bool usesWindowsWrappingHeuristics(TerminalWindowsPtyOptions options) =>
    options.backend == 'conpty' &&
    options.buildNumber != null &&
    options.buildNumber! < 21376;

/// Updates the current line's wrapped state from the preceding line's final
/// cell, matching xterm.js' legacy Windows PTY behavior.
void updateWindowsModeWrappedState(TerminalBuffer buffer, int columns) {
  final previous = buffer.getLine(buffer.absoluteCursorY - 1);
  final lastCell = previous?.getCell(columns - 1);
  final next = buffer.getLine(buffer.absoluteCursorY);
  if (next != null && lastCell != null) {
    next.isWrapped = lastCell.code != 0 && lastCell.code != 0x20;
  }
}
