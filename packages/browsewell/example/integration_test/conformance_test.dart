import 'dart:io';

import 'package:browsewell/browsewell.dart';
import 'package:browsewell_example/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Browsewell deliberately injects through Flutter's production pointer
  // pipeline. Live test bindings normally turn device-sourced pointer events
  // into finder diagnostics instead of dispatching them to widgets.
  binding.shouldPropagateDevicePointerEvents = true;

  late HttpServer server;
  late HttpServer frameServer;
  late Directory profileDirectory;
  late Uri fixtureUrl;

  setUpAll(() async {
    final fixtureTemplate = await rootBundle.loadString(
      'test_fixtures/conformance.html',
    );
    final frameFixture = await rootBundle.loadString(
      'test_fixtures/frame.html',
    );
    frameServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    frameServer.listen((request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write(frameFixture);
      await request.response.close();
    });
    final frameUrl = 'http://127.0.0.1:${frameServer.port}/';
    final fixture = fixtureTemplate.replaceFirst('__FRAME_URL__', frameUrl);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write(fixture);
      await request.response.close();
    });
    fixtureUrl = Uri.parse('http://127.0.0.1:${server.port}/');
    profileDirectory = await Directory.systemTemp.createTemp(
      'browsewell-conformance-',
    );
  });

  tearDownAll(() async {
    await server.close(force: true);
    await frameServer.close(force: true);
    await profileDirectory.delete(recursive: true);
  });

  Future<({BrowsewellController controller, Map<String, String> refs})> mount(
    WidgetTester tester,
  ) async {
    final controller = await BrowsewellController.create(
      profile: const BrowsewellProfile(
        id: 'net.tinyrack.browsewell.conformance',
      ),
      initialUrl: fixtureUrl,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(BrowsewellExample(controller: controller));
    await tester.pumpAndSettle();
    await controller.waitFor(text: 'Browsewell fixture');
    final snapshot = await controller.snapshot();
    final refs = _refs(snapshot.document);
    return (controller: controller, refs: refs);
  }

  testWidgets('reports the complete desktop capability and snapshot contract', (
    tester,
  ) async {
    final mounted = await mount(tester);
    final controller = mounted.controller;
    final refs = mounted.refs;
    expect(
      controller.capabilities.toJson(),
      BrowsewellCapabilities.desktop.toJson(),
    );
    final snapshot = await controller.snapshot();
    expect(snapshot.generation, greaterThan(0));
    expect(refs.keys, containsAll(<String>['Trusted click', 'Name', 'Choice']));
  });

  testWidgets('delivers trusted click input', (tester) async {
    final mounted = await mount(tester);
    final controller = mounted.controller;
    final refs = mounted.refs;
    await controller.click(refs['Trusted click']!);
    await controller.waitFor(text: 'trusted-click');
  });

  testWidgets('delivers trusted text keyboard and select input', (
    tester,
  ) async {
    final mounted = await mount(tester);
    final controller = mounted.controller;
    final refs = mounted.refs;
    await controller.fill(refs['Name']!, 'Ada');
    await controller.waitFor(text: 'trusted:Ada');
    await controller.type(' Lovelace', ref: refs['Name']);
    await controller.waitFor(text: 'trusted:Ada Lovelace');
    await controller.keypress('End', ref: refs['Name']);
    await controller.waitFor(text: 'trusted-key:End');
    await controller.select(refs['Choice']!, 'two');
    await controller.waitFor(text: 'trusted:two');
  });

  testWidgets('delivers trusted hover and drag input', (tester) async {
    final mounted = await mount(tester);
    final controller = mounted.controller;
    final refs = mounted.refs;
    await controller.hover(refs['Drag source']!);
    await controller.waitFor(text: 'trusted-hover');
    await controller.drag(refs['Drag source']!, refs['Drag target']!);
    await controller.waitFor(text: 'trusted-drop');
  });

  testWidgets('delivers trusted upload scroll and viewport resize', (
    tester,
  ) async {
    final mounted = await mount(tester);
    final controller = mounted.controller;
    final refs = mounted.refs;
    final upload = File('${profileDirectory.path}/upload.txt');
    await upload.writeAsString('browsewell');
    await controller.upload(refs['Upload']!, <String>[upload.path]);
    await controller.waitFor(text: 'trusted:upload.txt');
    final scrollBefore = await controller.evaluate('() => window.scrollY');
    await controller.scroll(deltaX: 0, deltaY: 120);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      await controller.evaluate('() => window.scrollY'),
      greaterThan(scrollBefore! as num),
    );
    await controller.resize(const Size(640, 480));
    await tester.pumpAndSettle();
    final width = await _waitForInnerWidth(controller, 640);
    expect(width, closeTo(640, 2));
  });

  testWidgets('captures evaluates logs dialogs and rejects stale refs', (
    tester,
  ) async {
    final mounted = await mount(tester);
    final controller = mounted.controller;
    final refs = mounted.refs;
    await controller.click(refs['Trusted click']!);
    await controller.waitFor(text: 'trusted-click');
    final png = await controller.screenshot(fullPage: true);
    expect(png.take(4), orderedEquals(<int>[137, 80, 78, 71]));
    expect(_pngHeight(png), greaterThanOrEqualTo(1400));
    expect(
      await controller.evaluate('() => document.title'),
      'Browsewell fixture',
    );
    expect(
      await controller.evaluate(
        r"() => { alert('accepted'); return String(confirm('rejected')) + "
        r"':' + prompt('rejected', 'default'); }",
      ),
      'false:',
    );
    expect(
      await controller.evaluate(
        '() => document.querySelector("#result").textContent',
      ),
      startsWith('trusted'),
    );
    expect(
      (await controller.logs()).any(
        (entry) => entry.message.contains('browsewell-fixture-ready'),
      ),
      isTrue,
    );

    await controller.snapshot();
    await expectLater(
      controller.click(refs['Trusted click']!),
      throwsA(
        isA<BrowsewellException>().having(
          (error) => error.code,
          'code',
          BrowsewellErrorCode.staleRef,
        ),
      ),
    );

    await controller.reload();
    await controller.waitFor(url: fixtureUrl.toString());
    await controller.back();
    await controller.forward();
  });

  testWidgets('snapshots and automates a cross-origin frame', (tester) async {
    final mounted = await mount(tester);
    final controller = mounted.controller;
    final refs = mounted.refs;
    expect(refs.keys, contains('Frame button'));
    await controller.click(refs['Frame button']!);
    await controller.waitFor(text: 'trusted-frame-click');
  });

  testWidgets('supports two isolated views sharing one persistent profile', (
    tester,
  ) async {
    const profile = BrowsewellProfile(
      id: 'net.tinyrack.browsewell.conformance',
    );
    final first = await BrowsewellController.create(
      profile: profile,
      initialUrl: fixtureUrl,
    );
    final second = await BrowsewellController.create(
      profile: profile,
      initialUrl: fixtureUrl,
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: <Widget>[
            Expanded(child: BrowsewellView(controller: first)),
            Expanded(child: BrowsewellView(controller: second)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(first.id, isNot(second.id));
    expect(first.capabilities.multipleInstances, isTrue);
    await first.waitFor(text: 'Browsewell fixture');
    await second.waitFor(text: 'Browsewell fixture');
    final secondRefs = _refs((await second.snapshot()).document);
    await second.click(secondRefs['Trusted click']!);
    await second.waitFor(text: 'trusted-click');
    expect(
      await first.evaluate(
        '() => document.querySelector("#result").textContent',
      ),
      'Ready',
    );
    await first.evaluate(
      '() => { localStorage.shared = "persisted"; return true; }',
    );
    await second.reload();
    await second.waitFor(text: 'Browsewell fixture');
    expect(await second.evaluate('() => localStorage.shared'), 'persisted');

    await first.dispose();
    await second.dispose();
    final restored = await BrowsewellController.create(
      profile: profile,
      initialUrl: fixtureUrl,
    );
    addTearDown(restored.dispose);
    await tester.pumpWidget(BrowsewellExample(controller: restored));
    await restored.waitFor(text: 'Browsewell fixture');
    expect(await restored.evaluate('() => localStorage.shared'), 'persisted');
  });
}

int _pngHeight(Uint8List png) => ByteData.sublistView(png, 20, 24).getUint32(0);

Future<num> _waitForInnerWidth(
  BrowsewellController controller,
  num expected,
) async {
  num width = -1;
  for (var attempt = 0; attempt < 40; attempt += 1) {
    final value = await controller.evaluate('() => window.innerWidth');
    if (value is num) width = value;
    if ((width - expected).abs() <= 2) return width;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return width;
}

Map<String, String> _refs(BrowsewellSnapshotNode root) {
  final result = <String, String>{};
  void visit(BrowsewellSnapshotNode node) {
    final ref = node.ref;
    if (ref != null && node.name.isNotEmpty) result[node.name] = ref;
    node.children.forEach(visit);
  }

  visit(root);
  return result;
}
