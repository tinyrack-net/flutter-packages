import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('xterm options', () {
    test('uses the pinned xterm defaults', () {
      final options = TerminalOptions();

      expect(options.cols, 80);
      expect(options.rows, 24);
      expect(options.scrollback, 1000);
      expect(options.fontFamily, 'monospace');
      expect(options.fontSize, 15);
      expect(options.cursorStyle, TerminalCursorStyle.block);
      expect(options.tabStopWidth, 8);
      expect(options.wordSeparator, ' ()[]{}\',"`');
    });

    test('matches option validation and clamping', () {
      expect(() => TerminalOptions(scrollback: -1), throwsArgumentError);
      expect(() => TerminalOptions(cursorWidth: 0), throwsArgumentError);
      expect(
        () => TerminalOptions(scrollSensitivity: 0),
        throwsArgumentError,
      );
      expect(
        TerminalOptions(minimumContrastRatio: 30).minimumContrastRatio,
        21,
      );
      expect(TerminalOptions(scrollback: 0x1ffffffff).scrollback, 0xffffffff);
    });
  });

  group('write buffer and events', () {
    test(
      'preserves callbacks, event order, and UTF-8 chunk boundaries',
      () async {
        final terminal = Terminal(options: TerminalOptions(cols: 8, rows: 2));
        addTearDown(terminal.dispose);
        final events = <String>[];
        terminal
          ..onCursorMove.listen((_) => events.add('cursor'))
          ..onRender.listen((_) => events.add('render'))
          ..onWriteParsed.listen((_) => events.add('parsed'));

        // Separate calls assert queue ordering across distinct writes.
        // ignore: cascade_invocations
        terminal.write(Uint8List.fromList(<int>[0xed, 0x95]));
        // This is the second independently queued chunk under test.
        // ignore: cascade_invocations
        terminal.write(
          Uint8List.fromList(<int>[0x9c]),
          onParsed: () {
            events.add('callback');
          },
        );
        await terminal.writeAndWait('!');

        expect(
          terminal.buffer.active.getLine(0)!.translateToString(),
          startsWith('한!'),
        );
        expect(
          events.indexOf('callback'),
          lessThan(events.lastIndexOf('parsed')),
        );
        expect(events.where((event) => event == 'render'), hasLength(3));
      },
    );

    test('fires synchronous data listeners in registration order', () {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final values = <String>[];
      final first = terminal.onData.listen((value) => values.add('a$value'));
      terminal.onData.listen((value) => values.add('b$value'));

      terminal.input('1');
      first.dispose();
      terminal.input('2');

      expect(values, <String>['a1', 'b1', 'b2']);
    });
  });

  group('custom parser', () {
    test(
      'observes preceding terminal output before invoking a handler',
      () async {
        final terminal = Terminal();
        addTearDown(terminal.dispose);
        String? lineSeenByHandler;
        terminal.parser.registerOscHandler(777, (data) {
          lineSeenByHandler = terminal.buffer.active
              .getLine(0)!
              .translateToString(trimRight: true);
          return true;
        });

        await terminal.writeAndWait('before\u001b]777;payload\u001b\\after');

        expect(lineSeenByHandler, 'before');
        expect(
          terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
          'beforeafter',
        );
      },
    );

    test(
      'tries newest handlers first and blocks until async completion',
      () async {
        final terminal = Terminal();
        addTearDown(terminal.dispose);
        final calls = <String>[];
        terminal.parser.registerOscHandler(777, (data) {
          calls.add('old:$data');
          return true;
        });
        terminal.parser.registerOscHandler(777, (data) async {
          await Future<void>.delayed(Duration.zero);
          calls.add('new:$data');
          return false;
        });

        terminal.write('\u001b]777;pay');
        await terminal.writeAndWait('load\u001b\\X');

        expect(calls, <String>['new:payload', 'old:payload']);
        expect(
          terminal.buffer.active.getLine(0)!.translateToString(),
          startsWith('X'),
        );
      },
    );

    test('handles CSI, DCS, ESC and APC identifiers', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final calls = <String>[];
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(prefix: '?', finalByte: 'z'),
        (params) {
          calls.add('csi:$params');
          return true;
        },
      );
      terminal.parser.registerDcsHandler(
        const TerminalFunctionIdentifier(finalByte: 'q'),
        (data, params) {
          calls.add('dcs:$data');
          return true;
        },
      );
      terminal.parser.registerEscHandler(
        const TerminalFunctionIdentifier(intermediates: '%', finalByte: 'G'),
        () {
          calls.add('esc');
          return true;
        },
      );
      terminal.parser.registerApcHandler(
        const TerminalFunctionIdentifier(finalByte: 'G'),
        (data) {
          calls.add('apc:$data');
          return true;
        },
      );

      await terminal.writeAndWait(
        '\u001b[?1;2:3z\u001bP1qDATA\u001b\\\u001b%G\u001b_Gkitty\u001b\\',
      );

      expect(calls, <String>[
        'csi:[1, [2, 3]]',
        'dcs:DATA',
        'esc',
        'apc:kitty',
      ]);
    });
  });

  group('terminal public behavior', () {
    test('tracks buffers, modes, marker, decoration, and selection', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 2));
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('hello\r\nworld');
      final marker = terminal.registerMarker();
      expect(marker, isNotNull);
      final decoration = terminal.registerDecoration(marker: marker!);
      expect(decoration, isNotNull);
      terminal.select(0, 0, 5);
      expect(terminal.getSelection(), 'hello');

      await terminal.writeAndWait('\u001b[?1;45;1004;2004h\u001b[?1049hALT');

      expect(terminal.buffer.active.type, TerminalBufferType.alternate);
      expect(terminal.modes.applicationCursorKeysMode, isTrue);
      expect(terminal.modes.reverseWraparoundMode, isTrue);
      expect(terminal.modes.sendFocusMode, isTrue);
      expect(terminal.modes.bracketedPasteMode, isTrue);
      expect(terminal.registerMarker(), isNull);
    });

    test('normalizes and sanitizes bracketed paste', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final output = <String>[];
      terminal.onData.listen(output.add);
      await terminal.writeAndWait('\u001b[?2004h');

      terminal.paste('a\nb\u001b[201~');

      expect(output.single, '\u001b[200~a\rb\u241b[201~\u001b[201~');
    });

    test(
      'implements cursor backward tab without exceeding the viewport',
      () async {
        final terminal = Terminal(options: TerminalOptions(cols: 20, rows: 2));
        addTearDown(terminal.dispose);

        await terminal.writeAndWait('\u001b[20G\u001b[2Z#');

        expect(terminal.buffer.active.cursorX, 9);
        expect(
          terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
          '${List.filled(8, ' ').join()}#',
        );
      },
    );

    test('reverse wraparound crosses only soft-wrapped lines', () async {
      const ttyBackspace = '\b \b';
      final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 3));
      addTearDown(terminal.dispose);

      await terminal.writeAndWait(
        '\u001b[?45h1234512345${List.filled(8, ttyBackspace).join()}',
      );

      expect(
        terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
        '12',
      );
      expect(
        terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
        '',
      );
      expect(terminal.buffer.active.cursorX, 2);
      expect(terminal.buffer.active.cursorY, 0);
    });

    test('DECSET 1049 restores the normal cursor and attributes', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 3));
      addTearDown(terminal.dispose);

      await terminal.writeAndWait(
        '\u001b[?1049h\r\n\u001b[31mJUNK\u001b[?1049lTEST',
      );

      expect(terminal.buffer.active.type, TerminalBufferType.normal);
      expect(
        terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
        'TEST',
      );
      expect(
        terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
        '',
      );
    });
  });

  final fixtureRoot = Directory(
    Directory.current.path.endsWith('termworld')
        ? 'test/fixtures/xterm/escape_sequence_files'
        : 'packages/termworld/test/fixtures/xterm/escape_sequence_files',
  );
  if (fixtureRoot.existsSync()) {
    // xterm's pinned browser fixture harness excludes these inputs in
    // src/browser/Terminal2.test.ts. Their behavior is covered above using
    // the corresponding focused InputHandler tests instead.
    const upstreamFixtureExclusions = <String>{
      't0084-CBT',
      't0103-reverse_wrap',
      't0504-vim',
    };
    final inputs =
        fixtureRoot
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.in'))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));
    group('xterm VT fixtures', () {
      for (final input in inputs) {
        final name = input.uri.pathSegments.last.replaceAll('.in', '');
        if (upstreamFixtureExclusions.contains(name)) continue;
        final expected = File('${fixtureRoot.path}/$name.text');
        if (!expected.existsSync()) continue;
        test(name, () async {
          final terminal = Terminal(
            options: TerminalOptions(rows: 25, scrollback: 0),
          );
          addTearDown(terminal.dispose);
          // The upstream fixtures are written through a PTY with OPOST/ONLCR,
          // so each source LF reaches the terminal as CRLF.
          await terminal.writeAndWait(
            input.readAsStringSync().replaceAll('\n', '\r\n'),
          );

          final actual = StringBuffer();
          final start = terminal.buffer.active.baseY;
          for (var row = 0; row < 25; row++) {
            actual.writeln(
              terminal.buffer.active
                  .getLine(start + row)!
                  .translateToString(trimRight: true),
            );
          }
          final expectedRightTrimmed = expected
              .readAsStringSync()
              .split('\n')
              .map((line) => line.trimRight())
              .join('\n');
          expect(actual.toString(), expectedRightTrimmed);
        });
      }
    });
  }
}
