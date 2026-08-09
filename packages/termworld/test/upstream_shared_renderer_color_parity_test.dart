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

    test('DOM foreground true color red', () async {
      await _verifyTrueColor(_TrueColorChannel.red, foreground: true);
    });

    test('DOM background true color red', () async {
      await _verifyTrueColor(_TrueColorChannel.red, foreground: false);
    });

    test('DOM foreground true color green', () async {
      await _verifyTrueColor(_TrueColorChannel.green, foreground: true);
    });

    test('DOM background true color green', () async {
      await _verifyTrueColor(_TrueColorChannel.green, foreground: false);
    });

    test('DOM foreground true color blue', () async {
      await _verifyTrueColor(_TrueColorChannel.blue, foreground: true);
    });

    test('DOM background true color blue', () async {
      await _verifyTrueColor(_TrueColorChannel.blue, foreground: false);
    });

    test('DOM foreground true color grey', () async {
      await _verifyTrueColor(_TrueColorChannel.grey, foreground: true);
    });

    test('DOM background true color grey', () async {
      await _verifyTrueColor(_TrueColorChannel.grey, foreground: false);
    });

    test('DOM foreground true color red inverse', () async {
      await _verifyTrueColor(
        _TrueColorChannel.red,
        foreground: true,
        inverse: true,
      );
    });

    test('DOM background true color red inverse', () async {
      await _verifyTrueColor(
        _TrueColorChannel.red,
        foreground: false,
        inverse: true,
      );
    });

    test('DOM foreground true color green inverse', () async {
      await _verifyTrueColor(
        _TrueColorChannel.green,
        foreground: true,
        inverse: true,
      );
    });

    test('DOM background true color green inverse', () async {
      await _verifyTrueColor(
        _TrueColorChannel.green,
        foreground: false,
        inverse: true,
      );
    });

    test('DOM foreground true color blue inverse', () async {
      await _verifyTrueColor(
        _TrueColorChannel.blue,
        foreground: true,
        inverse: true,
      );
    });

    test('DOM background true color blue inverse', () async {
      await _verifyTrueColor(
        _TrueColorChannel.blue,
        foreground: false,
        inverse: true,
      );
    });

    test('DOM foreground true color grey inverse', () async {
      await _verifyTrueColor(
        _TrueColorChannel.grey,
        foreground: true,
        inverse: true,
      );
    });

    test('DOM background true color grey inverse', () async {
      await _verifyTrueColor(
        _TrueColorChannel.grey,
        foreground: false,
        inverse: true,
      );
    });

    test('DOM foreground true color grey invisible', () async {
      await _verifyTrueColor(
        _TrueColorChannel.grey,
        foreground: true,
        invisible: true,
      );
    });

    test('DOM background true color grey invisible', () async {
      await _verifyTrueColor(
        _TrueColorChannel.grey,
        foreground: false,
        invisible: true,
      );
    });

    test('DOM foreground 16-255', () async {
      await _verifyPalette256(foreground: true);
    });

    test('DOM background 16-255', () async {
      await _verifyPalette256(foreground: false);
    });

    test('DOM foreground 16-255 inverse', () async {
      await _verifyPalette256(foreground: true, inverse: true);
    });

    test('DOM background 16-255 inverse', () async {
      await _verifyPalette256(foreground: false, inverse: true);
    });

    test('DOM foreground 16-255 invisible', () async {
      await _verifyPalette256(foreground: true, invisible: true);
    });

    test('DOM background 16-255 invisible', () async {
      await _verifyPalette256(foreground: false, invisible: true);
    });

    test('DOM foreground 16-255 dim', () async {
      await _verifyPalette256(foreground: true, dim: true);
    });

    test('DOM background 16-255 dim', () async {
      await _verifyPalette256(foreground: false, dim: true);
    });

    test('DOM minimum contrast adjusts 0-15 on black background', () async {
      expect(
        await _contrastColors(_black),
        const <Color>[
          Color(0xffb0b4b4),
          Color(0xffee9e9e),
          Color(0xff98c66e),
          Color(0xffd0b331),
          Color(0xffa1b7d7),
          Color(0xffbfaec2),
          Color(0xff6ec5c6),
          Color(0xffd3d7cf),
          Color(0xffb7b9b7),
          Color(0xfff99c9c),
          Color(0xff8ae234),
          Color(0xfffce94f),
          Color(0xff9abadd),
          Color(0xffcbadc7),
          Color(0xff34e2e2),
          Color(0xffeeeeec),
        ],
      );
    });

    test('DOM minimum contrast adjusts 0-15 on white background', () async {
      expect(
        await _contrastColors(const Color(0xffffffff)),
        const <Color>[
          Color(0xff2e3436),
          Color(0xff840000),
          Color(0xff244800),
          Color(0xff483b00),
          Color(0xff20406a),
          Color(0xff4b3350),
          Color(0xff004748),
          Color(0xff40403f),
          Color(0xff3d3f3b),
          Color(0xff7d1313),
          Color(0xff28430d),
          Color(0xff433f13),
          Color(0xff2d4157),
          Color(0xff51394e),
          Color(0xff0d4343),
          Color(0xff404040),
        ],
      );
    });

    test('DOM minimum contrast enforces half ratio for dim cells', () async {
      final actual = await _contrastColors(
        const Color(0xffffffff),
        dim: true,
      );
      const expected = <Color>[
        Color(0xff96999a),
        Color(0xffe57f7f),
        Color(0xff3f7c04),
        Color(0xff7f6800),
        Color(0xff99b2d1),
        Color(0xffbaa7bd),
        Color(0xff047a7c),
        Color(0xff6e706c),
        Color(0xffaaaba9),
        Color(0xffd72424),
        Color(0xff487519),
        Color(0xff756d24),
        Color(0xff486787),
        Color(0xff7d5b79),
        Color(0xff197575),
        Color(0xff6f6f6e),
      ];
      expect(actual, hasLength(expected.length));
      for (var index = 0; index < expected.length; index++) {
        _expectColorApprox(actual[index], expected[index]);
      }
    });

    test('DOM regression 4758 multiple invisible cells stay hidden', () async {
      final terminal = Terminal();
      try {
        await terminal.writeAndWait('■\x1b[8m■■\r\n');
        final line = terminal.buffer.active.getLine(0)!;
        expect(line.getCell(0)!.isInvisible, isFalse);
        expect(line.getCell(1)!.isInvisible, isTrue);
        expect(line.getCell(2)!.isInvisible, isTrue);
        final resolver = TerminalCellColorResolver(
          theme: TerminalThemes.defaultTheme,
          focused: true,
          drawBoldTextInBrightColors: true,
          minimumContrastRatio: 1,
        );
        expect(
          <Color>[
            for (var column = 0; column < 3; column++)
              if (line.getCell(column)!.isInvisible)
                resolver
                    .resolve(line.getCell(column)!, selected: false)
                    .background
              else
                resolver
                    .resolve(line.getCell(column)!, selected: false)
                    .foreground,
          ],
          const <Color>[Color(0xffffffff), _black, _black],
        );
      } finally {
        terminal.dispose();
      }
    });

    test('DOM transparent background inverse is opaque', () async {
      final terminal = Terminal();
      try {
        await terminal.writeAndWait('\x1b[7m■\x1b[0m');
        final cell = terminal.buffer.active.getLine(0)!.getCell(0)!;
        final base = TerminalThemes.defaultTheme;
        final colors = TerminalCellColorResolver(
          theme: TerminalTheme(
            foreground: base.foreground,
            background: const Color(0x80ff0000),
            cursor: base.cursor,
            selection: base.selection,
            palette: base.palette,
          ),
          focused: true,
          drawBoldTextInBrightColors: true,
          minimumContrastRatio: 1,
        ).resolve(cell, selected: false);
        expect(colors.foreground, const Color(0xffff0000));
      } finally {
        terminal.dispose();
      }
    });

    test('DOM regression 4759 inverse text respects contrast', () async {
      final terminal = Terminal();
      try {
        await terminal.writeAndWait('\x1b[7m■■');
        final line = terminal.buffer.active.getLine(0)!;
        final theme = _contrastTheme(
          foreground: const Color(0xffaaaaaa),
          background: const Color(0xff333333),
        );
        for (var column = 0; column < 2; column++) {
          final cell = line.getCell(column)!;
          expect(
            TerminalCellColorResolver(
              theme: theme,
              focused: true,
              drawBoldTextInBrightColors: true,
              minimumContrastRatio: 1,
            ).resolve(cell, selected: false).foreground,
            const Color(0xff333333),
          );
          expect(
            TerminalCellColorResolver(
              theme: theme,
              focused: true,
              drawBoldTextInBrightColors: true,
              minimumContrastRatio: 10,
            ).resolve(cell, selected: false).foreground,
            const Color(0xff000000),
          );
        }
      } finally {
        terminal.dispose();
      }
    });

    test('DOM regression 4759 selected inverse respects contrast', () async {
      final terminal = Terminal();
      try {
        await terminal.writeAndWait('\x1b[7m■■');
        final line = terminal.buffer.active.getLine(0)!;
        final theme = _contrastTheme(
          foreground: const Color(0xff777777),
          background: const Color(0xff555555),
          selection: const Color(0xff666666),
        );
        for (var column = 0; column < 2; column++) {
          final cell = line.getCell(column)!;
          expect(
            TerminalCellColorResolver(
              theme: theme,
              focused: true,
              drawBoldTextInBrightColors: true,
              minimumContrastRatio: 1,
            ).resolve(cell, selected: true).foreground,
            const Color(0xff555555),
          );
          expect(
            TerminalCellColorResolver(
              theme: theme,
              focused: true,
              drawBoldTextInBrightColors: true,
              minimumContrastRatio: 10,
            ).resolve(cell, selected: true).foreground,
            const Color(0xffffffff),
          );
        }
      } finally {
        terminal.dispose();
      }
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

enum _TrueColorChannel { red, green, blue, grey }

Future<List<Color>> _contrastColors(
  Color background, {
  bool dim = false,
}) async {
  final terminal = Terminal(options: TerminalOptions(cols: 8, rows: 2));
  try {
    await terminal.writeAndWait(
      "${dim ? '\x1b[2m' : ''}"
      '\x1b[30m■\x1b[31m■\x1b[32m■\x1b[33m■'
      '\x1b[34m■\x1b[35m■\x1b[36m■\x1b[37m■\r\n'
      '\x1b[90m■\x1b[91m■\x1b[92m■\x1b[93m■'
      '\x1b[94m■\x1b[95m■\x1b[96m■\x1b[97m■',
    );
    final base = TerminalThemes.defaultTheme;
    final resolver = TerminalCellColorResolver(
      theme: TerminalTheme(
        foreground: base.foreground,
        background: background,
        cursor: base.cursor,
        selection: base.selection,
        palette: base.palette,
      ),
      focused: true,
      drawBoldTextInBrightColors: true,
      minimumContrastRatio: 10,
    );
    final colors = <Color>[
      for (var row = 0; row < 2; row++)
        for (var column = 0; column < 8; column++)
          resolver
              .resolve(
                terminal.buffer.active.getLine(row)!.getCell(column)!,
                selected: false,
              )
              .foreground,
    ];
    return dim
        ? <Color>[
            for (final color in colors) TerminalThemes.blend(background, color),
          ]
        : colors;
  } finally {
    terminal.dispose();
  }
}

void _expectColorApprox(Color actual, Color expected) {
  expect((actual.r * 255).round(), closeTo((expected.r * 255).round(), 1));
  expect((actual.g * 255).round(), closeTo((expected.g * 255).round(), 1));
  expect((actual.b * 255).round(), closeTo((expected.b * 255).round(), 1));
  expect(actual.a, 1);
}

Future<void> _verifyPalette256({
  required bool foreground,
  bool inverse = false,
  bool invisible = false,
  bool dim = false,
}) async {
  final terminal = Terminal(
    options: TerminalOptions(cols: 16, scrollback: 0),
  );
  try {
    final output = StringBuffer();
    for (var index = 16; index < 256; index++) {
      final attributes = <String>[
        if (inverse) '7',
        if (invisible) '8',
        if (dim) '2',
        if (foreground) '38' else '48',
        '5',
        '$index',
      ].join(';');
      final glyph = foreground != inverse ? '■' : ' ';
      output.write('\x1b[${attributes}m$glyph\x1b[0m');
      if (index % 16 == 15) output.write('\r\n');
    }
    await terminal.writeAndWait(output.toString());

    final resolver = TerminalCellColorResolver(
      theme: TerminalThemes.defaultTheme,
      focused: true,
      drawBoldTextInBrightColors: true,
      minimumContrastRatio: 1,
    );
    for (var offset = 0; offset < 240; offset++) {
      final cell = terminal.buffer.active
          .getLine(offset ~/ 16)!
          .getCell(offset % 16)!;
      final colors = resolver.resolve(cell, selected: false);
      final paletteColor = TerminalThemes.defaultTheme.palette[offset + 16];
      if (invisible && foreground) {
        expect(colors.background, _black, reason: 'palette cell $offset');
      } else if (foreground != inverse) {
        if (dim) {
          expect(colors.foreground.a, closeTo(0.5, 0.001));
          expect(colors.foreground, isNot(paletteColor));
        } else {
          expect(
            colors.foreground,
            paletteColor,
            reason: 'palette cell $offset',
          );
        }
      } else {
        expect(colors.background, paletteColor, reason: 'palette cell $offset');
      }
      if (dim && !foreground) {
        expect(colors.background, paletteColor, reason: 'palette cell $offset');
      }
    }
  } finally {
    terminal.dispose();
  }
}

Future<void> _verifyTrueColor(
  _TrueColorChannel channel, {
  required bool foreground,
  bool inverse = false,
  bool invisible = false,
}) async {
  final terminal = Terminal(
    options: TerminalOptions(cols: 16, scrollback: 0),
  );
  try {
    final output = StringBuffer();
    for (var index = 0; index < 256; index++) {
      final (red, green, blue) = _trueColor(channel, index);
      final attributes = <String>[
        if (inverse) '7',
        if (invisible) '8',
        if (foreground) '38' else '48',
        '2',
        '$red',
        '$green',
        '$blue',
      ].join(';');
      final glyph = foreground != inverse ? '■' : ' ';
      output.write('\x1b[${attributes}m$glyph\x1b[0m');
      if (index % 16 == 15) output.write('\r\n');
    }
    await terminal.writeAndWait(output.toString());

    final resolver = TerminalCellColorResolver(
      theme: TerminalThemes.defaultTheme,
      focused: true,
      drawBoldTextInBrightColors: true,
      minimumContrastRatio: 1,
    );
    for (var index = 0; index < 256; index++) {
      final cell = terminal.buffer.active
          .getLine(index ~/ 16)!
          .getCell(index % 16)!;
      final colors = resolver.resolve(cell, selected: false);
      final actual = invisible
          ? colors.background
          : foreground != inverse
          ? colors.foreground
          : colors.background;
      final (red, green, blue) = _trueColor(channel, index);
      final expected = invisible && foreground
          ? _black
          : Color.fromARGB(0xff, red, green, blue);
      expect(actual, expected, reason: 'true-color cell $index');
    }
  } finally {
    terminal.dispose();
  }
}

(int, int, int) _trueColor(_TrueColorChannel channel, int value) =>
    switch (channel) {
      _TrueColorChannel.red => (value, 0, 0),
      _TrueColorChannel.green => (0, value, 0),
      _TrueColorChannel.blue => (0, 0, value),
      _TrueColorChannel.grey => (value, value, value),
    };

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

TerminalTheme _contrastTheme({
  required Color foreground,
  required Color background,
  Color selection = const Color(0x4dffffff),
}) {
  final base = TerminalThemes.defaultTheme;
  return TerminalTheme(
    foreground: foreground,
    background: background,
    cursor: base.cursor,
    selection: selection,
    selectionOpaque: selection,
    palette: base.palette,
  );
}
