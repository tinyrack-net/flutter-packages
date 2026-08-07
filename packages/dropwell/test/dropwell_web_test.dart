// The browser implementation has no native language, so this Dart suite is its
// L3 layer: it drives the real DOM listeners against a detached element, which
// keeps it off the document the test harness itself lives on.
@TestOn('browser')
library;

import 'dart:typed_data';
import 'dart:ui';

import 'package:dropwell/dropwell.dart';
import 'package:dropwell/dropwell_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLDivElement target;
  late DropwellWeb platform;

  setUp(() {
    target = web.HTMLDivElement();
    platform = DropwellWeb(target: target);
  });

  DropwellFile fixture(String name, String? mime) => DropwellFile.bytes(
    fileName: name,
    bytes: Uint8List.fromList(<int>[1, 2, 3]),
    mimeType: mime,
  );

  test('declares both capabilities', () {
    expect(platform.supportsDrop, isTrue);
    expect(platform.supportsClipboardFiles, isTrue);
  });

  test('reports no clipboard files before anything is pasted', () async {
    expect(await platform.readClipboardFiles(), isEmpty);
  });

  test('reads names, media types, and order out of a paste', () async {
    await platform.setSystemClipboard(<DropwellFile>[
      fixture('notes.txt', 'text/plain'),
      fixture('pixel.png', 'image/png'),
    ], asBitmap: false);

    final files = await platform.readClipboardFiles();

    expect(files.map((file) => file.fileName), <String>[
      'notes.txt',
      'pixel.png',
    ]);
    expect(files.map((file) => file.mimeType), <String>[
      'text/plain',
      'image/png',
    ]);
    expect(files.first.bytes, <int>[1, 2, 3]);
    expect(files.first.path, isNull);
  });

  test('keeps an unreported media type null rather than empty', () async {
    await platform.setSystemClipboard(<DropwellFile>[
      fixture('mystery', null),
    ], asBitmap: false);

    expect((await platform.readClipboardFiles()).single.mimeType, isNull);
  });

  test('forgets the paste when the clipboard is cleared', () async {
    await platform.setSystemClipboard(<DropwellFile>[
      fixture('notes.txt', 'text/plain'),
    ], asBitmap: false);
    await platform.clearSystemClipboard();

    expect(await platform.readClipboardFiles(), isEmpty);
  });

  test('emits enter, over, and leave through the real listeners', () async {
    final phases = <DropwellDragPhase>[];
    platform.dragEvents.listen((event) => phases.add(event.phase));

    for (final phase in <DropwellDragPhase>[
      DropwellDragPhase.enter,
      DropwellDragPhase.over,
      DropwellDragPhase.leave,
    ]) {
      await platform.synthesizeDrag(
        phase: phase,
        physicalPosition: const Offset(10, 10),
        files: const <DropwellFile>[],
      );
    }
    await pumpEventQueue();

    expect(phases, <DropwellDragPhase>[
      DropwellDragPhase.enter,
      DropwellDragPhase.over,
      DropwellDragPhase.leave,
    ]);
  });

  test('carries dropped files on the perform phase', () async {
    final events = <DropwellDragEvent>[];
    platform.dragEvents.listen(events.add);
    await platform.publishDropRegions(const <Rect>[
      Rect.fromLTRB(0, 0, 10000, 10000),
    ]);

    await platform.synthesizeDrag(
      phase: DropwellDragPhase.perform,
      physicalPosition: const Offset(10, 10),
      files: <DropwellFile>[fixture('dropped.txt', 'text/plain')],
    );
    await pumpEventQueue();

    final perform = events.singleWhere(
      (event) => event.phase == DropwellDragPhase.perform,
    );
    expect(perform.files.single.fileName, 'dropped.txt');
    expect(perform.files.single.bytes, <int>[1, 2, 3]);
  });

  test('refuses a browser drop outside every published region', () async {
    await platform.publishDropRegions(const <Rect>[
      Rect.fromLTRB(0, 0, 10, 10),
    ]);
    final outside = web.DragEvent(
      'dragover',
      web.DragEventInit(clientX: 5000, clientY: 5000, cancelable: true),
    );
    final inside = web.DragEvent(
      'dragover',
      web.DragEventInit(clientX: 0, clientY: 0, cancelable: true),
    );

    target
      ..dispatchEvent(outside)
      ..dispatchEvent(inside);
    await pumpEventQueue();

    // defaultPrevented is the browser's own record of whether the drop was
    // accepted, so this asserts the answer the user's cursor would show.
    expect(outside.defaultPrevented, isFalse);
    expect(inside.defaultPrevented, isTrue);
  });

  test('refuses to read a path a browser can never report', () async {
    await expectLater(
      platform.readFile('/tmp/a.txt'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
