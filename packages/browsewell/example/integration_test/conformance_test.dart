import 'dart:io';
import 'package:browsewell/browsewell.dart';
import 'package:browsewell_example/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late Directory profileDirectory;
  late Uri fixtureUrl;

  setUpAll(() async {
    final fixture = await rootBundle.loadString(
      'test_fixtures/conformance.html',
    );
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
    await profileDirectory.delete(recursive: true);
  });

  testWidgets('desktop backend satisfies the shared browser contract', (
    tester,
  ) async {
    final controller = await BrowsewellController.create(
      profile: BrowsewellProfile(directory: profileDirectory.path),
      initialUrl: fixtureUrl,
    );
    addTearDown(controller.dispose);
    expect(
      controller.capabilities.toJson(),
      BrowsewellCapabilities.desktop.toJson(),
    );

    await tester.pumpWidget(BrowsewellExample(controller: controller));
    await tester.pumpAndSettle();
    await controller.waitFor(text: 'Browsewell fixture');

    final snapshot = await controller.snapshot();
    final refs = _refs(snapshot.document);
    expect(snapshot.generation, greaterThan(0));
    expect(refs.keys, containsAll(<String>['Trusted click', 'Name', 'Choice']));

    await controller.click(refs['Trusted click']!);
    await controller.waitFor(text: 'trusted-click');
    await controller.fill(refs['Name']!, 'Ada');
    await controller.type(' Lovelace', ref: refs['Name']);
    await controller.keypress('End', ref: refs['Name']);
    await controller.select(refs['Choice']!, 'two');
    await controller.hover(refs['Drag source']!);
    await controller.scroll(deltaX: 0, deltaY: 120);
    await controller.resize(const Size(640, 480));

    final png = await controller.screenshot(fullPage: true);
    expect(png.take(4), orderedEquals(<int>[137, 80, 78, 71]));
    expect(
      await controller.evaluate('() => document.title'),
      'Browsewell fixture',
    );
    expect(
      await controller.evaluate(
        '() => document.querySelector("#result").textContent',
      ),
      startsWith('trusted:'),
    );
    expect(
      (await controller.logs()).any(
        (entry) => entry.message.contains('browsewell-fixture-ready'),
      ),
      isTrue,
    );

    await controller.reload();
    await controller.waitFor(url: fixtureUrl.toString());
    await controller.back();
    await controller.forward();
  });

  testWidgets('supports two isolated views sharing one persistent profile', (
    tester,
  ) async {
    final profile = BrowsewellProfile(directory: profileDirectory.path);
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

    expect(first.id, isNot(second.id));
    expect(first.capabilities.multipleInstances, isTrue);
    await first.evaluate(
      '() => { localStorage.shared = "persisted"; return true; }',
    );
    expect(await second.evaluate('() => localStorage.shared'), 'persisted');
  });
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
