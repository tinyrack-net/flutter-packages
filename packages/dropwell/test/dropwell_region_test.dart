import 'package:dropwell/dropwell.dart';
import 'package:dropwell/src/dropwell_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_dropwell_platform.dart';

void main() {
  late FakeDropwellPlatform platform;

  setUp(() async {
    await DropwellRegistry.resetInstance();
    platform = FakeDropwellPlatform();
    DropwellPlatform.instance = platform;
  });

  tearDown(() async {
    await DropwellRegistry.resetInstance();
    await platform.close();
  });

  Future<void> pumpRegion(
    WidgetTester tester, {
    required List<DropwellFile> drops,
    List<bool>? hovers,
    bool enabled = true,
    Size size = const Size(100, 50),
    double devicePixelRatio = 1,
  }) async {
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: DropwellRegion(
            enabled: enabled,
            onHoverChanged: hovers?.add,
            onDrop: (files) async => drops.addAll(files),
            child: SizedBox(width: size.width, height: size.height),
          ),
        ),
      ),
    );
  }

  testWidgets('publishes its bounds in physical pixels', (tester) async {
    await pumpRegion(tester, drops: <DropwellFile>[], devicePixelRatio: 2);
    await tester.pump();

    expect(platform.publishes.last, const <Rect>[
      Rect.fromLTRB(0, 0, 200, 100),
    ]);
  });

  testWidgets('withdraws its bounds while disabled', (tester) async {
    await pumpRegion(tester, drops: <DropwellFile>[], enabled: false);
    await tester.pump();

    expect(platform.publishes.every((regions) => regions.isEmpty), isTrue);
  });

  testWidgets('republishes after a resize', (tester) async {
    await pumpRegion(tester, drops: <DropwellFile>[]);
    await tester.pump();

    await pumpRegion(
      tester,
      drops: <DropwellFile>[],
      size: const Size(20, 20),
    );
    await tester.pump();

    expect(platform.publishes.last, const <Rect>[Rect.fromLTRB(0, 0, 20, 20)]);
  });

  testWidgets('withdraws its bounds after unmounting', (tester) async {
    await pumpRegion(tester, drops: <DropwellFile>[]);
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(platform.publishes.last, isEmpty);
  });

  testWidgets('reports hover while a drag is inside', (tester) async {
    final hovers = <bool>[];
    await pumpRegion(tester, drops: <DropwellFile>[], hovers: hovers);
    await tester.pump();

    platform.emit(
      const DropwellDragEvent(
        phase: DropwellDragPhase.enter,
        physicalPosition: Offset(10, 10),
      ),
    );
    await tester.pump();
    platform.emit(
      const DropwellDragEvent(
        phase: DropwellDragPhase.leave,
        physicalPosition: Offset.zero,
      ),
    );
    await tester.pump();

    expect(hovers, <bool>[true, false]);
  });

  testWidgets('delivers a drop inside its bounds', (tester) async {
    final drops = <DropwellFile>[];
    await pumpRegion(tester, drops: drops);
    await tester.pump();

    platform.emit(
      const DropwellDragEvent(
        phase: DropwellDragPhase.perform,
        physicalPosition: Offset(10, 10),
        files: <DropwellFile>[
          DropwellFile.path(fileName: 'a.txt', path: '/tmp/a.txt'),
        ],
      ),
    );
    await tester.pump();

    expect(drops.single.fileName, 'a.txt');
  });

  testWidgets('ignores a drop outside its bounds', (tester) async {
    final drops = <DropwellFile>[];
    await pumpRegion(tester, drops: drops);
    await tester.pump();

    platform.emit(
      const DropwellDragEvent(
        phase: DropwellDragPhase.perform,
        physicalPosition: Offset(500, 500),
        files: <DropwellFile>[
          DropwellFile.path(fileName: 'a.txt', path: '/tmp/a.txt'),
        ],
      ),
    );
    await tester.pump();

    expect(drops, isEmpty);
  });

  testWidgets('ignores a drop while disabled', (tester) async {
    final drops = <DropwellFile>[];
    await pumpRegion(tester, drops: drops, enabled: false);
    await tester.pump();

    platform.emit(
      const DropwellDragEvent(
        phase: DropwellDragPhase.perform,
        physicalPosition: Offset(10, 10),
        files: <DropwellFile>[
          DropwellFile.path(fileName: 'a.txt', path: '/tmp/a.txt'),
        ],
      ),
    );
    await tester.pump();

    expect(drops, isEmpty);
  });

  testWidgets('renders its child unchanged', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DropwellRegion(
          onDrop: (_) async {},
          child: const Text('payload'),
        ),
      ),
    );

    expect(find.text('payload'), findsOneWidget);
  });
}
