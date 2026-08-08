import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/ligature_tables.dart';

void main() {
  test('lookup trees flatten ranges and walk forward and reverse context', () {
    const direct = TerminalLigatureLookupResult(
      substitutions: <int?>[10],
      length: 1,
      index: 2,
      subIndex: 0,
      contextRange: (0, 1),
    );
    const contextual = TerminalLigatureLookupResult(
      substitutions: <int?>[11, 12],
      length: 2,
      index: 1,
      subIndex: 0,
      contextRange: (-1, 2),
    );
    final end = TerminalLigatureLookupEntry(lookup: contextual);
    final first = TerminalLigatureLookupEntry(
      lookup: direct,
      forward: TerminalLigatureLookupTree(
        ranges: <TerminalLigatureLookupRange>[
          TerminalLigatureLookupRange((2, 4), end),
        ],
      ),
    );
    final tree = flattenTerminalLigatureTree(
      TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{1: first},
      ),
    );
    expect(identical(tree[1]!.forward![2], tree[1]!.forward![3]), isTrue);
    expect(walkTerminalLigatureTree(tree, <int>[1, 3], 0, 0), contextual);

    final reverseRoot = TerminalLigatureLookupEntry(
      reverse: TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{
          8: TerminalLigatureLookupEntry(lookup: contextual),
        },
      ),
    );
    final reverseTree = flattenTerminalLigatureTree(
      TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{9: reverseRoot},
      ),
    );
    expect(
      walkTerminalLigatureTree(reverseTree, <int>[8, 9], 1, 1),
      contextual,
    );
  });

  test('coverage formats preserve glyph indexes and ranges', () {
    const glyphs = TerminalCoverageGlyphs(<int>[3, 8]);
    expect(terminalCoverageGlyphIndex(glyphs, 8), 1);
    expect(terminalCoverageGlyphIndex(glyphs, 9), isNull);
    expect(
      terminalCoverageGlyphs(glyphs),
      <({Object glyph, int index})>[(glyph: 3, index: 0), (glyph: 8, index: 1)],
    );

    const ranges = TerminalCoverageRanges(<TerminalCoverageRange>[
      TerminalCoverageRange(start: 10, end: 12, index: 4),
      TerminalCoverageRange(start: 20, end: 20, index: 7),
    ]);
    expect(terminalCoverageGlyphIndex(ranges, 11), 4);
    expect(
      terminalCoverageGlyphs(ranges),
      <({Object glyph, int index})>[
        (glyph: (10, 13), index: 0),
        (glyph: 20, index: 1),
      ],
    );
  });

  test('class definitions partition ranges when the class changes', () {
    const table = TerminalGlyphClassTable(<TerminalGlyphClassRange>[
      TerminalGlyphClassRange(start: 2, end: 3, classId: 1),
      TerminalGlyphClassRange(start: 4, end: 5, classId: 2),
    ]);
    expect(terminalIndividualGlyphClass(table, 3), 1);
    expect(terminalIndividualGlyphClass(table, 8), isNull);
    expect(terminalClassGlyphs(table, 2), <Object>[(4, 6)]);
    expect(
      terminalGlyphClasses(table, (2, 7)),
      <Object, int?>{(2, 4): 1, (2, 5): 1, (2, 6): 1, (2, 7): 1},
    );
  });

  test('single substitutions support delta, list and range partitioning', () {
    const coverage = TerminalCoverageGlyphs(<int>[1, 2, 3]);
    const delta = TerminalDeltaSubstitution(coverage, -2);
    expect(terminalSubstitutionGlyph(delta, 1), 0xffff);
    expect(terminalSubstitutionGlyph(delta, 8), isNull);

    const listed = TerminalListSubstitution(coverage, <int>[10, 10, 12]);
    expect(terminalSubstitutionGlyph(listed, 3), 12);
    expect(
      terminalRangeSubstitutionGlyphs(listed, (1, 5)),
      <Object, int?>{(1, 3): 10, (1, 4): 10, (1, 5): 10},
    );
  });
}
