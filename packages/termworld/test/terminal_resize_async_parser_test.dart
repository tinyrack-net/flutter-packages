import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

/// A resize can land on any frame, including one where the parser is suspended
/// on an asynchronous handler. `Terminal.resize` flushes the write buffer
/// synchronously first, and that flush must not re-enter the parser: this
/// parser is genuinely asynchronous, unlike xterm.js' resumable synchronous
/// one, so a re-entrant parse used to throw and abandon the queued chunk.
void main() {
  test(
    'resize during an async parser handler keeps the queued output',
    () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final gate = Completer<bool>();
      final handled = <String>[];
      terminal.parser.registerOscHandler(1337, (data) {
        handled.add(data);
        return gate.future;
      });

      terminal.write('\x1b]1337;hold\x07');
      // Let the write buffer reach the handler and suspend there.
      await Future<void>.delayed(Duration.zero);
      expect(handled, <String>[
        'hold',
      ], reason: 'the handler should be awaiting');

      terminal
        ..write('queued')
        ..resize(40, 10);
      expect(terminal.cols, 40);
      expect(terminal.rows, 10);

      gate.complete(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        _line(terminal, 0),
        contains('queued'),
        reason: 'output queued behind the handler must still be parsed',
      );
    },
  );

  test(
    'resize without a pending handler still flushes before resizing',
    () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);

      terminal
        ..write('flushed')
        ..resize(40, 10);

      expect(_line(terminal, 0), contains('flushed'));
      expect(terminal.cols, 40);
    },
  );
}

String _line(Terminal terminal, int row) =>
    terminal.buffer.active.getLine(row)?.translateToString(trimRight: true) ??
    '';
