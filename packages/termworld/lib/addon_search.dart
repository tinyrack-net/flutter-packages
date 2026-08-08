/// Search addon for normal and alternate terminal buffers.
library;

import 'dart:async';

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/marker.dart';
import 'package:termworld/src/core/terminal.dart';

/// Colors used for inactive and active search result decorations.
final class TerminalSearchDecorationOptions {
  /// Creates xterm-compatible search decoration options.
  const TerminalSearchDecorationOptions({
    required this.matchOverviewRuler,
    required this.activeMatchColorOverviewRuler,
    this.matchBackground,
    this.matchBorder,
    this.activeMatchBackground,
    this.activeMatchBorder,
  });

  /// Background color of an inactive match.
  final String? matchBackground;

  /// Border color of an inactive match.
  final String? matchBorder;

  /// Overview ruler color of an inactive match.
  final String matchOverviewRuler;

  /// Background color of the active match.
  final String? activeMatchBackground;

  /// Border color of the active match.
  final String? activeMatchBorder;

  /// Overview ruler color of the active match.
  final String activeMatchColorOverviewRuler;
}

/// Search behavior flags.
final class TerminalSearchOptions {
  /// Creates xterm-compatible search options.
  const TerminalSearchOptions({
    this.regex = false,
    this.wholeWord = false,
    this.caseSensitive = false,
    this.incremental = false,
    this.decorations,
  });

  /// Whether the search term is interpreted as a regular expression.
  final bool regex;

  /// Whether matches must be surrounded by xterm non-word characters.
  final bool wholeWord;

  /// Whether matching preserves case.
  final bool caseSensitive;

  /// Whether an edited term expands the current selection.
  final bool incremental;

  /// Optional all-result and active-result decoration colors.
  final TerminalSearchDecorationOptions? decorations;
}

/// Current result position and tracked match count.
final class TerminalSearchResult {
  /// Creates a search result change event.
  const TerminalSearchResult({
    required this.resultIndex,
    required this.resultCount,
  });

  /// Index of the active result, or -1 when it is not tracked.
  final int resultIndex;

  /// Number of results tracked up to the configured highlight limit.
  final int resultCount;
}

/// Searches retained terminal content with xterm-compatible wrap semantics.
final class SearchAddon extends ManagedTerminalAddon {
  /// Creates a search addon.
  SearchAddon({this.highlightLimit = 1000}) {
    if (highlightLimit < 1) {
      throw ArgumentError.value(highlightLimit, 'highlightLimit');
    }
  }

  static const String _nonWordCharacters =
      ' ~!@#\$%^&*()+`-=[]{}|\\;:"\',./<>?';

  /// Maximum number of results retained for decoration and result events.
  final int highlightLimit;
  final TerminalEventEmitter<TerminalVoid> _onBeforeSearch =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<TerminalVoid> _onAfterSearch =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<TerminalSearchResult> _onDidChangeResults =
      TerminalEventEmitter<TerminalSearchResult>();
  final List<_SearchDecoration> _highlightDecorations = <_SearchDecoration>[];
  List<_SearchMatch> _trackedMatches = <_SearchMatch>[];
  _SearchDecorationGroup? _activeDecoration;
  String? _cachedTerm;
  TerminalSearchOptions? _lastOptions;
  Timer? _refreshTimer;

  /// Fired synchronously immediately before each search.
  TerminalEvent<TerminalVoid> get onBeforeSearch => _onBeforeSearch.event;

  /// Fired synchronously immediately after each search.
  TerminalEvent<TerminalVoid> get onAfterSearch => _onAfterSearch.event;

  /// Fired after decorated searches with active index and result count.
  TerminalEvent<TerminalSearchResult> get onDidChangeResults =>
      _onDidChangeResults.event;

  @override
  void onActivate(Terminal terminal) {
    add(terminal.onWriteParsed.listen((_) => _scheduleRefresh()));
    add(terminal.onResize.listen((_) => _scheduleRefresh()));
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    final term = _cachedTerm;
    final options = _lastOptions;
    if (term == null || options?.decorations == null) return;
    _refreshTimer = Timer(const Duration(milliseconds: 200), () {
      if (!isActive) return;
      _cachedTerm = null;
      _find(term, options!, forward: false, noScroll: true);
    });
  }

  /// Selects the next result after the current selection, wrapping at the end.
  bool findNext(
    String term, {
    TerminalSearchOptions options = const TerminalSearchOptions(),
  }) => _find(term, options, forward: true);

  /// Selects the previous result before the current selection, wrapping at top.
  bool findPrevious(
    String term, {
    TerminalSearchOptions options = const TerminalSearchOptions(),
  }) => _find(term, options, forward: false);

  bool _find(
    String term,
    TerminalSearchOptions options, {
    required bool forward,
    bool noScroll = false,
  }) {
    _onBeforeSearch.fire(TerminalVoid.value);
    try {
      final previousOptions = _lastOptions;
      _lastOptions = options;
      if (term.isEmpty) {
        terminal.clearSelection();
        clearDecorations();
        return false;
      }

      final selection = terminal.getSelectionPosition();
      final matches = _collect(term, options);
      final shouldHighlight =
          options.decorations != null &&
          (_cachedTerm == null ||
              _cachedTerm != term ||
              _searchShapeChanged(previousOptions, options));
      if (shouldHighlight) {
        _replaceHighlights(matches, options.decorations!);
      }

      final selected = _selectMatch(
        matches,
        selection,
        term,
        forward: forward,
      );
      _clearActiveDecoration();
      if (selected == null) {
        terminal.clearSelection();
      } else {
        terminal.select(selected.column, selected.row, selected.length);
        final decorationOptions = options.decorations;
        if (decorationOptions != null) {
          _activeDecoration = _createDecorationGroup(
            selected,
            decorationOptions,
            active: true,
          );
        }
        if (!noScroll &&
            (selected.row >= terminal.viewportY + terminal.rows ||
                selected.row < terminal.viewportY)) {
          terminal.scrollLines(
            selected.row - terminal.viewportY - terminal.rows ~/ 2,
          );
        }
      }
      _cachedTerm = term;
      _fireResults(options, selected);
      return selected != null;
    } finally {
      _onAfterSearch.fire(TerminalVoid.value);
    }
  }

  bool _searchShapeChanged(
    TerminalSearchOptions? previous,
    TerminalSearchOptions options,
  ) {
    if (previous == null) return true;
    return previous.caseSensitive != options.caseSensitive ||
        previous.regex != options.regex ||
        previous.wholeWord != options.wholeWord;
  }

  _SearchMatch? _selectMatch(
    List<_SearchMatch> matches,
    TerminalBufferRange? selection,
    String term, {
    required bool forward,
  }) {
    if (matches.isEmpty) return null;
    if (selection == null) return forward ? matches.first : matches.last;

    final sameTerm = _cachedTerm == term;
    final start = selection.start.y * terminal.cols + selection.start.x;
    final end = selection.end.y * terminal.cols + selection.end.x;
    if (forward) {
      final offset = sameTerm ? end : start;
      return matches.firstWhere(
        (match) => match.linearStart >= offset,
        orElse: () => matches.first,
      );
    }

    if (!sameTerm) {
      for (final match in matches) {
        if (match.row == selection.start.y && match.linearStart >= start) {
          return match;
        }
      }
    }
    final reverseOffset = sameTerm ? start : end;
    for (var index = matches.length - 1; index >= 0; index--) {
      if (matches[index].linearStart < reverseOffset) return matches[index];
    }
    return matches.last;
  }

  List<_SearchMatch> _collect(String term, TerminalSearchOptions options) {
    final pattern = RegExp(
      options.regex ? term : RegExp.escape(term),
      caseSensitive: options.caseSensitive,
      multiLine: true,
    );
    final result = <_SearchMatch>[];
    for (final line in _logicalLines()) {
      for (final match in pattern.allMatches(line.text)) {
        if (match.start == match.end) continue;
        final matchedTerm = match.group(0)!;
        if (options.wholeWord &&
            !_isWholeWord(line.text, match.start, matchedTerm.length)) {
          continue;
        }
        final linearStart = line.boundaries[match.start];
        final linearEnd = line.boundaries[match.end];
        result.add(
          _SearchMatch(
            linearStart ~/ terminal.cols,
            linearStart % terminal.cols,
            linearEnd - linearStart,
            linearStart,
          ),
        );
      }
    }
    return result;
  }

  Iterable<_LogicalLine> _logicalLines() sync* {
    final buffer = terminal.buffer.active;
    var row = 0;
    while (row < buffer.length) {
      if (buffer.getLine(row)!.isWrapped) {
        row++;
        continue;
      }
      final text = StringBuffer();
      final boundaries = <int>[row * terminal.cols];
      var currentRow = row;
      while (currentRow < buffer.length) {
        final line = buffer.getLine(currentRow)!;
        final next = buffer.getLine(currentRow + 1);
        final wraps = next?.isWrapped ?? false;
        var lastCell = line.length;
        if (!wraps) {
          while (lastCell > 0) {
            final cell = line.getCell(lastCell - 1)!;
            if (cell.width == 0 || cell.chars.isNotEmpty) break;
            lastCell--;
          }
        } else if (lastCell > 0 &&
            line.getCell(lastCell - 1)!.code == 0 &&
            line.getCell(lastCell - 1)!.width == 1 &&
            next?.getCell(0)?.width == 2) {
          lastCell--;
        }
        for (var column = 0; column < lastCell; column++) {
          final cell = line.getCell(column)!;
          if (cell.width == 0) continue;
          final value = cell.chars.isEmpty ? ' ' : cell.chars;
          text.write(value);
          for (var unit = 0; unit < value.length; unit++) {
            boundaries.add(
              unit == value.length - 1
                  ? currentRow * terminal.cols + column + cell.width
                  : currentRow * terminal.cols + column,
            );
          }
        }
        if (!wraps) break;
        currentRow++;
      }
      yield _LogicalLine(text.toString(), boundaries);
      row = currentRow + 1;
    }
  }

  bool _isWholeWord(String line, int index, int length) {
    final before = index == 0 || _nonWordCharacters.contains(line[index - 1]);
    final end = index + length;
    final after = end == line.length || _nonWordCharacters.contains(line[end]);
    return before && after;
  }

  void _replaceHighlights(
    List<_SearchMatch> matches,
    TerminalSearchDecorationOptions options,
  ) {
    _clearHighlights();
    _trackedMatches = matches.take(highlightLimit).toList(growable: false);
    for (final match in _trackedMatches) {
      final group = _createDecorationGroup(match, options, active: false);
      if (group != null) _highlightDecorations.addAll(group.decorations);
    }
  }

  _SearchDecorationGroup? _createDecorationGroup(
    _SearchMatch match,
    TerminalSearchDecorationOptions options, {
    required bool active,
  }) {
    final decorations = <_SearchDecoration>[];
    var column = match.column;
    var remaining = match.length;
    var row = match.row;
    while (remaining > 0) {
      final width = (terminal.cols - column).clamp(0, remaining);
      if (width == 0) {
        row++;
        column = 0;
        continue;
      }
      final marker = terminal.registerMarker(
        cursorYOffset: row - terminal.buffer.normal.absoluteCursorY,
      );
      if (marker != null) {
        final decoration = terminal.registerDecoration(
          marker: marker,
          x: column,
          width: width,
          layer: active
              ? TerminalDecorationLayer.top
              : TerminalDecorationLayer.bottom,
          backgroundColor: active
              ? options.activeMatchBackground
              : options.matchBackground,
          borderColor: active ? options.activeMatchBorder : options.matchBorder,
          overviewRulerColor: active
              ? options.activeMatchColorOverviewRuler
              : options.matchOverviewRuler,
        );
        if (decoration != null) {
          decorations.add(_SearchDecoration(marker, decoration));
        } else {
          marker.dispose();
        }
      }
      remaining -= width;
      row++;
      column = 0;
    }
    return decorations.isEmpty
        ? null
        : _SearchDecorationGroup(match, decorations);
  }

  void _fireResults(
    TerminalSearchOptions options,
    _SearchMatch? selected,
  ) {
    if (options.decorations == null) return;
    final activeIndex = selected == null
        ? -1
        : _trackedMatches.indexWhere((match) => match.samePosition(selected));
    _onDidChangeResults.fire(
      TerminalSearchResult(
        resultIndex: activeIndex,
        resultCount: _trackedMatches.length,
      ),
    );
  }

  /// Clears all search decorations and cached search state.
  void clearDecorations({bool retainCachedSearchTerm = false}) {
    _clearActiveDecoration();
    _clearHighlights();
    _trackedMatches = <_SearchMatch>[];
    if (!retainCachedSearchTerm) _cachedTerm = null;
  }

  void _clearHighlights() {
    for (final decoration in _highlightDecorations) {
      decoration.dispose();
    }
    _highlightDecorations.clear();
  }

  /// Clears only the active-result decoration without changing selection.
  void clearActiveDecoration() => _clearActiveDecoration();

  void _clearActiveDecoration() {
    _activeDecoration?.dispose();
    _activeDecoration = null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    clearDecorations();
    _onBeforeSearch.dispose();
    _onAfterSearch.dispose();
    _onDidChangeResults.dispose();
    super.dispose();
  }
}

final class _LogicalLine {
  const _LogicalLine(this.text, this.boundaries);

  final String text;
  final List<int> boundaries;
}

final class _SearchMatch {
  const _SearchMatch(this.row, this.column, this.length, this.linearStart);

  final int row;
  final int column;
  final int length;
  final int linearStart;

  bool samePosition(_SearchMatch other) =>
      row == other.row && column == other.column && length == other.length;
}

final class _SearchDecoration implements Disposable {
  const _SearchDecoration(this.marker, this.decoration);

  final TerminalMarker marker;
  final TerminalDecoration decoration;

  @override
  bool get isDisposed => decoration.isDisposed;

  @override
  void dispose() {
    decoration.dispose();
    marker.dispose();
  }
}

final class _SearchDecorationGroup implements Disposable {
  const _SearchDecorationGroup(this.match, this.decorations);

  final _SearchMatch match;
  final List<_SearchDecoration> decorations;

  @override
  bool get isDisposed => decorations.every((value) => value.isDisposed);

  @override
  void dispose() {
    for (final decoration in decorations) {
      decoration.dispose();
    }
  }
}
