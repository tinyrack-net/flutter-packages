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

  test('format 3 GSUB applies contextual single substitutions', () {
    final font = TerminalLigatureFont.fromBytes(_format3LigatureFont());
    final result = font.findLigatures('ab');
    expect(result.inputGlyphs, <int>[1, 2]);
    expect(result.outputGlyphs, <int>[11, 12]);
    expect(result.contextRanges, <(int, int)>[(0, 2)]);
  });

  test('findLigatures caches successive calls correctly', () {
    final font = TerminalLigatureFont.fromBytes(
      _format3LigatureFont(),
      cacheSize: 100,
    );
    final first = font.findLigatures('ab');
    final second = font.findLigatures('ab');
    expect(second, same(first));
  });

  test('findLigatureRanges caches successive calls correctly', () {
    final font = TerminalLigatureFont.fromBytes(
      _format3LigatureFont(),
      cacheSize: 100,
    );
    final first = font.findLigatureRanges('ab');
    final second = font.findLigatureRanges('ab');
    expect(second, same(first));
  });

  test('caches calls to findLigatures after findLigatureRanges correctly', () {
    final font = TerminalLigatureFont.fromBytes(
      _format3LigatureFont(),
      cacheSize: 100,
    );
    final ranges = font.findLigatureRanges('ab');
    final ligatures = font.findLigatures('ab');
    expect(ligatures.contextRanges, ranges);
    expect(ligatures.outputGlyphs, <int>[11, 12]);
  });

  test('caches calls to findLigatureRanges after findLigatures correctly', () {
    final font = TerminalLigatureFont.fromBytes(
      _format3LigatureFont(),
      cacheSize: 100,
    );
    final ligatures = font.findLigatures('ab');
    final ranges = font.findLigatureRanges('ab');
    expect(ranges, same(ligatures.contextRanges));
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

Uint8List _format3LigatureFont() {
  final bytes = Uint8List(190);
  final data = ByteData.sublistView(bytes)
    ..setUint32(0, 0x00010000)
    ..setUint16(4, 2);
  _tableRecord(data, 12, 'cmap', 44, 52);
  _tableRecord(data, 28, 'GSUB', 96, 94);

  // cmap format 4: a -> 1, b -> 2.
  data
    ..setUint16(44, 0)
    ..setUint16(46, 1)
    ..setUint16(48, 3)
    ..setUint16(50, 1)
    ..setUint32(52, 12)
    ..setUint16(56, 4)
    ..setUint16(58, 40)
    ..setUint16(60, 0)
    ..setUint16(62, 6)
    ..setUint16(64, 4)
    ..setUint16(66, 1)
    ..setUint16(68, 2)
    ..setUint16(70, 97)
    ..setUint16(72, 98)
    ..setUint16(74, 0xffff)
    ..setUint16(76, 0)
    ..setUint16(78, 97)
    ..setUint16(80, 98)
    ..setUint16(82, 0xffff)
    ..setInt16(84, -96)
    ..setInt16(86, -96)
    ..setInt16(88, 1)
    ..setUint16(90, 0)
    ..setUint16(92, 0)
    ..setUint16(94, 0);

  const gsub = 96;
  const featureList = gsub + 10;
  const lookupList = gsub + 24;
  data
    ..setUint32(gsub, 0x00010000)
    ..setUint16(gsub + 4, 0)
    ..setUint16(gsub + 6, 10)
    ..setUint16(gsub + 8, 24)
    // FeatureList with calt selecting lookup 1.
    ..setUint16(featureList, 1)
    ..setUint8(featureList + 2, 0x63)
    ..setUint8(featureList + 3, 0x61)
    ..setUint8(featureList + 4, 0x6c)
    ..setUint8(featureList + 5, 0x74)
    ..setUint16(featureList + 6, 8)
    ..setUint16(featureList + 8, 0)
    ..setUint16(featureList + 10, 1)
    ..setUint16(featureList + 12, 1)
    // LookupList offsets.
    ..setUint16(lookupList, 2)
    ..setUint16(lookupList + 2, 6)
    ..setUint16(lookupList + 4, 28);

  const single = lookupList + 6;
  data
    ..setUint16(single, 1)
    ..setUint16(single + 2, 0)
    ..setUint16(single + 4, 1)
    ..setUint16(single + 6, 8)
    // Single substitution format 1 and coverage [1, 2].
    ..setUint16(single + 8, 1)
    ..setUint16(single + 10, 6)
    ..setInt16(single + 12, 10)
    ..setUint16(single + 14, 1)
    ..setUint16(single + 16, 2)
    ..setUint16(single + 18, 1)
    ..setUint16(single + 20, 2);

  const chaining = lookupList + 28;
  const subtable = chaining + 8;
  data
    ..setUint16(chaining, 6)
    ..setUint16(chaining + 2, 0)
    ..setUint16(chaining + 4, 1)
    ..setUint16(chaining + 6, 8)
    // Chaining contextual substitution format 3.
    ..setUint16(subtable, 3)
    ..setUint16(subtable + 2, 0)
    ..setUint16(subtable + 4, 2)
    ..setUint16(subtable + 6, 22)
    ..setUint16(subtable + 8, 28)
    ..setUint16(subtable + 10, 0)
    ..setUint16(subtable + 12, 2)
    ..setUint16(subtable + 14, 0)
    ..setUint16(subtable + 16, 0)
    ..setUint16(subtable + 18, 1)
    ..setUint16(subtable + 20, 0);
  _coverage1(data, subtable + 22, 1);
  _coverage1(data, subtable + 28, 2);
  return bytes;
}

void _tableRecord(
  ByteData data,
  int offset,
  String tag,
  int tableOffset,
  int length,
) {
  for (var index = 0; index < 4; index++) {
    data.setUint8(offset + index, tag.codeUnitAt(index));
  }
  data
    ..setUint32(offset + 8, tableOffset)
    ..setUint32(offset + 12, length);
}

void _coverage1(ByteData data, int offset, int glyph) {
  data
    ..setUint16(offset, 1)
    ..setUint16(offset + 2, 1)
    ..setUint16(offset + 4, glyph);
}
