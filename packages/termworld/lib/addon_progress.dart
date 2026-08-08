/// OSC 9;4 task progress addon.
library;

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/terminal.dart';

/// Progress state codes defined by the xterm progress addon.
/// xterm-compatible `TerminalProgressState` API.
enum TerminalProgressState {
  /// Removes progress state.
  remove,

  /// Shows normal progress.
  set,

  /// Shows an error state.
  error,

  /// Shows indeterminate progress.
  indeterminate,

  /// Shows paused progress.
  paused,
}

/// Current taskbar progress.
final class TerminalProgress {
  /// xterm-compatible `TerminalProgress` API.
  const TerminalProgress({required this.state, required this.value});

  /// Semantic progress state.
  final TerminalProgressState state;

  /// Progress percentage clamped from 0 through 100.
  final int value;
}

/// Parses and exposes OSC 9;4 progress sequences.
final class ProgressAddon extends ManagedTerminalAddon {
  TerminalProgress _progress = const TerminalProgress(
    state: TerminalProgressState.remove,
    value: 0,
  );
  final TerminalEventEmitter<TerminalProgress> _onChange =
      TerminalEventEmitter<TerminalProgress>();

  /// Fires synchronously whenever [progress] changes.
  TerminalEvent<TerminalProgress> get onChange => _onChange.event;

  /// Current progress.
  TerminalProgress get progress => _progress;

  set progress(TerminalProgress value) {
    _progress = TerminalProgress(
      state: value.state,
      value: value.value.clamp(0, 100),
    );
    _onChange.fire(_progress);
  }

  @override
  void onActivate(Terminal terminal) {
    add(
      terminal.parser.registerOscHandler(9, (data) {
        if (!data.startsWith('4;')) return false;
        final parts = data.split(';');
        if (parts.length > 3) return true;
        if (parts.length == 2) parts.add('');
        final state = _strictInt(parts[1]);
        final amount = _strictInt(parts[2]);
        if (state < 0 || state > 4) return true;
        final nextState = TerminalProgressState.values[state];
        switch (nextState) {
          case TerminalProgressState.remove:
            progress = TerminalProgress(state: nextState, value: 0);
          case TerminalProgressState.set:
            if (amount >= 0) {
              progress = TerminalProgress(state: nextState, value: amount);
            }
          case TerminalProgressState.error:
          case TerminalProgressState.paused:
            if (amount >= 0) {
              progress = TerminalProgress(
                state: nextState,
                value: amount == 0 ? progress.value : amount,
              );
            }
          case TerminalProgressState.indeterminate:
            progress = TerminalProgress(
              state: nextState,
              value: progress.value,
            );
        }
        return true;
      }),
    );
  }

  static int _strictInt(String value) {
    var result = 0;
    for (final code in value.codeUnits) {
      if (code < 0x30 || code > 0x39) return -1;
      result = result * 10 + code - 0x30;
    }
    return result;
  }

  @override
  void dispose() {
    _onChange.dispose();
    super.dispose();
  }
}
