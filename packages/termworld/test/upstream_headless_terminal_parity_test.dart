import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  test('xterm HeadlessTerminal 00', () {
    final terminal = _terminal();
    expect(terminal.cols, 80);
    expect(terminal.rows, 24);
  });

  test('xterm HeadlessTerminal 01', () async {
    final terminal = _terminal();
    await terminal.writeAndWait('foo');
    await terminal.writeAndWait('bar');
    await terminal.writeAndWait('文');
    _lineEquals(terminal, 0, 'foobar文');
  });

  test('xterm HeadlessTerminal 02', () async {
    final terminal = _terminal();
    final done = Completer<void>();
    String? result;
    terminal
      ..write('foo', onParsed: () => result = 'a')
      ..write('bar', onParsed: () => result = '${result}b')
      ..write(
        '文',
        onParsed: () {
          result = '${result}c';
          done.complete();
        },
      );
    await done.future;
    _lineEquals(terminal, 0, 'foobar文');
    expect(result, 'abc');
  });

  test('xterm HeadlessTerminal 03', () async {
    final terminal = _terminal();
    await terminal.writeAndWait(Uint8List.fromList(<int>[102, 111, 111]));
    await terminal.writeAndWait(Uint8List.fromList(<int>[98, 97, 114]));
    await terminal.writeAndWait(Uint8List.fromList(<int>[230, 150, 135]));
    _lineEquals(terminal, 0, 'foobar文');
  });

  test('xterm HeadlessTerminal 04', () async {
    final terminal = _terminal();
    final done = Completer<void>();
    String? result;
    terminal
      ..write(
        Uint8List.fromList(<int>[102, 111, 111]),
        onParsed: () => result = 'A',
      )
      ..write(
        Uint8List.fromList(<int>[98, 97, 114]),
        onParsed: () => result = '${result}B',
      )
      ..write(
        Uint8List.fromList(<int>[230, 150, 135]),
        onParsed: () {
          result = '${result}C';
          done.complete();
        },
      );
    await done.future;
    _lineEquals(terminal, 0, 'foobar文');
    expect(result, 'ABC');
  });

  test('xterm HeadlessTerminal 05', () async {
    final terminal = _terminal();
    await _writelnAndWait(terminal, 'foo');
    await _writelnAndWait(terminal, 'bar');
    await _writelnAndWait(terminal, '文');
    _lineEquals(terminal, 0, 'foo');
    _lineEquals(terminal, 1, 'bar');
    _lineEquals(terminal, 2, '文');
  });

  test('xterm HeadlessTerminal 06', () async {
    final terminal = _terminal();
    final done = Completer<void>();
    String? result;
    terminal
      ..writeln('foo', onParsed: () => result = '1')
      ..writeln('bar', onParsed: () => result = '${result}2')
      ..writeln(
        '文',
        onParsed: () {
          result = '${result}3';
          done.complete();
        },
      );
    await done.future;
    _lineEquals(terminal, 0, 'foo');
    _lineEquals(terminal, 1, 'bar');
    _lineEquals(terminal, 2, '文');
    expect(result, '123');
  });

  test('xterm HeadlessTerminal 07', () async {
    final terminal = _terminal();
    await _writelnAndWait(
      terminal,
      Uint8List.fromList(<int>[102, 111, 111]),
    );
    await _writelnAndWait(
      terminal,
      Uint8List.fromList(<int>[98, 97, 114]),
    );
    await _writelnAndWait(
      terminal,
      Uint8List.fromList(<int>[230, 150, 135]),
    );
    _lineEquals(terminal, 0, 'foo');
    _lineEquals(terminal, 1, 'bar');
    _lineEquals(terminal, 2, '文');
  });

  test('xterm HeadlessTerminal 08', () async {
    final terminal = _terminal(rows: 5);
    for (var index = 0; index < 10; index++) {
      await terminal.writeAndWait('\n\rtest$index');
    }
    terminal.clear();
    expect(terminal.buffer.active.length, 5);
    _lineEquals(terminal, 0, 'test9');
    for (var index = 1; index < 5; index++) {
      _lineEquals(terminal, index, '');
    }
  });

  test('xterm HeadlessTerminal 09', () async {
    final terminal = _terminal(rows: 5);
    for (var index = 0; index < 10; index++) {
      await terminal.writeAndWait('\n\rtest$index');
    }
    final markers = <TerminalMarker>[
      terminal.registerMarker(cursorYOffset: 1)!,
      terminal.registerMarker(cursorYOffset: 2)!,
      terminal.registerMarker(cursorYOffset: 3)!,
      terminal.registerMarker(cursorYOffset: 4)!,
    ];
    var disposeCount = 0;
    for (final marker in markers) {
      marker.onDispose.listen((_) => disposeCount++);
    }
    terminal.clear();
    expect(disposeCount, markers.length);
    for (final marker in markers) {
      expect(marker.isDisposed, isTrue);
    }
    expect(terminal.markers, isEmpty);
  });

  test('xterm HeadlessTerminal 10', () {
    final terminal = _terminal();
    expect(terminal.options.lineHeight, 1);
    expect(terminal.options.cursorWidth, 1);
  });

  test('xterm HeadlessTerminal 11', () {
    final terminal = _terminal();
    terminal.options
      ..scrollback = 1
      ..fontSize = 12
      ..fontFamily = 'Arial';
    expect(terminal.options.scrollback, 1);
    expect(terminal.options.fontSize, 12);
    expect(terminal.options.fontFamily, 'Arial');
  });

  test('xterm HeadlessTerminal 12', () {
    final terminal = Terminal(
      options: TerminalOptions(cols: 5, allowProposedApi: true),
    );
    addTearDown(terminal.dispose);
    final addon = _TrackingAddon();
    terminal.loadAddon(addon);
    expect(addon.activatedColumns, 5);
  });

  test('xterm HeadlessTerminal 13', () {
    final terminal = _terminal();
    final addon = _TrackingAddon();
    terminal.loadAddon(addon);
    expect(addon.isDisposed, isFalse);
    addon.dispose();
    expect(addon.isDisposed, isTrue);
  });

  test('xterm HeadlessTerminal 14', () {
    final terminal = _terminal();
    final addon = _TrackingAddon();
    terminal.loadAddon(addon);
    expect(addon.isDisposed, isFalse);
    terminal.dispose();
    expect(addon.isDisposed, isTrue);
  });

  test('xterm HeadlessTerminal 15', () async {
    final terminal = _terminal();
    var callCount = 0;
    terminal.onCursorMove.listen((_) => callCount++);
    await terminal.writeAndWait('foo');
    expect(callCount, 1);
    await terminal.writeAndWait('bar');
    expect(callCount, 2);
  });

  test('xterm HeadlessTerminal 16', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.onData.listen(calls.add);
    await terminal.writeAndWait('\u001b[5n');
    expect(calls, <String>['\u001b[0n']);
  });

  test('xterm HeadlessTerminal 17', () async {
    final terminal = _terminal();
    var callCount = 0;
    terminal.onLineFeed.listen((_) => callCount++);
    await _writelnAndWait(terminal, 'foo');
    expect(callCount, 1);
    await _writelnAndWait(terminal, 'bar');
    expect(callCount, 2);
  });

  test('xterm HeadlessTerminal 18', () async {
    final terminal = _terminal();
    final calls = <List<int>>[];
    terminal.onRender.listen(
      (event) => calls.add(<int>[event.start, event.end]),
    );
    await terminal.writeAndWait('foo');
    expect(calls, <List<int>>[
      <int>[0, 0],
    ]);
    await terminal.writeAndWait('\n\nbar');
    expect(calls, <List<int>>[
      <int>[0, 0],
      <int>[0, 2],
    ]);
  });

  test('xterm HeadlessTerminal 19', () async {
    final terminal = _terminal(rows: 5);
    final calls = <int>[];
    terminal.onScroll.listen(calls.add);
    for (var index = 0; index < 4; index++) {
      await _writelnAndWait(terminal, 'foo');
    }
    expect(calls, isEmpty);
    await _writelnAndWait(terminal, 'bar');
    expect(calls, <int>[1]);
    await _writelnAndWait(terminal, 'baz');
    expect(calls, <int>[1, 2]);
  });

  test('xterm HeadlessTerminal 20', () {
    final terminal = _terminal();
    final calls = <List<int>>[];
    terminal.onResize.listen(
      (event) => calls.add(<int>[event.cols, event.rows]),
    );
    expect(calls, isEmpty);
    terminal.resize(10, 5);
    expect(calls, <List<int>>[
      <int>[10, 5],
    ]);
    terminal.resize(20, 15);
    expect(calls, <List<int>>[
      <int>[10, 5],
      <int>[20, 15],
    ]);
  });

  test('xterm HeadlessTerminal 21', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.onTitleChange.listen(calls.add);
    expect(calls, isEmpty);
    await terminal.writeAndWait('\u001b]2;foo\u009c');
    expect(calls, <String>['foo']);
  });

  test('xterm HeadlessTerminal 22', () async {
    final terminal = _terminal();
    final calls = <bool>[];
    terminal.onBell.listen((_) => calls.add(true));
    expect(calls, isEmpty);
    await terminal.writeAndWait('\u0007');
    expect(calls, <bool>[true]);
  });
}

Terminal _terminal({int rows = 24}) {
  final terminal = Terminal(
    options: TerminalOptions(allowProposedApi: true, rows: rows),
  );
  addTearDown(terminal.dispose);
  return terminal;
}

Future<void> _writelnAndWait(Terminal terminal, Object data) {
  final completer = Completer<void>();
  terminal.writeln(data, onParsed: completer.complete);
  return completer.future;
}

void _lineEquals(Terminal terminal, int line, String expected) {
  expect(
    terminal.buffer.active.getLine(line)!.translateToString(trimRight: true),
    expected,
  );
}

final class _TrackingAddon extends TerminalAddon {
  int? activatedColumns;

  @override
  void activate(Terminal terminal) {
    activatedColumns = terminal.cols;
  }
}
