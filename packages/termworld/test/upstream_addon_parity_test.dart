import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_progress.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('addon-progress/test/ProgressAddon.test.ts ProgressAddon', () {
    late Terminal terminal;
    late ProgressAddon addon;
    late List<TerminalProgress> changes;

    setUp(() {
      terminal = Terminal();
      addon = ProgressAddon();
      changes = <TerminalProgress>[];
      terminal.loadAddon(addon);
      addon.onChange.listen(changes.add);
    });

    tearDown(() => terminal.dispose());

    test('initial values should be 0;0', () {
      _expectProgress(addon.progress, TerminalProgressState.remove, 0);
    });

    test('state 0: remove', () async {
      await _write(terminal, 0);
      await _write(terminal, 0, '12');
      expect(changes, hasLength(2));
      for (final change in changes) {
        _expectProgress(change, TerminalProgressState.remove, 0);
      }
    });

    test('state 1: set', () async {
      await _write(terminal, 1, '10');
      await _write(terminal, 1, '50');
      await _write(terminal, 1, '23');
      expect(changes.map((change) => change.value), <int>[10, 50, 23]);
    });

    test('state 1: set - special sequence handling', () async {
      await _write(terminal, 1);
      await _write(terminal, 1, '12x');
      await _write(terminal, 1, '123');
      expect(changes.map((change) => change.value), <int>[0, 100]);
    });

    test('state 2: error - preserve previous value on empty/0', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 2);
      await _write(terminal, 2, '');
      await _write(terminal, 2, '0');
      expect(changes.map((change) => change.value), <int>[12, 12, 12, 12]);
    });

    test('state 2: error - with new value', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 2, '25');
      await _write(terminal, 2, '123');
      expect(changes.map((change) => change.value), <int>[12, 25, 100]);
    });

    test('state 3: indeterminate - keeps value untouched', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 3);
      await _write(terminal, 3, '123');
      expect(changes.map((change) => change.value), <int>[12, 12, 12]);
    });

    test('state 4: pause - preserve previous value on empty/0', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 4);
      await _write(terminal, 4, '');
      await _write(terminal, 4, '0');
      expect(changes.map((change) => change.value), <int>[12, 12, 12, 12]);
    });

    test('state 4: pause - with new value', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 4, '25');
      await _write(terminal, 4, '123');
      expect(changes.map((change) => change.value), <int>[12, 25, 100]);
    });

    test('invalid sequences should not emit anything', () async {
      await _write(terminal, 5, '12');
      await _write(terminal, 1, ' 123xxxx');
      await terminal.writeAndWait('\u001b]9;4;1;2;3\u001b\\');
      expect(changes, isEmpty);
    });
  });
}

Future<void> _write(Terminal terminal, int state, [String? value]) {
  final suffix = value == null ? '' : ';$value';
  return terminal.writeAndWait('\u001b]9;4;$state$suffix\u001b\\');
}

void _expectProgress(
  TerminalProgress progress,
  TerminalProgressState state,
  int value,
) {
  expect(progress.state, state);
  expect(progress.value, value);
}
