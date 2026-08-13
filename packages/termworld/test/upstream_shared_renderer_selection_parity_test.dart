import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/src/addons/webgl_cell_color_resolver.dart';
import 'package:termworld/src/flutter/cell_color_resolver.dart';
import 'package:termworld/src/flutter/terminal_theme.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('SharedRendererTests selection colors', () {
    test('DOM selection inverse foreground uses original background', () {
      final result = _dom(
        theme: _theme(
          foreground: const Color(0xffff0000),
          background: const Color(0xff00ff00),
          selection: const Color(0xff0000ff),
        ),
        inverse: true,
      );
      expect(result.foreground, const Color(0xff00ff00));
      expect(result.background, const Color(0xff7f0080));
    });

    test('WebGL selection inverse foreground uses original background', () {
      final result = _webgl(
        inverse: true,
        colors: _webglColors(
          foreground: 0xff0000ff,
          background: 0x00ff00ff,
          selection: 0x0000ffff,
        ),
      );
      expect(_rgb(result.foreground), 0x00ff00);
      expect(result.foreground & TerminalWebglAttributes.inverse, 0);
      expect(_rgb(result.background), 0x7f0080);
    });

    test('DOM inactive selection renders when unfocused', () {
      final result = _dom(
        theme: _theme(
          selection: const Color(0x80ff0000),
          inactiveSelection: const Color(0x800000ff),
        ),
        focused: false,
      );
      expect(result.background, const Color(0xff000080));
    });

    test('WebGL inactive selection renders when unfocused', () {
      final result = _webgl(
        focused: false,
        colors: _webglColors(
          selection: 0x800000ff,
          inactiveSelection: 0x000080ff,
        ),
      );
      expect(_rgb(result.background), 0x000080);
    });

    test('DOM selection foreground overrides transparent inverse', () {
      final result = _dom(
        theme: _theme(selectionForeground: const Color(0xffff0000)),
        inverse: true,
      );
      expect(result.foreground, const Color(0xffff0000));
    });

    test('WebGL selection foreground overrides transparent inverse', () {
      final result = _webgl(
        inverse: true,
        colors: _webglColors(selectionForeground: 0xff0000ff),
      );
      expect(_rgb(result.foreground), 0xff0000);
      expect(result.foreground & TerminalWebglAttributes.inverse, 0);
    });

    test('WebGL selection blending background', () {
      final colors = _webglColors(
        ansi: const <int>[0x000000ff, 0xcc0000ff],
      );
      const red = TerminalWebglAttributes.colorModePalette16 | 1;
      const trueRed = TerminalWebglAttributes.colorModeRgb | 0xcc0000;
      expect(
        _rgb(_webgl(colors: colors, background: red).background),
        0xe68080,
      );
      expect(
        _rgb(_webgl(colors: colors, inverse: true).background),
        0xffffff,
      );
      expect(
        _rgb(
          _webgl(
            colors: colors,
            foreground: red | TerminalWebglAttributes.inverse,
          ).background,
        ),
        0xe68080,
      );
      expect(
        _rgb(_webgl(colors: colors, background: trueRed).background),
        0xe68080,
      );
    });

    test('WebGL selection blending powerline symbols', () {
      final colors = _webglColors(
        ansi: const <int>[0x000000ff, 0xcc0000ff, 0x00cc00ff],
      );
      const red = TerminalWebglAttributes.colorModePalette16 | 1;
      const green = TerminalWebglAttributes.colorModePalette16 | 2;
      expect(
        _rgb(_webgl(colors: colors, code: 0xe0b4).foreground),
        0xffffff,
      );
      expect(
        _rgb(
          _webgl(
            colors: colors,
            code: 0xe0b4,
            foreground: red,
            background: green,
          ).foreground,
        ),
        0xe68080,
      );
      expect(
        _rgb(
          _webgl(
            colors: colors,
            code: 0xe0b4,
            foreground: green,
            background: red,
          ).foreground,
        ),
        0x80e680,
      );
      expect(
        _rgb(
          _webgl(
            colors: colors,
            code: 0xe0b4,
            foreground: red | TerminalWebglAttributes.inverse,
            background: green,
          ).foreground,
        ),
        0x80e680,
      );
      expect(
        _rgb(
          _webgl(
            colors: colors,
            code: 0xe0b4,
            foreground: green | TerminalWebglAttributes.inverse,
            background: red,
          ).foreground,
        ),
        0xe68080,
      );
    });

    test('DOM inactive selection replaces regular cell background', () {
      final theme = _theme(
        selection: const Color(0xffff0000),
        inactiveSelection: const Color(0xff0000ff),
      );
      expect(_dom(theme: theme).background, const Color(0xffff0000));
      expect(
        _dom(theme: theme, focused: false).background,
        const Color(0xff0000ff),
      );
    });

    test('WebGL inactive selection replaces regular cell background', () {
      final colors = _webglColors(
        selection: 0xff0000ff,
        inactiveSelection: 0x0000ffff,
      );
      expect(_rgb(_webgl(colors: colors).background), 0xff0000);
      expect(
        _rgb(_webgl(colors: colors, focused: false).background),
        0x0000ff,
      );
    });
  });
}

TerminalResolvedCellColors _dom({
  required TerminalTheme theme,
  bool inverse = false,
  bool focused = true,
}) {
  final line = TerminalBufferLine(1)
    ..setCell(
      0,
      '■',
      1,
      TerminalCellAttributes(inverse: inverse),
    );
  return TerminalCellColorResolver(
    theme: theme,
    focused: focused,
    drawBoldTextInBrightColors: true,
    minimumContrastRatio: 1,
  ).resolve(line.getCell(0)!, selected: true);
}

TerminalWebglCellColorResult _webgl({
  required TerminalWebglCellColorSet colors,
  bool inverse = false,
  bool focused = true,
  int code = 0x25a0,
  int? foreground,
  int background = 0,
}) =>
    TerminalWebglCellColorResolver(
      colors: colors,
      isFocused: focused,
      fontSize: 15,
      devicePixelRatio: 1,
      isCellSelected: (_, _) => true,
    ).resolve(
      TerminalWebglPackedCell(
        code: code,
        foreground:
            foreground ?? (inverse ? TerminalWebglAttributes.inverse : 0),
        background: background,
      ),
      0,
      0,
      10,
      20,
    );

TerminalTheme _theme({
  Color foreground = const Color(0xffffffff),
  Color background = const Color(0xff000000),
  Color selection = const Color(0x80ffffff),
  Color? inactiveSelection,
  Color? selectionForeground,
}) => TerminalTheme(
  foreground: foreground,
  background: background,
  cursor: foreground,
  selection: selection,
  selectionOpaque: TerminalThemes.blend(background, selection),
  selectionInactive: inactiveSelection ?? selection,
  selectionInactiveOpaque: TerminalThemes.blend(
    background,
    inactiveSelection ?? selection,
  ),
  selectionForeground: selectionForeground,
  palette: const <Color>[],
);

TerminalWebglCellColorSet _webglColors({
  List<int> ansi = const <int>[],
  int foreground = 0xffffffff,
  int background = 0x000000ff,
  int selection = 0xffffffff,
  int? inactiveSelection,
  int? selectionForeground,
}) => TerminalWebglCellColorSet(
  ansi: ansi,
  foregroundRgba: foreground,
  backgroundRgba: background,
  selectionBackgroundOpaqueRgba: selection,
  selectionInactiveBackgroundOpaqueRgba: inactiveSelection ?? selection,
  selectionForegroundRgba: selectionForeground,
);

int _rgb(int packed) => packed & TerminalWebglAttributes.rgbMask;
