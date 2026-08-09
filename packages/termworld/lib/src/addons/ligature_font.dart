import 'dart:collection';
import 'dart:typed_data';

import 'package:termworld/src/addons/ligature_ranges.dart';
import 'package:termworld/src/addons/ligature_tables.dart';

/// Glyph substitutions and context ranges found for one string.
final class TerminalLigatureData {
  /// Creates a ligature result.
  const TerminalLigatureData({
    required this.inputGlyphs,
    required this.outputGlyphs,
    required this.contextRanges,
  });

  /// Glyph identifiers before contextual substitutions.
  final List<int> inputGlyphs;

  /// Glyph identifiers after contextual substitutions.
  final List<int> outputGlyphs;

  /// End-exclusive source ranges affected by contextual substitutions.
  final List<(int, int)> contextRanges;
}

/// A dependency-free OpenType font wrapper matching xterm's ligature engine.
final class TerminalLigatureFont {
  TerminalLigatureFont._(this._cmap, this._lookups, this._cacheSize);

  /// Parses an SFNT/TrueType/OpenType byte buffer without external packages.
  factory TerminalLigatureFont.fromBytes(Uint8List bytes, {int cacheSize = 0}) {
    final parser = _OpenTypeParser(bytes);
    final parsed = parser.parse();
    final font = TerminalLigatureFont._(
      parsed.cmap,
      parsed.caltLookups,
      cacheSize,
    );
    return font
      .._singleLookups = parsed.allLookups.map((lookup) {
        return switch (lookup) {
          _SingleLookup(:final tables) => tables,
          _ => const <TerminalSubstitutionTable>[],
        };
      }).toList()
      // Trees depend on all lookup records. Rebuild after the complete single
      // lookup list is installed, mirroring opentype.js's parsed lookup graph.
      .._lookupTrees.clear()
      .._glyphLookups.clear()
      .._initializeTrees();
  }

  final _TerminalCmap _cmap;
  final List<_ParsedLookup> _lookups;
  final int _cacheSize;
  List<List<TerminalSubstitutionTable>> _singleLookups =
      const <List<TerminalSubstitutionTable>>[];
  final List<
    ({Map<int, TerminalFlattenedLigatureEntry> tree, bool processForward})
  >
  _lookupTrees = [];
  final Map<int, List<int>> _glyphLookups = <int, List<int>>{};
  final LinkedHashMap<String, Object> _cache = LinkedHashMap<String, Object>();
  var _cacheUnits = 0;

  void _initializeTrees() {
    for (var groupIndex = 0; groupIndex < _lookups.length; groupIndex++) {
      final lookup = _lookups[groupIndex];
      final trees = <TerminalLigatureLookupTree>[];
      switch (lookup) {
        case _ChainingLookup(:final tables):
          for (var subIndex = 0; subIndex < tables.length; subIndex++) {
            final table = tables[subIndex];
            trees.add(
              switch (table) {
                TerminalChainingGlyphTable() => buildTerminalChainingGlyphTree(
                  table,
                  _singleLookups,
                  subIndex,
                ),
                TerminalChainingClassTable() => buildTerminalChainingClassTree(
                  table,
                  _singleLookups,
                  subIndex,
                ),
                TerminalChainingCoverageTable() =>
                  buildTerminalChainingCoverageTree(
                    table,
                    _singleLookups,
                    subIndex,
                  ),
                _ => throw const FormatException(
                  'Unsupported chaining substitution table',
                ),
              },
            );
          }
        case _ReverseLookup(:final tables):
          for (var subIndex = 0; subIndex < tables.length; subIndex++) {
            trees.add(
              buildTerminalReverseChainingTree(tables[subIndex], subIndex),
            );
          }
        case _SingleLookup():
          continue;
      }
      final tree = flattenTerminalLigatureTree(
        mergeTerminalLigatureTrees(trees),
      );
      _lookupTrees.add((tree: tree, processForward: lookup is! _ReverseLookup));
      for (final glyph in tree.keys) {
        (_glyphLookups[glyph] ??= <int>[]).add(groupIndex);
      }
    }
  }

  /// Finds input/output glyphs and affected context ranges.
  TerminalLigatureData findLigatures(String text) {
    final cached = _cacheGet(text);
    if (cached is TerminalLigatureData) return cached;
    final glyphs = <int>[for (final rune in text.runes) _cmap.glyph(rune)];
    if (_lookupTrees.isEmpty) {
      return TerminalLigatureData(
        inputGlyphs: glyphs,
        outputGlyphs: glyphs,
        contextRanges: const <(int, int)>[],
      );
    }
    final result = _findInternal(glyphs.toList());
    final data = TerminalLigatureData(
      inputGlyphs: glyphs,
      outputGlyphs: result.sequence,
      contextRanges: result.ranges,
    );
    _cacheSet(text, data);
    return data;
  }

  /// Finds only source ranges affected by contextual substitutions.
  List<(int, int)> findLigatureRanges(String text) {
    if (_lookupTrees.isEmpty) return const <(int, int)>[];
    final cached = _cacheGet(text);
    if (cached is TerminalLigatureData) return cached.contextRanges;
    if (cached is List<(int, int)>) return cached;
    final glyphs = <int>[for (final rune in text.runes) _cmap.glyph(rune)];
    final ranges = _findInternal(glyphs).ranges;
    _cacheSet(text, ranges);
    return ranges;
  }

  ({List<int> sequence, List<(int, int)> ranges}) _findInternal(
    List<int> sequence,
  ) {
    final ranges = <(int, int)>[];
    var next = _nextLookup(sequence, 0);
    while (next.index != null) {
      final lookup = _lookupTrees[next.index!];
      if (lookup.processForward) {
        var lastGlyphIndex = next.last;
        for (var index = next.first; index < lastGlyphIndex; index++) {
          final result = walkTerminalLigatureTree(
            lookup.tree,
            sequence,
            index,
            index,
          );
          if (result == null) continue;
          for (var offset = 0; offset < result.substitutions.length; offset++) {
            final replacement = result.substitutions[offset];
            if (replacement != null) sequence[index + offset] = replacement;
          }
          mergeLigatureRange(
            ranges,
            result.contextRange.$1 + index,
            result.contextRange.$2 + index,
          );
          if (index + result.length >= lastGlyphIndex) {
            lastGlyphIndex = index + result.length + 1;
          }
          index += result.length - 1;
        }
      } else {
        for (var index = next.last - 1; index >= next.first; index--) {
          final result = walkTerminalLigatureTree(
            lookup.tree,
            sequence,
            index,
            index,
          );
          if (result == null) continue;
          for (var offset = 0; offset < result.substitutions.length; offset++) {
            final replacement = result.substitutions[offset];
            if (replacement != null) sequence[index + offset] = replacement;
          }
          mergeLigatureRange(
            ranges,
            result.contextRange.$1 + index,
            result.contextRange.$2 + index,
          );
          index -= result.length - 1;
        }
      }
      next = _nextLookup(sequence, next.index! + 1);
    }
    return (sequence: sequence, ranges: ranges);
  }

  ({int? index, int first, int last}) _nextLookup(
    List<int> sequence,
    int start,
  ) {
    int? resultIndex;
    var first = 0x7fffffff;
    var last = -1;
    for (var index = 0; index < sequence.length; index++) {
      final lookups = _glyphLookups[sequence[index]];
      if (lookups == null) continue;
      for (final lookupIndex in lookups) {
        if (lookupIndex < start) continue;
        if (resultIndex == null || lookupIndex <= resultIndex) {
          resultIndex = lookupIndex;
          if (first > index) first = index;
          last = index + 1;
        }
        break;
      }
    }
    return (index: resultIndex, first: first, last: last);
  }

  Object? _cacheGet(String key) {
    final value = _cache.remove(key);
    if (value != null) _cache[key] = value;
    return value;
  }

  void _cacheSet(String key, Object value) {
    if (_cacheSize <= 0 || key.length > _cacheSize) return;
    final previous = _cache.remove(key);
    if (previous != null) _cacheUnits -= key.length;
    while (_cache.isNotEmpty && _cacheUnits + key.length > _cacheSize) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      _cacheUnits -= oldest.length;
    }
    _cache[key] = value;
    _cacheUnits += key.length;
  }
}

sealed class _ParsedLookup {
  const _ParsedLookup();
}

final class _SingleLookup extends _ParsedLookup {
  const _SingleLookup(this.tables);
  final List<TerminalSubstitutionTable> tables;
}

final class _ChainingLookup extends _ParsedLookup {
  const _ChainingLookup(this.tables);
  final List<Object> tables;
}

final class _ReverseLookup extends _ParsedLookup {
  const _ReverseLookup(this.tables);
  final List<TerminalReverseChainingTable> tables;
}

abstract interface class _TerminalCmap {
  int glyph(int codePoint);

  bool get supportsSupplementaryPlanes;
}

final class _CmapGroups implements _TerminalCmap {
  const _CmapGroups(this.groups);
  final List<(int, int, int)> groups;

  @override
  bool get supportsSupplementaryPlanes => true;

  @override
  int glyph(int codePoint) {
    var low = 0;
    var high = groups.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final group = groups[middle];
      if (codePoint < group.$1) {
        high = middle - 1;
      } else if (codePoint > group.$2) {
        low = middle + 1;
      } else {
        return group.$3 + codePoint - group.$1;
      }
    }
    return 0;
  }
}

final class _CmapFormat4 implements _TerminalCmap {
  const _CmapFormat4(this.data, this.base, this.segCount);
  final ByteData data;
  final int base;
  final int segCount;

  @override
  bool get supportsSupplementaryPlanes => false;

  @override
  int glyph(int codePoint) {
    if (codePoint > 0xffff) return 0;
    final endCodes = base + 14;
    final startCodes = endCodes + segCount * 2 + 2;
    final deltas = startCodes + segCount * 2;
    final rangeOffsets = deltas + segCount * 2;
    for (var index = 0; index < segCount; index++) {
      final end = data.getUint16(endCodes + index * 2);
      if (codePoint > end) continue;
      final start = data.getUint16(startCodes + index * 2);
      if (codePoint < start) return 0;
      final delta = data.getInt16(deltas + index * 2);
      final rangeOffset = data.getUint16(rangeOffsets + index * 2);
      if (rangeOffset == 0) return (codePoint + delta) & 0xffff;
      final address =
          rangeOffsets + index * 2 + rangeOffset + (codePoint - start) * 2;
      final glyph = data.getUint16(address);
      return glyph == 0 ? 0 : (glyph + delta) & 0xffff;
    }
    return 0;
  }
}

final class _OpenTypeParser {
  _OpenTypeParser(Uint8List bytes)
    : data = ByteData.sublistView(bytes),
      length = bytes.length;

  final ByteData data;
  final int length;
  final Map<String, (int, int)> _tables = <String, (int, int)>{};

  ({
    _TerminalCmap cmap,
    List<_ParsedLookup> allLookups,
    List<_ParsedLookup> caltLookups,
  })
  parse() {
    _require(0, 12);
    final tableCount = _u16(4);
    for (var index = 0; index < tableCount; index++) {
      final record = 12 + index * 16;
      _require(record, 16);
      final tag = String.fromCharCodes(<int>[
        data.getUint8(record),
        data.getUint8(record + 1),
        data.getUint8(record + 2),
        data.getUint8(record + 3),
      ]);
      final offset = _u32(record + 8);
      final tableLength = _u32(record + 12);
      _require(offset, tableLength);
      _tables[tag] = (offset, tableLength);
    }
    final cmap = _parseCmap();
    final gsub = _tables['GSUB'];
    if (gsub == null) {
      return (cmap: cmap, allLookups: const [], caltLookups: const []);
    }
    final base = gsub.$1;
    final featureList = base + _u16(base + 6);
    final lookupList = base + _u16(base + 8);
    final caltIndices = <int>[];
    final featureCount = _u16(featureList);
    for (var index = 0; index < featureCount; index++) {
      final record = featureList + 2 + index * 6;
      final tag = String.fromCharCodes(<int>[
        data.getUint8(record),
        data.getUint8(record + 1),
        data.getUint8(record + 2),
        data.getUint8(record + 3),
      ]);
      if (tag != 'calt') continue;
      final feature = featureList + _u16(record + 4);
      final count = _u16(feature + 2);
      for (var item = 0; item < count; item++) {
        caltIndices.add(_u16(feature + 4 + item * 2));
      }
    }
    final lookupCount = _u16(lookupList);
    final all = <_ParsedLookup>[];
    for (var index = 0; index < lookupCount; index++) {
      all.add(_parseLookup(lookupList + _u16(lookupList + 2 + index * 2)));
    }
    final calt = <_ParsedLookup>[
      for (var index = 0; index < all.length; index++)
        if (caltIndices.contains(index)) all[index],
    ];
    return (cmap: cmap, allLookups: all, caltLookups: calt);
  }

  _TerminalCmap _parseCmap() {
    final table = _tables['cmap'];
    if (table == null) throw const FormatException('OpenType cmap is missing');
    final base = table.$1;
    final count = _u16(base + 2);
    int? format12;
    int? format4;
    for (var index = 0; index < count; index++) {
      final record = base + 4 + index * 8;
      final subtable = base + _u32(record + 4);
      final format = _u16(subtable);
      if (format == 12) format12 ??= subtable;
      if (format == 4) format4 ??= subtable;
    }
    if (format12 != null) {
      final count = _u32(format12 + 12);
      return _CmapGroups(<(int, int, int)>[
        for (var index = 0; index < count; index++)
          (
            _u32(format12 + 16 + index * 12),
            _u32(format12 + 20 + index * 12),
            _u32(format12 + 24 + index * 12),
          ),
      ]);
    }
    if (format4 != null) {
      return _CmapFormat4(data, format4, _u16(format4 + 6) ~/ 2);
    }
    throw const FormatException('Unsupported OpenType cmap format');
  }

  _ParsedLookup _parseLookup(int base) {
    final type = _u16(base);
    final count = _u16(base + 4);
    final offsets = <int>[
      for (var index = 0; index < count; index++)
        base + _u16(base + 6 + index * 2),
    ];
    return switch (type) {
      1 => _SingleLookup([
        for (final offset in offsets) _parseSingleSubstitution(offset),
      ]),
      6 => _ChainingLookup([
        for (final offset in offsets) _parseChainingSubstitution(offset),
      ]),
      8 => _ReverseLookup([
        for (final offset in offsets) _parseReverseSubstitution(offset),
      ]),
      _ => const _SingleLookup(<TerminalSubstitutionTable>[]),
    };
  }

  TerminalSubstitutionTable _parseSingleSubstitution(int base) {
    final format = _u16(base);
    final coverage = _parseCoverage(base + _u16(base + 2));
    if (format == 1) {
      return TerminalDeltaSubstitution(coverage, _i16(base + 4));
    }
    if (format == 2) {
      final count = _u16(base + 4);
      return TerminalListSubstitution(coverage, <int>[
        for (var index = 0; index < count; index++) _u16(base + 6 + index * 2),
      ]);
    }
    throw FormatException('Unsupported GSUB type 1 format $format');
  }

  Object _parseChainingSubstitution(int base) {
    return switch (_u16(base)) {
      1 => _parseChainingGlyph(base),
      2 => _parseChainingClass(base),
      3 => _parseChainingCoverage(base),
      final format => throw FormatException(
        'Unsupported GSUB type 6 format $format',
      ),
    };
  }

  TerminalChainingGlyphTable _parseChainingGlyph(int base) {
    final coverage = _parseCoverage(base + _u16(base + 2));
    final count = _u16(base + 4);
    return TerminalChainingGlyphTable(
      coverage: coverage,
      chainRuleSets: <List<TerminalChainingGlyphRule>?>[
        for (var index = 0; index < count; index++)
          _u16(base + 6 + index * 2) == 0
              ? null
              : _parseGlyphRuleSet(base + _u16(base + 6 + index * 2)),
      ],
    );
  }

  List<TerminalChainingGlyphRule> _parseGlyphRuleSet(int base) {
    final count = _u16(base);
    return <TerminalChainingGlyphRule>[
      for (var index = 0; index < count; index++)
        _parseGlyphRule(base + _u16(base + 2 + index * 2)),
    ];
  }

  TerminalChainingGlyphRule _parseGlyphRule(int base) {
    var cursor = base;
    final backtrack = _readCountedU16(cursor);
    cursor += 2 + backtrack.length * 2;
    final inputCount = _u16(cursor);
    final input = <int>[
      for (var index = 1; index < inputCount; index++) _u16(cursor + index * 2),
    ];
    cursor += 2 + (inputCount - 1) * 2;
    final lookahead = _readCountedU16(cursor);
    cursor += 2 + lookahead.length * 2;
    final records = _parseLookupRecords(cursor);
    return TerminalChainingGlyphRule(
      backtrack: backtrack,
      input: input,
      lookahead: lookahead,
      lookupRecords: records.records,
    );
  }

  TerminalChainingClassTable _parseChainingClass(int base) {
    final coverage = _parseCoverage(base + _u16(base + 2));
    final backtrack = _parseClassDefinition(base + _u16(base + 4));
    final input = _parseClassDefinition(base + _u16(base + 6));
    final lookahead = _parseClassDefinition(base + _u16(base + 8));
    final count = _u16(base + 10);
    return TerminalChainingClassTable(
      coverage: coverage,
      inputClassDefinition: input,
      lookaheadClassDefinition: lookahead,
      backtrackClassDefinition: backtrack,
      chainClassSets: <List<TerminalChainingClassRule>?>[
        for (var index = 0; index < count; index++)
          _u16(base + 12 + index * 2) == 0
              ? null
              : _parseClassRuleSet(base + _u16(base + 12 + index * 2)),
      ],
    );
  }

  List<TerminalChainingClassRule> _parseClassRuleSet(int base) {
    final count = _u16(base);
    return <TerminalChainingClassRule>[
      for (var index = 0; index < count; index++)
        _parseClassRule(base + _u16(base + 2 + index * 2)),
    ];
  }

  TerminalChainingClassRule _parseClassRule(int base) {
    final glyph = _parseGlyphRule(base);
    return TerminalChainingClassRule(
      backtrack: glyph.backtrack,
      input: glyph.input,
      lookahead: glyph.lookahead,
      lookupRecords: glyph.lookupRecords,
    );
  }

  TerminalChainingCoverageTable _parseChainingCoverage(int base) {
    var cursor = base + 2;
    final backtrackCount = _u16(cursor);
    cursor += 2;
    final backtrack = <TerminalCoverageTable>[
      for (var index = 0; index < backtrackCount; index++)
        _parseCoverage(base + _u16(cursor + index * 2)),
    ];
    cursor += backtrackCount * 2;
    final inputCount = _u16(cursor);
    cursor += 2;
    final input = <TerminalCoverageTable>[
      for (var index = 0; index < inputCount; index++)
        _parseCoverage(base + _u16(cursor + index * 2)),
    ];
    cursor += inputCount * 2;
    final lookaheadCount = _u16(cursor);
    cursor += 2;
    final lookahead = <TerminalCoverageTable>[
      for (var index = 0; index < lookaheadCount; index++)
        _parseCoverage(base + _u16(cursor + index * 2)),
    ];
    cursor += lookaheadCount * 2;
    return TerminalChainingCoverageTable(
      inputCoverage: input,
      lookaheadCoverage: lookahead,
      backtrackCoverage: backtrack,
      lookupRecords: _parseLookupRecords(cursor).records,
    );
  }

  TerminalReverseChainingTable _parseReverseSubstitution(int base) {
    final coverage = _parseCoverage(base + _u16(base + 2));
    var cursor = base + 4;
    final backtrackCount = _u16(cursor);
    cursor += 2;
    final backtrack = <TerminalCoverageTable>[
      for (var index = 0; index < backtrackCount; index++)
        _parseCoverage(base + _u16(cursor + index * 2)),
    ];
    cursor += backtrackCount * 2;
    final lookaheadCount = _u16(cursor);
    cursor += 2;
    final lookahead = <TerminalCoverageTable>[
      for (var index = 0; index < lookaheadCount; index++)
        _parseCoverage(base + _u16(cursor + index * 2)),
    ];
    cursor += lookaheadCount * 2;
    final glyphCount = _u16(cursor);
    cursor += 2;
    return TerminalReverseChainingTable(
      coverage: coverage,
      lookaheadCoverage: lookahead,
      backtrackCoverage: backtrack,
      substitutes: <int>[
        for (var index = 0; index < glyphCount; index++)
          _u16(cursor + index * 2),
      ],
    );
  }

  TerminalCoverageTable _parseCoverage(int base) {
    final format = _u16(base);
    final count = _u16(base + 2);
    if (format == 1) {
      return TerminalCoverageGlyphs(<int>[
        for (var index = 0; index < count; index++) _u16(base + 4 + index * 2),
      ]);
    }
    if (format == 2) {
      return TerminalCoverageRanges(<TerminalCoverageRange>[
        for (var index = 0; index < count; index++)
          TerminalCoverageRange(
            start: _u16(base + 4 + index * 6),
            end: _u16(base + 6 + index * 6),
            index: _u16(base + 8 + index * 6),
          ),
      ]);
    }
    throw FormatException('Unsupported coverage format $format');
  }

  TerminalGlyphClassTable _parseClassDefinition(int base) {
    final format = _u16(base);
    if (format != 2) return const TerminalGlyphClassTable([]);
    final count = _u16(base + 2);
    return TerminalGlyphClassTable(<TerminalGlyphClassRange>[
      for (var index = 0; index < count; index++)
        TerminalGlyphClassRange(
          start: _u16(base + 4 + index * 6),
          end: _u16(base + 6 + index * 6),
          classId: _u16(base + 8 + index * 6),
        ),
    ]);
  }

  ({List<TerminalSubstitutionLookupRecord> records, int end})
  _parseLookupRecords(int base) {
    final count = _u16(base);
    return (
      records: <TerminalSubstitutionLookupRecord>[
        for (var index = 0; index < count; index++)
          TerminalSubstitutionLookupRecord(
            sequenceIndex: _u16(base + 2 + index * 4),
            lookupListIndex: _u16(base + 4 + index * 4),
          ),
      ],
      end: base + 2 + count * 4,
    );
  }

  List<int> _readCountedU16(int base) {
    final count = _u16(base);
    return <int>[
      for (var index = 0; index < count; index++) _u16(base + 2 + index * 2),
    ];
  }

  int _u16(int offset) {
    _require(offset, 2);
    return data.getUint16(offset);
  }

  int _i16(int offset) {
    _require(offset, 2);
    return data.getInt16(offset);
  }

  int _u32(int offset) {
    _require(offset, 4);
    return data.getUint32(offset);
  }

  void _require(int offset, int byteLength) {
    if (offset < 0 || byteLength < 0 || offset + byteLength > length) {
      throw const FormatException('Truncated OpenType font');
    }
  }
}
