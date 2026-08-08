import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
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
      expect(buffers.normal.viewportY, 2);
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
}
