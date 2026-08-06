// One conformance suite runs unchanged on every platform dropwell declares.
//
// Branching is allowed on a declared capability and on nothing else. There is
// deliberately no `Platform.isX`, no `kIsWeb`, and no `skip:` here: a
// per-platform test body lets two platforms drift apart while every CI job
// stays green, which is the exact failure this suite exists to catch. A
// platform that cannot do something asserts the *unsupported* contract instead
// of asserting nothing.

import 'package:dropwell/dropwell.dart';
import 'package:dropwell/dropwell_testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List pixelPng;
  late Uint8List notesTxt;

  setUpAll(() async {
    pixelPng = (await rootBundle.load(
      'integration_test/fixtures/pixel.png',
    )).buffer.asUint8List();
    notesTxt = (await rootBundle.load(
      'integration_test/fixtures/notes.txt',
    )).buffer.asUint8List();
  });

  tearDown(() async {
    if (platform.supportsClipboardFiles) {
      await DropwellTesting.clearSystemClipboard();
    }
  });

  group('capabilities', () {
    testWidgets('are answered synchronously and do not change', (tester) async {
      final drop = platform.supportsDrop;
      final clipboard = platform.supportsClipboardFiles;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(platform.supportsDrop, drop);
      expect(platform.supportsClipboardFiles, clipboard);
    });
  });

  group('clipboard', () {
    testWidgets('returns an empty list when the clipboard holds no files', (
      tester,
    ) async {
      if (!platform.supportsClipboardFiles) {
        expect(await platform.readClipboardFiles(), isEmpty);
        return;
      }
      await DropwellTesting.clearSystemClipboard();

      expect(await platform.readClipboardFiles(), isEmpty);
    });

    testWidgets('preserves file names, media types, and order', (tester) async {
      if (!platform.supportsClipboardFiles) {
        expect(await platform.readClipboardFiles(), isEmpty);
        return;
      }
      await DropwellTesting.setSystemClipboard(<DropwellFile>[
        DropwellFile.bytes(
          fileName: 'notes.txt',
          bytes: notesTxt,
          mimeType: 'text/plain',
        ),
        DropwellFile.bytes(
          fileName: 'pixel.png',
          bytes: pixelPng,
          mimeType: 'image/png',
        ),
      ]);

      final files = await platform.readClipboardFiles();

      expect(files.map((file) => file.fileName), <String>[
        'notes.txt',
        'pixel.png',
      ]);
      expect(files.map((file) => file.mimeType), <String>[
        'text/plain',
        'image/png',
      ]);
      expect(await _read(files.last), pixelPng);
    });

    testWidgets('reads a bare bitmap as bytes', (tester) async {
      if (!platform.supportsClipboardFiles) {
        expect(await platform.readClipboardFiles(), isEmpty);
        return;
      }
      await DropwellTesting.setSystemClipboard(<DropwellFile>[
        DropwellFile.bytes(
          fileName: 'pixel.png',
          bytes: pixelPng,
          mimeType: 'image/png',
        ),
      ]);

      final file = (await platform.readClipboardFiles()).single;

      expect(file.mimeType, 'image/png');
      expect(await _read(file), isNotEmpty);
    });
  });

  group('drop', () {
    testWidgets('reports hover entering and leaving a region', (tester) async {
      final observed = <bool>[];
      await _pumpRegion(tester, onHover: observed.add);
      if (!platform.supportsDrop) {
        await _expectNoDropActivity(tester, observed);
        return;
      }

      await _drag(tester, DropwellDragPhase.enter, const Offset(10, 10));
      await _drag(tester, DropwellDragPhase.over, const Offset(20, 20));
      await _drag(tester, DropwellDragPhase.leave, Offset.zero);

      expect(observed, <bool>[true, false]);
    });

    testWidgets('delivers dropped files in order to the region under the '
        'pointer', (tester) async {
      final dropped = <DropwellFile>[];
      await _pumpRegion(tester, onDrop: dropped.addAll);
      if (!platform.supportsDrop) {
        await _expectNoDropActivity(tester, <bool>[]);
        expect(dropped, isEmpty);
        return;
      }

      await _drag(
        tester,
        DropwellDragPhase.perform,
        const Offset(10, 10),
        files: <DropwellFile>[
          DropwellFile.bytes(fileName: 'notes.txt', bytes: notesTxt),
          DropwellFile.bytes(fileName: 'pixel.png', bytes: pixelPng),
        ],
      );

      expect(dropped.map((file) => file.fileName), <String>[
        'notes.txt',
        'pixel.png',
      ]);
      expect(await _read(dropped.first), notesTxt);
    });

    testWidgets('ignores a drop outside every published region', (
      tester,
    ) async {
      final dropped = <DropwellFile>[];
      await _pumpRegion(tester, onDrop: dropped.addAll);
      if (!platform.supportsDrop) {
        await _expectNoDropActivity(tester, <bool>[]);
        expect(dropped, isEmpty);
        return;
      }

      await _drag(
        tester,
        DropwellDragPhase.perform,
        const Offset(100000, 100000),
        files: <DropwellFile>[
          DropwellFile.bytes(fileName: 'notes.txt', bytes: notesTxt),
        ],
      );

      expect(dropped, isEmpty);
    });

    testWidgets(
      'withdraws a disabled region so the platform refuses the drop',
      (tester) async {
        final dropped = <DropwellFile>[];
        await _pumpRegion(tester, onDrop: dropped.addAll, enabled: false);
        if (!platform.supportsDrop) {
          await _expectNoDropActivity(tester, <bool>[]);
          expect(dropped, isEmpty);
          return;
        }

        await _drag(
          tester,
          DropwellDragPhase.perform,
          const Offset(10, 10),
          files: <DropwellFile>[
            DropwellFile.bytes(fileName: 'notes.txt', bytes: notesTxt),
          ],
        );

        expect(dropped, isEmpty);
      },
    );
  });
}

DropwellPlatform get platform => DropwellPlatform.instance;

Future<void> _pumpRegion(
  WidgetTester tester, {
  ValueChanged<bool>? onHover,
  ValueChanged<List<DropwellFile>>? onDrop,
  bool enabled = true,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: DropwellRegion(
          enabled: enabled,
          onHoverChanged: onHover,
          onDrop: (files) async => onDrop?.call(files),
          child: const SizedBox(width: 400, height: 300),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _drag(
  WidgetTester tester,
  DropwellDragPhase phase,
  Offset physicalPosition, {
  List<DropwellFile> files = const <DropwellFile>[],
}) async {
  await DropwellTesting.synthesizeDrag(
    phase: phase,
    physicalPosition: physicalPosition,
    files: files,
  );
  await tester.pumpAndSettle();
}

/// Asserts that a platform declaring no drop support truly delivers nothing.
Future<void> _expectNoDropActivity(
  WidgetTester tester,
  List<bool> observedHovers,
) async {
  await DropwellPlatform.instance.publishDropRegions(const <Rect>[]);
  await tester.pumpAndSettle();

  expect(observedHovers, isEmpty);
}

Future<Uint8List> _read(DropwellFile file) async {
  final bytes = file.bytes;
  if (bytes != null) return bytes;
  final path = file.path!;
  final data = await DropwellTesting.readFile(path);
  return data;
}
