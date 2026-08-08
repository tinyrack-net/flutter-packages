import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/webgl_glyph_renderer.dart';
import 'package:termworld/src/addons/webgl_rectangle_renderer.dart';

void main() {
  test('clear allocates double buffers and normalized cell positions', () {
    final renderer = _renderer();
    expect(renderer.count, 4 * terminalWebglGlyphFloatCount);
    expect(renderer.attributes[9], 0);
    expect(renderer.attributes[10], 0);
    expect(renderer.attributes[20], 0.5);
    expect(renderer.attributes[21], 0);
    expect(renderer.attributes[31], 0);
    expect(renderer.attributes[32], 0.5);
    expect(renderer.attributes[42], 0.5);
    expect(renderer.attributes[43], 0.5);
    renderer.attributes[0] = 9;
    renderer.clear();
    expect(renderer.attributes[0], 0);
  });

  test('beginFrame rebuilds without an atlas and on layout changes', () {
    final renderer = _renderer();
    expect(renderer.beginFrame(), isTrue);
    final atlas = _Atlas();
    renderer.setAtlas(atlas);
    expect(renderer.beginFrame(), isTrue);
    expect(renderer.beginFrame(), isFalse);
    atlas.pageLayoutVersion = 2;
    expect(renderer.beginFrame(), isTrue);
  });

  test('single and combined glyphs use their atlas paths', () {
    final atlas = _Atlas();
    final renderer = _renderer()
      ..setAtlas(atlas)
      ..updateCell(
        x: 0,
        y: 0,
        code: 65,
        background: 1,
        foreground: 2,
        extended: 3,
        characters: 'A',
        width: 1,
        lastBackground: 1,
      );
    expect(atlas.singleCalls, 1);
    _expectFloats(renderer.attributes.take(9), <double>[
      -1,
      2,
      0.4,
      0.25,
      0,
      0.1,
      0.2,
      0.3,
      0.4,
    ]);
    renderer.updateCell(
      x: 1,
      y: 0,
      code: 65,
      background: 1,
      foreground: 2,
      extended: 3,
      characters: 'AB',
      width: 1,
      lastBackground: 1,
    );
    expect(atlas.combinedCalls, 1);
  });

  test('background transition clips glyphs extending into the left cell', () {
    final atlas = _Atlas(
      glyph: const TerminalWebglRasterizedGlyph(
        offset: TerminalWebglGlyphVector(4, 1),
        size: TerminalWebglGlyphVector(8, 5),
        texturePage: 0,
        texturePositionClipSpace: TerminalWebglGlyphVector(0.1, 0.2),
        sizeClipSpace: TerminalWebglGlyphVector(0.3, 0.4),
      ),
    );
    final renderer = _renderer()
      ..setAtlas(atlas)
      ..updateCell(
        x: 0,
        y: 0,
        code: 65,
        background: 2,
        foreground: 0,
        extended: 0,
        characters: 'A',
        width: 1,
        lastBackground: 1,
      );
    _expectFloats(renderer.attributes.take(9), <double>[
      1,
      2,
      0.25,
      0.25,
      0,
      0.25,
      0.2,
      0.15,
      0.4,
    ]);
  });

  test('null cells clear glyph attributes but retain cell position', () {
    final renderer = _renderer()..setAtlas(_Atlas());
    renderer.attributes.fillRange(0, 11, 7);
    renderer.updateCell(
      x: 0,
      y: 0,
      code: null,
      background: 0,
      foreground: 0,
      extended: 0,
      characters: '',
      width: 1,
      lastBackground: 0,
    );
    expect(renderer.attributes.take(9).every((value) => value == 0), isTrue);
    expect(renderer.attributes[9], 7);
    expect(renderer.attributes[10], 7);
    renderer.updateCell(
      x: 0,
      y: 0,
      code: 0,
      background: 0,
      foreground: 0,
      extended: 0,
      characters: '',
      width: 1,
      lastBackground: 0,
    );
  });

  test('overlapping non-emoji glyphs rescale when enabled', () {
    final renderer = _renderer(rescale: true)
      ..setAtlas(
        _Atlas(
          glyph: const TerminalWebglRasterizedGlyph(
            offset: TerminalWebglGlyphVector(0, 0),
            size: TerminalWebglGlyphVector(20, 5),
            texturePage: 0,
            texturePositionClipSpace: TerminalWebglGlyphVector(0, 0),
            sizeClipSpace: TerminalWebglGlyphVector(1, 1),
          ),
        ),
      )
      ..updateCell(
        x: 0,
        y: 0,
        code: 0x400,
        background: 0,
        foreground: 0,
        extended: 0,
        characters: '\u0400',
        width: 1,
        lastBackground: 0,
      );
    expect(renderer.attributes[2], closeTo(0.45, 0.000001));
  });

  test('upload packs line prefixes and alternates GPU buffers', () {
    final renderer = _renderer();
    for (var index = 0; index < renderer.attributes.length; index++) {
      renderer.attributes[index] = index.toDouble();
    }
    final first = renderer.buildUploadBuffer(Uint32List.fromList(<int>[1, 2]));
    expect(renderer.activeBuffer, 1);
    expect(first, hasLength(3 * terminalWebglGlyphFloatCount));
    expect(first[0], 0);
    expect(first[11], 22);
    final second = renderer.buildUploadBuffer(Uint32List.fromList(<int>[2, 0]));
    expect(renderer.activeBuffer, 0);
    expect(second, hasLength(2 * terminalWebglGlyphFloatCount));
  });

  test('resize reallocates cell storage and positions', () {
    final renderer = _renderer()
      ..columns = 1
      ..rows = 1
      ..handleResize(_dimensions);
    expect(renderer.count, terminalWebglGlyphFloatCount);
    expect(renderer.attributes[9], 0);
    expect(renderer.attributes[10], 0);
  });
}

TerminalWebglGlyphRendererModel _renderer({bool rescale = false}) =>
    TerminalWebglGlyphRendererModel(
      columns: 2,
      rows: 2,
      dimensions: _dimensions,
      rescaleOverlappingGlyphs: rescale,
    );

const TerminalWebglGlyphDimensions _dimensions = TerminalWebglGlyphDimensions(
  device: TerminalWebglDeviceDimensions(
    cellWidth: 10,
    cellHeight: 20,
    canvasWidth: 20,
    canvasHeight: 20,
  ),
  characterWidth: 8,
  characterLeft: 2,
  characterTop: 3,
);

final class _Atlas implements TerminalWebglGlyphAtlas {
  _Atlas({
    this.glyph = const TerminalWebglRasterizedGlyph(
      offset: TerminalWebglGlyphVector(3, 1),
      size: TerminalWebglGlyphVector(8, 5),
      texturePage: 0,
      texturePositionClipSpace: TerminalWebglGlyphVector(0.1, 0.2),
      sizeClipSpace: TerminalWebglGlyphVector(0.3, 0.4),
    ),
  });

  final TerminalWebglRasterizedGlyph glyph;
  int singleCalls = 0;
  int combinedCalls = 0;

  @override
  int pageLayoutVersion = 1;

  @override
  List<TerminalWebglGlyphAtlasPage> get pages =>
      const <TerminalWebglGlyphAtlasPage>[
        TerminalWebglGlyphAtlasPage(width: 20, height: 20, version: 1),
      ];

  @override
  TerminalWebglRasterizedGlyph getGlyph(
    int code,
    int background,
    int foreground,
    int extended,
  ) {
    singleCalls++;
    return glyph;
  }

  @override
  TerminalWebglRasterizedGlyph getCombinedGlyph(
    String characters,
    int background,
    int foreground,
    int extended,
  ) {
    combinedCalls++;
    return glyph;
  }
}

void _expectFloats(Iterable<double> actual, List<double> expected) {
  final values = actual.toList();
  expect(values, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    expect(values[index], closeTo(expected[index], 0.000001));
  }
}
