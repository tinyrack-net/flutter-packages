import 'package:flutter/foundation.dart';
import 'package:termworld/src/terminal_emulator.dart';
import 'package:termworld/src/terminal_models.dart';

/// Owns selection and scroll state for a terminal viewport.
final class TerminalViewController extends ChangeNotifier {
  /// Creates view state, optionally connected to an emulator for text helpers.
  TerminalViewController({this._emulator});

  TerminalEmulator? _emulator;
  TerminalSelection? _selection;
  double _scrollOffset = 0;

  /// Current selection, if any.
  TerminalSelection? get selection => _selection;

  /// Whether the view has a selection.
  bool get hasSelection => _selection != null;

  /// Selected plain text, or `null` when no emulator or selection is attached.
  String? get selectedText => _emulator?.selectedText(this);

  /// Scrollback offset in logical rows from the bottom.
  double get scrollOffset => _scrollOffset;

  /// Replaces the selection.
  void setSelection(TerminalSelection? value) {
    if (_selection == value) return;
    _selection = value;
    notifyListeners();
  }

  /// Clears the selection.
  void clearSelection() => setSelection(null);

  /// Selects all retained terminal text.
  void selectAll() => _emulator?.selectAll(this);

  /// Selects the word at [position].
  void selectWordAt(TerminalPosition position) =>
      _emulator?.selectWordAt(this, position);

  /// Selects the retained line at [row].
  void selectLineAt(int row) => _emulator?.selectLineAt(this, row);

  /// Emulator used by text selection helpers.
  TerminalEmulator? get emulator => _emulator;

  /// Connects text helpers to [value].
  set emulator(TerminalEmulator value) => _emulator = value;

  /// Updates scrollback offset.
  void setScrollOffset(double value) {
    final normalized = value < 0 ? 0.0 : value;
    if (_scrollOffset == normalized) return;
    _scrollOffset = normalized;
    notifyListeners();
  }
}
