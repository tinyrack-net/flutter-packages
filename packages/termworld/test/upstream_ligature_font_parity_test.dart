import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/ligature_font.dart';

void main() {
  test('dependency-free OpenType cmap produces input and output glyphs', () {
    final font = TerminalLigatureFont.fromBytes(_minimalFormat4Font());
    final result = font.findLigatures('a');
    expect(result.inputGlyphs, <int>[5]);
    expect(result.outputGlyphs, <int>[5]);
    expect(result.contextRanges, isEmpty);
    expect(font.findLigatureRanges('a'), isEmpty);
  });

  test('truncated OpenType data reports a format error', () {
    expect(
      () => TerminalLigatureFont.fromBytes(Uint8List(4)),
      throwsFormatException,
    );
  });
}

Uint8List _minimalFormat4Font() {
  final bytes = Uint8List(72);
  ByteData.sublistView(bytes)
    ..setUint32(0, 0x00010000)
    ..setUint16(4, 1)
    // SFNT table directory.
    ..setUint8(12, 0x63)
    ..setUint8(13, 0x6d)
    ..setUint8(14, 0x61)
    ..setUint8(15, 0x70)
    ..setUint32(20, 28)
    ..setUint32(24, 44)
    // cmap header and one Windows Unicode encoding record.
    ..setUint16(28, 0)
    ..setUint16(30, 1)
    ..setUint16(32, 3)
    ..setUint16(34, 1)
    ..setUint32(36, 12)
    // cmap format 4 with U+0061 -> glyph 5 plus the sentinel segment.
    ..setUint16(40, 4)
    ..setUint16(42, 32)
    ..setUint16(44, 0)
    ..setUint16(46, 4)
    ..setUint16(48, 4)
    ..setUint16(50, 1)
    ..setUint16(52, 0)
    ..setUint16(54, 0x0061)
    ..setUint16(56, 0xffff)
    ..setUint16(58, 0)
    ..setUint16(60, 0x0061)
    ..setUint16(62, 0xffff)
    ..setInt16(64, 5 - 0x0061)
    ..setInt16(66, 1)
    ..setUint16(68, 0)
    ..setUint16(70, 0);
  return bytes;
}
