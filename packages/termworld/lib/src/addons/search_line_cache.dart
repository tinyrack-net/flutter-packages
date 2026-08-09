import 'dart:async';

import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/terminal.dart';

/// Cached string form of one logical buffer line and its wrapped-line offsets.
final class SearchLineCacheEntry {
  /// Creates an entry matching xterm.js' `LineCacheEntry` tuple.
  const SearchLineCacheEntry(this.line, this.lineOffsets);

  /// String representation of the logical line.
  final String line;

  /// String offsets at which each physical wrapped line begins.
  final List<int> lineOffsets;
}

/// Memoizes xterm search line translations with a sliding 15 second lifetime.
final class SearchLineCache extends DisposableStore {
  /// Creates an uninitialized cache for [terminal].
  SearchLineCache(this.terminal);

  static const Duration _timeToLive = Duration(seconds: 15);

  /// Terminal whose active buffer is translated.
  final Terminal terminal;
  List<SearchLineCacheEntry?>? _linesCache;
  Timer? _linesCacheTimer;
  final List<Disposable> _linesCacheDisposables = <Disposable>[];
  DateTime? _lastAccess;

  /// Initializes the cache without replacing entries from an existing search.
  void initLinesCache() {
    if (_linesCache == null) {
      _linesCache = List<SearchLineCacheEntry?>.filled(
        terminal.buffer.active.length,
        null,
        growable: true,
      );
      _linesCacheDisposables
        ..add(terminal.onLineFeed.listen((_) => _destroyLinesCache()))
        ..add(terminal.onCursorMove.listen((_) => _destroyLinesCache()))
        ..add(terminal.onResize.listen((_) => _destroyLinesCache()));
    }
    _lastAccess = DateTime.now();
    _linesCacheTimer ??= Timer(_timeToLive, _expireLinesCache);
  }

  void _expireLinesCache() {
    _linesCacheTimer = null;
    if (_linesCache == null) return;
    final elapsed = DateTime.now().difference(_lastAccess!);
    if (elapsed >= _timeToLive) {
      _destroyLinesCache();
      return;
    }
    _linesCacheTimer = Timer(_timeToLive - elapsed, _expireLinesCache);
  }

  void _destroyLinesCache() {
    _linesCache = null;
    _lastAccess = null;
    _linesCacheTimer?.cancel();
    _linesCacheTimer = null;
    for (final disposable in _linesCacheDisposables) {
      disposable.dispose();
    }
    _linesCacheDisposables.clear();
  }

  /// Returns row [row], or `null` before initialization and for unset rows.
  SearchLineCacheEntry? getLineFromCache(int row) {
    final cache = _linesCache;
    if (cache == null || row < 0 || row >= cache.length) return null;
    return cache[row];
  }

  /// Stores [entry] at [row] when the cache has been initialized.
  void setLineInCache(int row, SearchLineCacheEntry entry) {
    final cache = _linesCache;
    if (cache == null || row < 0) return;
    if (row >= cache.length) cache.length = row + 1;
    cache[row] = entry;
  }

  /// Translates [lineIndex] and every continuation line into one string.
  SearchLineCacheEntry translateBufferLineToStringWithWrap(
    int lineIndex, {
    required bool trimRight,
  }) {
    final strings = <String>[];
    final lineOffsets = <int>[0];
    var currentIndex = lineIndex;
    var line = terminal.buffer.active.getLine(currentIndex);
    while (line != null) {
      final nextLine = terminal.buffer.active.getLine(currentIndex + 1);
      final lineWrapsToNext = nextLine?.isWrapped ?? false;
      var string = line.translateToString(
        trimRight: !lineWrapsToNext && trimRight,
      );
      if (lineWrapsToNext && nextLine != null) {
        final lastCell = line.getCell(line.length - 1);
        final lastCellIsNull =
            lastCell != null && lastCell.code == 0 && lastCell.width == 1;
        if (lastCellIsNull && nextLine.getCell(0)?.width == 2) {
          string = string.substring(0, string.length - 1);
        }
      }
      strings.add(string);
      if (!lineWrapsToNext) break;
      lineOffsets.add(lineOffsets.last + string.length);
      currentIndex++;
      line = nextLine;
    }
    return SearchLineCacheEntry(strings.join(), lineOffsets);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    _destroyLinesCache();
    super.dispose();
  }
}
