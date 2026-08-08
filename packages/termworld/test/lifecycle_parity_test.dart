import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
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
