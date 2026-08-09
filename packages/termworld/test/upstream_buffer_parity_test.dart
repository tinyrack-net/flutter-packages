import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/core/buffer_line_string_cache.dart';
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

  test('xterm Buffer 24', () {
    final buffers = _bufferNamespace()
      ..resize(80, 14, TerminalCellAttributes());
    expect(buffers.normal.length, 14);
  });

  test('xterm Buffer 25', () {
    final buffers = _bufferNamespace();
    buffers.normal.cursorY = 18;
    buffers.resize(80, 14, TerminalCellAttributes());
    expect(buffers.normal.length, 19);
    expect((buffers.normal.viewportY, buffers.normal.baseY), (5, 5));
  });

  test('xterm Buffer 26', () {
    final buffers = _bufferNamespace(scrollback: 0);
    final attributes = TerminalCellAttributes();
    buffers.normal
      ..cursorY = 23
      ..getLine(5)!.setCell(0, 'a', 1, attributes)
      ..getLine(23)!.setCell(0, 'b', 1, attributes);
    buffers.resize(80, 19, attributes);
    expect(buffers.normal.getLine(0)!.getCell(0)!.chars, 'a');
    expect(buffers.normal.getLine(18)!.getCell(0)!.chars, 'b');
  });

  test('xterm Buffer 27', () {
    final buffers = _bufferNamespace();
    expect(buffers.normal.viewportY, 0);
    buffers.resize(80, 34, TerminalCellAttributes());
    expect(buffers.normal.viewportY, 0);
    expect(buffers.normal.length, 34);
  });

  test('xterm Buffer 28', () {
    final buffers = _scrolledBuffer();
    buffers.normal.displayY = buffers.normal.baseY;
    buffers.resize(80, 29, TerminalCellAttributes());
    expect((buffers.normal.viewportY, buffers.normal.baseY), (5, 5));
    expect(buffers.normal.length, 34);
  });

  test('xterm Buffer 29', () {
    final buffers = _scrolledBuffer();
    buffers.normal.displayY = 0;
    buffers.resize(80, 29, TerminalCellAttributes());
    expect(buffers.normal.viewportY, 0);
    expect(buffers.normal.baseY, 5);
    expect(buffers.normal.length, 34);
  });

  test('xterm Buffer 30', () {
    final buffers = _bufferNamespace();
    final attributes = TerminalCellAttributes();
    buffers.normal.getLine(0)!.setCell(0, 'a', 1, attributes);
    buffers.normal.translateBufferLineToString(0);
    expect(buffers.normal.stringCache.entries.length, 1);
    expect(buffers.normal.stringCache.hasPendingClear, isTrue);

    buffers.normal.clear();
    expect(buffers.normal.stringCache.entries, isEmpty);
    expect(buffers.normal.stringCache.hasPendingClear, isFalse);

    buffers.normal.getLine(0)!.setCell(0, 'b', 1, attributes);
    buffers.normal.translateBufferLineToString(0);
    expect(buffers.normal.stringCache.entries.length, 1);
    buffers.resize(79, 24, attributes);
    expect(buffers.normal.stringCache.entries, isEmpty);
    expect(buffers.normal.stringCache.hasPendingClear, isFalse);
  });

  test('xterm Buffer 31', () async {
    final buffers = _bufferNamespace()
      ..resize(39, 24, TerminalCellAttributes());
    for (var row = 0; row < 24; row++) {
      expect(buffers.normal.getLine(row)!.length, 39);
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
    for (var row = 0; row < 24; row++) {
      expect(buffers.normal.getLine(row)!.length, 39);
    }
  });

  test('xterm Buffer 32', () {
    final buffers = _bufferNamespace()
      ..resize(85, 29, TerminalCellAttributes());
    expect(buffers.normal.length, 29);
    for (var row = 0; row < 29; row++) {
      expect(buffers.normal.getLine(row)!.length, 85);
    }
  });

  test('xterm Buffer 33', () {
    final buffers = _bufferNamespace()
      ..resize(75, 24, TerminalCellAttributes());
    expect(buffers.normal.length, 24);
  });

  test('xterm Buffer 34', () {
    final buffers = _bufferNamespace()..resize(5, 10, TerminalCellAttributes());
    expect(buffers.normal.length, 10);
    for (var row = 0; row < 10; row++) {
      expect(buffers.normal.getLine(row)!.length, 5);
    }
  });

  test('xterm Buffer 35', () {
    final attributes = TerminalCellAttributes();
    final buffers = _bufferNamespace()..resize(5, 10, attributes);
    for (var column = 0; column < 5; column++) {
      buffers.normal
          .getLine(0)!
          .setCell(
            column,
            String.fromCharCode('a'.codeUnitAt(0) + column),
            1,
            attributes,
          );
    }
    buffers.normal.cursorY = 1;
    expect(buffers.normal.getLine(0)!.translateToString(), 'abcde');
    buffers.resize(1, 10, attributes);
    expect(buffers.normal.length, 10);
    for (var row = 0; row < 5; row++) {
      expect(
        buffers.normal.getLine(row)!.translateToString(),
        String.fromCharCode('a'.codeUnitAt(0) + row),
      );
    }
    for (var row = 5; row < 10; row++) {
      expect(buffers.normal.getLine(row)!.translateToString(), ' ');
    }
    buffers.resize(5, 10, attributes);
    expect(buffers.normal.length, 10);
    expect(buffers.normal.getLine(0)!.translateToString(), 'abcde');
    for (var row = 1; row < 10; row++) {
      expect(buffers.normal.getLine(row)!.translateToString(), '     ');
    }
  });

  test('xterm Buffer 36', () {
    final attributes = TerminalCellAttributes();
    final buffers = _bufferNamespace()..resize(4, 3, attributes);
    buffers.normal
      ..cursorY = 2
      ..getLine(0)!.setCell(0, 'a', 1, attributes)
      ..getLine(0)!.setCell(1, 'b', 1, attributes)
      ..getLine(0)!.setCell(2, 'c', 1, attributes)
      ..getLine(0)!.setCell(3, '😁', 1, attributes);
    expect(buffers.normal.getLine(0)!.translateToString(), 'abc😁');
    buffers.resize(2, 3, attributes);
    expect(buffers.normal.getLine(0)!.translateToString(), 'ab');
    expect(buffers.normal.getLine(1)!.translateToString(), 'c😁');
  });

  test('xterm Buffer 37', () {
    final attributes = TerminalCellAttributes();
    final buffers = _cursorReflowBuffer(attributes)..resize(1, 10, attributes);
    buffers.normal.cursorY = 2;
    buffers.resize(5, 10, attributes);
    expect(buffers.normal.getLine(0)!.translateToString(), isNot('abcde'));
  });

  test('xterm Buffer 38', () {
    final attributes = TerminalCellAttributes();
    final buffers = _cursorReflowBuffer(attributes)
      ..resize(1, 10, attributes, reflowCursorLine: true);
    buffers.normal.cursorY = 2;
    buffers.resize(5, 10, attributes, reflowCursorLine: true);
    expect(buffers.normal.getLine(0)!.translateToString(), 'abcde');
  });

  test('xterm Buffer 39', () {
    var now = 0;
    final scheduled = <_ManualCacheTimer>[];
    final cache = BufferLineStringCache(
      now: () => now,
      createTimer: (delay, callback) {
        late _ManualCacheTimer timer;
        timer = _ManualCacheTimer(delay, () {
          scheduled.remove(timer);
          callback();
        });
        scheduled.add(timer);
        return timer.cancel;
      },
    );
    addTearDown(cache.dispose);
    final attributes = TerminalCellAttributes();
    final first = TerminalBufferLine(80, stringCache: cache)
      ..setCell(0, 'a', 1, attributes);
    final second = TerminalBufferLine(80, stringCache: cache)
      ..setCell(0, 'b', 1, attributes);
    final padding = List<String>.filled(79, ' ').join();

    expect(first.translateToString(), 'a$padding');
    expect(second.translateToString(), 'b$padding');
    expect(cache.entries.length, 2);
    expect(scheduled.length, 1);
    expect(scheduled.single.delay, const Duration(seconds: 15));

    now = 5000;
    expect(first.translateToString(), 'a$padding');
    expect(scheduled.length, 1);

    now = 15000;
    scheduled.single.fire();
    expect(cache.entries.length, 2);
    expect(scheduled.length, 1);
    expect(scheduled.single.delay, const Duration(seconds: 5));

    now = 20000;
    scheduled.single.fire();
    expect(cache.entries, isEmpty);
    expect(cache.hasPendingClear, isFalse);
  });

  test('xterm Buffer 40', () {
    final attributes = TerminalCellAttributes();
    final buffers = _wideReflowBuffer(attributes);
    expect(_trimmedLine(buffers.normal, 0), '汉语汉语汉语');
    expect(_trimmedLine(buffers.normal, 1), '汉语汉语汉语');
    buffers.resize(13, 10, attributes);
    expect(_trimmedLine(buffers.normal, 0), '汉语汉语汉语');
    expect(_trimmedLine(buffers.normal, 1), '汉语汉语汉语');
    buffers.resize(14, 10, attributes);
    expect(_trimmedLine(buffers.normal, 0), '汉语汉语汉语汉');
    expect(_trimmedLine(buffers.normal, 1), '语汉语汉语');
  });

  test('xterm Buffer 41', () {
    final attributes = TerminalCellAttributes();
    final buffers = _wideReflowBuffer(attributes)..resize(11, 10, attributes);
    expect(_trimmedLines(buffers.normal, 3), <String>[
      '汉语汉语汉',
      '语汉语汉语',
      '汉语',
    ]);
    buffers.resize(10, 10, attributes);
    expect(_trimmedLines(buffers.normal, 3), <String>[
      '汉语汉语汉',
      '语汉语汉语',
      '汉语',
    ]);
    buffers.resize(9, 10, attributes);
    expect(_trimmedLines(buffers.normal, 3), <String>[
      '汉语汉语',
      '汉语汉语',
      '汉语汉语',
    ]);
    buffers.resize(8, 10, attributes);
    expect(_trimmedLines(buffers.normal, 3), <String>[
      '汉语汉语',
      '汉语汉语',
      '汉语汉语',
    ]);
    buffers.resize(7, 10, attributes);
    expect(_trimmedLines(buffers.normal, 4), <String>[
      '汉语汉',
      '语汉语',
      '汉语汉',
      '语汉语',
    ]);
    buffers.resize(6, 10, attributes);
    expect(_trimmedLines(buffers.normal, 4), <String>[
      '汉语汉',
      '语汉语',
      '汉语汉',
      '语汉语',
    ]);
  });

  test('xterm Buffer 42', () {
    final attributes = TerminalCellAttributes();
    final buffers = _tabReflowBuffer(attributes)..resize(5, 10, attributes);
    expect(_trimmedLine(buffers.normal, 0), 'ab  c');
    expect(buffers.normal.getLine(1)!.translateToString(), 'd    ');
    buffers.resize(6, 10, attributes);
    expect(_trimmedLine(buffers.normal, 0), 'ab  cd');
    expect(buffers.normal.getLine(1)!.translateToString(), '      ');
  });

  test('xterm Buffer 43', () {
    final attributes = TerminalCellAttributes();
    final buffers = _tabReflowBuffer(attributes)..resize(3, 10, attributes);
    expect(buffers.normal.cursorY, 2);
    expect(buffers.normal.getLine(0)!.translateToString(), 'ab ');
    expect(buffers.normal.getLine(1)!.translateToString(), ' cd');
    buffers.resize(2, 10, attributes);
    expect(buffers.normal.cursorY, 3);
    expect(buffers.normal.getLine(0)!.translateToString(), 'ab');
    expect(buffers.normal.getLine(1)!.translateToString(), '  ');
    expect(buffers.normal.getLine(2)!.translateToString(), 'cd');
  });

  test('xterm Buffer 44', () {
    final attributes = TerminalCellAttributes();
    final buffers = _bufferNamespace()..resize(10, 16, attributes);
    _writeAsciiLine(buffers.normal, 0, 'abcdefghij', attributes);
    _writeAsciiLine(buffers.normal, 1, '0123456789', attributes);
    _writeAsciiLine(buffers.normal, 2, 'klmnopqrst', attributes);
    buffers.normal.cursorY = 3;
    final first = buffers.normal.addMarker(0);
    final second = buffers.normal.addMarker(1);
    final third = buffers.normal.addMarker(2);

    buffers.resize(2, 16, attributes);
    expect(_trimmedLines(buffers.normal, 15), <String>[
      'ab',
      'cd',
      'ef',
      'gh',
      'ij',
      '01',
      '23',
      '45',
      '67',
      '89',
      'kl',
      'mn',
      'op',
      'qr',
      'st',
    ]);
    expect((first.line, second.line, third.line), (0, 5, 10));

    buffers.resize(10, 16, attributes);
    expect(_trimmedLines(buffers.normal, 3), <String>[
      'abcdefghij',
      '0123456789',
      'klmnopqrst',
    ]);
    expect((first.line, second.line, third.line), (0, 1, 2));
    expect(
      (first.isDisposed, second.isDisposed, third.isDisposed),
      (false, false, false),
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

TerminalBufferNamespace _scrolledBuffer() {
  final buffers = _bufferNamespace();
  final attributes = TerminalCellAttributes();
  buffers.normal.cursorY = 23;
  for (var row = 0; row < 10; row++) {
    buffers.normal.scroll(attributes);
  }
  expect((buffers.normal.length, buffers.normal.baseY), (34, 10));
  return buffers;
}

TerminalBufferNamespace _cursorReflowBuffer(
  TerminalCellAttributes attributes,
) {
  final buffers = _bufferNamespace()..resize(5, 10, attributes);
  for (var column = 0; column < 5; column++) {
    buffers.normal
        .getLine(0)!
        .setCell(
          column,
          String.fromCharCode('a'.codeUnitAt(0) + column),
          1,
          attributes,
        );
  }
  return buffers;
}

final class _ManualCacheTimer {
  _ManualCacheTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  var _isCanceled = false;

  void fire() {
    if (!_isCanceled) _callback();
  }

  void cancel() => _isCanceled = true;
}

TerminalBufferNamespace _wideReflowBuffer(
  TerminalCellAttributes attributes,
) {
  final buffers = _bufferNamespace()..resize(12, 10, attributes);
  buffers.normal.cursorY = 2;
  for (var row = 0; row < 2; row++) {
    final line = buffers.normal.getLine(row)!;
    for (var column = 0; column < 12; column += 4) {
      line
        ..setCell(column, '汉', 2, attributes)
        ..setCell(column + 2, '语', 2, attributes);
    }
  }
  buffers.normal.getLine(1)!.isWrapped = true;
  return buffers;
}

String _trimmedLine(TerminalBuffer buffer, int row) =>
    buffer.getLine(row)!.translateToString(trimRight: true);

List<String> _trimmedLines(TerminalBuffer buffer, int count) => <String>[
  for (var row = 0; row < count; row++) _trimmedLine(buffer, row),
];

TerminalBufferNamespace _tabReflowBuffer(
  TerminalCellAttributes attributes,
) {
  final buffers = _bufferNamespace()..resize(4, 10, attributes);
  buffers.normal
    ..cursorY = 2
    ..getLine(0)!.setCell(0, 'a', 1, attributes)
    ..getLine(0)!.setCell(1, 'b', 1, attributes)
    ..getLine(1)!.setCell(0, 'c', 1, attributes)
    ..getLine(1)!.setCell(1, 'd', 1, attributes)
    ..getLine(1)!.isWrapped = true;
  return buffers;
}

void _writeAsciiLine(
  TerminalBuffer buffer,
  int row,
  String value,
  TerminalCellAttributes attributes,
) {
  for (var column = 0; column < value.length; column++) {
    buffer.getLine(row)!.setCell(column, value[column], 1, attributes);
  }
}
