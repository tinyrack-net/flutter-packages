import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  test('xterm Buffer 00', () {
    final buffer = TerminalBufferNamespace(
      columns: 80,
      rows: 24,
      scrollback: 1000,
    );
    addTearDown(buffer.dispose);
    expect(buffer.normal.maximumLength, 1024);
  });

  test('xterm Buffer 01', () {
    final buffer = TerminalBufferNamespace(
      columns: 80,
      rows: 24,
      scrollback: 1000,
    );
    addTearDown(buffer.dispose);
    expect(buffer.normal.scrollBottom, 23);
  });

  test('xterm Buffer 02', () {
    final buffer = TerminalBufferNamespace(
      columns: 80,
      rows: 24,
      scrollback: 1000,
    );
    addTearDown(buffer.dispose);
    expect(buffer.normal.length, 24);
    expect(buffer.normal.getLine(0), isNotNull);
    expect(buffer.normal.getLine(23), isNotNull);
  });

  test('xterm Buffer 03', () {
    final buffer = _rangeBuffer();
    expect(buffer.getWrappedRangeForLine(0), (first: 0, last: 0));
  });

  test('xterm Buffer 04', () {
    final buffer = _rangeBuffer();
    expect(buffer.getWrappedRangeForLine(3), (first: 3, last: 3));
  });

  test('xterm Buffer 05', () {
    final buffer = _rangeBuffer();
    expect(buffer.getWrappedRangeForLine(9), (first: 9, last: 9));
  });

  test('xterm Buffer 06', () {
    final buffer = _rangeBuffer()..getLine(1)!.isWrapped = true;
    expect(buffer.getWrappedRangeForLine(0), (first: 0, last: 1));
  });

  test('xterm Buffer 07', () {
    final buffer = _rangeBuffer()..getLine(3)!.isWrapped = true;
    expect(buffer.getWrappedRangeForLine(3), (first: 2, last: 3));
  });

  test('xterm Buffer 08', () {
    final buffer = _rangeBuffer()..getLine(4)!.isWrapped = true;
    expect(buffer.getWrappedRangeForLine(3), (first: 3, last: 4));
  });

  test('xterm Buffer 09', () {
    final buffer = _rangeBuffer()
      ..getLine(3)!.isWrapped = true
      ..getLine(4)!.isWrapped = true;
    expect(buffer.getWrappedRangeForLine(3), (first: 2, last: 4));
  });

  test('xterm Buffer 10', () {
    final buffer = _rangeBuffer()..getLine(9)!.isWrapped = true;
    expect(buffer.getWrappedRangeForLine(9), (first: 8, last: 9));
  });

  test('xterm Buffer 11', () {
    final buffer = _rangeBuffer();
    for (var row = 1; row <= 3; row++) {
      buffer.getLine(row)!.isWrapped = true;
    }
    expect(buffer.getWrappedRangeForLine(3), (first: 0, last: 3));
  });

  test('xterm Buffer 12', () {
    final buffer = _rangeBuffer();
    for (var row = 7; row <= 9; row++) {
      buffer.getLine(row)!.isWrapped = true;
    }
    expect(buffer.getWrappedRangeForLine(7), (first: 6, last: 9));
  });

  test('xterm Buffer 13', () {
    final buffer = _bufferNamespace()..resize(40, 24, TerminalCellAttributes());
    expect(buffer.normal.length, 24);
    for (var row = 0; row < 24; row++) {
      expect(buffer.normal.getLine(row)!.length, 40);
    }
  });

  test('xterm Buffer 14', () {
    final buffer = _bufferNamespace()..resize(90, 24, TerminalCellAttributes());
    expect(buffer.normal.length, 24);
    for (var row = 0; row < 24; row++) {
      expect(buffer.normal.getLine(row)!.length, 90);
    }
  });

  test('xterm Buffer 15', () {
    final buffers = _bufferNamespace();
    expect(buffers.alternate.maximumLength, 24);
    buffers.resize(80, 48, TerminalCellAttributes());
    expect(buffers.alternate.maximumLength, 48);
    buffers.resize(80, 12, TerminalCellAttributes());
    expect(buffers.alternate.maximumLength, 12);
  });

  test('xterm Buffer 16', () {
    final buffers = _bufferNamespace(scrollback: 0);
    final marker = buffers.normal.addMarker(23);
    buffers.normal.scroll(TerminalCellAttributes());
    expect(marker.line, 22);
  });

  test('xterm Buffer 17', () {
    final buffers = _bufferNamespace(scrollback: 0);
    final marker = buffers.normal.addMarker(0);
    expect((marker.isDisposed, buffers.normal.markers.length), (false, 1));
    buffers.normal.scroll(TerminalCellAttributes());
    expect((marker.isDisposed, buffers.normal.markers.length), (true, 0));
  });

  test('xterm Buffer 18', () {
    final buffers = _bufferNamespace(scrollback: 0);
    final events = <String>[];
    final marker = buffers.normal.addMarker(0);
    marker.onDispose.listen((_) => events.add('disposed'));
    buffers.normal.scroll(TerminalCellAttributes());
    expect(events, <String>['disposed']);
  });

  test('xterm Buffer 19', () {
    final buffer = _translationBuffer(4)
      ..getLine(0)!.setCell(0, 'a', 1, TerminalCellAttributes())
      ..getLine(0)!.setCell(1, 'b', 1, TerminalCellAttributes())
      ..getLine(0)!.setCell(2, 'c', 1, TerminalCellAttributes())
      ..getLine(0)!.setCell(3, 'd', 1, TerminalCellAttributes());
    expect(
      buffer.translateBufferLineToString(0, trimRight: true, endColumn: 2),
      'ab',
    );
  });

  test('xterm Buffer 20', () {
    final buffer = _translationBuffer(3);
    final line = buffer.getLine(0)!
      ..setCell(0, '語', 2, TerminalCellAttributes())
      ..setCell(1, '', 0, TerminalCellAttributes())
      ..setCell(2, 'a', 1, TerminalCellAttributes());
    expect(line.getCell(0)!.width, 2);
    expect(
      buffer.translateBufferLineToString(0, trimRight: true, endColumn: 1),
      '語',
    );
  });

  test('xterm Buffer 21', () {
    final buffer = _wideTranslationBuffer();
    expect(
      buffer.translateBufferLineToString(0, trimRight: true, endColumn: 1),
      '語',
    );
    expect(
      buffer.translateBufferLineToString(0, trimRight: true, endColumn: 2),
      '語',
    );
    expect(
      buffer.translateBufferLineToString(0, trimRight: true, endColumn: 3),
      '語a',
    );
  });

  test('xterm Buffer 22', () {
    final buffer = _translationBuffer(2);
    buffer.getLine(0)!
      ..setCell(0, '😁', 1, TerminalCellAttributes())
      ..setCell(1, 'a', 1, TerminalCellAttributes());
    expect(
      buffer.translateBufferLineToString(0, trimRight: true, endColumn: 1),
      '😁',
    );
    expect(
      buffer.translateBufferLineToString(0, trimRight: true, endColumn: 2),
      '😁a',
    );
  });

  test('xterm Buffer 23', () {
    final firstBuffer = _translationBuffer(2);
    firstBuffer.getLine(0)!
      ..setCell(0, '😁', 2, TerminalCellAttributes())
      ..setCell(1, '', 0, TerminalCellAttributes());
    expect(
      firstBuffer.translateBufferLineToString(
        0,
        trimRight: true,
        endColumn: 1,
      ),
      '😁',
    );
    expect(
      firstBuffer.translateBufferLineToString(
        0,
        trimRight: true,
        endColumn: 2,
      ),
      '😁',
    );
    final secondBuffer = _translationBuffer(3);
    secondBuffer.getLine(0)!
      ..setCell(0, '😁', 2, TerminalCellAttributes())
      ..setCell(1, '', 0, TerminalCellAttributes())
      ..setCell(2, 'a', 1, TerminalCellAttributes());
    expect(
      secondBuffer.translateBufferLineToString(
        0,
        trimRight: true,
        endColumn: 3,
      ),
      '😁a',
    );
  });

  test('BufferLine cell mutation, copy and selective erase', () {
    final attributes = TerminalCellAttributes(
      foreground: const TerminalCellColor.palette(3),
      background: const TerminalCellColor.rgb(4, 5, 6),
      underlineColor: const TerminalCellColor.palette(7),
      bold: true,
      dim: true,
      italic: true,
      underline: TerminalUnderlineStyle.curly,
      blink: true,
      inverse: true,
      invisible: true,
      strikethrough: true,
      overline: true,
      protected: true,
    );
    final line = TerminalBufferLine(5);
    expect(line.getCell(-1), isNull);
    expect(line.getCell(5), isNull);
    line
      ..setCell(-1, 'x', 1, attributes)
      ..setCell(1, '界', 2, attributes)
      ..appendCombining(2, '\u0301')
      ..appendCombining(-1, 'x')
      ..joinCell(-1, 'x', 1);

    final wide = line.getCell(1)!;
    expect(wide.chars, '界́');
    expect(wide.code, 0x301);
    expect(wide.width, 2);
    expect(line.getCell(2)!.width, 0);
    expect(line.getCell(2)!.chars, '');
    expect(wide.foreground, 3);
    expect(wide.background, 0x040506);
    expect(wide.backgroundMode, TerminalColorMode.rgb);
    expect(wide.underlineColor, const TerminalCellColor.palette(7));
    expect(wide.isUnderline, isTrue);
    expect(wide.isProtected, isTrue);
    final destination = TerminalBufferLine(1).getCell(0)!;
    expect(line.getCell(1, destination), same(destination));
    expect(destination.chars, '界́');

    final copy = line.copy();
    expect(copy.isWrapped, line.isWrapped);
    line.erase(0, 5, TerminalCellAttributes(), respectProtection: true);
    expect(line.getCell(1)!.chars, '界́');
    line.erase(0, 5, TerminalCellAttributes());
    expect(line.translateToString(trimRight: true), '');
    expect(copy.getCell(1)!.chars, '界́');
  });

  test('BufferLine insert, delete, resize and joining clamp ranges', () {
    final line = TerminalBufferLine(4);
    final erase = TerminalCellAttributes();
    line
      ..setCell(0, 'a', 1, erase)
      ..setCell(1, 'b', 1, erase)
      ..setCell(2, 'c', 1, erase)
      ..setCell(3, 'd', 1, erase)
      ..insertCells(1, 2, erase);
    expect(line.translateToString(), 'a  b');
    line.deleteCells(1, 2, erase);
    expect(line.translateToString(), 'ab  ');
    line
      ..insertCells(-1, 1, erase)
      ..insertCells(0, 0, erase)
      ..deleteCells(-1, 1, erase)
      ..deleteCells(0, 0, erase)
      ..joinCell(0, 'x', 2);
    expect(line.getCell(0)!.chars, 'ax');
    expect(line.getCell(1)!.width, 0);
    line.resize(2, erase);
    expect(line.length, 2);
    line.resize(6, erase);
    expect(line.length, 6);
    expect(
      line.translateToString(startColumn: -10, endColumn: 99).length,
      6,
    );
  });

  test(
    'BufferSet switches, scrolls and resizes normal and alternate buffers',
    () {
      final buffers = TerminalBufferNamespace(
        columns: 4,
        rows: 2,
        scrollback: 2,
      );
      final erase = TerminalCellAttributes();
      final changes = <TerminalBufferType>[];
      buffers.onBufferChange.listen((buffer) => changes.add(buffer.type));
      expect(buffers.normal.getLine(-1), isNull);
      expect(buffers.normal.getLine(2), isNull);
      expect(buffers.normal.getNullCell().isAttributeDefault, isTrue);

      buffers.normal
        ..scroll(erase)
        ..scroll(erase)
        ..scroll(erase);
      expect(buffers.normal.length, 4);
      expect(buffers.normal.baseY, 2);
      // BufferService, not a raw Buffer mutation, owns ydisp synchronization.
      expect(buffers.normal.viewportY, 0);
      buffers.normal.clearScrollback();
      expect(buffers.normal.length, 2);

      buffers
        ..useAlternate()
        ..useAlternate();
      expect(buffers.active.type, TerminalBufferType.alternate);
      buffers.alternate
        ..reverseScroll(erase)
        ..insertLines(0, 8, erase)
        ..deleteLines(0, 8, erase)
        ..scroll(erase, bottom: 1);
      buffers
        ..useNormal()
        ..useNormal();
      expect(changes, <TerminalBufferType>[
        TerminalBufferType.alternate,
        TerminalBufferType.normal,
      ]);

      buffers.resize(6, 4, erase);
      expect((buffers.normal.columns, buffers.normal.rows), (6, 4));
      expect((buffers.alternate.columns, buffers.alternate.rows), (6, 4));
      buffers.resize(2, 1, erase);
      expect((buffers.normal.columns, buffers.normal.rows), (2, 1));
      buffers.dispose();
    },
  );

  test('shrinking rows removes blank lines below the cursor', () {
    final buffers = TerminalBufferNamespace(
      columns: 80,
      rows: 24,
      scrollback: 1000,
    )..resize(5, 5, TerminalCellAttributes());

    expect(buffers.normal.length, 5);
    expect(buffers.normal.baseY, 0);
    expect(buffers.normal.cursorY, 0);
    expect(buffers.alternate.length, 5);
    buffers.dispose();
  });

  test('growing rows reveals history only when the cursor is at the end', () {
    final erase = TerminalCellAttributes();
    final atEnd = TerminalBufferNamespace(
      columns: 4,
      rows: 2,
      scrollback: 10,
    );
    atEnd.normal
      ..cursorY = 1
      ..scroll(erase)
      ..scroll(erase)
      ..scroll(erase);

    atEnd.resize(4, 4, erase);
    expect((atEnd.normal.length, atEnd.normal.baseY), (5, 1));
    expect(atEnd.normal.cursorY, 3);
    atEnd.resize(4, 6, erase);
    expect((atEnd.normal.length, atEnd.normal.baseY), (6, 0));
    expect(atEnd.normal.cursorY, 4);

    final aboveEnd = TerminalBufferNamespace(
      columns: 4,
      rows: 2,
      scrollback: 10,
    );
    aboveEnd.normal
      ..scroll(erase)
      ..scroll(erase)
      ..scroll(erase);
    aboveEnd.resize(4, 4, erase);
    expect((aboveEnd.normal.length, aboveEnd.normal.baseY), (7, 3));

    atEnd.dispose();
    aboveEnd.dispose();
  });

  test('column resize reflows logical lines and preserves wide cells', () {
    final erase = TerminalCellAttributes();
    final buffers = TerminalBufferNamespace(
      columns: 5,
      rows: 5,
      scrollback: 10,
    );
    for (var column = 0; column < 5; column++) {
      buffers.normal
          .getLine(0)!
          .setCell(
            column,
            String.fromCharCode(0x61 + column),
            1,
            erase,
          );
      buffers.normal
          .getLine(1)!
          .setCell(
            column,
            String.fromCharCode(0x66 + column),
            1,
            erase,
          );
    }
    buffers.normal
      ..cursorY = 4
      ..getLine(1)!.isWrapped = true;

    buffers.resize(10, 5, erase);
    expect(
      buffers.normal.getLine(0)!.translateToString(trimRight: true),
      'abcdefghij',
    );
    expect(buffers.normal.getLine(1)!.isWrapped, isFalse);

    buffers.normal.getLine(0)!
      ..erase(0, 10, erase)
      ..setCell(0, '界', 2, erase)
      ..setCell(2, 'a', 1, erase)
      ..setCell(3, 'b', 1, erase);
    buffers.resize(3, 5, erase);
    expect(buffers.normal.getLine(0)!.translateToString(), '界a');
    expect(
      buffers.normal.getLine(1)!.translateToString(trimRight: true),
      'b',
    );
    expect(buffers.normal.getLine(1)!.isWrapped, isTrue);
    buffers.dispose();
  });

  test('cursor logical line reflows only with reflowCursorLine', () {
    TerminalBufferNamespace createBuffer() {
      final value = TerminalBufferNamespace(
        columns: 5,
        rows: 3,
        scrollback: 10,
      );
      final erase = TerminalCellAttributes();
      for (var column = 0; column < 5; column++) {
        value.normal.getLine(0)!.setCell(column, 'a', 1, erase);
        value.normal.getLine(1)!.setCell(column, 'b', 1, erase);
      }
      value.normal.getLine(1)!.isWrapped = true;
      return value;
    }

    final preserved = createBuffer();
    final reflowed = createBuffer();
    final erase = TerminalCellAttributes();
    preserved.resize(10, 3, erase);
    reflowed.resize(10, 3, erase, reflowCursorLine: true);

    expect(preserved.normal.getLine(1)!.isWrapped, isTrue);
    expect(
      reflowed.normal.getLine(0)!.translateToString(trimRight: true),
      'aaaaabbbbb',
    );
    expect(reflowed.normal.getLine(1)!.isWrapped, isFalse);
    preserved.dispose();
    reflowed.dispose();
  });

  test(
    'markers follow reflow insertions, removals, and scrollback trims',
    () async {
      final terminal = Terminal(
        options: TerminalOptions(
          cols: 10,
          rows: 16,
          scrollback: 1,
          reflowCursorLine: true,
        ),
      );
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        'abcdefghij\r\n0123456789\r\nklmnopqrst',
      );
      final first = terminal.registerMarker(cursorYOffset: -2)!;
      final second = terminal.registerMarker(cursorYOffset: -1)!;
      final third = terminal.registerMarker()!;

      terminal.resize(2, 16);
      expect((first.line, second.line, third.line), (0, 5, 10));
      terminal.resize(10, 16);
      expect((first.line, second.line, third.line), (0, 1, 2));

      terminal.resize(10, 2);
      await terminal.writeAndWait('\r\nnext\r\nlast');
      expect(first.isDisposed, isTrue);
    },
  );
}

TerminalBuffer _rangeBuffer() {
  final namespace = TerminalBufferNamespace(
    columns: 20,
    rows: 10,
    scrollback: 0,
  );
  addTearDown(namespace.dispose);
  return namespace.normal;
}

TerminalBufferNamespace _bufferNamespace({int scrollback = 1000}) {
  final namespace = TerminalBufferNamespace(
    columns: 80,
    rows: 24,
    scrollback: scrollback,
  );
  addTearDown(namespace.dispose);
  return namespace;
}

TerminalBuffer _translationBuffer(int columns) {
  final namespace = TerminalBufferNamespace(
    columns: columns,
    rows: 1,
    scrollback: 0,
  );
  addTearDown(namespace.dispose);
  return namespace.normal;
}

TerminalBuffer _wideTranslationBuffer() {
  final buffer = _translationBuffer(3);
  buffer.getLine(0)!
    ..setCell(0, '語', 2, TerminalCellAttributes())
    ..setCell(1, '', 0, TerminalCellAttributes())
    ..setCell(2, 'a', 1, TerminalCellAttributes());
  return buffer;
}
