import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/ligature_tables.dart';

TerminalLigatureLookupResult _lookup(int glyph, [int index = 0]) =>
    TerminalLigatureLookupResult(
      substitutions: <int?>[glyph],
      length: 1,
      index: index,
      subIndex: 0,
      contextRange: const (0, 1),
    );

TerminalLigatureLookupEntry _entry(int glyph, [int index = 0]) =>
    TerminalLigatureLookupEntry(lookup: _lookup(glyph, index));

List<Object> _treeShape(TerminalLigatureLookupTree tree) => <Object>[
  <int, int?>{
    for (final item in tree.individual.entries)
      item.key: item.value.lookup?.substitutions.single,
  },
  <((int, int), int?)>[
    for (final item in tree.ranges)
      (item.range, item.entry.lookup?.substitutions.single),
  ],
];

void main() {
  test('combines disjoint trees', () {
    final result = mergeTerminalLigatureTrees(<TerminalLigatureLookupTree>[
      TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{1: _entry(1)},
      ),
      TerminalLigatureLookupTree(
        ranges: <TerminalLigatureLookupRange>[
          TerminalLigatureLookupRange((2, 4), _entry(2)),
        ],
      ),
      TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{5: _entry(3)},
      ),
      TerminalLigatureLookupTree(
        ranges: <TerminalLigatureLookupRange>[
          TerminalLigatureLookupRange((8, 10), _entry(4)),
        ],
      ),
    ]);
    expect(_treeShape(result), <Object>[
      <int, int?>{1: 1, 5: 3},
      <((int, int), int?)>[((2, 4), 2), ((8, 10), 4)],
    ]);
  });

  test('merges matching individual glyphs', () {
    final result = mergeTerminalLigatureTrees(<TerminalLigatureLookupTree>[
      TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{1: _entry(1, 1)},
      ),
      TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{1: _entry(2)},
      ),
      TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{1: _entry(3, 2)},
      ),
    ]);
    expect(_treeShape(result), <Object>[
      <int, int?>{1: 2},
      <Object>[],
    ]);
  });

  test('merges range glyphs overlapping individual glyphs', () {
    final result = mergeTerminalLigatureTrees(<TerminalLigatureLookupTree>[
      TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{1: _entry(1)},
      ),
      TerminalLigatureLookupTree(
        ranges: <TerminalLigatureLookupRange>[
          TerminalLigatureLookupRange((0, 4), _entry(2, 1)),
        ],
      ),
    ]);
    expect(_treeShape(result), <Object>[
      <int, int?>{1: 1, 0: 2},
      <((int, int), int?)>[((2, 4), 2)],
    ]);
  });

  test('merges individual glyphs overlapping range glyphs', () {
    final result = mergeTerminalLigatureTrees(<TerminalLigatureLookupTree>[
      TerminalLigatureLookupTree(
        ranges: <TerminalLigatureLookupRange>[
          TerminalLigatureLookupRange((0, 4), _entry(2, 1)),
        ],
      ),
      TerminalLigatureLookupTree(
        individual: <int, TerminalLigatureLookupEntry>{1: _entry(1)},
      ),
    ]);
    expect(_treeShape(result), <Object>[
      <int, int?>{1: 1, 0: 2},
      <((int, int), int?)>[((2, 4), 2)],
    ]);
  });

  test('merges multiple overlapping ranges', () {
    final result = mergeTerminalLigatureTrees(<TerminalLigatureLookupTree>[
      TerminalLigatureLookupTree(
        ranges: <TerminalLigatureLookupRange>[
          TerminalLigatureLookupRange((0, 3), _entry(1, 2)),
          TerminalLigatureLookupRange((6, 12), _entry(2, 1)),
          TerminalLigatureLookupRange((15, 20), _entry(5, 3)),
          TerminalLigatureLookupRange((20, 22), _entry(7, 4)),
        ],
      ),
      TerminalLigatureLookupTree(
        ranges: <TerminalLigatureLookupRange>[
          TerminalLigatureLookupRange((2, 8), _entry(3)),
          TerminalLigatureLookupRange((10, 13), _entry(4)),
          TerminalLigatureLookupRange((16, 21), _entry(6)),
        ],
      ),
    ]);
    expect(_treeShape(result), <Object>[
      <int, int?>{2: 3, 12: 4, 15: 5, 20: 6, 21: 7},
      <((int, int), int?)>[
        ((0, 2), 1),
        ((6, 8), 3),
        ((3, 6), 3),
        ((8, 10), 2),
        ((10, 12), 4),
        ((16, 20), 6),
      ],
    ]);
  });

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

  test('GSUB format 6.3 and 8.1 build contextual lookup trees', () {
    const one = TerminalCoverageGlyphs(<int>[1]);
    const two = TerminalCoverageGlyphs(<int>[2]);
    const three = TerminalCoverageGlyphs(<int>[3]);
    const zero = TerminalCoverageGlyphs(<int>[0]);
    const chaining = TerminalChainingCoverageTable(
      inputCoverage: <TerminalCoverageTable>[one, two],
      lookaheadCoverage: <TerminalCoverageTable>[three],
      backtrackCoverage: <TerminalCoverageTable>[zero],
      lookupRecords: <TerminalSubstitutionLookupRecord>[
        TerminalSubstitutionLookupRecord(
          sequenceIndex: 0,
          lookupListIndex: 0,
        ),
        TerminalSubstitutionLookupRecord(
          sequenceIndex: 1,
          lookupListIndex: 1,
        ),
      ],
    );
    final chainingTree = flattenTerminalLigatureTree(
      buildTerminalChainingCoverageTree(
        chaining,
        const <List<TerminalSubstitutionTable>>[
          <TerminalSubstitutionTable>[
            TerminalDeltaSubstitution(one, 10),
          ],
          <TerminalSubstitutionTable>[
            TerminalDeltaSubstitution(two, 20),
          ],
        ],
        7,
      ),
    );
    final match = walkTerminalLigatureTree(
      chainingTree,
      <int>[0, 1, 2, 3],
      1,
      1,
    );
    expect(match?.substitutions, <int?>[11, 22]);
    expect(match?.contextRange, (-1, 3));
    expect(match?.index, 7);

    const reverse = TerminalReverseChainingTable(
      coverage: TerminalCoverageGlyphs(<int>[5]),
      lookaheadCoverage: <TerminalCoverageTable>[
        TerminalCoverageGlyphs(<int>[6]),
      ],
      backtrackCoverage: <TerminalCoverageTable>[
        TerminalCoverageGlyphs(<int>[4]),
      ],
      substitutes: <int>[9],
    );
    final reverseTree = flattenTerminalLigatureTree(
      buildTerminalReverseChainingTree(reverse, 8),
    );
    final reverseMatch = walkTerminalLigatureTree(
      reverseTree,
      <int>[4, 5, 6],
      1,
      1,
    );
    expect(reverseMatch?.substitutions, <int?>[9]);
    expect(reverseMatch?.contextRange, (-1, 2));
    expect(reverseMatch?.index, 8);
  });

  test('GSUB format 6.1 and 6.2 build glyph and class lookup trees', () {
    const one = TerminalCoverageGlyphs(<int>[1]);
    const two = TerminalCoverageGlyphs(<int>[2]);
    const records = <TerminalSubstitutionLookupRecord>[
      TerminalSubstitutionLookupRecord(
        sequenceIndex: 0,
        lookupListIndex: 0,
      ),
      TerminalSubstitutionLookupRecord(
        sequenceIndex: 1,
        lookupListIndex: 1,
      ),
    ];
    const lookups = <List<TerminalSubstitutionTable>>[
      <TerminalSubstitutionTable>[TerminalDeltaSubstitution(one, 10)],
      <TerminalSubstitutionTable>[TerminalDeltaSubstitution(two, 20)],
    ];
    const glyphTable = TerminalChainingGlyphTable(
      coverage: one,
      chainRuleSets: <List<TerminalChainingGlyphRule>?>[
        <TerminalChainingGlyphRule>[
          TerminalChainingGlyphRule(
            backtrack: <int>[],
            input: <int>[2],
            lookahead: <int>[],
            lookupRecords: records,
          ),
        ],
      ],
    );
    final glyphTree = flattenTerminalLigatureTree(
      buildTerminalChainingGlyphTree(glyphTable, lookups, 6),
    );
    expect(
      walkTerminalLigatureTree(glyphTree, <int>[1, 2], 0, 0)?.substitutions,
      <int?>[11, 22],
    );

    const inputClasses = TerminalGlyphClassTable(<TerminalGlyphClassRange>[
      TerminalGlyphClassRange(start: 1, end: 1, classId: 1),
      TerminalGlyphClassRange(start: 2, end: 2, classId: 2),
    ]);
    const classTable = TerminalChainingClassTable(
      coverage: one,
      inputClassDefinition: inputClasses,
      lookaheadClassDefinition: inputClasses,
      backtrackClassDefinition: inputClasses,
      chainClassSets: <List<TerminalChainingClassRule>?>[
        null,
        <TerminalChainingClassRule>[
          TerminalChainingClassRule(
            backtrack: <int>[],
            input: <int>[2],
            lookahead: <int>[],
            lookupRecords: records,
          ),
        ],
      ],
    );
    final classTree = flattenTerminalLigatureTree(
      buildTerminalChainingClassTree(classTable, lookups, 7),
    );
    expect(
      walkTerminalLigatureTree(classTree, <int>[1, 2], 0, 0)?.substitutions,
      <int?>[11, 22],
    );
  });
}
