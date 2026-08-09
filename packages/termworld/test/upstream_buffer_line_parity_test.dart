import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  test('xterm BufferLine 00', () {
    final line = TerminalBufferLine(3);
    expect(line.length, 3);
    expect(line.translateToString(), '   ');
    expect(line.isWrapped, isFalse);
  });

  test('xterm BufferLine 01', () {
    final line = _line('abc')..isWrapped = true;
    final clone = line.copy();
    line.setCell(0, 'z', 1, TerminalCellAttributes());
    expect(clone.translateToString(), 'abc');
    expect(clone.isWrapped, isTrue);
  });

  test('xterm BufferLine 02', () {
    final source = _line('abc')..isWrapped = true;
    final target = _line('12345')..copyFrom(source);
    source.setCell(0, 'z', 1, TerminalCellAttributes());
    expect(target.translateToString(), 'abc');
    expect(target.length, 3);
    expect(target.isWrapped, isTrue);
  });

  test('xterm BufferLine 03', () {
    final line = _line('abc')..fill(TerminalCellAttributes(bold: true));
    expect(line.translateToString(), '   ');
    expect(line.getCell(0)!.isBold, isTrue);
  });

  test('xterm BufferLine 04', () {
    expect(TerminalBufferLine(5).getTrimmedLength(), 0);
  });

  test('xterm BufferLine 05', () {
    expect(_line('abc  ').getTrimmedLength(), 3);
  });

  test('xterm BufferLine 06', () {
    final line = TerminalBufferLine(4)
      ..setCell(0, '中', 2, TerminalCellAttributes());
    expect(line.getTrimmedLength(), 2);
  });

  test('xterm BufferLine 07', () {
    final line = _line('a  ')..appendCombining(0, '\u0301');
    expect(line.getTrimmedLength(), 1);
    expect(line.translateToString(trimRight: true), 'a\u0301');
  });

  test('xterm BufferLine 08', () {
    final line = TerminalBufferLine(2)
      ..setCell(0, '𝄞', 1, TerminalCellAttributes());
    expect(line.getTrimmedLength(), 1);
  });

  test('xterm BufferLine 09', () {
    final line = TerminalBufferLine(1)
      ..setCell(0, 'a', 1, TerminalCellAttributes())
      ..addCodepointToCell(0, 0x301);
    expect(line.getCell(0)!.chars, 'a\u0301');
  });

  test('xterm BufferLine 10', () {
    final line = TerminalBufferLine(1)
      ..setCell(0, '', 0, TerminalCellAttributes())
      ..addCodepointToCell(0, 0x61);
    expect(line.getCell(0)!.chars, 'a');
    expect(line.getCell(0)!.width, 1);
  });

  test('xterm BufferLine 11', () {
    final line = _line('abcd')..insertCells(1, 2, TerminalCellAttributes());
    expect(line.translateToString(), 'a  b');
  });

  test('xterm BufferLine 12', () {
    final line = _line('abcd')..deleteCells(1, 2, TerminalCellAttributes());
    expect(line.translateToString(), 'ad  ');
  });

  test('xterm BufferLine 13', () {
    final line = _line('abcd')..replaceCells(1, 3, TerminalCellAttributes());
    expect(line.translateToString(), 'a  d');
  });

  test('xterm BufferLine 14', () {
    final line = TerminalBufferLine(4)
      ..setCell(0, '中', 2, TerminalCellAttributes())
      ..setCell(2, 'x', 1, TerminalCellAttributes())
      ..insertCells(1, 1, TerminalCellAttributes());
    expect(line.getCell(0)!.width, 1);
    expect(line.getCell(3)!.width, 1);
  });

  test('xterm BufferLine 15', () {
    final line = TerminalBufferLine(4)
      ..setCell(0, '中', 2, TerminalCellAttributes())
      ..setCell(2, 'x', 1, TerminalCellAttributes())
      ..deleteCells(1, 1, TerminalCellAttributes());
    expect(line.getCell(0)!.width, 1);
    expect(line.getCell(1)!.chars, 'x');
  });

  test('xterm BufferLine 16', () {
    final line = TerminalBufferLine(4)
      ..setCell(0, '中', 2, TerminalCellAttributes())
      ..replaceCells(1, 2, TerminalCellAttributes());
    expect(line.getCell(0)!.width, 1);
    expect(line.getCell(1)!.width, 1);
  });
}

TerminalBufferLine _line(String value) {
  final line = TerminalBufferLine(value.length);
  for (var index = 0; index < value.length; index++) {
    line.setCell(index, value[index], 1, TerminalCellAttributes());
  }
  return line;
}
