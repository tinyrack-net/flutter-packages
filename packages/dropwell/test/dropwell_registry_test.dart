import 'dart:ui';

import 'package:dropwell/dropwell.dart';
import 'package:dropwell/src/dropwell_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_dropwell_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDropwellPlatform platform;
  late DropwellRegistry registry;

  setUp(() {
    platform = FakeDropwellPlatform();
    registry = DropwellRegistry(platform);
  });

  tearDown(() async {
    await registry.dispose();
    await platform.close();
  });

  test('publishes bounds once and stays quiet while nothing moves', () async {
    registry.register(_StubTarget(const Rect.fromLTRB(0, 0, 10, 10)));

    await registry.publishIfChanged();
    await registry.publishIfChanged();

    expect(platform.publishes, <List<Rect>>[
      const <Rect>[Rect.fromLTRB(0, 0, 10, 10)],
    ]);
  });

  test('republishes when a target moves', () async {
    final target = _StubTarget(const Rect.fromLTRB(0, 0, 10, 10));
    registry.register(target);
    await registry.publishIfChanged();

    target.bounds = const Rect.fromLTRB(5, 5, 15, 15);
    await registry.publishIfChanged();

    expect(platform.publishes.last, const <Rect>[Rect.fromLTRB(5, 5, 15, 15)]);
  });

  test('omits a target that reports no bounds', () async {
    registry
      ..register(_StubTarget(null))
      ..register(_StubTarget(const Rect.fromLTRB(0, 0, 1, 1)));

    await registry.publishIfChanged();

    expect(platform.publishes.single, const <Rect>[Rect.fromLTRB(0, 0, 1, 1)]);
  });

  test('publishes an empty list after the last target unregisters', () async {
    final target = _StubTarget(const Rect.fromLTRB(0, 0, 10, 10));
    registry.register(target);
    await registry.publishIfChanged();

    registry.unregister(target);
    await registry.publishIfChanged();

    expect(platform.publishes.last, isEmpty);
  });

  test('reports hover enter once while the pointer stays inside', () async {
    final target = _StubTarget(const Rect.fromLTRB(0, 0, 10, 10));
    registry.register(target);

    await registry.handleEvent(_at(DropwellDragPhase.enter, 1, 1));
    await registry.handleEvent(_at(DropwellDragPhase.over, 2, 2));

    expect(target.hoverChanges, <bool>[true]);
  });

  test('reports hover leave when the pointer moves outside', () async {
    final target = _StubTarget(const Rect.fromLTRB(0, 0, 10, 10));
    registry.register(target);

    await registry.handleEvent(_at(DropwellDragPhase.enter, 1, 1));
    await registry.handleEvent(_at(DropwellDragPhase.over, 50, 50));

    expect(target.hoverChanges, <bool>[true, false]);
  });

  test('reports hover leave on a leave phase', () async {
    final target = _StubTarget(const Rect.fromLTRB(0, 0, 10, 10));
    registry.register(target);

    await registry.handleEvent(_at(DropwellDragPhase.enter, 1, 1));
    await registry.handleEvent(
      const DropwellDragEvent(
        phase: DropwellDragPhase.leave,
        physicalPosition: Offset.zero,
      ),
    );

    expect(target.hoverChanges, <bool>[true, false]);
  });

  test('moves hover between overlapping targets, topmost first', () async {
    final under = _StubTarget(const Rect.fromLTRB(0, 0, 100, 100));
    final over = _StubTarget(const Rect.fromLTRB(10, 10, 20, 20));
    registry
      ..register(under)
      ..register(over);

    await registry.handleEvent(_at(DropwellDragPhase.enter, 5, 5));
    await registry.handleEvent(_at(DropwellDragPhase.over, 15, 15));

    expect(under.hoverChanges, <bool>[true, false]);
    expect(over.hoverChanges, <bool>[true]);
  });

  test('delivers a drop to the topmost target and clears hover', () async {
    final under = _StubTarget(const Rect.fromLTRB(0, 0, 100, 100));
    final over = _StubTarget(const Rect.fromLTRB(10, 10, 20, 20));
    registry
      ..register(under)
      ..register(over);
    await registry.handleEvent(_at(DropwellDragPhase.enter, 15, 15));

    await registry.handleEvent(
      DropwellDragEvent(
        phase: DropwellDragPhase.perform,
        physicalPosition: const Offset(15, 15),
        files: <DropwellFile>[_file('a.txt')],
      ),
    );

    expect(over.drops.single.single.fileName, 'a.txt');
    expect(under.drops, isEmpty);
    expect(over.hoverChanges, <bool>[true, false]);
  });

  test('ignores a drop outside every target', () async {
    final target = _StubTarget(const Rect.fromLTRB(0, 0, 10, 10));
    registry.register(target);

    await registry.handleEvent(
      DropwellDragEvent(
        phase: DropwellDragPhase.perform,
        physicalPosition: const Offset(90, 90),
        files: <DropwellFile>[_file('a.txt')],
      ),
    );

    expect(target.drops, isEmpty);
  });

  test('drops hover state when the hovered target unregisters', () async {
    final target = _StubTarget(const Rect.fromLTRB(0, 0, 10, 10));
    registry.register(target);
    await registry.handleEvent(_at(DropwellDragPhase.enter, 1, 1));

    registry.unregister(target);
    await registry.handleEvent(
      const DropwellDragEvent(
        phase: DropwellDragPhase.leave,
        physicalPosition: Offset.zero,
      ),
    );

    expect(target.hoverChanges, <bool>[true]);
  });

  test('exposes registration order and the published list', () async {
    final first = _StubTarget(const Rect.fromLTRB(0, 0, 1, 1));
    final second = _StubTarget(const Rect.fromLTRB(1, 1, 2, 2));
    registry
      ..register(first)
      ..register(second);
    await registry.publishIfChanged();

    expect(registry.targets, <DropwellTarget>[first, second]);
    expect(registry.publishedRegions, hasLength(2));
  });

  test('stops publishing after dispose', () async {
    final target = _StubTarget(const Rect.fromLTRB(0, 0, 10, 10));
    registry.register(target);

    await registry.dispose();
    platform.emit(_at(DropwellDragPhase.enter, 1, 1));
    await pumpEventQueue();

    expect(target.hoverChanges, isEmpty);
    expect(registry.targets, isEmpty);
  });

  test('routes events arriving on the platform stream', () async {
    final target = _StubTarget(const Rect.fromLTRB(0, 0, 10, 10));
    registry.register(target);

    platform.emit(_at(DropwellDragPhase.enter, 1, 1));
    await pumpEventQueue();

    expect(target.hoverChanges, <bool>[true]);
  });
}

DropwellDragEvent _at(DropwellDragPhase phase, double x, double y) =>
    DropwellDragEvent(phase: phase, physicalPosition: Offset(x, y));

DropwellFile _file(String name) =>
    DropwellFile.path(fileName: name, path: '/tmp/$name');

final class _StubTarget implements DropwellTarget {
  _StubTarget(this.bounds);

  Rect? bounds;
  final List<bool> hoverChanges = <bool>[];
  final List<List<DropwellFile>> drops = <List<DropwellFile>>[];

  @override
  Rect? get physicalBounds => bounds;

  @override
  void onHoverChanged({required bool hovering}) => hoverChanges.add(hovering);

  @override
  Future<void> onDrop(List<DropwellFile> files) async => drops.add(files);
}
