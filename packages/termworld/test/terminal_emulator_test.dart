import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

void main() {
  group('VT parser', () {
    test('parses a sequence identically at every input chunk boundary', () {
      const source = 'before\u001b[2J\u001b[3;4H\u001b[1;38;2;1;2;3m한글';
      String snapshot(Iterable<String> chunks) {
        final emulator = TerminalEmulator(columns: 12, rows: 5);
        chunks.forEach(emulator.write);
        final result = emulator.lines
            .map(
              (line) => line
                  .where((cell) => cell.width != 0)
                  .map((cell) => cell.text)
                  .join(),
            )
            .join('\n');
        emulator.dispose();
        return result;
      }

      final expected = snapshot(<String>[source]);
      for (var boundary = 0; boundary <= source.length; boundary++) {
        expect(
          snapshot(<String>[
            source.substring(0, boundary),
            source.substring(boundary),
          ]),
          expected,
          reason: 'boundary $boundary',
        );
      }
    });

    test('supports cursor, erase, alternate screen, title, and colors', () {
      final emulator = TerminalEmulator(columns: 8, rows: 3);
      addTearDown(emulator.dispose);

      emulator
        ..write('abc\u001b[2D!')
        ..write('\u001b]2;build shell\u0007')
        ..write('\u001b[31;48;5;25mR')
        ..write('\u001b[?1049hALT')
        ..write('\u001b[?1049l');

      expect(emulator.title, 'build shell');
      expect(
        emulator.lines.first.map((cell) => cell.text).join(),
        startsWith('a!R'),
      );
      expect(
        emulator.lines.first[2].style.foreground,
        defaultTerminalPalette[1],
      );
    });

    test(
      'supports cursor movement, editing, scrolling, and reset commands',
      () {
        final emulator = TerminalEmulator(columns: 6, rows: 4);
        addTearDown(emulator.dispose);

        emulator
          ..write('abcdef')
          ..write('\u001b[2;3HXY')
          ..write('\u001b[1A\u001b[2C!')
          ..write('\u001b[1B\u001b[1D?')
          ..write('\u001b[2E@\u001b[1F#')
          ..write('\u001b[2G\$')
          ..write('\u001b[s\u001b[4;6HZ\u001b[u')
          ..write('\u001b[2@++\u001b[1P')
          ..write('\u001b[1L\u001b[1M')
          ..write('\u001b[1K\u001b[0K')
          ..write('\u001b[1J\u001b[0J')
          ..write('\u001b[2J')
          ..write('clean');

        expect(_plain(emulator).replaceAll('\n', ''), contains('clean'));
        emulator
          ..write('\u001b7\u001b[4;6H!\u001b8')
          ..write('\u001bD\u001bE\u001bM')
          ..write('\u001bc');
        expect(_plain(emulator).trim(), isEmpty);
        expect(emulator.cursorColumn, 0);
        expect(emulator.cursorRow, 0);
      },
    );

    test('supports SGR attributes, indexed colors, and private modes', () {
      final emulator = TerminalEmulator(columns: 20, rows: 3);
      addTearDown(emulator.dispose);

      emulator
        ..write('\u001b[1;3;4;7;91;104mA')
        ..write('\u001b[22;23;24;27;39;49mB')
        ..write('\u001b[38;5;232;48;2;300;2;3mC')
        ..write('\u001b[38;5;250mD')
        ..write('\u001b[?1;6;7;25h')
        ..write('\u001b[?25l');

      final cells = emulator.lines.first;
      expect(cells[0].style.bold, isTrue);
      expect(cells[0].style.italic, isTrue);
      expect(cells[0].style.underline, isTrue);
      expect(cells[0].style.inverse, isTrue);
      expect(cells[1].style.foreground, isNull);
      expect(cells[1].style.background, isNull);
      expect(cells[2].style.foreground, const Color(0xFF080808));
      expect(cells[2].style.background, const Color(0xFFFF0203));
      expect(cells[3].style.foreground, const Color(0xFFBCBCBC));
      expect(emulator.cursorVisible, isFalse);
      expect(emulator.keySequence(LogicalKeyboardKey.arrowUp), '\u001bOA');
    });

    test('supports scroll regions, origin mode, wrap mode, and OSC ST', () {
      final emulator = TerminalEmulator(columns: 4, rows: 4);
      addTearDown(emulator.dispose);

      emulator
        ..write('\u001b[2;3r\u001b[?6h')
        ..write('\u001b[1;1Haa\n\nbb')
        ..write('\u001b[?7l\u001b[1;4HXY')
        ..write('\u001b]0;other title\u001b\\');

      expect(emulator.title, 'other title');
      expect(emulator.lines.length, 4);
      emulator.write('\u001b[?6;7l\u001b[r');
    });

    test('encodes application keypad and DEC mouse protocols', () {
      final emulator = TerminalEmulator(columns: 20, rows: 10);
      addTearDown(emulator.dispose);

      expect(
        emulator.mouseReport(
          button: 0,
          column: 1,
          row: 2,
          pressed: true,
        ),
        isNull,
      );
      emulator.write('\u001b=\u001b[?1000;1006h');
      expect(emulator.keySequence(LogicalKeyboardKey.numpad0), '\u001bOp');
      expect(emulator.keySequence(LogicalKeyboardKey.numpad9), '\u001bOy');
      expect(
        emulator.keySequence(LogicalKeyboardKey.numpadDecimal),
        '\u001bOn',
      );
      expect(emulator.keySequence(LogicalKeyboardKey.numpadAdd), '\u001bOk');
      expect(
        emulator.keySequence(LogicalKeyboardKey.numpadSubtract),
        '\u001bOm',
      );
      expect(
        emulator.keySequence(LogicalKeyboardKey.numpadMultiply),
        '\u001bOj',
      );
      expect(emulator.keySequence(LogicalKeyboardKey.numpadDivide), '\u001bOo');
      expect(
        emulator.mouseReport(
          button: 0,
          column: 1,
          row: 2,
          pressed: true,
          shift: true,
          meta: true,
          control: true,
        ),
        '\u001b[<28;2;3M',
      );
      expect(
        emulator.mouseReport(
          button: 0,
          column: 1,
          row: 2,
          pressed: true,
          motion: true,
        ),
        isNull,
      );
      expect(
        emulator.mouseReport(
          button: 0,
          column: 1,
          row: 2,
          pressed: false,
        ),
        '\u001b[<3;2;3m',
      );

      emulator.write('\u001b[?1000;1006l\u001b[?1002h');
      expect(
        emulator.mouseReport(
          button: 0,
          column: 100,
          row: -1,
          pressed: true,
          motion: true,
        ),
        isNotNull,
      );
      expect(
        emulator.mouseReport(
          button: 3,
          column: 0,
          row: 0,
          pressed: false,
          motion: true,
        ),
        isNull,
      );
      emulator.write('\u001b[?1002l\u001b[?1003h\u001b>');
      expect(emulator.mouseTrackingMode, TerminalMouseTrackingMode.anyEvent);
      expect(emulator.keySequence(LogicalKeyboardKey.numpad0), isNull);
    });

    test('bounds malformed control strings and resumes printable input', () {
      final emulator = TerminalEmulator(columns: 10, rows: 2);
      addTearDown(emulator.dispose);

      emulator.write('\u001b[${'1;' * 200}mOK');

      expect(
        emulator.lines.expand((line) => line).map((cell) => cell.text).join(),
        contains('OK'),
      );
      emulator
        ..write('\u001b]${'x' * 4100}\u0007')
        ..write('\u001b]2;broken\u001bX\u0007')
        ..write('\u001b]missing separator\u0007');
    });
  });

  group('buffer and input', () {
    test(
      'keeps wide graphemes and combining sequences in one leading cell',
      () {
        final emulator = TerminalEmulator(columns: 8, rows: 2)
          ..write('한é👩🏽‍💻');
        addTearDown(emulator.dispose);

        final line = emulator.lines.first;
        expect(
          line[0],
          isA<TerminalCell>().having((cell) => cell.text, 'text', '한'),
        );
        expect(line[0].width, 2);
        expect(line[1].width, 0);
        expect(line[2].text, 'é');
        expect(line[3].text, '👩🏽‍💻');
        expect(line[3].width, 2);
      },
    );

    test('retains bounded scrollback and reports resize once', () {
      final sizes = <TerminalSize>[];
      final emulator = TerminalEmulator(
        columns: 4,
        rows: 2,
        maxScrollbackLines: 2,
        onResize: sizes.add,
      );
      addTearDown(emulator.dispose);
      emulator
        ..write('a\nb\nc\nd\ne')
        ..resize(6, 3)
        ..resize(6, 3);

      expect(emulator.lines.length, lessThanOrEqualTo(5));
      expect(sizes, const <TerminalSize>[TerminalSize(columns: 6, rows: 3)]);
    });

    test('extracts selection and maps non-printing keys', () {
      final emulator = TerminalEmulator(columns: 8, rows: 2)..write('hello');
      final controller = TerminalViewController();
      addTearDown(emulator.dispose);
      addTearDown(controller.dispose);
      controller.setSelection(
        const TerminalSelection(
          TerminalPosition(1, 0),
          TerminalPosition(4, 0),
        ),
      );

      expect(emulator.selectedText(controller), 'ell');
      expect(emulator.keySequence(LogicalKeyboardKey.arrowUp), '\u001b[A');
      expect(emulator.keySequence(LogicalKeyboardKey.backspace), '\u007f');
      expect(emulator.keySequence(LogicalKeyboardKey.arrowDown), '\u001b[B');
      expect(emulator.keySequence(LogicalKeyboardKey.arrowRight), '\u001b[C');
      expect(emulator.keySequence(LogicalKeyboardKey.arrowLeft), '\u001b[D');
      expect(emulator.keySequence(LogicalKeyboardKey.home), '\u001b[H');
      expect(emulator.keySequence(LogicalKeyboardKey.end), '\u001b[F');
      expect(emulator.keySequence(LogicalKeyboardKey.insert), '\u001b[2~');
      expect(emulator.keySequence(LogicalKeyboardKey.delete), '\u001b[3~');
      expect(emulator.keySequence(LogicalKeyboardKey.pageUp), '\u001b[5~');
      expect(emulator.keySequence(LogicalKeyboardKey.pageDown), '\u001b[6~');
      expect(emulator.keySequence(LogicalKeyboardKey.enter), '\r');
      expect(emulator.keySequence(LogicalKeyboardKey.numpadEnter), '\r');
      expect(emulator.keySequence(LogicalKeyboardKey.tab), '\t');
      expect(emulator.keySequence(LogicalKeyboardKey.escape), '\u001b');
      expect(emulator.keySequence(LogicalKeyboardKey.f12), isNull);

      expect(controller.selectedText, isNull);
      controller.emulator = emulator;
      expect(controller.selectedText, 'ell');
      controller
        ..clearSelection()
        ..selectAll()
        ..setScrollOffset(-4)
        ..setScrollOffset(2);
      expect(controller.hasSelection, isTrue);
      expect(controller.selectedText, contains('hello'));
      expect(controller.scrollOffset, 2);

      controller.selectWordAt(const TerminalPosition(2, 0));
      expect(controller.selectedText, 'hello');
      controller.selectLineAt(0);
      expect(controller.selectedText, 'hello');
    });

    test('ignores invalid and unchanged resize requests', () {
      final emulator = TerminalEmulator(columns: 2, rows: 2);
      addTearDown(emulator.dispose);

      emulator
        ..resize(0, 2)
        ..resize(2, 0)
        ..resize(2, 2)
        ..resize(4, 3)
        ..write('\u0000\u0007a\b\t\r\u000b\f');

      expect(emulator.columns, 4);
      expect(emulator.rows, 3);
    });
  });
}

String _plain(TerminalEmulator emulator) => emulator.lines
    .map(
      (line) =>
          line.where((cell) => cell.width != 0).map((cell) => cell.text).join(),
    )
    .join('\n');
