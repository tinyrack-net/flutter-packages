import 'dart:async';

import 'package:termworld/src/core/disposable.dart';

/// Platform scheduling boundary for animation-frame render coalescing.
abstract interface class TerminalFrameHost {
  /// Requests a frame and returns its cancellation identifier.
  int requestFrame(void Function(double timestamp) callback);

  /// Cancels a pending frame.
  void cancelFrame(int id);
}

/// Coalesces dirty row ranges into one animation-frame render.
final class RenderDebouncer implements Disposable {
  /// Creates an xterm-compatible render debouncer.
  RenderDebouncer(this._render, this._host);

  final void Function(int start, int end) _render;
  final TerminalFrameHost _host;
  final List<void Function(double)> _callbacks = <void Function(double)>[];
  int? _rowStart;
  int? _rowEnd;
  int? _rowCount;
  int? _frame;
  bool _isDisposed = false;

  /// Schedules [callback] after the next coalesced render.
  int addRefreshCallback(void Function(double timestamp) callback) {
    _callbacks.add(callback);
    return _frame ??= _host.requestFrame((_) => _innerRefresh());
  }

  /// Adds a dirty row range, using the full viewport for omitted bounds.
  void refresh(int? rowStart, int? rowEnd, int rowCount) {
    _rowCount = rowCount;
    final start = rowStart ?? 0;
    final end = rowEnd ?? rowCount - 1;
    _rowStart = _rowStart == null
        ? start
        : (_rowStart! < start ? _rowStart : start);
    _rowEnd = _rowEnd == null ? end : (_rowEnd! > end ? _rowEnd : end);
    _frame ??= _host.requestFrame((_) => _innerRefresh());
  }

  void _innerRefresh() {
    _frame = null;
    final rowStart = _rowStart;
    final rowEnd = _rowEnd;
    final rowCount = _rowCount;
    if (rowStart != null && rowEnd != null && rowCount != null) {
      final start = rowStart < 0 ? 0 : rowStart;
      final lastRow = rowCount - 1;
      final end = rowEnd > lastRow ? lastRow : rowEnd;
      _rowStart = null;
      _rowEnd = null;
      _render(start, end);
    }
    final callbacks = List<void Function(double)>.of(_callbacks);
    _callbacks.clear();
    for (final callback in callbacks) {
      callback(0);
    }
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    final frame = _frame;
    if (frame != null) {
      _host.cancelFrame(frame);
      _frame = null;
    }
  }
}

/// Timer and monotonic-clock boundary for [TimeBasedDebouncer].
abstract interface class TerminalDebounceHost {
  /// Current monotonic time in milliseconds.
  double get now;

  /// Schedules [callback] and returns its cancellation identifier.
  int setTimeout(void Function() callback, double milliseconds);

  /// Cancels a pending timeout.
  void clearTimeout(int id);
}

/// Dart timer implementation of xterm's browser timeout boundary.
final class DartTerminalDebounceHost implements TerminalDebounceHost {
  final Stopwatch _clock = Stopwatch()..start();
  final Map<int, Timer> _timers = <int, Timer>{};
  var _nextId = 0;

  @override
  double get now => _clock.elapsedMicroseconds / 1000;

  @override
  int setTimeout(void Function() callback, double milliseconds) {
    final id = ++_nextId;
    _timers[id] = Timer(
      Duration(microseconds: (milliseconds * 1000).round()),
      () {
        _timers.remove(id);
        callback();
      },
    );
    return id;
  }

  @override
  void clearTimeout(int id) => _timers.remove(id)?.cancel();
}

/// Throttles accessibility renders while preserving a trailing refresh.
final class TimeBasedDebouncer implements Disposable {
  /// Creates a time-based debouncer with xterm's one-second default threshold.
  TimeBasedDebouncer(
    this._render, {
    TerminalDebounceHost? host,
    this.thresholdMilliseconds = 1000,
  }) : _host = host ?? DartTerminalDebounceHost();

  final void Function(int start, int end) _render;
  final TerminalDebounceHost _host;

  /// Minimum time between renders.
  final double thresholdMilliseconds;

  int? _rowStart;
  int? _rowEnd;
  int? _rowCount;
  double _lastRefresh = 0;
  bool _additionalRefreshRequested = false;
  int? _timeout;
  bool _isDisposed = false;

  /// Adds a dirty row range and renders now or at the trailing edge.
  void refresh(int? rowStart, int? rowEnd, int rowCount) {
    _rowCount = rowCount;
    final start = rowStart ?? 0;
    final end = rowEnd ?? rowCount - 1;
    _rowStart = _rowStart == null
        ? start
        : (_rowStart! < start ? _rowStart : start);
    _rowEnd = _rowEnd == null ? end : (_rowEnd! > end ? _rowEnd : end);
    final requestedAt = _host.now;
    if (requestedAt - _lastRefresh >= thresholdMilliseconds) {
      final timeout = _timeout;
      if (timeout != null) {
        _host.clearTimeout(timeout);
        _timeout = null;
        _additionalRefreshRequested = false;
      }
      _lastRefresh = requestedAt;
      _innerRefresh();
    } else if (!_additionalRefreshRequested) {
      final wait = thresholdMilliseconds - (requestedAt - _lastRefresh);
      _additionalRefreshRequested = true;
      _timeout = _host.setTimeout(() {
        _lastRefresh = _host.now;
        _innerRefresh();
        _additionalRefreshRequested = false;
        _timeout = null;
      }, wait);
    }
  }

  void _innerRefresh() {
    final rowStart = _rowStart;
    final rowEnd = _rowEnd;
    final rowCount = _rowCount;
    if (rowStart == null || rowEnd == null || rowCount == null) return;
    final start = rowStart < 0 ? 0 : rowStart;
    final lastRow = rowCount - 1;
    final end = rowEnd > lastRow ? lastRow : rowEnd;
    _rowStart = null;
    _rowEnd = null;
    _render(start, end);
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    final timeout = _timeout;
    if (timeout != null) {
      _host.clearTimeout(timeout);
      _timeout = null;
    }
    _additionalRefreshRequested = false;
  }
}
