import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/webgl_render_layer.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  test('render layer exposes every xterm lifecycle transition', () {
    final terminal = Terminal();
    final layer = _Layer();
    addTearDown(terminal.dispose);
    layer
      ..handleFocus(terminal)
      ..handleBlur(terminal)
      ..handleCursorMove(terminal)
      ..handleGridChanged(terminal, 1, 2)
      ..handleSelectionChanged(
        terminal,
        (1, 2),
        (3, 4),
        columnSelectMode: true,
      )
      ..resize(
        terminal,
        const TerminalRenderDimensions(
          width: 100,
          height: 50,
          cellWidth: 10,
          cellHeight: 20,
          devicePixelRatio: 1,
        ),
      )
      ..reset(terminal);
    expect(layer.calls, <String>[
      'focus',
      'blur',
      'cursor',
      'grid:1:2',
      'selection:(1, 2):(3, 4):true',
      'resize:100.0:50.0',
      'reset',
    ]);
    expect(layer.isDisposed, isFalse);
    layer.dispose();
    expect(layer.isDisposed, isTrue);
  });

  test('character joiner layer registers and deregisters callbacks', () {
    final layer = _Layer();
    final id = layer.registerCharacterJoiner((_) => <(int, int)>[(0, 2)]);
    expect(id, 1);
    expect(layer.deregisterCharacterJoiner(id), isTrue);
    expect(layer.deregisterCharacterJoiner(id), isFalse);
  });
}

final class _Layer
    implements TerminalWebglRenderLayer, TerminalWebglCharacterJoinerLayer {
  final List<String> calls = <String>[];
  final Map<int, List<(int, int)> Function(String)> _joiners =
      <int, List<(int, int)> Function(String)>{};
  int _nextJoinerId = 1;
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  void handleBlur(Terminal terminal) => calls.add('blur');

  @override
  void handleFocus(Terminal terminal) => calls.add('focus');

  @override
  void handleCursorMove(Terminal terminal) => calls.add('cursor');

  @override
  void handleGridChanged(Terminal terminal, int startRow, int endRow) =>
      calls.add('grid:$startRow:$endRow');

  @override
  void handleSelectionChanged(
    Terminal terminal,
    (int, int)? start,
    (int, int)? end, {
    bool columnSelectMode = false,
  }) => calls.add('selection:$start:$end:$columnSelectMode');

  @override
  void resize(Terminal terminal, TerminalRenderDimensions dimensions) =>
      calls.add('resize:${dimensions.width}:${dimensions.height}');

  @override
  void reset(Terminal terminal) => calls.add('reset');

  @override
  int registerCharacterJoiner(
    List<(int, int)> Function(String text) handler,
  ) {
    final id = _nextJoinerId++;
    _joiners[id] = handler;
    return id;
  }

  @override
  bool deregisterCharacterJoiner(int joinerId) =>
      _joiners.remove(joinerId) != null;

  @override
  void dispose() => _disposed = true;
}
