import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/webgl_cell_color_resolver.dart';
import 'package:termworld/src/addons/webgl_rectangle_renderer.dart';
import 'package:termworld/src/addons/webgl_utils.dart';

void main() {
  test(
    'viewport rectangle fills the normalized canvas with theme background',
    () {
      final renderer = _renderer();
      _expectFloats(renderer.backgrounds.attributes.take(8), <double>[
        0,
        0,
        1,
        1,
        0x11 / 255,
        0x22 / 255,
        0x33 / 255,
        1,
      ]);
    },
  );

  test('adjacent backgrounds coalesce and inverse resolves foreground', () {
    final renderer = _renderer();
    final model = TerminalWebglRenderModel()..resize(2, 2);
    _cell(model, 0, background: 0x3ff0000);
    _cell(model, 1, background: 0x3ff0000);
    _cell(model, 2, background: 0x1000002);
    _cell(
      model,
      3,
      foreground: TerminalWebglAttributes.inverse | 0x300ff00,
    );
    renderer.updateBackgrounds(model);
    expect(renderer.backgrounds.count, 4);
    _expectFloats(
      renderer.backgrounds.attributes.sublist(8, 16),
      <double>[0, 0, 1, 0.5, 1, 0, 0, 1],
    );
    _expectFloats(
      renderer.backgrounds.attributes.sublist(16, 24),
      <double>[0, 0.5, 0.5, 0.5, 2 / 255, 2 / 255, 2 / 255, 1],
    );
    _expectFloats(
      renderer.backgrounds.attributes.sublist(24, 32),
      <double>[0.5, 0.5, 0.5, 0.5, 0, 1, 0, 1],
    );
  });

  test('default backgrounds leave only the viewport-clear rectangle', () {
    final renderer = _renderer();
    final model = TerminalWebglRenderModel()..resize(2, 2);
    renderer.updateBackgrounds(model);
    expect(renderer.backgrounds.count, 1);
  });

  test('bar, underline and outline cursors match xterm geometry', () {
    final renderer = _renderer();
    final model = TerminalWebglRenderModel()
      ..resize(2, 2)
      ..cursor = const TerminalWebglCursorModel(
        x: 1,
        y: 0,
        width: 1,
        style: 'bar',
        cursorWidth: 2,
        devicePixelRatio: 2,
      );
    renderer.updateCursor(model);
    expect(renderer.cursor.count, 1);
    _expectFloats(
      renderer.cursor.attributes.take(4),
      <double>[0.5, 0, 0.2, 0.5],
    );

    model.cursor = const TerminalWebglCursorModel(
      x: 0,
      y: 1,
      width: 2,
      style: 'underline',
      cursorWidth: 1,
      devicePixelRatio: 2,
    );
    renderer.updateCursor(model);
    expect(renderer.cursor.count, 1);
    _expectFloats(
      renderer.cursor.attributes.take(4),
      <double>[0, 0.95, 1, 0.05],
    );

    model.cursor = const TerminalWebglCursorModel(
      x: 0,
      y: 0,
      width: 2,
      style: 'outline',
      cursorWidth: 1,
      devicePixelRatio: 2,
    );
    renderer.updateCursor(model);
    expect(renderer.cursor.count, 4);
    _expectFloats(renderer.cursor.attributes.sublist(24, 28), <double>[
      0.9,
      0,
      0.1,
      0.5,
    ]);

    model.cursor = const TerminalWebglCursorModel(
      x: 0,
      y: 0,
      width: 1,
      style: 'block',
      cursorWidth: 1,
      devicePixelRatio: 1,
    );
    renderer.updateCursor(model);
    expect(renderer.cursor.count, 0);
    model.cursor = null;
    renderer.updateCursor(model);
    expect(renderer.cursor.count, 0);
  });

  test('background storage expands to the terminal maximum', () {
    final renderer = TerminalWebglRectangleRendererModel(
      columns: 25,
      rows: 1,
      dimensions: const TerminalWebglDeviceDimensions(
        cellWidth: 1,
        cellHeight: 1,
        canvasWidth: 25,
        canvasHeight: 1,
      ),
      colors: _colors,
      cursorRgba: 0xffffffff,
    );
    final model = TerminalWebglRenderModel()..resize(25, 1);
    for (var x = 0; x < 25; x++) {
      _cell(
        model,
        x,
        background: TerminalWebglAttributes.colorModeRgb | x + 1,
      );
    }
    renderer.updateBackgrounds(model);
    expect(renderer.backgrounds.count, 26);
    expect(renderer.backgrounds.attributes.length, 26 * 8);
  });

  test('dimension and color changes refresh the viewport rectangle', () {
    final renderer = _renderer()
      ..dimensions = const TerminalWebglDeviceDimensions(
        cellWidth: 5,
        cellHeight: 10,
        canvasWidth: 20,
        canvasHeight: 40,
      )
      ..setColors(
        TerminalWebglCellColorSet(
          ansi: _colors.ansi,
          foregroundRgba: 0,
          backgroundRgba: 0xff000080,
          selectionBackgroundOpaqueRgba: 0,
          selectionInactiveBackgroundOpaqueRgba: 0,
        ),
        0x00ff00ff,
      )
      ..handleResize();
    _expectFloats(renderer.backgrounds.attributes.take(8), <double>[
      0,
      0,
      0.5,
      0.5,
      1,
      0,
      0,
      128 / 255,
    ]);
  });
}

TerminalWebglRectangleRendererModel _renderer() =>
    TerminalWebglRectangleRendererModel(
      columns: 2,
      rows: 2,
      dimensions: const TerminalWebglDeviceDimensions(
        cellWidth: 10,
        cellHeight: 20,
        canvasWidth: 20,
        canvasHeight: 40,
      ),
      colors: _colors,
      cursorRgba: 0xffffffff,
    );

final TerminalWebglCellColorSet _colors = TerminalWebglCellColorSet(
  ansi: <int>[
    for (final index in Iterable<int>.generate(256))
      index << 24 | index << 16 | index << 8 | 0xff,
  ],
  foregroundRgba: 0xaabbccff,
  backgroundRgba: 0x112233ff,
  selectionBackgroundOpaqueRgba: 0,
  selectionInactiveBackgroundOpaqueRgba: 0,
);

void _cell(
  TerminalWebglRenderModel model,
  int index, {
  int background = 0,
  int foreground = 0,
}) {
  final offset = index * terminalWebglIndicesPerCell;
  model.cells[offset + terminalWebglBackgroundOffset] = background;
  model.cells[offset + terminalWebglForegroundOffset] = foreground;
}

void _expectFloats(Iterable<double> actual, List<double> expected) {
  final values = actual.toList();
  expect(values, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    expect(values[index], closeTo(expected[index], 0.000001));
  }
}
