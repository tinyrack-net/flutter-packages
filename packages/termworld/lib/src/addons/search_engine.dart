import 'package:termworld/src/addons/search_line_cache.dart';
import 'package:vtworld/vtworld.dart';

/// Search flags consumed by the standalone search engine.
final class SearchEngineOptions {
  /// Creates xterm-compatible search flags.
  const SearchEngineOptions({
    this.regex = false,
    this.wholeWord = false,
    this.caseSensitive = false,
  });

  /// Whether [SearchEngine] interprets the term as a regular expression.
  final bool regex;

  /// Whether adjacent word characters reject a match.
  final bool wholeWord;

  /// Whether matching preserves case.
  final bool caseSensitive;
}

/// Position and buffer-cell size of a search match.
final class SearchEngineResult {
  /// Creates a match result.
  const SearchEngineResult({
    required this.term,
    required this.column,
    required this.row,
    required this.size,
  });

  /// Actual matched text.
  final String term;

  /// Zero-based buffer column.
  final int column;

  /// Zero-based absolute buffer row.
  final int row;

  /// Match size in buffer cells, including wrapped rows.
  final int size;

  @override
  // Safe without Flutter's @immutable: this value type has only final fields.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      other is SearchEngineResult &&
      other.term == term &&
      other.column == column &&
      other.row == row &&
      other.size == size;

  @override
  // Safe without Flutter's @immutable: this value type has only final fields.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hash(term, column, row, size);
}

final class _SearchPosition {
  _SearchPosition(this.row, this.column);

  int row;
  int column;
}

/// Core search algorithm ported from xterm.js' addon-search.
final class SearchEngine {
  /// Creates an engine over [terminal] using [lineCache].
  const SearchEngine(this.terminal, this.lineCache);

  static const String _nonWordCharacters =
      ' ~!@#\$%^&*()+`-=[]{}|\\;:"\',./<>?';

  /// Terminal whose active buffer is searched.
  final Terminal terminal;

  /// Logical-line translation cache.
  final SearchLineCache lineCache;

  /// Finds the first match at or after [startRow], [startColumn].
  SearchEngineResult? find(
    String term,
    int startRow,
    int startColumn, {
    SearchEngineOptions options = const SearchEngineOptions(),
  }) {
    if (term.isEmpty) {
      terminal.clearSelection();
      return null;
    }
    if (startColumn >= terminal.cols) {
      throw StateError(
        'Invalid col: $startColumn to search in terminal of '
        '${terminal.cols} cols',
      );
    }
    lineCache.initLinesCache();
    final position = _SearchPosition(startRow, startColumn);
    var result = _findInLine(term, position, options);
    if (result == null) {
      for (
        var row = startRow + 1;
        row < terminal.buffer.active.baseY + terminal.rows;
        row++
      ) {
        position
          ..row = row
          ..column = 0;
        result = _findInLine(term, position, options);
        if (result != null) break;
      }
    }
    return result;
  }

  /// Finds the next match using the current selection and wraps at the end.
  SearchEngineResult? findNextWithSelection(
    String term, {
    SearchEngineOptions options = const SearchEngineOptions(),
    String? cachedSearchTerm,
  }) {
    if (term.isEmpty) {
      terminal.clearSelection();
      return null;
    }
    final previous = terminal.getSelectionPosition();
    terminal.clearSelection();
    var startColumn = 0;
    var startRow = 0;
    if (previous != null) {
      if (cachedSearchTerm == term) {
        startColumn = previous.end.x;
        startRow = previous.end.y;
      } else {
        startColumn = previous.start.x;
        startRow = previous.start.y;
      }
    }
    lineCache.initLinesCache();
    final position = _SearchPosition(startRow, startColumn);
    var result = _findInLine(term, position, options);
    if (result == null) {
      for (
        var row = startRow + 1;
        row < terminal.buffer.active.baseY + terminal.rows;
        row++
      ) {
        position
          ..row = row
          ..column = 0;
        result = _findInLine(term, position, options);
        if (result != null) break;
      }
    }
    if (result == null && startRow != 0) {
      for (var row = 0; row < startRow; row++) {
        position
          ..row = row
          ..column = 0;
        result = _findInLine(term, position, options);
        if (result != null) break;
      }
    }
    if (result == null && previous != null) {
      position
        ..row = previous.start.y
        ..column = 0;
      result = _findInLine(term, position, options);
    }
    return result;
  }

  /// Finds the previous match using the current selection and wraps at the top.
  SearchEngineResult? findPreviousWithSelection(
    String term, {
    SearchEngineOptions options = const SearchEngineOptions(),
    String? cachedSearchTerm,
  }) {
    if (term.isEmpty) {
      terminal.clearSelection();
      return null;
    }
    final previous = terminal.getSelectionPosition();
    terminal.clearSelection();
    var startRow = terminal.buffer.active.baseY + terminal.rows - 1;
    final position = _SearchPosition(startRow, terminal.cols);
    SearchEngineResult? result;
    lineCache.initLinesCache();
    if (previous != null) {
      position
        ..row = startRow = previous.start.y
        ..column = previous.start.x;
      if (cachedSearchTerm != term) {
        result = _findInLine(term, position, options);
        if (result == null) {
          position
            ..row = startRow = previous.end.y
            ..column = previous.end.x;
        }
      }
    }
    result ??= _findInLine(term, position, options, reverse: true);
    if (result == null) {
      position.column = position.column < terminal.cols
          ? terminal.cols
          : position.column;
      for (var row = startRow - 1; row >= 0; row--) {
        position.row = row;
        result = _findInLine(term, position, options, reverse: true);
        if (result != null) break;
      }
    }
    final bottom = terminal.buffer.active.baseY + terminal.rows - 1;
    if (result == null && startRow != bottom) {
      for (var row = bottom; row >= startRow; row--) {
        position.row = row;
        result = _findInLine(term, position, options, reverse: true);
        if (result != null) break;
      }
    }
    return result;
  }

  SearchEngineResult? _findInLine(
    String term,
    _SearchPosition position,
    SearchEngineOptions options, {
    bool reverse = false,
  }) {
    final row = position.row;
    final firstLine = terminal.buffer.active.getLine(row);
    if (firstLine?.isWrapped ?? false) {
      if (reverse) {
        position.column += terminal.cols;
        return null;
      }
      position.row--;
      position.column += terminal.cols;
      return _findInLine(term, position, options);
    }
    var cache = lineCache.getLineFromCache(row);
    if (cache == null) {
      cache = lineCache.translateBufferLineToStringWithWrap(
        row,
        trimRight: true,
      );
      lineCache.setLineInCache(row, cache);
    }
    final stringLine = cache.line;
    final offsets = cache.lineOffsets;
    final offset = _bufferColumnsToStringOffset(row, position.column);
    // JavaScript's String#indexOf/String#lastIndexOf clamp their position to
    // the string length. Dart instead throws when the start index is beyond
    // the end, which is common for a reverse search beginning at terminal.cols
    // on a short line.
    final searchOffset = offset.clamp(0, stringLine.length);
    var matchedTerm = term;
    final searchableTerm = options.regex || options.caseSensitive
        ? term
        : term.toLowerCase();
    final searchableLine = options.regex || options.caseSensitive
        ? stringLine
        : stringLine.toLowerCase();
    var resultIndex = -1;
    if (options.regex) {
      final expression = RegExp(term, caseSensitive: options.caseSensitive);
      if (reverse) {
        final prefix = searchableLine.substring(
          0,
          searchOffset,
        );
        for (final match in _overlappingMatches(expression, prefix)) {
          if (match.end > searchOffset) break;
          if (match.start == match.end ||
              options.wholeWord &&
                  !_isWholeWord(match.start, searchableLine, match.value)) {
            continue;
          }
          resultIndex = match.start;
          matchedTerm = match.value;
        }
      } else {
        for (final match in expression.allMatches(
          searchableLine.substring(searchOffset),
        )) {
          if (match.start == match.end) continue;
          final candidateIndex = searchOffset + match.start;
          final candidateTerm = match.group(0)!;
          if (options.wholeWord &&
              !_isWholeWord(candidateIndex, searchableLine, candidateTerm)) {
            continue;
          }
          resultIndex = candidateIndex;
          matchedTerm = candidateTerm;
          break;
        }
      }
    } else if (reverse) {
      if (searchOffset - searchableTerm.length >= 0) {
        resultIndex = searchableLine.lastIndexOf(
          searchableTerm,
          searchOffset - searchableTerm.length,
        );
        while (resultIndex >= 0 &&
            options.wholeWord &&
            !_isWholeWord(resultIndex, searchableLine, searchableTerm)) {
          resultIndex = resultIndex == 0
              ? -1
              : searchableLine.lastIndexOf(searchableTerm, resultIndex - 1);
        }
      }
    } else {
      resultIndex = searchableLine.indexOf(searchableTerm, searchOffset);
      while (resultIndex >= 0 &&
          options.wholeWord &&
          !_isWholeWord(resultIndex, searchableLine, searchableTerm)) {
        resultIndex = searchableLine.indexOf(searchableTerm, resultIndex + 1);
      }
    }
    if (resultIndex < 0) return null;
    if (options.wholeWord &&
        !_isWholeWord(resultIndex, searchableLine, matchedTerm)) {
      return null;
    }
    var startRowOffset = 0;
    while (startRowOffset < offsets.length - 1 &&
        resultIndex >= offsets[startRowOffset + 1]) {
      startRowOffset++;
    }
    var endRowOffset = startRowOffset;
    while (endRowOffset < offsets.length - 1 &&
        resultIndex + matchedTerm.length >= offsets[endRowOffset + 1]) {
      endRowOffset++;
    }
    final startOffset = resultIndex - offsets[startRowOffset];
    final endOffset = resultIndex + matchedTerm.length - offsets[endRowOffset];
    final startColumn = _stringLengthToBufferSize(
      row + startRowOffset,
      startOffset,
    );
    final endColumn = _stringLengthToBufferSize(
      row + endRowOffset,
      endOffset,
    );
    return SearchEngineResult(
      term: matchedTerm,
      column: startColumn,
      row: row + startRowOffset,
      size:
          endColumn -
          startColumn +
          terminal.cols * (endRowOffset - startRowOffset),
    );
  }

  Iterable<({int start, int end, String value})> _overlappingMatches(
    RegExp expression,
    String value,
  ) sync* {
    var start = 0;
    while (start <= value.length) {
      final match = expression.firstMatch(value.substring(start));
      if (match == null) return;
      final absoluteStart = start + match.start;
      final absoluteEnd = start + match.end;
      yield (
        start: absoluteStart,
        end: absoluteEnd,
        value: match.group(0)!,
      );
      start = absoluteStart + 1;
    }
  }

  bool _isWholeWord(int index, String line, String term) =>
      (index == 0 || _nonWordCharacters.contains(line[index - 1])) &&
      (index + term.length == line.length ||
          _nonWordCharacters.contains(line[index + term.length]));

  int _stringLengthToBufferSize(int row, int offset) {
    final line = terminal.buffer.active.getLine(row);
    if (line == null) return 0;
    var bufferSize = offset;
    for (var column = 0; column < bufferSize; column++) {
      final cell = line.getCell(column);
      if (cell == null) break;
      if (cell.chars.length > 1) bufferSize -= cell.chars.length - 1;
      if (line.getCell(column + 1)?.width == 0) bufferSize++;
    }
    return bufferSize;
  }

  int _bufferColumnsToStringOffset(int startRow, int columns) {
    var lineIndex = startRow;
    var offset = 0;
    var remaining = columns;
    var line = terminal.buffer.active.getLine(lineIndex);
    while (remaining > 0 && line != null) {
      for (
        var column = 0;
        column < remaining && column < terminal.cols;
        column++
      ) {
        final cell = line.getCell(column);
        if (cell == null) break;
        if (cell.width != 0) {
          offset += cell.code == 0 ? 1 : cell.chars.length;
        }
      }
      line = terminal.buffer.active.getLine(++lineIndex);
      if (line != null && !line.isWrapped) break;
      remaining -= terminal.cols;
    }
    return offset;
  }
}
