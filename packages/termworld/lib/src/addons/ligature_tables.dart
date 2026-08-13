import 'dart:collection';

/// One glyph identifier or an end-exclusive glyph range.
typedef TerminalGlyphSelector = Object;

/// A substitution match stored in an OpenType lookup tree.
final class TerminalLigatureLookupResult {
  /// Creates a lookup result.
  const TerminalLigatureLookupResult({
    required this.substitutions,
    required this.length,
    required this.index,
    required this.subIndex,
    required this.contextRange,
  });

  /// Replacement glyphs, with null retaining the input glyph.
  final List<int?> substitutions;

  /// Number of input glyphs consumed.
  final int length;

  /// Parent lookup order.
  final int index;

  /// Subtable order within the parent lookup.
  final int subIndex;

  /// Context range relative to the match start.
  final (int, int) contextRange;
}

/// One node before lookup-tree ranges have been expanded.
final class TerminalLigatureLookupEntry {
  /// Creates an empty lookup node.
  TerminalLigatureLookupEntry({this.lookup, this.forward, this.reverse});

  /// Best substitution terminating at this node.
  TerminalLigatureLookupResult? lookup;

  /// Glyphs following the current position.
  TerminalLigatureLookupTree? forward;

  /// Glyphs preceding the match start.
  TerminalLigatureLookupTree? reverse;
}

/// One end-exclusive glyph range sharing a lookup entry.
final class TerminalLigatureLookupRange {
  /// Creates a ranged lookup edge.
  const TerminalLigatureLookupRange(this.range, this.entry);

  /// End-exclusive glyph range.
  final (int, int) range;

  /// Entry shared by every glyph in [range].
  final TerminalLigatureLookupEntry entry;
}

/// Sparse OpenType lookup tree before range expansion.
final class TerminalLigatureLookupTree {
  /// Creates an empty or populated tree.
  TerminalLigatureLookupTree({
    Map<int, TerminalLigatureLookupEntry>? individual,
    List<TerminalLigatureLookupRange>? ranges,
  }) : individual = individual ?? <int, TerminalLigatureLookupEntry>{},
       ranges = ranges ?? <TerminalLigatureLookupRange>[];

  /// Edges for individual glyph identifiers.
  final Map<int, TerminalLigatureLookupEntry> individual;

  /// Edges shared by glyph ranges.
  final List<TerminalLigatureLookupRange> ranges;
}

/// Merges lookup trees using xterm's lookup/subtable priority rules.
TerminalLigatureLookupTree mergeTerminalLigatureTrees(
  List<TerminalLigatureLookupTree> trees,
) {
  final result = TerminalLigatureLookupTree();
  final mergedEntries =
      HashMap<
        TerminalLigatureLookupEntry,
        Set<TerminalLigatureLookupEntry>
      >.identity();
  for (final tree in trees) {
    _mergeTerminalLigatureSubtree(result, tree, mergedEntries);
  }
  return result;
}

void _mergeTerminalLigatureSubtree(
  TerminalLigatureLookupTree mainTree,
  TerminalLigatureLookupTree mergeTree,
  Map<TerminalLigatureLookupEntry, Set<TerminalLigatureLookupEntry>> merged,
) {
  for (final item in mergeTree.individual.entries) {
    final glyph = item.key;
    final value = item.value;
    final existing = mainTree.individual[glyph];
    if (existing != null) {
      _mergeTerminalLigatureEntry(existing, value, merged);
      continue;
    }
    var matched = false;
    for (var index = 0; index < mainTree.ranges.length; index++) {
      final ranged = mainTree.ranges[index];
      final overlap = _terminalIndividualOverlap(glyph, ranged.range);
      if (overlap.both == null) continue;
      matched = true;
      final target = _cloneTerminalLigatureEntry(ranged.entry);
      mainTree.individual[glyph] = value;
      _mergeTerminalLigatureEntry(value, target, merged);
      mainTree.ranges.removeAt(index);
      index--;
      _addTerminalSelectors(mainTree, overlap.second, ranged.entry);
    }
    if (!matched) mainTree.individual[glyph] = value;
  }

  for (final rangedToMerge in mergeTree.ranges) {
    var remaining = <TerminalGlyphSelector>[rangedToMerge.range];
    for (var index = 0; index < mainTree.ranges.length; index++) {
      final current = mainTree.ranges[index];
      for (
        var remainingIndex = 0;
        remainingIndex < remaining.length;
        remainingIndex++
      ) {
        final selector = remaining[remainingIndex];
        if (selector is (int, int)) {
          final overlap = _terminalRangeOverlap(selector, current.range);
          if (overlap.both == null) continue;
          mainTree.ranges.removeAt(index);
          index--;
          final entry = _cloneTerminalLigatureEntry(current.entry);
          _addTerminalSelector(mainTree, overlap.both!, entry);
          _mergeTerminalLigatureEntry(
            entry,
            _cloneTerminalLigatureEntry(rangedToMerge.entry),
            merged,
          );
          _addTerminalSelectors(mainTree, overlap.second, current.entry);
          remaining = overlap.first;
        } else {
          final glyph = selector as int;
          final overlap = _terminalIndividualOverlap(glyph, current.range);
          if (overlap.both == null) continue;
          final entry = _cloneTerminalLigatureEntry(rangedToMerge.entry);
          mainTree.individual[glyph] = entry;
          _mergeTerminalLigatureEntry(
            entry,
            _cloneTerminalLigatureEntry(current.entry),
            merged,
          );
          mainTree.ranges.removeAt(index);
          index--;
          _addTerminalSelectors(mainTree, overlap.second, current.entry);
          remaining
            ..removeAt(remainingIndex)
            ..insertAll(remainingIndex, overlap.first);
          break;
        }
      }
    }
    for (final glyph in mainTree.individual.keys.toList()) {
      for (var index = 0; index < remaining.length; index++) {
        final selector = remaining[index];
        if (selector is (int, int)) {
          final overlap = _terminalIndividualOverlap(glyph, selector);
          if (overlap.both == null) continue;
          _mergeTerminalLigatureEntry(
            mainTree.individual[glyph]!,
            _cloneTerminalLigatureEntry(rangedToMerge.entry),
            merged,
          );
          remaining
            ..removeAt(index)
            ..insertAll(index, overlap.second);
          break;
        }
        if (glyph == selector) {
          _mergeTerminalLigatureEntry(
            mainTree.individual[glyph]!,
            _cloneTerminalLigatureEntry(rangedToMerge.entry),
            merged,
          );
          break;
        }
      }
    }
    _addTerminalSelectors(mainTree, remaining, rangedToMerge.entry);
  }
}

void _mergeTerminalLigatureEntry(
  TerminalLigatureLookupEntry mainEntry,
  TerminalLigatureLookupEntry mergeEntry,
  Map<TerminalLigatureLookupEntry, Set<TerminalLigatureLookupEntry>> merged,
) {
  final mergedSet = merged.putIfAbsent(
    mainEntry,
    HashSet<TerminalLigatureLookupEntry>.identity,
  );
  if (!mergedSet.add(mergeEntry)) return;
  final incoming = mergeEntry.lookup;
  final current = mainEntry.lookup;
  if (incoming != null &&
      (current == null ||
          current.index > incoming.index ||
          current.index == incoming.index &&
              current.subIndex > incoming.subIndex)) {
    mainEntry.lookup = incoming;
  }
  final incomingForward = mergeEntry.forward;
  if (incomingForward != null) {
    final currentForward = mainEntry.forward;
    if (currentForward == null) {
      mainEntry.forward = incomingForward;
    } else {
      _mergeTerminalLigatureSubtree(currentForward, incomingForward, merged);
    }
  }
  final incomingReverse = mergeEntry.reverse;
  if (incomingReverse != null) {
    final currentReverse = mainEntry.reverse;
    if (currentReverse == null) {
      mainEntry.reverse = incomingReverse;
    } else {
      _mergeTerminalLigatureSubtree(currentReverse, incomingReverse, merged);
    }
  }
}

typedef _TerminalRangeOverlap = ({
  List<TerminalGlyphSelector> first,
  List<TerminalGlyphSelector> second,
  TerminalGlyphSelector? both,
});

_TerminalRangeOverlap _terminalRangeOverlap(
  (int, int) first,
  (int, int) second,
) {
  final firstOnly = <TerminalGlyphSelector>[];
  final secondOnly = <TerminalGlyphSelector>[];
  TerminalGlyphSelector? both;
  if (first.$1 < second.$2 && second.$1 < first.$2) {
    both = _terminalRangeOrIndividual(
      first.$1 > second.$1 ? first.$1 : second.$1,
      first.$2 < second.$2 ? first.$2 : second.$2,
    );
  }
  if (first.$1 < second.$1) {
    firstOnly.add(
      _terminalRangeOrIndividual(
        first.$1,
        second.$1 < first.$2 ? second.$1 : first.$2,
      ),
    );
  } else if (second.$1 < first.$1) {
    secondOnly.add(
      _terminalRangeOrIndividual(
        second.$1,
        second.$2 < first.$1 ? second.$2 : first.$1,
      ),
    );
  }
  if (first.$2 > second.$2) {
    firstOnly.add(
      _terminalRangeOrIndividual(
        first.$1 > second.$2 ? first.$1 : second.$2,
        first.$2,
      ),
    );
  } else if (second.$2 > first.$2) {
    secondOnly.add(
      _terminalRangeOrIndividual(
        first.$2 > second.$1 ? first.$2 : second.$1,
        second.$2,
      ),
    );
  }
  return (first: firstOnly, second: secondOnly, both: both);
}

_TerminalRangeOverlap _terminalIndividualOverlap(
  int first,
  (int, int) second,
) {
  if (first < second.$1 || first > second.$2) {
    return (
      first: <TerminalGlyphSelector>[first],
      second: [second],
      both: null,
    );
  }
  final secondOnly = <TerminalGlyphSelector>[];
  if (second.$1 < first) {
    secondOnly.add(_terminalRangeOrIndividual(second.$1, first));
  }
  if (second.$2 > first) {
    secondOnly.add(_terminalRangeOrIndividual(first + 1, second.$2));
  }
  return (
    first: const <TerminalGlyphSelector>[],
    second: secondOnly,
    both: first,
  );
}

TerminalGlyphSelector _terminalRangeOrIndividual(int start, int end) =>
    end - start == 1 ? start : (start, end);

void _addTerminalSelectors(
  TerminalLigatureLookupTree tree,
  Iterable<TerminalGlyphSelector> selectors,
  TerminalLigatureLookupEntry entry,
) {
  for (final selector in selectors) {
    _addTerminalSelector(tree, selector, _cloneTerminalLigatureEntry(entry));
  }
}

void _addTerminalSelector(
  TerminalLigatureLookupTree tree,
  TerminalGlyphSelector selector,
  TerminalLigatureLookupEntry entry,
) {
  if (selector is int) {
    tree.individual[selector] = entry;
  } else {
    tree.ranges.add(TerminalLigatureLookupRange(selector as (int, int), entry));
  }
}

TerminalLigatureLookupEntry _cloneTerminalLigatureEntry(
  TerminalLigatureLookupEntry entry, [
  Map<TerminalLigatureLookupEntry, TerminalLigatureLookupEntry>? visited,
]) {
  final known =
      visited ??
      HashMap<
        TerminalLigatureLookupEntry,
        TerminalLigatureLookupEntry
      >.identity();
  final cached = known[entry];
  if (cached != null) return cached;
  final result = TerminalLigatureLookupEntry(lookup: entry.lookup);
  known[entry] = result;
  final forward = entry.forward;
  if (forward != null) {
    result.forward = _cloneTerminalLigatureTree(forward, known);
  }
  final reverse = entry.reverse;
  if (reverse != null) {
    result.reverse = _cloneTerminalLigatureTree(reverse, known);
  }
  return result;
}

TerminalLigatureLookupTree _cloneTerminalLigatureTree(
  TerminalLigatureLookupTree tree,
  Map<TerminalLigatureLookupEntry, TerminalLigatureLookupEntry> visited,
) => TerminalLigatureLookupTree(
  individual: <int, TerminalLigatureLookupEntry>{
    for (final item in tree.individual.entries)
      item.key: _cloneTerminalLigatureEntry(item.value, visited),
  },
  ranges: <TerminalLigatureLookupRange>[
    for (final item in tree.ranges)
      TerminalLigatureLookupRange(
        item.range,
        _cloneTerminalLigatureEntry(item.entry, visited),
      ),
  ],
);

/// One lookup node after range expansion.
final class TerminalFlattenedLigatureEntry {
  /// Best substitution terminating at this node.
  TerminalLigatureLookupResult? lookup;

  /// Expanded following-glyph edges.
  Map<int, TerminalFlattenedLigatureEntry>? forward;

  /// Expanded preceding-glyph edges.
  Map<int, TerminalFlattenedLigatureEntry>? reverse;
}

/// Expands ranged glyph edges while preserving shared/cyclic entry identity.
Map<int, TerminalFlattenedLigatureEntry> flattenTerminalLigatureTree(
  TerminalLigatureLookupTree tree, [
  Map<TerminalLigatureLookupEntry, TerminalFlattenedLigatureEntry>? visited,
]) {
  final known =
      visited ??
      HashMap<
        TerminalLigatureLookupEntry,
        TerminalFlattenedLigatureEntry
      >.identity();
  final result = <int, TerminalFlattenedLigatureEntry>{};
  for (final MapEntry(key: glyph, value: entry) in tree.individual.entries) {
    result[glyph] = _flattenTerminalLigatureEntry(entry, known);
  }
  for (final ranged in tree.ranges) {
    final flattened = _flattenTerminalLigatureEntry(ranged.entry, known);
    for (var glyph = ranged.range.$1; glyph < ranged.range.$2; glyph++) {
      result[glyph] = flattened;
    }
  }
  return result;
}

TerminalFlattenedLigatureEntry _flattenTerminalLigatureEntry(
  TerminalLigatureLookupEntry entry,
  Map<TerminalLigatureLookupEntry, TerminalFlattenedLigatureEntry> visited,
) {
  final existing = visited[entry];
  if (existing != null) return existing;
  final result = TerminalFlattenedLigatureEntry();
  visited[entry] = result;
  final forward = entry.forward;
  if (forward != null) {
    result.forward = flattenTerminalLigatureTree(forward, visited);
  }
  final reverse = entry.reverse;
  if (reverse != null) {
    result.reverse = flattenTerminalLigatureTree(reverse, visited);
  }
  result.lookup = entry.lookup;
  return result;
}

/// Walks a flattened lookup tree and returns the highest-priority match.
TerminalLigatureLookupResult? walkTerminalLigatureTree(
  Map<int, TerminalFlattenedLigatureEntry> tree,
  List<int> sequence,
  int startIndex,
  int index,
) {
  if (index < 0 || index >= sequence.length) return null;
  final subtree = tree[sequence[index]];
  if (subtree == null) return null;
  var lookup = subtree.lookup;
  final reverse = subtree.reverse;
  if (reverse != null) {
    final reverseLookup = _walkTerminalLigatureReverse(
      reverse,
      sequence,
      startIndex,
    );
    if (_preferTerminalLigatureLookup(reverseLookup, lookup)) {
      lookup = reverseLookup;
    }
  }
  final nextIndex = index + 1;
  final forward = subtree.forward;
  if (nextIndex >= sequence.length || forward == null) return lookup;
  final forwardLookup = walkTerminalLigatureTree(
    forward,
    sequence,
    startIndex,
    nextIndex,
  );
  if (_preferTerminalLigatureLookup(forwardLookup, lookup)) {
    lookup = forwardLookup;
  }
  return lookup;
}

TerminalLigatureLookupResult? _walkTerminalLigatureReverse(
  Map<int, TerminalFlattenedLigatureEntry> tree,
  List<int> sequence,
  int index,
) {
  var cursor = index - 1;
  if (cursor < 0) return null;
  var subtree = tree[sequence[cursor]];
  var lookup = subtree?.lookup;
  while (subtree != null) {
    final candidate = subtree.lookup;
    if (candidate != null &&
        (lookup == null || lookup.index > candidate.index)) {
      lookup = candidate;
    }
    cursor--;
    final reverse = subtree.reverse;
    if (cursor < 0 || reverse == null) break;
    subtree = reverse[sequence[cursor]];
  }
  return lookup;
}

bool _preferTerminalLigatureLookup(
  TerminalLigatureLookupResult? candidate,
  TerminalLigatureLookupResult? current,
) =>
    candidate != null &&
    (current == null ||
        current.index > candidate.index ||
        current.index == candidate.index &&
            current.subIndex > candidate.subIndex);

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
      if (range.start == range.end)
        range.start
      else
        (range.start, range.end + 1),
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
  final classStart = range.$1;
  final currentClass = terminalIndividualGlyphClass(table, classStart);
  for (var glyph = range.$1 + 1; glyph < range.$2; glyph++) {
    final nextClass = terminalIndividualGlyphClass(table, glyph);
    if (nextClass == currentClass) continue;
    result[glyph - classStart <= 1 ? classStart : (classStart, glyph)] =
        currentClass;
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
  final segmentStart = range.$1;
  final current = terminalSubstitutionGlyph(table, segmentStart);
  for (var glyph = range.$1 + 1; glyph < range.$2; glyph++) {
    final next = terminalSubstitutionGlyph(table, glyph);
    if (next == current) continue;
    result[glyph - segmentStart <= 1 ? segmentStart : (segmentStart, glyph)] =
        current;
  }
  result[range.$2 - segmentStart <= 1
          ? segmentStart
          : (segmentStart, range.$2)] =
      current;
  return result;
}

/// One GSUB contextual substitution lookup reference.
final class TerminalSubstitutionLookupRecord {
  /// Creates a reference to a single-substitution lookup.
  const TerminalSubstitutionLookupRecord({
    required this.sequenceIndex,
    required this.lookupListIndex,
  });

  /// Input position to replace.
  final int sequenceIndex;

  /// Index in the font's lookup list.
  final int lookupListIndex;
}

/// Temporary tree entry and the substitutions accumulated along its path.
final class TerminalLigatureEntryMetadata {
  /// Creates path metadata.
  const TerminalLigatureEntryMetadata(this.entry, this.substitutions);

  /// Current lookup-tree node.
  final TerminalLigatureLookupEntry entry;

  /// Replacement glyph for each input position.
  final List<int?> substitutions;
}

/// A GSUB format 6.3 coverage-based chaining-context table.
final class TerminalChainingCoverageTable {
  /// Creates a coverage-based chaining table.
  const TerminalChainingCoverageTable({
    required this.inputCoverage,
    required this.lookaheadCoverage,
    required this.backtrackCoverage,
    required this.lookupRecords,
  });

  /// Coverage for each consumed input position.
  final List<TerminalCoverageTable> inputCoverage;

  /// Coverage following the consumed input.
  final List<TerminalCoverageTable> lookaheadCoverage;

  /// Coverage preceding the consumed input.
  final List<TerminalCoverageTable> backtrackCoverage;

  /// Substitutions applied to the input positions.
  final List<TerminalSubstitutionLookupRecord> lookupRecords;
}

/// One glyph-based GSUB format 6.1 chaining rule.
final class TerminalChainingGlyphRule {
  /// Creates a glyph-context rule.
  const TerminalChainingGlyphRule({
    required this.backtrack,
    required this.input,
    required this.lookahead,
    required this.lookupRecords,
  });

  /// Preceding glyphs, nearest first.
  final List<int> backtrack;

  /// Consumed glyphs after the coverage glyph.
  final List<int> input;

  /// Required following glyphs.
  final List<int> lookahead;

  /// Substitutions applied to input positions.
  final List<TerminalSubstitutionLookupRecord> lookupRecords;
}

/// A GSUB format 6.1 simple-glyph chaining-context table.
final class TerminalChainingGlyphTable {
  /// Creates a glyph-context table.
  const TerminalChainingGlyphTable({
    required this.coverage,
    required this.chainRuleSets,
  });

  /// First input glyphs.
  final TerminalCoverageTable coverage;

  /// Rules indexed by coverage position; null represents an absent rule set.
  final List<List<TerminalChainingGlyphRule>?> chainRuleSets;
}

/// One class-based GSUB format 6.2 chaining rule.
final class TerminalChainingClassRule {
  /// Creates a class-context rule.
  const TerminalChainingClassRule({
    required this.backtrack,
    required this.input,
    required this.lookahead,
    required this.lookupRecords,
  });

  /// Preceding class identifiers, nearest first.
  final List<int> backtrack;

  /// Consumed class identifiers after the first input glyph.
  final List<int> input;

  /// Required following class identifiers.
  final List<int> lookahead;

  /// Substitutions applied to input positions.
  final List<TerminalSubstitutionLookupRecord> lookupRecords;
}

/// A GSUB format 6.2 class-based chaining-context table.
final class TerminalChainingClassTable {
  /// Creates a class-context table.
  const TerminalChainingClassTable({
    required this.coverage,
    required this.inputClassDefinition,
    required this.lookaheadClassDefinition,
    required this.backtrackClassDefinition,
    required this.chainClassSets,
  });

  /// First input glyph coverage.
  final TerminalCoverageTable coverage;

  /// Class assignment for consumed inputs.
  final TerminalGlyphClassTable inputClassDefinition;

  /// Class assignment for following context.
  final TerminalGlyphClassTable lookaheadClassDefinition;

  /// Class assignment for preceding context.
  final TerminalGlyphClassTable backtrackClassDefinition;

  /// Rules indexed by the first input's class.
  final List<List<TerminalChainingClassRule>?> chainClassSets;
}

/// A GSUB format 8.1 reverse-chaining single-substitution table.
final class TerminalReverseChainingTable {
  /// Creates a reverse chaining table.
  const TerminalReverseChainingTable({
    required this.coverage,
    required this.lookaheadCoverage,
    required this.backtrackCoverage,
    required this.substitutes,
  });

  /// Glyphs replaced by this lookup.
  final TerminalCoverageTable coverage;

  /// Required following context.
  final List<TerminalCoverageTable> lookaheadCoverage;

  /// Required preceding context.
  final List<TerminalCoverageTable> backtrackCoverage;

  /// Replacements in coverage order.
  final List<int> substitutes;
}

/// Node and optional replacement produced while adding an input selector.
typedef TerminalInputTreeResult = ({
  TerminalLigatureLookupEntry entry,
  int? substitution,
});

/// Adds one input selector to a lookup tree and resolves its substitution.
List<TerminalInputTreeResult> terminalLigatureInputTree(
  TerminalLigatureLookupTree tree,
  List<TerminalSubstitutionLookupRecord> substitutions,
  List<List<TerminalSubstitutionTable>> lookups,
  int inputIndex,
  TerminalGlyphSelector glyph,
) {
  final result = <TerminalInputTreeResult>[];
  if (glyph is int) {
    final entry = TerminalLigatureLookupEntry();
    tree.individual[glyph] = entry;
    result.add((
      entry: entry,
      substitution: _terminalSubstitutionAtPosition(
        substitutions,
        lookups,
        inputIndex,
        glyph,
      ),
    ));
    return result;
  }
  final range = glyph as (int, int);
  final rangeSubstitutions = _terminalSubstitutionAtPositionRange(
    substitutions,
    lookups,
    inputIndex,
    range,
  );
  for (final item in rangeSubstitutions.entries) {
    final entry = TerminalLigatureLookupEntry();
    final selector = item.key;
    if (selector is (int, int)) {
      tree.ranges.add(TerminalLigatureLookupRange(selector, entry));
    } else {
      // Preserve the pinned xterm implementation's detached range-individual
      // entry behavior here; lookup traversal observes this exact structure.
      tree.individual[selector as int] = TerminalLigatureLookupEntry();
    }
    result.add((entry: entry, substitution: item.value));
  }
  return result;
}

/// Extends lookup paths with a consumed input position.
List<TerminalLigatureEntryMetadata> terminalProcessInputPosition(
  List<TerminalGlyphSelector> glyphs,
  int position,
  List<TerminalLigatureEntryMetadata> currentEntries,
  List<TerminalSubstitutionLookupRecord> lookupRecords,
  List<List<TerminalSubstitutionTable>> lookups,
) {
  final nextEntries = <TerminalLigatureEntryMetadata>[];
  for (final current in currentEntries) {
    final forward = TerminalLigatureLookupTree();
    current.entry.forward = forward;
    for (final glyph in glyphs) {
      for (final next in terminalLigatureInputTree(
        forward,
        lookupRecords,
        lookups,
        position,
        glyph,
      )) {
        nextEntries.add(
          TerminalLigatureEntryMetadata(next.entry, <int?>[
            ...current.substitutions,
            next.substitution,
          ]),
        );
      }
    }
  }
  return nextEntries;
}

/// Extends lookup paths with a non-consuming lookahead position.
List<TerminalLigatureEntryMetadata> terminalProcessLookaheadPosition(
  List<TerminalGlyphSelector> glyphs,
  List<TerminalLigatureEntryMetadata> currentEntries,
) => _terminalProcessContextPosition(glyphs, currentEntries, reverse: false);

/// Extends lookup paths with a non-consuming backtrack position.
List<TerminalLigatureEntryMetadata> terminalProcessBacktrackPosition(
  List<TerminalGlyphSelector> glyphs,
  List<TerminalLigatureEntryMetadata> currentEntries,
) => _terminalProcessContextPosition(glyphs, currentEntries, reverse: true);

List<TerminalLigatureEntryMetadata> _terminalProcessContextPosition(
  List<TerminalGlyphSelector> glyphs,
  List<TerminalLigatureEntryMetadata> currentEntries, {
  required bool reverse,
}) {
  final nextEntries = <TerminalLigatureEntryMetadata>[];
  final processed = HashSet<TerminalLigatureLookupEntry>.identity();
  for (final current in currentEntries) {
    if (!processed.add(current.entry)) continue;
    final tree = reverse
        ? (current.entry.reverse ??= TerminalLigatureLookupTree())
        : (current.entry.forward ??= TerminalLigatureLookupTree());
    final sharedEntry = TerminalLigatureLookupEntry();
    for (final glyph in glyphs) {
      if (glyph is (int, int)) {
        tree.ranges.add(TerminalLigatureLookupRange(glyph, sharedEntry));
      } else {
        tree.individual[glyph as int] = sharedEntry;
      }
    }
    nextEntries.add(
      TerminalLigatureEntryMetadata(sharedEntry, current.substitutions),
    );
  }
  return nextEntries;
}

/// Builds xterm's GSUB type 6 format 3 lookup tree.
TerminalLigatureLookupTree buildTerminalChainingCoverageTree(
  TerminalChainingCoverageTable table,
  List<List<TerminalSubstitutionTable>> lookups,
  int tableIndex,
) {
  final result = TerminalLigatureLookupTree();
  final firstCoverage = table.inputCoverage.first;
  for (final first in terminalCoverageGlyphs(firstCoverage)) {
    var current =
        terminalLigatureInputTree(
              result,
              table.lookupRecords,
              lookups,
              0,
              first.glyph,
            )
            .map(
              (item) => TerminalLigatureEntryMetadata(
                item.entry,
                <int?>[item.substitution],
              ),
            )
            .toList();
    for (var index = 1; index < table.inputCoverage.length; index++) {
      current = terminalProcessInputPosition(
        terminalCoverageGlyphs(
          table.inputCoverage[index],
        ).map((item) => item.glyph).toList(),
        index,
        current,
        table.lookupRecords,
        lookups,
      );
    }
    for (final coverage in table.lookaheadCoverage) {
      current = terminalProcessLookaheadPosition(
        terminalCoverageGlyphs(coverage).map((item) => item.glyph).toList(),
        current,
      );
    }
    for (final coverage in table.backtrackCoverage) {
      current = terminalProcessBacktrackPosition(
        terminalCoverageGlyphs(coverage).map((item) => item.glyph).toList(),
        current,
      );
    }
    for (final metadata in current) {
      metadata.entry.lookup = TerminalLigatureLookupResult(
        substitutions: metadata.substitutions,
        length: table.inputCoverage.length,
        index: tableIndex,
        subIndex: 0,
        contextRange: (
          -table.backtrackCoverage.length,
          table.inputCoverage.length + table.lookaheadCoverage.length,
        ),
      );
    }
  }
  return result;
}

/// Builds xterm's GSUB type 6 format 1 lookup tree.
TerminalLigatureLookupTree buildTerminalChainingGlyphTree(
  TerminalChainingGlyphTable table,
  List<List<TerminalSubstitutionTable>> lookups,
  int tableIndex,
) {
  final result = TerminalLigatureLookupTree();
  for (final first in terminalCoverageGlyphs(table.coverage)) {
    final rules = table.chainRuleSets[first.index];
    if (rules == null) continue;
    for (var subIndex = 0; subIndex < rules.length; subIndex++) {
      final rule = rules[subIndex];
      var current =
          terminalLigatureInputTree(
                result,
                rule.lookupRecords,
                lookups,
                0,
                first.glyph,
              )
              .map(
                (item) => TerminalLigatureEntryMetadata(
                  item.entry,
                  <int?>[item.substitution],
                ),
              )
              .toList();
      for (var index = 0; index < rule.input.length; index++) {
        current = terminalProcessInputPosition(
          <TerminalGlyphSelector>[rule.input[index]],
          index + 1,
          current,
          rule.lookupRecords,
          lookups,
        );
      }
      for (final glyph in rule.lookahead) {
        current = terminalProcessLookaheadPosition(
          <TerminalGlyphSelector>[glyph],
          current,
        );
      }
      for (final glyph in rule.backtrack) {
        current = terminalProcessBacktrackPosition(
          <TerminalGlyphSelector>[glyph],
          current,
        );
      }
      _terminalFinishChainingEntries(
        current,
        inputLength: rule.input.length + 1,
        lookaheadLength: rule.lookahead.length,
        backtrackLength: rule.backtrack.length,
        tableIndex: tableIndex,
        subIndex: subIndex,
      );
    }
  }
  return result;
}

/// Builds xterm's GSUB type 6 format 2 lookup tree.
TerminalLigatureLookupTree buildTerminalChainingClassTree(
  TerminalChainingClassTable table,
  List<List<TerminalSubstitutionTable>> lookups,
  int tableIndex,
) {
  final results = <TerminalLigatureLookupTree>[];
  for (final first in terminalCoverageGlyphs(table.coverage)) {
    final classes = terminalGlyphClasses(
      table.inputClassDefinition,
      first.glyph,
    );
    for (final classEntry in classes.entries) {
      final inputClass = classEntry.value;
      if (inputClass == null) continue;
      final rules = table.chainClassSets[inputClass];
      if (rules == null) continue;
      for (var subIndex = 0; subIndex < rules.length; subIndex++) {
        final rule = rules[subIndex];
        final result = TerminalLigatureLookupTree();
        var current =
            terminalLigatureInputTree(
                  result,
                  rule.lookupRecords,
                  lookups,
                  0,
                  classEntry.key,
                )
                .map(
                  (item) => TerminalLigatureEntryMetadata(
                    item.entry,
                    <int?>[item.substitution],
                  ),
                )
                .toList();
        for (var index = 0; index < rule.input.length; index++) {
          current = terminalProcessInputPosition(
            terminalClassGlyphs(
              table.inputClassDefinition,
              rule.input[index],
            ),
            index + 1,
            current,
            rule.lookupRecords,
            lookups,
          );
        }
        for (final classId in rule.lookahead) {
          current = terminalProcessLookaheadPosition(
            terminalClassGlyphs(table.lookaheadClassDefinition, classId),
            current,
          );
        }
        for (final classId in rule.backtrack) {
          current = terminalProcessBacktrackPosition(
            terminalClassGlyphs(table.backtrackClassDefinition, classId),
            current,
          );
        }
        _terminalFinishChainingEntries(
          current,
          inputLength: rule.input.length + 1,
          lookaheadLength: rule.lookahead.length,
          backtrackLength: rule.backtrack.length,
          tableIndex: tableIndex,
          subIndex: subIndex,
        );
        results.add(result);
      }
    }
  }
  return mergeTerminalLigatureTrees(results);
}

void _terminalFinishChainingEntries(
  List<TerminalLigatureEntryMetadata> entries, {
  required int inputLength,
  required int lookaheadLength,
  required int backtrackLength,
  required int tableIndex,
  required int subIndex,
}) {
  for (final metadata in entries) {
    metadata.entry.lookup = TerminalLigatureLookupResult(
      substitutions: metadata.substitutions,
      length: inputLength,
      index: tableIndex,
      subIndex: subIndex,
      contextRange: (-backtrackLength, inputLength + lookaheadLength),
    );
  }
}

/// Builds xterm's GSUB type 8 format 1 lookup tree.
TerminalLigatureLookupTree buildTerminalReverseChainingTree(
  TerminalReverseChainingTable table,
  int tableIndex,
) {
  final result = TerminalLigatureLookupTree();
  for (final glyph in terminalCoverageGlyphs(table.coverage)) {
    final entry = TerminalLigatureLookupEntry();
    final selector = glyph.glyph;
    if (selector is (int, int)) {
      result.ranges.add(TerminalLigatureLookupRange(selector, entry));
    } else {
      result.individual[selector as int] = entry;
    }
    var current = <TerminalLigatureEntryMetadata>[
      TerminalLigatureEntryMetadata(entry, <int?>[
        table.substitutes[glyph.index],
      ]),
    ];
    for (final coverage in table.lookaheadCoverage) {
      current = terminalProcessLookaheadPosition(
        terminalCoverageGlyphs(coverage).map((item) => item.glyph).toList(),
        current,
      );
    }
    for (final coverage in table.backtrackCoverage) {
      current = terminalProcessBacktrackPosition(
        terminalCoverageGlyphs(coverage).map((item) => item.glyph).toList(),
        current,
      );
    }
    for (final metadata in current) {
      metadata.entry.lookup = TerminalLigatureLookupResult(
        substitutions: metadata.substitutions,
        length: 1,
        index: tableIndex,
        subIndex: 0,
        contextRange: (
          -table.backtrackCoverage.length,
          1 + table.lookaheadCoverage.length,
        ),
      );
    }
  }
  return result;
}

Map<TerminalGlyphSelector, int?> _terminalSubstitutionAtPositionRange(
  List<TerminalSubstitutionLookupRecord> records,
  List<List<TerminalSubstitutionTable>> lookups,
  int position,
  (int, int) range,
) {
  for (final record in records.where(
    (record) => record.sequenceIndex == position,
  )) {
    for (final table in lookups[record.lookupListIndex]) {
      final substitutions = terminalRangeSubstitutionGlyphs(table, range);
      if (!substitutions.values.every((value) => value != null)) {
        return substitutions;
      }
    }
  }
  return <TerminalGlyphSelector, int?>{range: null};
}

int? _terminalSubstitutionAtPosition(
  List<TerminalSubstitutionLookupRecord> records,
  List<List<TerminalSubstitutionTable>> lookups,
  int position,
  int glyph,
) {
  for (final record in records.where(
    (record) => record.sequenceIndex == position,
  )) {
    for (final table in lookups[record.lookupListIndex]) {
      final substitution = terminalSubstitutionGlyph(table, glyph);
      if (substitution != null) return substitution;
    }
  }
  return null;
}
