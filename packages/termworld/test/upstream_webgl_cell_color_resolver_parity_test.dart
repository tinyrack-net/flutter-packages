import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/webgl_cell_color_resolver.dart';

void main() {
  test('preserves unmodified colors and encodes dotted underline phase', () {
    final resolver = _resolver();
    final result = resolver.resolve(
      const TerminalWebglPackedCell(
        code: 0x61,
        foreground: 0x1000002,
        background: TerminalWebglAttributes.hasExtended,
        extended: TerminalWebglAttributes.variantOffset | 7,
        underlineStyle: 4,
      ),
      1,
      0,
      3,
      5,
    );
    expect(result.foreground, 0x1000002);
    expect(result.background, TerminalWebglAttributes.hasExtended);
    expect(result.extended, 1 << 29 | 7);
  });

  test('encodes block-pattern x and y phase when underline phase is zero', () {
    final result = _resolver().resolve(
      const TerminalWebglPackedCell(
        code: 0x2592,
        foreground: 0,
        background: TerminalWebglAttributes.hasExtended,
      ),
      1,
      1,
      3,
      3,
    );
    expect(result.extended, 3 << 29);
  });

  test('top decorations override bottom decorations and preserve flags', () {
    final resolver = _resolver(
      bottomDecorations: (_, _) => const <TerminalWebglDecorationColors>[
        TerminalWebglDecorationColors(
          backgroundRgba: 0x112233ff,
          foregroundRgba: 0x445566ff,
        ),
      ],
      topDecorations: (_, _) => const <TerminalWebglDecorationColors>[
        TerminalWebglDecorationColors(
          backgroundRgba: 0xaabbccff,
          foregroundRgba: 0xddeeffff,
        ),
      ],
    );
    final result = resolver.resolve(
      const TerminalWebglPackedCell(
        code: 0x61,
        foreground: 0x8000000,
        background: TerminalWebglAttributes.dim,
      ),
      0,
      0,
      1,
      1,
    );
    expect(result.background, 0xbaabbcc);
    expect(result.foreground, 0xbddeeff);
  });

  test('selection blends explicit cell background and clears dim', () {
    final resolver = _resolver(isCellSelected: (_, _) => true);
    final result = resolver.resolve(
      const TerminalWebglPackedCell(
        code: 0x61,
        foreground: 0,
        background:
            TerminalWebglAttributes.colorModeRgb |
            0x204060 |
            TerminalWebglAttributes.dim,
      ),
      0,
      0,
      1,
      1,
    );
    expect(result.background & TerminalWebglAttributes.dim, 0);
    expect(
      result.background & TerminalWebglAttributes.colorModeMask,
      TerminalWebglAttributes.colorModeRgb,
    );
    expect(result.background & TerminalWebglAttributes.rgbMask, 0x902030);
  });

  test('inactive selection uses inactive colors and explicit foreground', () {
    final result =
        _resolver(
          isFocused: false,
          isCellSelected: (_, _) => true,
        ).resolve(
          const TerminalWebglPackedCell(
            code: 0x61,
            foreground: 0,
            background: 0,
          ),
          0,
          0,
          1,
          1,
        );
    expect(result.background, 0x3405060);
    expect(result.foreground, 0x3abcdef);
  });

  test('inverse resolves the missing side of a decoration override', () {
    final result =
        _resolver(
          bottomDecorations: (_, _) => const <TerminalWebglDecorationColors>[
            TerminalWebglDecorationColors(backgroundRgba: 0x010203ff),
          ],
        ).resolve(
          const TerminalWebglPackedCell(
            code: 0x61,
            foreground: TerminalWebglAttributes.inverse,
            background: 0,
          ),
          0,
          0,
          1,
          1,
        );
    expect(result.background, 0x3010203);
    expect(result.foreground, 0x3445566);
  });

  test('selected Powerline glyph treats its foreground as background', () {
    final result = _resolver(isCellSelected: (_, _) => true).resolve(
      const TerminalWebglPackedCell(
        code: 0xe0b0,
        foreground: TerminalWebglAttributes.colorModePalette16 | 2,
        background: 0,
      ),
      0,
      0,
      1,
      1,
    );
    expect(result.foreground & TerminalWebglAttributes.rgbMask, 0x810101);
  });
}

TerminalWebglCellColorResolver _resolver({
  bool isFocused = true,
  bool Function(int x, int y)? isCellSelected,
  Iterable<TerminalWebglDecorationColors> Function(int x, int y)?
  bottomDecorations,
  Iterable<TerminalWebglDecorationColors> Function(int x, int y)?
  topDecorations,
}) => TerminalWebglCellColorResolver(
  colors: TerminalWebglCellColorSet(
    ansi: <int>[
      for (final index in Iterable<int>.generate(256))
        (index << 24 | index << 16 | index << 8 | 0xff),
    ],
    foregroundRgba: 0x112233ff,
    backgroundRgba: 0x445566ff,
    selectionBackgroundOpaqueRgba: 0xff0000ff,
    selectionInactiveBackgroundOpaqueRgba: 0x405060ff,
    selectionForegroundRgba: 0xabcdefff,
  ),
  isFocused: isFocused,
  fontSize: 15,
  devicePixelRatio: 1,
  isCellSelected: isCellSelected ?? (_, _) => false,
  bottomDecorations:
      bottomDecorations ?? (_, _) => const <TerminalWebglDecorationColors>[],
  topDecorations:
      topDecorations ?? (_, _) => const <TerminalWebglDecorationColors>[],
);
