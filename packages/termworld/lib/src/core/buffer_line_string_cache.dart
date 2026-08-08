import 'dart:async';

import 'package:termworld/src/core/disposable.dart';

/// Cached canonical string translation for one buffer line.
final class BufferLineStringCacheEntry {
  /// Creates an empty entry for [generation].
  BufferLineStringCacheEntry(this.generation);

  /// Cached translated value.
  String? value;

  /// Whether [value] was produced with right trimming.
  bool isTrimmed = false;

  /// Cache generation that owns this entry.
  final int generation;

  /// Stores a translated [text] and whether it was right-trimmed.
  void setValue(String text, {required bool isTrimmed}) {
    value = text;
    this.isTrimmed = isTrimmed;
  }
}

/// Shared short-lived cache used by all lines in one terminal buffer.
final class BufferLineStringCache implements Disposable {
  /// Time after the last access before cached translations are discarded.
  static const int cacheTtlMilliseconds = 15000;

  /// Generation used to invalidate weak line references after [clear].
  int generation = 0;

  /// Entries retained until the cache expires or is cleared.
  final Set<BufferLineStringCacheEntry> entries =
      <BufferLineStringCacheEntry>{};

  Timer? _clearTimer;
  int _lastAccessTimestamp = 0;
  bool _isDisposed = false;

  /// Whether a cache expiry timer is pending.
  bool get hasPendingClear => _clearTimer != null;

  /// Refreshes the expiry deadline without allocating an entry.
  void touch() {
    if (_isDisposed) return;
    _scheduleClear();
  }

  /// Allocates and retains a new empty cache entry.
  BufferLineStringCacheEntry allocateEntry() {
    if (_isDisposed) throw StateError('String cache has been disposed');
    final entry = BufferLineStringCacheEntry(generation);
    entries.add(entry);
    _scheduleClear();
    return entry;
  }

  /// Invalidates all entries and cancels pending expiry work.
  void clear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _lastAccessTimestamp = 0;
    generation++;
    for (final entry in entries) {
      entry
        ..value = null
        ..isTrimmed = false;
    }
    entries.clear();
  }

  void _scheduleClear() {
    _lastAccessTimestamp = DateTime.now().millisecondsSinceEpoch;
    if (_clearTimer != null) return;
    _scheduleClearTimeout(cacheTtlMilliseconds);
  }

  void _scheduleClearTimeout(int milliseconds) {
    _clearTimer = Timer(Duration(milliseconds: milliseconds), () {
      _clearTimer = null;
      final elapsed =
          DateTime.now().millisecondsSinceEpoch - _lastAccessTimestamp;
      if (elapsed >= cacheTtlMilliseconds) {
        clear();
        return;
      }
      _scheduleClearTimeout(cacheTtlMilliseconds - elapsed);
    });
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    clear();
    _isDisposed = true;
  }
}
