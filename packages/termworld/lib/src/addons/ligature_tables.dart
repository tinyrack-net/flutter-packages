/// One glyph identifier or an end-exclusive glyph range.
typedef TerminalGlyphSelector = Object;

/// One OpenType coverage-table range (the end is inclusive).
final class TerminalCoverageRange {
  /// Creates a coverage range.
  const TerminalCoverageRange({
    required this.start,
    required this.end,
    required this.index,
  });

  /// First covered glyph.
  final int start;

  /// Last covered glyph, inclusive.
  final int end;

  /// Coverage index assigned to the range.
  final int index;
}

/// Parsed OpenType coverage table.
sealed class TerminalCoverageTable {
  const TerminalCoverageTable();
}

/// Coverage format 1, listing individual glyphs.
final class TerminalCoverageGlyphs extends TerminalCoverageTable {
  /// Creates a format 1 table.
  const TerminalCoverageGlyphs(this.glyphs);

  /// Glyphs in coverage-index order.
  final List<int> glyphs;
}

/// Coverage format 2, listing inclusive ranges.
final class TerminalCoverageRanges extends TerminalCoverageTable {
  /// Creates a format 2 table.
  const TerminalCoverageRanges(this.ranges);

  /// Covered glyph ranges.
  final List<TerminalCoverageRange> ranges;
}

/// Returns a glyph's coverage index, or null when it is absent.
int? terminalCoverageGlyphIndex(TerminalCoverageTable table, int glyphId) {
  switch (table) {
    case TerminalCoverageGlyphs(:final glyphs):
      final index = glyphs.indexOf(glyphId);
      return index == -1 ? null : index;
    case TerminalCoverageRanges(:final ranges):
      for (final range in ranges) {
        if (range.start <= glyphId && range.end >= glyphId) return range.index;
      }
      return null;
  }
}

/// Lists coverage selectors paired with their lookup index.
List<({TerminalGlyphSelector glyph, int index})> terminalCoverageGlyphs(
  TerminalCoverageTable table,
) {
  switch (table) {
    case TerminalCoverageGlyphs(:final glyphs):
      return <({TerminalGlyphSelector glyph, int index})>[
        for (var index = 0; index < glyphs.length; index++)
          (glyph: glyphs[index], index: index),
      ];
    case TerminalCoverageRanges(:final ranges):
      return <({TerminalGlyphSelector glyph, int index})>[
        for (var index = 0; index < ranges.length; index++)
          (
            glyph: ranges[index].start == ranges[index].end
                ? ranges[index].start
                : (ranges[index].start, ranges[index].end + 1),
            index: index,
          ),
      ];
  }
}

/// One OpenType class-definition range (the end is inclusive).
final class TerminalGlyphClassRange {
  /// Creates a glyph class range.
  const TerminalGlyphClassRange({
    required this.start,
    required this.end,
    required this.classId,
  });

  /// First glyph in this class.
  final int start;

  /// Last glyph in this class, inclusive.
  final int end;

  /// OpenType class identifier.
  final int classId;
}

/// Parsed class-definition format 2 table.
final class TerminalGlyphClassTable {
  /// Creates a class-definition table.
  const TerminalGlyphClassTable(this.ranges);

  /// Ranges in font order.
  final List<TerminalGlyphClassRange> ranges;
}

/// Finds the class assigned to one glyph.
int? terminalIndividualGlyphClass(
  TerminalGlyphClassTable table,
  int glyphId,
) {
  for (final range in table.ranges) {
    if (range.start <= glyphId && range.end >= glyphId) return range.classId;
  }
  return null;
}

/// Lists glyph selectors assigned to [classId].
List<TerminalGlyphSelector> terminalClassGlyphs(
  TerminalGlyphClassTable table,
  int classId,
) => <TerminalGlyphSelector>[
  for (final range in table.ranges)
    if (range.classId == classId)
      range.start == range.end ? range.start : (range.start, range.end + 1),
];

/// Maps a selector to its class, retaining xterm's selector partitioning.
Map<TerminalGlyphSelector, int?> terminalGlyphClasses(
  TerminalGlyphClassTable table,
  TerminalGlyphSelector selector,
) {
  if (selector is int) {
    return <TerminalGlyphSelector, int?>{
      selector: terminalIndividualGlyphClass(table, selector),
    };
  }
  final range = selector as (int, int);
  final result = <TerminalGlyphSelector, int?>{};
  var classStart = range.$1;
  var currentClass = terminalIndividualGlyphClass(table, classStart);
  for (var glyph = range.$1 + 1; glyph < range.$2; glyph++) {
    final nextClass = terminalIndividualGlyphClass(table, glyph);
    if (nextClass == currentClass) continue;
    result[glyph - classStart <= 1 ? classStart : (classStart, glyph)] =
        currentClass;
    classStart = glyph;
    currentClass = nextClass;
  }
  result[range.$2 - classStart <= 1 ? classStart : (classStart, range.$2)] =
      currentClass;
  return result;
}

/// Parsed OpenType single-substitution table.
sealed class TerminalSubstitutionTable {
  const TerminalSubstitutionTable(this.coverage);

  /// Glyphs to which the substitution applies.
  final TerminalCoverageTable coverage;
}

/// Single-substitution format 1 using a glyph delta.
final class TerminalDeltaSubstitution extends TerminalSubstitutionTable {
  /// Creates a delta substitution.
  const TerminalDeltaSubstitution(super.coverage, this.deltaGlyphId);

  /// Signed substitution delta.
  final int deltaGlyphId;
}

/// Single-substitution format 2 using explicit replacement glyphs.
final class TerminalListSubstitution extends TerminalSubstitutionTable {
  /// Creates a replacement-list substitution.
  const TerminalListSubstitution(super.coverage, this.substitutes);

  /// Replacements in coverage-index order.
  final List<int> substitutes;
}

/// Returns the replacement for [glyphId], or null when it is not covered.
int? terminalSubstitutionGlyph(
  TerminalSubstitutionTable table,
  int glyphId,
) {
  final coverageIndex = terminalCoverageGlyphIndex(table.coverage, glyphId);
  if (coverageIndex == null) return null;
  return switch (table) {
    TerminalDeltaSubstitution(:final deltaGlyphId) =>
      (glyphId + deltaGlyphId) % 0x10000,
    TerminalListSubstitution(:final substitutes) =>
      coverageIndex < substitutes.length ? substitutes[coverageIndex] : null,
  };
}

/// Partitions [range] by replacement result.
Map<TerminalGlyphSelector, int?> terminalRangeSubstitutionGlyphs(
  TerminalSubstitutionTable table,
  (int, int) range,
) {
  final result = <TerminalGlyphSelector, int?>{};
  var segmentStart = range.$1;
  var current = terminalSubstitutionGlyph(table, segmentStart);
  for (var glyph = range.$1 + 1; glyph < range.$2; glyph++) {
    final next = terminalSubstitutionGlyph(table, glyph);
    if (next == current) continue;
    result[glyph - segmentStart <= 1 ? segmentStart : (segmentStart, glyph)] =
        current;
    segmentStart = glyph;
    current = next;
  }
  result[range.$2 - segmentStart <= 1
          ? segmentStart
          : (segmentStart, range.$2)] =
      current;
  return result;
}
