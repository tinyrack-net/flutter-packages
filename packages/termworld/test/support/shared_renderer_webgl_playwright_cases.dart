import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/webgl_cell_color_resolver.dart';
import 'package:termworld/src/flutter/cell_color_resolver.dart';
import 'package:termworld/termworld.dart';

const _black = Color(0xff000000);
const _white = Color(0xffffffff);
const _red = Color(0xffff0000);
const _blue = Color(0xff0000ff);
const _cellWidth = 6;
const _cellHeight = 10;

/// Executes one pinned xterm WebGL shared-renderer Playwright behavior.
Future<void> verifyWebglSharedRendererPlaywrightCase(
  WidgetTester tester,
  String behavior,
) async {
  if (behavior.contains('cursor') ||
      behavior.contains('selection should not be displayed')) {
    await _verifyRenderedRegression(tester, behavior);
    return;
  }
  if (behavior.contains('decoration color overrides')) {
    _verifyDecoration(behavior);
    return;
  }
  if (behavior.contains('minimumContrastRatio') ||
      behavior.contains('minimum contrast ratio')) {
    await _verifyContrast(behavior);
    return;
  }
  if (behavior.contains('#4758')) {
    await _verifyInvisibleRun();
    return;
  }
  if (behavior.contains('allowTransparency')) {
    await _verifyTransparentInverse();
    return;
  }
  await _verifyColorGrid(behavior);
}

Future<void> _verifyColorGrid(String behavior) async {
  if (behavior.contains('16-255')) {
    await _verifyPalette256(behavior);
    return;
  }
  if (behavior.contains('true color')) {
    await _verifyTrueColor(behavior);
    return;
  }

  final foreground = behavior.contains('foreground');
  final inverse = behavior.contains('inverse');
  final invisible = behavior.contains('invisible');
  final bright =
      behavior.contains('bright') ||
      behavior.contains('drawBoldTextInBrightColors');
  final terminal = Terminal(options: TerminalOptions(cols: 8, rows: 2));
  try {
    final output = StringBuffer();
    for (var index = 0; index < 8; index++) {
      final sgr = foreground
          ? bright && !behavior.contains('drawBold')
                ? 90 + index
                : 30 + index
          : bright
          ? 100 + index
          : 40 + index;
      output
        ..write('\x1b[')
        ..writeAll(<int>[
          if (inverse) 7,
          if (invisible) 8,
          if (behavior.contains('drawBold')) 1,
          sgr,
        ], ';')
        ..write('m')
        ..write(foreground != inverse ? '■' : ' ');
    }
    await terminal.writeAndWait(output.toString());
    final theme = _fixtureTheme(bright: bright);
    final resolver = TerminalCellColorResolver(
      theme: theme,
      focused: true,
      drawBoldTextInBrightColors: true,
      minimumContrastRatio: 1,
    );
    for (var index = 0; index < 8; index++) {
      final cell = terminal.buffer.active.getLine(0)!.getCell(index)!;
      final colors = resolver.resolve(cell, selected: false);
      final sampled = invisible && foreground
          ? colors.background
          : foreground != inverse
          ? colors.foreground
          : colors.background;
      expect(sampled, invisible && foreground ? _black : _fixture[index]);
    }
  } finally {
    terminal.dispose();
  }
}

Future<void> _verifyTrueColor(String behavior) async {
  final foreground = behavior.contains('foreground');
  final inverse = behavior.contains('inverse');
  final invisible = behavior.contains('invisible');
  final channel = behavior.contains('red')
      ? 0
      : behavior.contains('green')
      ? 1
      : behavior.contains('blue')
      ? 2
      : 3;
  final terminal = Terminal(options: TerminalOptions(cols: 16, rows: 16));
  try {
    final output = StringBuffer();
    for (var value = 0; value < 256; value++) {
      final rgb = switch (channel) {
        0 => (value, 0, 0),
        1 => (0, value, 0),
        2 => (0, 0, value),
        _ => (value, value, value),
      };
      output
        ..write('\x1b[')
        ..writeAll(<Object>[
          if (inverse) 7,
          if (invisible) 8,
          if (foreground) 38 else 48,
          2,
          rgb.$1,
          rgb.$2,
          rgb.$3,
        ], ';')
        ..write('m')
        ..write(foreground != inverse ? '■' : ' ')
        ..write('\x1b[0m');
      if (value % 16 == 15 && value != 255) output.write('\r\n');
    }
    await terminal.writeAndWait(output.toString());
    final resolver = _resolver(TerminalThemes.defaultTheme);
    for (var value = 0; value < 256; value++) {
      final cell = terminal.buffer.active
          .getLine(value ~/ 16)!
          .getCell(value % 16)!;
      final colors = resolver.resolve(cell, selected: false);
      final expected = switch (channel) {
        0 => Color(0xff000000 | value << 16),
        1 => Color(0xff000000 | value << 8),
        2 => Color(0xff000000 | value),
        _ => Color(0xff000000 | value << 16 | value << 8 | value),
      };
      final actual = invisible && foreground
          ? colors.background
          : foreground != inverse
          ? colors.foreground
          : colors.background;
      expect(actual, invisible && foreground ? _black : expected);
    }
  } finally {
    terminal.dispose();
  }
}

Future<void> _verifyPalette256(String behavior) async {
  final foreground = behavior.contains('foreground');
  final inverse = behavior.contains('inverse');
  final invisible = behavior.contains('invisible');
  final dim = behavior.contains('dim');
  final terminal = Terminal(options: TerminalOptions(cols: 16, rows: 15));
  try {
    final output = StringBuffer();
    for (var index = 16; index < 256; index++) {
      output
        ..write('\x1b[')
        ..writeAll(<int>[
          if (inverse) 7,
          if (invisible) 8,
          if (dim) 2,
          if (foreground) 38 else 48,
          5,
          index,
        ], ';')
        ..write('m')
        ..write(foreground != inverse ? '■' : ' ')
        ..write('\x1b[0m');
      if (index % 16 == 15 && index != 255) output.write('\r\n');
    }
    await terminal.writeAndWait(output.toString());
    final theme = TerminalThemes.defaultTheme;
    final resolver = _resolver(theme);
    for (var offset = 0; offset < 240; offset++) {
      final cell = terminal.buffer.active
          .getLine(offset ~/ 16)!
          .getCell(offset % 16)!;
      final colors = resolver.resolve(cell, selected: false);
      final expected = theme.palette[offset + 16];
      if (invisible && foreground) {
        expect(colors.background, _black);
      } else if (foreground != inverse) {
        expect(colors.foreground.withValues(alpha: 1), expected);
        if (dim) expect(colors.foreground.a, closeTo(0.5, 0.001));
      } else {
        expect(colors.background, expected);
      }
    }
  } finally {
    terminal.dispose();
  }
}

void _verifyDecoration(String behavior) {
  final foreground = behavior.contains('foregroundColor');
  final only = behavior.contains('(only ');
  final inverse = behavior.contains('ignore inverse');
  final result =
      TerminalWebglCellColorResolver(
        colors: const TerminalWebglCellColorSet(
          ansi: <int>[],
          foregroundRgba: 0xffffffff,
          backgroundRgba: 0x000000ff,
          selectionBackgroundOpaqueRgba: 0x000000ff,
          selectionInactiveBackgroundOpaqueRgba: 0x000000ff,
        ),
        isFocused: true,
        fontSize: 15,
        devicePixelRatio: 1,
        isCellSelected: (_, _) => false,
        bottomDecorations: (_, _) => <TerminalWebglDecorationColors>[
          TerminalWebglDecorationColors(
            foregroundRgba: foreground || !only ? 0xff0000ff : null,
            backgroundRgba: !foreground || !only ? 0x0000ffff : null,
          ),
        ],
      ).resolve(
        TerminalWebglPackedCell(
          code: 0x25a0,
          foreground: inverse ? TerminalWebglAttributes.inverse : 0,
          background: 0,
        ),
        0,
        0,
        10,
        20,
      );
  if (foreground) {
    expect(result.foreground & 0xffffff, 0xff0000);
    expect(result.foreground & TerminalWebglAttributes.inverse, 0);
    if (only) expect(result.background & 0xffffff, _white.toARGB32() >> 8);
  } else {
    expect(result.background & 0xffffff, 0x0000ff);
    if (only) expect(result.foreground & 0xffffff, 0x000000);
  }
}

Future<void> _verifyContrast(String behavior) async {
  final selected = behavior.contains('selected inverse');
  final inverse = behavior.contains('inverse text') || selected;
  final dim = behavior.contains('dim cells');
  final background = behavior.contains('white background') || dim
      ? _white
      : behavior.contains('black background')
      ? _black
      : const Color(0xff333333);
  final terminal = Terminal(options: TerminalOptions(cols: 16, rows: 2));
  try {
    await terminal.writeAndWait(
      '${inverse ? '\x1b[7m' : ''}${dim ? '\x1b[2m' : ''}'
      '\x1b[30m■\x1b[31m■\x1b[32m■\x1b[33m■'
      '\x1b[34m■\x1b[35m■\x1b[36m■\x1b[37m■',
    );
    final base = TerminalThemes.defaultTheme;
    final theme = TerminalTheme(
      foreground: inverse ? const Color(0xffaaaaaa) : base.foreground,
      background: background,
      cursor: base.cursor,
      selection: selected ? const Color(0xff666666) : base.selection,
      palette: base.palette,
    );
    final plain = TerminalCellColorResolver(
      theme: theme,
      focused: true,
      drawBoldTextInBrightColors: true,
      minimumContrastRatio: 1,
    );
    final contrasted = TerminalCellColorResolver(
      theme: theme,
      focused: true,
      drawBoldTextInBrightColors: true,
      minimumContrastRatio: 10,
    );
    for (var column = 0; column < 8; column++) {
      final cell = terminal.buffer.active.getLine(0)!.getCell(column)!;
      final before = plain.resolve(cell, selected: selected).foreground;
      final after = contrasted.resolve(cell, selected: selected).foreground;
      expect(after, isNot(before), reason: 'contrast cell $column');
      expect(
        _contrastRatio(
          contrasted.resolve(cell, selected: selected).background,
          after,
        ),
        greaterThanOrEqualTo(dim ? 5 : 10),
      );
    }
  } finally {
    terminal.dispose();
  }
}

double _contrastRatio(Color first, Color second) {
  double luminance(Color color) {
    double channel(double value) => value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    return channel(color.r) * 0.2126 +
        channel(color.g) * 0.7152 +
        channel(color.b) * 0.0722;
  }

  final a = luminance(first);
  final b = luminance(second);
  return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
}

Future<void> _verifyInvisibleRun() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('■\x1b[8m■■\r\n');
    final line = terminal.buffer.active.getLine(0)!;
    expect(line.getCell(0)!.isInvisible, isFalse);
    expect(line.getCell(1)!.isInvisible, isTrue);
    expect(line.getCell(2)!.isInvisible, isTrue);
  } finally {
    terminal.dispose();
  }
}

Future<void> _verifyTransparentInverse() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('\x1b[7m■');
    final base = TerminalThemes.defaultTheme;
    final result =
        _resolver(
          TerminalTheme(
            foreground: base.foreground,
            background: const Color(0x80ff0000),
            cursor: base.cursor,
            selection: base.selection,
            palette: base.palette,
          ),
        ).resolve(
          terminal.buffer.active.getLine(0)!.getCell(0)!,
          selected: false,
        );
    expect(result.foreground, _red);
    expect(result.foreground.a, 1);
  } finally {
    terminal.dispose();
  }
}

Future<void> _verifyRenderedRegression(
  WidgetTester tester,
  String behavior,
) async {
  final fixture = await _mount(
    tester,
    theme: TerminalColorTheme(
      cursor: behavior.contains('#5241') ? '#FF000080' : '#0000FF',
      cursorAccent: behavior.contains('cursorAccent') ? '#FF000080' : null,
      selectionBackground: '#FF0000',
    ),
    nested: behavior.contains('Shadow dom'),
  );
  if (behavior.contains('#4790')) {
    final image = await fixture.capture(tester);
    expect(_cellContains(image, 0, 0, _blue), isFalse);
    return;
  }
  if (behavior.contains('#4799')) {
    await fixture.terminal.writeAndWait(
      '${List<String>.filled(160, '\r\n').join()}\x1b[A\x1b[A',
    );
    fixture.terminal.scrollLines(-2);
    fixture.focusNode.requestFocus();
    await tester.pump();
    final image = await fixture.capture(tester);
    expect(_cellContains(image, 0, 4, _blue), isTrue);
    return;
  }
  if (behavior.contains('#4917')) {
    await fixture.terminal.writeAndWait(
      List<String>.filled(160, '\r\n').join(),
    );
    fixture.terminal
      ..scrollToBottom()
      ..selectLines(
        fixture.terminal.buffer.active.length - 1,
        fixture.terminal.buffer.active.length - 1,
      )
      ..scrollLines(-2);
    await tester.pump();
    expect(_cellContains(await fixture.capture(tester), 0, 0, _red), isFalse);
    return;
  }
  if (behavior.contains('#4773')) {
    fixture.terminal.selectAll();
    fixture.focusNode.requestFocus();
    await tester.pump();
    expect(_cellContains(await fixture.capture(tester), 0, 0, _blue), isTrue);
    return;
  }
  if (behavior.contains('cursorAccent')) {
    await fixture.terminal.writeAndWait('■\x1b[1D');
  }
  fixture.focusNode.requestFocus();
  await tester.pump();
  final expected = behavior.contains('#5241') ? const Color(0xff800000) : _blue;
  expect(_cellContains(await fixture.capture(tester), 0, 0, expected), isTrue);
}

TerminalCellColorResolver _resolver(TerminalTheme theme) =>
    TerminalCellColorResolver(
      theme: theme,
      focused: true,
      drawBoldTextInBrightColors: true,
      minimumContrastRatio: 1,
    );

TerminalTheme _fixtureTheme({required bool bright}) {
  final base = TerminalThemes.defaultTheme;
  final palette = List<Color>.of(base.palette);
  for (var index = 0; index < 8; index++) {
    palette[(bright ? 8 : 0) + index] = _fixture[index];
  }
  return TerminalTheme(
    foreground: base.foreground,
    background: base.background,
    cursor: base.cursor,
    selection: base.selection,
    palette: palette,
  );
}

const _fixture = <Color>[
  Color(0xff010203),
  Color(0xff040506),
  Color(0xff070809),
  Color(0xff0a0b0c),
  Color(0xff0d0e0f),
  Color(0xff101112),
  Color(0xff131415),
  Color(0xff161718),
];

final class _RenderFixture {
  const _RenderFixture(this.terminal, this.focusNode, this.boundaryKey);

  final Terminal terminal;
  final FocusNode focusNode;
  final GlobalKey boundaryKey;

  Future<_Pixels> capture(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final data = await image.toByteData();
          return _Pixels(image.width, image.height, data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      }))!;
}

Future<_RenderFixture> _mount(
  WidgetTester tester, {
  required TerminalColorTheme theme,
  required bool nested,
}) async {
  final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 5));
  final focusNode = FocusNode();
  final boundaryKey = GlobalKey();
  addTearDown(terminal.dispose);
  addTearDown(focusNode.dispose);
  final view = RepaintBoundary(
    key: boundaryKey,
    child: SizedBox(
      width: 30,
      height: 50,
      child: TerminalView(
        terminal: terminal,
        focusNode: focusNode,
        autoResize: false,
        theme: TerminalThemes.resolve(theme),
        style: const TerminalStyle(fontSize: 10, height: 1),
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: nested
            ? Material(type: MaterialType.transparency, child: view)
            : view,
      ),
    ),
  );
  await tester.pump();
  return _RenderFixture(terminal, focusNode, boundaryKey);
}

final class _Pixels {
  const _Pixels(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final List<int> bytes;

  Color at(int x, int y) {
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      bytes[offset + 3],
      bytes[offset],
      bytes[offset + 1],
      bytes[offset + 2],
    );
  }
}

bool _cellContains(_Pixels image, int column, int row, Color color) {
  for (var y = row * _cellHeight; y < (row + 1) * _cellHeight; y++) {
    for (var x = column * _cellWidth; x < (column + 1) * _cellWidth; x++) {
      if (image.at(x, y) == color) return true;
    }
  }
  return false;
}
