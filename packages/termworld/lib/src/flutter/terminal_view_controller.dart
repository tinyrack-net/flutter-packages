import 'package:flutter/foundation.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/terminal.dart';
import 'package:xterm/ui.dart' as xterm_ui;

/// Controls selection and keyboard focus for a mounted [xterm_ui.TerminalView].
final class TerminalViewController extends ChangeNotifier {
  final xterm_ui.TerminalController _delegate = xterm_ui.TerminalController();
  Terminal? _terminal;
  VoidCallback? _requestKeyboard;

  /// Whether the terminal currently has a selection.
  bool get hasSelection => _delegate.selection != null;

  /// Selected terminal text, or null when there is no selection.
  String? get selectedText => hasSelection ? _terminal?.getSelection() : null;

  /// Current selection in buffer coordinates.
  TerminalBufferRange? get selection => _terminal?.getSelectionPosition();

  /// Requests focus and opens the platform keyboard.
  void requestKeyboard() => _requestKeyboard?.call();

  /// Clears the current selection.
  void clearSelection() {
    _delegate.clearSelection();
    _terminal?.clearSelection();
    notifyListeners();
  }

  /// Selects all retained normal or alternate buffer text.
  void selectAll() {
    final terminal = _terminal;
    if (terminal == null || terminal.buffer.active.length == 0) return;
    terminal.selectAll();
    _applySelection(terminal.getSelectionPosition());
  }

  /// Selects complete lines from [start] through [end].
  void selectLines(int start, int end) {
    final terminal = _terminal;
    if (terminal == null) return;
    terminal.selectLines(start, end);
    _applySelection(terminal.getSelectionPosition());
  }

  void _applySelection(TerminalBufferRange? range) {
    final terminal = _terminal;
    if (range == null || terminal == null) return;
    final buffer = terminal.rendererDelegate.buffer;
    final startLine = buffer.lines[range.start.y];
    final endLine = buffer.lines[range.end.y];
    _delegate.setSelection(
      startLine.createAnchor(range.start.x),
      endLine.createAnchor(range.end.x),
    );
    notifyListeners();
  }

  /// xterm-compatible `attach` API.
  void attach(Terminal terminal, VoidCallback requestKeyboard) {
    _terminal = terminal;
    _requestKeyboard = requestKeyboard;
    _delegate.addListener(_selectionChanged);
  }

  /// xterm-compatible `detach` API.
  void detach() {
    _delegate.removeListener(_selectionChanged);
    _terminal = null;
    _requestKeyboard = null;
  }

  void _selectionChanged() {
    final terminal = _terminal;
    final selection = _delegate.selection;
    if (terminal == null) return;
    if (selection == null) {
      terminal.clearSelection();
    } else {
      final begin = selection.normalized.begin;
      final end = selection.normalized.end;
      final length = (end.y - begin.y) * terminal.cols + end.x - begin.x;
      terminal.select(begin.x, begin.y, length);
    }
    notifyListeners();
  }

  /// Native xterm controller used by the renderer adapter.
  xterm_ui.TerminalController get rendererController => _delegate;

  @override
  void dispose() {
    detach();
    _delegate.dispose();
    super.dispose();
  }
}
