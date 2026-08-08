/// A resource with an explicit lifetime.
abstract interface class Disposable {
  /// Whether [dispose] has already been called.
  bool get isDisposed;

  /// Releases the resource. Calling this more than once is harmless.
  void dispose();
}

/// A disposable backed by a callback.
final class CallbackDisposable implements Disposable {
  /// Creates a disposable that invokes [callback] once.
  CallbackDisposable(void Function() callback) : _callback = callback;

  void Function()? _callback;

  @override
  bool get isDisposed => _callback == null;

  @override
  void dispose() {
    final callback = _callback;
    if (callback == null) return;
    _callback = null;
    callback();
  }
}

/// Base class for resources that own other disposables.
abstract class DisposableStore implements Disposable {
  final List<Disposable> _children = <Disposable>[];
  bool _isDisposed = false;

  @override
  bool get isDisposed => _isDisposed;

  /// Adds [child] to this object's lifetime.
  T own<T extends Disposable>(T child) {
    if (_isDisposed) {
      child.dispose();
      throw StateError('Cannot register a disposable after disposal');
    }
    _children.add(child);
    return child;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final child in _children.reversed) {
      child.dispose();
    }
    _children.clear();
  }
}
