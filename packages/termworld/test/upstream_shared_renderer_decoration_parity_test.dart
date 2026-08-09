import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/webgl_cell_color_resolver.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/flutter/cell_color_resolver.dart';
import 'package:termworld/src/flutter/terminal_theme.dart';

const _red = Color(0xffff0000);
const _blue = Color(0xff0000ff);
const _black = Color(0xff000000);
const _white = Color(0xffffffff);

void main() {
  group('SharedRendererTests decoration color overrides', () {
    test('DOM Renderer decoration foregroundColor', () {
      expect(
        _resolveDom(
          decorations: const [
            TerminalCellDecorationColors(
              foreground: _red,
              background: _blue,
            ),
          ],
        ).foreground,
        _red,
      );
    });

    test('DOM Renderer decoration foregroundColor should ignore inverse', () {
      expect(
        _resolveDom(
          inverse: true,
          decorations: const [
            TerminalCellDecorationColors(
              foreground: _red,
              background: _blue,
            ),
          ],
        ).foreground,
        _red,
      );
    });

    test(
      'DOM Renderer only foreground decoration ignores inverse',
      () {
        final decorated = _resolveDom(
          inverse: true,
          decorations: const [
            TerminalCellDecorationColors(foreground: _red),
          ],
        );
        final undecorated = _resolveDom(inverse: true);
        expect(decorated.foreground, _red);
        expect(undecorated.background, _white);
      },
    );

    test('DOM Renderer decoration backgroundColor', () {
      expect(
        _resolveDom(
          decorations: const [
            TerminalCellDecorationColors(
              foreground: _red,
              background: _blue,
            ),
          ],
        ).background,
        _blue,
      );
    });

    test('DOM Renderer decoration backgroundColor should ignore inverse', () {
      expect(
        _resolveDom(
          inverse: true,
          decorations: const [
            TerminalCellDecorationColors(
              foreground: _red,
              background: _blue,
            ),
          ],
        ).background,
        _blue,
      );
    });

    test(
      'DOM Renderer only background decoration ignores inverse',
      () {
        final decorated = _resolveDom(
          inverse: true,
          decorations: const [
            TerminalCellDecorationColors(background: _blue),
          ],
        );
        final undecorated = _resolveDom(inverse: true);
        expect(decorated.background, _blue);
        expect(decorated.foreground, _black);
        expect(undecorated.background, _white);
      },
    );

    test('WebGL Renderer decoration foregroundColor', () {
      expect(
        _webglRgb(
          _resolveWebgl(
            decorations: const [
              TerminalWebglDecorationColors(
                foregroundRgba: 0xff0000ff,
                backgroundRgba: 0x0000ffff,
              ),
            ],
          ).foreground,
        ),
        0xff0000,
      );
    });

    test('WebGL Renderer decoration foregroundColor should ignore inverse', () {
      final result = _resolveWebgl(
        inverse: true,
        decorations: const [
          TerminalWebglDecorationColors(
            foregroundRgba: 0xff0000ff,
            backgroundRgba: 0x0000ffff,
          ),
        ],
      );
      expect(_webglRgb(result.foreground), 0xff0000);
      expect(result.foreground & TerminalWebglAttributes.inverse, 0);
    });

    test(
      'WebGL Renderer only foreground decoration ignores inverse',
      () {
        final result = _resolveWebgl(
          inverse: true,
          decorations: const [
            TerminalWebglDecorationColors(foregroundRgba: 0xff0000ff),
          ],
        );
        expect(_webglRgb(result.foreground), 0xff0000);
        expect(_webglRgb(result.background), 0xffffff);
        expect(result.foreground & TerminalWebglAttributes.inverse, 0);
      },
    );

    test('WebGL Renderer decoration backgroundColor', () {
      expect(
        _webglRgb(
          _resolveWebgl(
            decorations: const [
              TerminalWebglDecorationColors(
                foregroundRgba: 0xff0000ff,
                backgroundRgba: 0x0000ffff,
              ),
            ],
          ).background,
        ),
        0x0000ff,
      );
    });

    test('WebGL Renderer decoration backgroundColor should ignore inverse', () {
      expect(
        _webglRgb(
          _resolveWebgl(
            inverse: true,
            decorations: const [
              TerminalWebglDecorationColors(
                foregroundRgba: 0xff0000ff,
                backgroundRgba: 0x0000ffff,
              ),
            ],
          ).background,
        ),
        0x0000ff,
      );
    });

    test(
      'WebGL Renderer only background decoration ignores inverse',
      () {
        final result = _resolveWebgl(
          inverse: true,
          decorations: const [
            TerminalWebglDecorationColors(backgroundRgba: 0x0000ffff),
          ],
        );
        expect(_webglRgb(result.background), 0x0000ff);
        expect(_webglRgb(result.foreground), 0x000000);
        expect(result.foreground & TerminalWebglAttributes.inverse, 0);
      },
    );
  });
}

TerminalResolvedCellColors _resolveDom({
  bool inverse = false,
  List<TerminalCellDecorationColors> decorations = const [],
}) {
  final line = TerminalBufferLine(1)
    ..setCell(
      0,
      '■',
      1,
      TerminalCellAttributes(inverse: inverse),
    );
  return const TerminalCellColorResolver(
    theme: _theme,
    focused: true,
    drawBoldTextInBrightColors: true,
    minimumContrastRatio: 1,
  ).resolve(
    line.getCell(0)!,
    selected: false,
    bottomDecorations: decorations,
  );
}

TerminalWebglCellColorResult _resolveWebgl({
  bool inverse = false,
  List<TerminalWebglDecorationColors> decorations = const [],
}) =>
    TerminalWebglCellColorResolver(
      colors: const TerminalWebglCellColorSet(
        ansi: <int>[],
        foregroundRgba: 0xffffffff,
        backgroundRgba: 0x000000ff,
        selectionBackgroundOpaqueRgba: 0xffffffff,
        selectionInactiveBackgroundOpaqueRgba: 0xffffffff,
      ),
      isFocused: true,
      fontSize: 15,
      devicePixelRatio: 1,
      isCellSelected: (_, _) => false,
      bottomDecorations: (_, _) => decorations,
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

int _webglRgb(int packed) => packed & TerminalWebglAttributes.rgbMask;

const _theme = TerminalTheme(
  foreground: _white,
  background: _black,
  cursor: _white,
  selection: Color(0x80ffffff),
  palette: <Color>[],
);
