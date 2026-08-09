import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/core/render_debouncer.dart';

void main() {
  test('RenderDebouncer coalesces ranges and runs refresh callbacks', () {
    final host = _FrameHost();
    final renders = <(int, int)>[];
    final callbacks = <double>[];
    final debouncer =
        RenderDebouncer((start, end) {
            renders.add((start, end));
          }, host)
          ..refresh(3, 5, 10)
          ..refresh(-2, 12, 10)
          ..addRefreshCallback(callbacks.add);

    expect(host.pending, hasLength(1));
    host.fire();
    expect(renders, <(int, int)>[(0, 9)]);
    expect(callbacks, <double>[0]);
    debouncer.dispose();
  });

  test('TimeBasedDebouncer preserves one trailing coalesced refresh', () {
    final host = _TimeHost()..time = 1000;
    final renders = <(int, int)>[];
    final debouncer =
        TimeBasedDebouncer(
            (start, end) => renders.add((start, end)),
            host: host,
          )
          ..refresh(2, 3, 10)
          ..refresh(4, 20, 10)
          ..refresh(1, 5, 10);

    expect(renders, <(int, int)>[(2, 3)]);
    expect(host.pending, hasLength(1));
    host
      ..time = 2000
      ..fire();
    expect(renders, <(int, int)>[(2, 3), (1, 9)]);
    debouncer.dispose();
  });

  test('debouncer disposal cancels pending platform work', () {
    final frameHost = _FrameHost();
    RenderDebouncer((_, _) {}, frameHost)
      ..refresh(null, null, 5)
      ..dispose();
    expect(frameHost.cancelled, hasLength(1));

    final timeHost = _TimeHost();
    TimeBasedDebouncer((_, _) {}, host: timeHost)
      ..refresh(null, null, 5)
      ..dispose();
    expect(timeHost.cancelled, hasLength(1));
  });
}

final class _FrameHost implements TerminalFrameHost {
  final Map<int, void Function(double)> pending =
      <int, void Function(double)>{};
  final List<int> cancelled = <int>[];
  var _nextId = 0;

  @override
  void cancelFrame(int id) {
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  int requestFrame(void Function(double timestamp) callback) {
    final id = ++_nextId;
    pending[id] = callback;
    return id;
  }

  void fire() {
    final callback = pending.remove(pending.keys.single)!;
    callback(0);
  }
}

final class _TimeHost implements TerminalDebounceHost {
  final Map<int, void Function()> pending = <int, void Function()>{};
  final List<int> cancelled = <int>[];
  var _nextId = 0;
  double time = 0;

  @override
  double get now => time;

  @override
  void clearTimeout(int id) {
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  int setTimeout(void Function() callback, double milliseconds) {
    final id = ++_nextId;
    pending[id] = callback;
    return id;
  }

  void fire() => pending.remove(pending.keys.single)!();
}
