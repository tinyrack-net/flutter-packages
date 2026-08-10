import 'package:flutter/foundation.dart';
import 'package:vtworld/vtworld.dart';

/// Controls selection, scrolling and keyboard focus for a terminal view.
final class TerminalViewController extends ChangeNotifier {
  /// Creates a detached terminal view controller.
  TerminalViewController();

  Terminal? _terminal;
  VoidCallback? _requestKeyboard;
  Disposable? _selectionListener;

  /// Whether the attached terminal has a selection.
  bool get hasSelection => _terminal?.hasSelection() ?? false;

  /// Selected text, or `null` when there is no selection.
  String? get selectedText => hasSelection ? _terminal?.getSelection() : null;

  /// Selected buffer range, or `null` when there is no selection.
  TerminalBufferRange? get selection => _terminal?.getSelectionPosition();

  /// Requests keyboard focus for the attached view.
  void requestKeyboard() => _requestKeyboard?.call();

  /// Clears the current selection.
  void clearSelection() => _terminal?.clearSelection();

  /// Selects the complete active buffer.
  void selectAll() => _terminal?.selectAll();

  /// Selects complete lines from [start] through [end].
  void selectLines(int start, int end) => _terminal?.selectLines(start, end);

  /// Selects [length] cells beginning at [column], [row].
  void select(int column, int row, int length) =>
      _terminal?.select(column, row, length);

  /// Scrolls the viewport by [amount] lines.
  void scrollLines(int amount) => _terminal?.scrollLines(amount);

  /// Scrolls the viewport by [amount] pages.
  void scrollPages(int amount) => _terminal?.scrollPages(amount);

  /// Scrolls to the oldest retained line.
  void scrollToTop() => _terminal?.scrollToTop();

  /// Scrolls to the live viewport.
  void scrollToBottom() => _terminal?.scrollToBottom();

  /// Attaches this controller to [terminal].
  void attach(Terminal terminal, VoidCallback requestKeyboard) {
    detach();
    _terminal = terminal;
    _requestKeyboard = requestKeyboard;
    _selectionListener = terminal.onSelectionChange.listen((_) {
      notifyListeners();
    });
  }

  /// Detaches this controller from its current terminal.
  void detach() {
    _selectionListener?.dispose();
    _selectionListener = null;
    _terminal = null;
    _requestKeyboard = null;
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
