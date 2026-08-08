/// Search addon for normal and alternate terminal buffers.
library;

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/terminal.dart';

/// Search behavior flags.
final class TerminalSearchOptions {
  /// xterm-compatible `TerminalSearchOptions` API.
  const TerminalSearchOptions({
    this.regex = false,
    this.wholeWord = false,
    this.caseSensitive = false,
    this.incremental = false,
    this.decorateAll = false,
  });

  /// xterm-compatible `regex` API.
  final bool regex;

  /// xterm-compatible `wholeWord` API.
  final bool wholeWord;

  /// xterm-compatible `caseSensitive` API.
  final bool caseSensitive;

  /// xterm-compatible `incremental` API.
  final bool incremental;

  /// xterm-compatible `decorateAll` API.
  final bool decorateAll;
}

/// Current result position and total match count.
final class TerminalSearchResult {
  /// xterm-compatible `TerminalSearchResult` API.
  const TerminalSearchResult({
    required this.resultIndex,
    required this.resultCount,
  });

  /// xterm-compatible `resultIndex` API.
  final int resultIndex;

  /// xterm-compatible `resultCount` API.
  final int resultCount;
}

/// Searches the retained buffer and selects matches.
final class SearchAddon extends ManagedTerminalAddon {
  /// Creates a search addon.
  SearchAddon({this.highlightLimit = 1000}) {
    if (highlightLimit < 1) {
      throw ArgumentError.value(highlightLimit, 'highlightLimit');
    }
  }

  /// xterm-compatible `highlightLimit` API.
  final int highlightLimit;
  final TerminalEventEmitter<TerminalVoid> _onBeforeSearch =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<TerminalVoid> _onAfterSearch =
      TerminalEventEmitter<TerminalVoid>();
  final TerminalEventEmitter<TerminalSearchResult> _onDidChangeResults =
      TerminalEventEmitter<TerminalSearchResult>();
  List<_SearchMatch> _matches = <_SearchMatch>[];
  int _active = -1;

  /// xterm-compatible `onBeforeSearch` API.
  TerminalEvent<TerminalVoid> get onBeforeSearch => _onBeforeSearch.event;

  /// xterm-compatible `onAfterSearch` API.
  TerminalEvent<TerminalVoid> get onAfterSearch => _onAfterSearch.event;

  /// xterm-compatible `onDidChangeResults` API.
  TerminalEvent<TerminalSearchResult> get onDidChangeResults =>
      _onDidChangeResults.event;

  @override
  void onActivate(Terminal terminal) {
    own(
      terminal.onWriteParsed.listen((_) {
        if (_matches.isNotEmpty) _matches = <_SearchMatch>[];
      }),
    );
  }

  /// Selects the next result after the active selection.
  bool findNext(
    String term, {
    TerminalSearchOptions options = const TerminalSearchOptions(),
  }) => _find(term, options, forward: true);

  /// Selects the previous result before the active selection.
  bool findPrevious(
    String term, {
    TerminalSearchOptions options = const TerminalSearchOptions(),
  }) => _find(term, options, forward: false);

  bool _find(
    String term,
    TerminalSearchOptions options, {
    required bool forward,
  }) {
    _onBeforeSearch.fire(TerminalVoid.value);
    try {
      if (term.isEmpty) {
        clearDecorations();
        return false;
      }
      _matches = _collect(term, options);
      if (_matches.isEmpty) {
        _active = -1;
        _fireResults(options);
        return false;
      }
      _active = forward
          ? (_active + 1) % _matches.length
          : (_active <= 0 ? _matches.length : _active) - 1;
      final match = _matches[_active];
      terminal
        ..select(match.column, match.row, match.length)
        ..scrollToLine(match.row);
      _fireResults(options);
      return true;
    } finally {
      _onAfterSearch.fire(TerminalVoid.value);
    }
  }

  List<_SearchMatch> _collect(String term, TerminalSearchOptions options) {
    final expression = options.regex ? term : RegExp.escape(term);
    final pattern = RegExp(
      options.wholeWord ? '(?<![\\w])(?:$expression)(?![\\w])' : expression,
      caseSensitive: options.caseSensitive,
      multiLine: true,
    );
    final result = <_SearchMatch>[];
    for (var row = 0; row < terminal.buffer.active.length; row++) {
      final text = terminal.buffer.active
          .getLine(row)!
          .translateToString(trimRight: true);
      for (final match in pattern.allMatches(text)) {
        result.add(_SearchMatch(row, match.start, match.end - match.start));
      }
    }
    return result;
  }

  void _fireResults(TerminalSearchOptions options) {
    final exceedsLimit =
        options.decorateAll && _matches.length > highlightLimit;
    _onDidChangeResults.fire(
      TerminalSearchResult(
        resultIndex: exceedsLimit ? -1 : _active,
        resultCount: _matches.length,
      ),
    );
  }

  /// Clears cached matches and terminal selection.
  void clearDecorations() {
    _matches = <_SearchMatch>[];
    _active = -1;
    if (isActive) terminal.clearSelection();
    _onDidChangeResults.fire(
      const TerminalSearchResult(resultIndex: -1, resultCount: 0),
    );
  }

  /// Clears only the selected active match.
  void clearActiveDecoration() {
    _active = -1;
    if (isActive) terminal.clearSelection();
  }

  @override
  void dispose() {
    _onBeforeSearch.dispose();
    _onAfterSearch.dispose();
    _onDidChangeResults.dispose();
    super.dispose();
  }
}

final class _SearchMatch {
  const _SearchMatch(this.row, this.column, this.length);

  final int row;
  final int column;
  final int length;
}
