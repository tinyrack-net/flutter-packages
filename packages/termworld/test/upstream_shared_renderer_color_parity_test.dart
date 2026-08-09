import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/flutter/cell_color_resolver.dart';
import 'package:termworld/src/flutter/terminal_theme.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('SharedRendererTests DOM basic colors', () {
    test('DOM colors foreground 0-15', () async {
      final frame = await _frame(
        '\x1b[30m■\x1b[31m■\x1b[32m■\x1b[33m■'
        '\x1b[34m■\x1b[35m■\x1b[36m■\x1b[37m■',
        _baseTheme(),
      );
      expect(_glyphColors(frame), _fixtureColors);
    });

    test('DOM foreground 0-7 drawBoldTextInBrightColors', () async {
      final frame = await _frame(
        '\x1b[1;30m■\x1b[1;31m■\x1b[1;32m■\x1b[1;33m■'
        '\x1b[1;34m■\x1b[1;35m■\x1b[1;36m■\x1b[1;37m■',
        _brightTheme(),
      );
      expect(_glyphColors(frame), _fixtureColors);
    });

    test('DOM background 0-15', () async {
      final frame = await _frame(
        '\x1b[40m \x1b[41m \x1b[42m \x1b[43m '
        '\x1b[44m \x1b[45m \x1b[46m \x1b[47m ',
        _baseTheme(),
      );
      expect(_backgroundColors(frame), _fixtureColors);
    });

    test('DOM foreground 0-15 inverse', () async {
      final frame = await _frame(
        '\x1b[7;30m \x1b[7;31m \x1b[7;32m \x1b[7;33m '
        '\x1b[7;34m \x1b[7;35m \x1b[7;36m \x1b[7;37m ',
        _baseTheme(),
      );
      expect(_backgroundColors(frame), _fixtureColors);
    });

    test('DOM background 0-15 inverse', () async {
      final frame = await _frame(
        '\x1b[7;40m■\x1b[7;41m■\x1b[7;42m■\x1b[7;43m■'
        '\x1b[7;44m■\x1b[7;45m■\x1b[7;46m■\x1b[7;47m■',
        _baseTheme(),
      );
      expect(_glyphColors(frame), _fixtureColors);
    });

    test('DOM foreground 0-15 invisible', () async {
      final frame = await _frame(
        '\x1b[8;30m■\x1b[8;31m■\x1b[8;32m■\x1b[8;33m■'
        '\x1b[8;34m■\x1b[8;35m■\x1b[8;36m■\x1b[8;37m■',
        _baseTheme(),
      );
      expect(_sampledColors(frame), List<Color>.filled(8, _black));
    });

    test('DOM background 0-15 invisible', () async {
      final frame = await _frame(
        '\x1b[8;40m■\x1b[8;41m■\x1b[8;42m■\x1b[8;43m■'
        '\x1b[8;44m■\x1b[8;45m■\x1b[8;46m■\x1b[8;47m■',
        _baseTheme(),
      );
      expect(_sampledColors(frame), _fixtureColors);
    });

    test('DOM foreground 0-15 bright', () async {
      final frame = await _frame(
        '\x1b[90m■\x1b[91m■\x1b[92m■\x1b[93m■'
        '\x1b[94m■\x1b[95m■\x1b[96m■\x1b[97m■',
        _brightTheme(),
      );
      expect(_glyphColors(frame), _fixtureColors);
    });

    test('DOM background 0-15 bright', () async {
      final frame = await _frame(
        '\x1b[100m \x1b[101m \x1b[102m \x1b[103m '
        '\x1b[104m \x1b[105m \x1b[106m \x1b[107m ',
        _brightTheme(),
      );
      expect(_backgroundColors(frame), _fixtureColors);
    });
  });
}

const _black = Color(0xff000000);
const _fixtureColors = <Color>[
  Color(0xff010203),
  Color(0xff040506),
  Color(0xff070809),
  Color(0xff0a0b0c),
  Color(0xff0d0e0f),
  Color(0xff101112),
  Color(0xff131415),
  Color(0xff161718),
];

final class _CellFrame {
  const _CellFrame(this.cells, this.colors);

  final List<TerminalCell> cells;
  final List<TerminalResolvedCellColors> colors;
}

Future<_CellFrame> _frame(String data, TerminalTheme theme) async {
  final terminal = Terminal(options: TerminalOptions(cols: 20, rows: 2));
  try {
    await terminal.writeAndWait(data);
    final line = terminal.buffer.active.getLine(0)!;
    final resolver = TerminalCellColorResolver(
      theme: theme,
      focused: true,
      drawBoldTextInBrightColors: true,
      minimumContrastRatio: 1,
    );
    final cells = <TerminalCell>[];
    final colors = <TerminalResolvedCellColors>[];
    for (var index = 0; index < 8; index++) {
      final cell = line.getCell(index)!;
      cells.add(cell);
      colors.add(resolver.resolve(cell, selected: false));
    }
    return _CellFrame(cells, colors);
  } finally {
    terminal.dispose();
  }
}

List<Color> _glyphColors(_CellFrame frame) =>
    frame.colors.map((entry) => entry.foreground).toList();

List<Color> _backgroundColors(_CellFrame frame) =>
    frame.colors.map((entry) => entry.background).toList();

List<Color> _sampledColors(_CellFrame frame) => <Color>[
  for (var index = 0; index < frame.cells.length; index++)
    frame.cells[index].isInvisible
        ? frame.colors[index].background
        : frame.colors[index].foreground,
];

TerminalTheme _baseTheme() => _themeWithFixtureColors(0);

TerminalTheme _brightTheme() => _themeWithFixtureColors(8);

TerminalTheme _themeWithFixtureColors(int offset) {
  final palette = List<Color>.of(TerminalThemes.defaultTheme.palette)
    ..setRange(offset, offset + _fixtureColors.length, _fixtureColors);
  return TerminalTheme(
    foreground: const Color(0xffffffff),
    background: _black,
    cursor: const Color(0xffffffff),
    selection: const Color(0x4dffffff),
    palette: List<Color>.unmodifiable(palette),
  );
}
