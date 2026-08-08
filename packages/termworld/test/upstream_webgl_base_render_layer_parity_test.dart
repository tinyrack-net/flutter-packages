import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/webgl_base_render_layer.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  test('opaque layer initializes, resizes, clears and refreshes its atlas', () {
    final terminal = Terminal();
    final canvas = _Canvas();
    final replacements = <(_Canvas, _Canvas)>[];
    var refreshes = 0;
    final layer = _Layer(
      terminal: terminal,
      canvas: canvas,
      alpha: false,
      replaceCanvas: (oldCanvas, newCanvas) {
        replacements.add((oldCanvas as _Canvas, newCanvas as _Canvas));
      },
      refreshAtlas: () => refreshes++,
    );
    addTearDown(terminal.dispose);
    expect(canvas.context.commands, <String>[
      'context:false',
      'fillStyle:#112233',
      'fill:0.0:0.0:0.0:0.0',
    ]);
    layer.resize(
      terminal,
      const TerminalRenderDimensions(
        width: 100,
        height: 40,
        cellWidth: 10,
        cellHeight: 20,
        devicePixelRatio: 2,
      ),
    );
    expect(canvas.width, 200);
    expect(canvas.height, 80);
    expect(canvas.cssWidth, 100);
    expect(canvas.cssHeight, 40);
    expect(refreshes, 1);
    layer.clearCells(1, 1, 2, 1);
    expect(canvas.context.commands, contains('fill:20.0:40.0:40.0:40.0'));
    expect(replacements, isEmpty);
  });

  test(
    'transparent layer uses clear operations and clones on alpha change',
    () {
      final terminal = Terminal();
      final canvas = _Canvas();
      var refreshes = 0;
      final replacements =
          <(TerminalWebglLayerCanvas, TerminalWebglLayerCanvas)>[];
      final layer = _Layer(
        terminal: terminal,
        canvas: canvas,
        alpha: true,
        replaceCanvas: (oldCanvas, newCanvas) =>
            replacements.add((oldCanvas, newCanvas)),
        refreshAtlas: () => refreshes++,
      );
      addTearDown(terminal.dispose);
      layer
        ..resize(
          terminal,
          const TerminalRenderDimensions(
            width: 20,
            height: 20,
            cellWidth: 10,
            cellHeight: 20,
            devicePixelRatio: 1,
          ),
        )
        ..clearAll()
        ..clearCells(0, 0, 1, 1)
        ..setTransparency(value: false);
      expect(canvas.context.commands, contains('clear:0.0:0.0:20.0:20.0'));
      expect(replacements, hasLength(1));
      expect(layer.alpha, isFalse);
      expect(layer.gridChanges, <(int, int)>[(0, terminal.rows - 1)]);
      expect(refreshes, 2);
      layer.setTransparency(value: false);
      expect(replacements, hasLength(1));
    },
  );

  test('text, bottom-line, theme and font helpers match xterm geometry', () {
    final terminal = Terminal(
      options: TerminalOptions(
        fontFamily: 'Fira Code',
        fontWeight: 400,
        fontWeightBold: 700,
      ),
    );
    final canvas = _Canvas();
    var refreshes = 0;
    final layer = _Layer(
      terminal: terminal,
      canvas: canvas,
      alpha: true,
      replaceCanvas: (_, _) {},
      refreshAtlas: () => refreshes++,
    );
    addTearDown(terminal.dispose);
    layer
      ..resize(
        terminal,
        const TerminalRenderDimensions(
          width: 20,
          height: 20,
          cellWidth: 10,
          cellHeight: 20,
          devicePixelRatio: 2,
        ),
      )
      ..fillBottomLineAtCells(1, 0, width: 2)
      ..fillCharacterTrueColor(
        characters: 'A',
        width: 1,
        x: 1,
        y: 0,
      )
      ..handleThemeChanged('#abcdef');
    expect(layer.font(isBold: false, isItalic: false), ' 400 30.0px Fira Code');
    expect(
      layer.font(isBold: true, isItalic: true),
      'italic 700 30.0px Fira Code',
    );
    expect(canvas.context.commands, contains('fill:20.0:37.0:40.0:2.0'));
    expect(canvas.context.commands, contains('rect:20.0:0.0:20.0:40.0'));
    expect(canvas.context.commands, contains('text:A:20.0:40.0'));
    expect(layer.resets, 1);
    expect(refreshes, 2);
    layer.dispose();
    expect(canvas.removed, isTrue);
  });
}

final class _Layer extends TerminalWebglBaseRenderLayer {
  _Layer({
    required super.terminal,
    required _Canvas super.canvas,
    required super.alpha,
    required super.replaceCanvas,
    required super.refreshAtlas,
  }) : super(devicePixelRatio: 2, backgroundCss: '#112233');

  final List<(int, int)> gridChanges = <(int, int)>[];
  int resets = 0;

  @override
  void handleGridChanged(Terminal terminal, int startRow, int endRow) {
    gridChanges.add((startRow, endRow));
  }

  @override
  void reset(Terminal terminal) => resets++;
}

final class _Canvas implements TerminalWebglLayerCanvas {
  _Canvas();

  final _Context context = _Context();

  @override
  int width = 0;

  @override
  int height = 0;

  @override
  double cssWidth = 0;

  @override
  double cssHeight = 0;

  bool removed = false;

  @override
  TerminalWebglLayerCanvasContext createContext({required bool alpha}) {
    context.commands.add('context:$alpha');
    return context;
  }

  @override
  TerminalWebglLayerCanvas clone() => _Canvas()
    ..width = width
    ..height = height
    ..cssWidth = cssWidth
    ..cssHeight = cssHeight;

  @override
  void remove() => removed = true;
}

final class _Context implements TerminalWebglLayerCanvasContext {
  final List<String> commands = <String>[];
  String _fillStyle = '';
  String _font = '';
  String _textBaseline = '';

  @override
  String get fillStyle => _fillStyle;

  @override
  set fillStyle(String value) {
    _fillStyle = value;
    commands.add('fillStyle:$value');
  }

  @override
  String get font => _font;

  @override
  set font(String value) {
    _font = value;
    commands.add('font:$value');
  }

  @override
  String get textBaseline => _textBaseline;

  @override
  set textBaseline(String value) {
    _textBaseline = value;
    commands.add('baseline:$value');
  }

  @override
  void beginPath() => commands.add('begin');

  @override
  void clearRect(double x, double y, double width, double height) =>
      commands.add('clear:$x:$y:$width:$height');

  @override
  void clip() => commands.add('clip');

  @override
  void fillRect(double x, double y, double width, double height) =>
      commands.add('fill:$x:$y:$width:$height');

  @override
  void fillText(String text, double x, double y) =>
      commands.add('text:$text:$x:$y');

  @override
  void rect(double x, double y, double width, double height) =>
      commands.add('rect:$x:$y:$width:$height');
}
