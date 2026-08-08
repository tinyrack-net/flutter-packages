import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('Emitter', () {
    test('should fire with 0 listeners without error', () {
      final emitter = TerminalEventEmitter<int>();
      addTearDown(emitter.dispose);
      emitter.fire(42);
    });

    test('should fire with 1 listener', () {
      final emitter = TerminalEventEmitter<int>();
      addTearDown(emitter.dispose);
      int? received;
      emitter.event.listen((value) => received = value);
      emitter.fire(42);
      expect(received, 42);
    });

    test('should fire with 1 listener using thisArgs', () {
      final emitter = TerminalEventEmitter<int>();
      final receiver = _Receiver();
      addTearDown(emitter.dispose);
      emitter.event.listen(receiver.handle);
      emitter.fire(42);
      expect(receiver.value, 42);
    });

    test('should fire with multiple listeners', () {
      final emitter = TerminalEventEmitter<int>();
      final results = <int>[];
      addTearDown(emitter.dispose);
      emitter.event
        ..listen(results.add)
        ..listen((value) => results.add(value * 2))
        ..listen((value) => results.add(value * 3));
      emitter.fire(10);
      expect(results, <int>[10, 20, 30]);
    });

    test('should handle listener removal during fire', () {
      final emitter = TerminalEventEmitter<int>();
      final results = <String>[];
      addTearDown(emitter.dispose);
      late Disposable second;
      emitter.event.listen((_) => results.add('first'));
      second = emitter.event.listen((_) {
        results.add('second');
        second.dispose();
      });
      emitter.event.listen((_) => results.add('third'));
      emitter.fire(1);
      expect(results, <String>['first', 'second', 'third']);
    });

    test('should not fire after dispose', () {
      final emitter = TerminalEventEmitter<int>();
      var called = false;
      emitter.event.listen((_) => called = true);
      emitter
        ..dispose()
        ..fire(42);
      expect(called, isFalse);
    });

    test('should allow disposing a listener', () {
      final emitter = TerminalEventEmitter<int>();
      var count = 0;
      addTearDown(emitter.dispose);
      final listener = emitter.event.listen((_) => count++);
      emitter.fire(1);
      listener.dispose();
      emitter.fire(2);
      expect(count, 1);
    });
  });

  test('disposable lifetimes are idempotent and reject late ownership', () {
    var calls = 0;
    final callback = CallbackDisposable(() => calls++);
    expect(
      (
        (callback
              ..dispose()
              ..dispose())
            .isDisposed,
        calls,
      ),
      (true, 1),
    );

    final store = _Store();
    final child = CallbackDisposable(() => calls++);
    store
      ..own(child)
      ..dispose()
      ..dispose();
    expect((store.isDisposed, child.isDisposed, calls), (true, true, 2));

    final lateChild = CallbackDisposable(() => calls++);
    expect(() => store.own(lateChild), throwsStateError);
    expect((lateChild.isDisposed, calls), (true, 3));
  });

  test('event disposal rejects listeners and suppresses later delivery', () {
    final emitter = TerminalEventEmitter<int>();
    final values = <int>[];
    final listener = emitter.event.listen(values.add);
    emitter.fire(1);
    listener.dispose();
    emitter
      ..fire(2)
      ..dispose()
      ..dispose()
      ..fire(3);

    expect(values, <int>[1]);
    expect(emitter.isDisposed, isTrue);
    expect(() => emitter.event.listen(values.add), throwsStateError);
  });
}

final class _Store extends DisposableStore {}

final class _Receiver {
  int value = 0;

  int handle(int next) => value = next;
}
