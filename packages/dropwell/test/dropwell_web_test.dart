// The browser implementation has no native language, so this Dart suite is its
// L3 layer: it is the only place the web-specific class is exercised in
// isolation, before the conformance suite drives it inside a real browser.
@TestOn('browser')
library;

import 'dart:ui';

import 'package:dropwell/dropwell.dart';
import 'package:dropwell/dropwell_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DropwellWeb web;

  setUp(() => web = DropwellWeb());

  test('declares the capabilities it can currently deliver', () {
    expect(web.supportsDrop, isFalse);
    expect(web.supportsClipboardFiles, isFalse);
  });

  test('reports an empty clipboard rather than throwing', () async {
    expect(await web.readClipboardFiles(), isEmpty);
  });

  test('accepts a region publish without a drop implementation', () async {
    await expectLater(
      web.publishDropRegions(const <Rect>[Rect.fromLTRB(0, 0, 1, 1)]),
      completes,
    );
  });

  test('exposes a drag stream that stays open and silent', () async {
    final events = <DropwellDragEvent>[];
    web.dragEvents.listen(events.add);

    await pumpEventQueue();

    expect(events, isEmpty);
  });
}
