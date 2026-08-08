import 'dart:typed_data';

import 'package:browsewell/browsewell.dart';
import 'package:browsewell/browsewell_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BrowsewellPlatform original;
  late _FakeBrowsewellPlatform platform;

  setUp(() {
    original = BrowsewellPlatform.instance;
    platform = _FakeBrowsewellPlatform();
    BrowsewellPlatform.instance = platform;
  });

  tearDown(() {
    BrowsewellPlatform.instance = original;
  });

  test(
    'creates an isolated browser with an explicit persistent profile',
    () async {
      final controller = await BrowsewellController.create(
        profile: const BrowsewellProfile(directory: '/profiles/coder'),
        initialUrl: Uri.parse('https://example.test'),
      );

      expect(controller.id, 'browser-1');
      expect(platform.created.single.profile.directory, '/profiles/coder');
      expect(
        platform.created.single.initialUrl,
        Uri.parse('https://example.test'),
      );

      await controller.dispose();
      expect(platform.disposed, <String>['browser-1']);
      await expectLater(controller.reload(), throwsStateError);
    },
  );

  test('exposes the complete desktop automation contract', () async {
    final controller = await BrowsewellController.create(
      profile: const BrowsewellProfile(directory: '/profiles/coder'),
    );

    await controller.navigate(Uri.parse('https://example.test/form'));
    await controller.back();
    await controller.forward();
    await controller.reload();
    await controller.resize(const Size(390, 844));
    await controller.click('@e1');
    await controller.fill('@e2', 'Ada');
    await controller.type(' Lovelace', ref: '@e2');
    await controller.keypress('Enter', ref: '@e2');
    await controller.hover('@e3');
    await controller.select('@e4', 'two');
    await controller.drag('@e5', '@e6');
    await controller.upload('@e7', const <String>['/workspace/photo.png']);
    await controller.scroll(deltaX: 0, deltaY: 420, ref: '@e8');
    await controller.waitFor(text: 'Saved');
    await controller.waitFor(url: 'example.test');
    expect(controller.waitFor, throwsArgumentError);

    expect(await controller.snapshot(), isA<BrowsewellSnapshot>());
    expect(
      await controller.screenshot(fullPage: true),
      Uint8List.fromList(<int>[1, 2, 3]),
    );
    expect(await controller.logs(maxEntries: 10), hasLength(1));
    expect(await controller.evaluate('() => document.title'), 'Fixture');
    expect(
      platform.commands.map((item) => item.name),
      containsAll(<String>{
        'navigate',
        'back',
        'forward',
        'reload',
        'resize',
        'click',
        'fill',
        'type',
        'keypress',
        'hover',
        'select',
        'drag',
        'upload',
        'scroll',
        'wait',
        'snapshot',
        'screenshot',
        'logs',
        'evaluate',
      }),
    );
  });

  test('rejects navigation outside the configured scheme policy', () async {
    final controller = await BrowsewellController.create(
      profile: const BrowsewellProfile(directory: '/profiles/coder'),
    );

    await expectLater(
      controller.navigate(Uri.parse('file:///etc/passwd')),
      throwsA(
        isA<BrowsewellException>().having(
          (error) => error.code,
          'code',
          BrowsewellErrorCode.denied,
        ),
      ),
    );
    expect(platform.commands, isEmpty);
  });

  testWidgets('view reports its global viewport and visibility', (
    tester,
  ) async {
    final controller = await BrowsewellController.create(
      profile: const BrowsewellProfile(directory: '/profiles/coder'),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 240,
            child: BrowsewellView(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(platform.viewports.single.id, 'browser-1');
    expect(platform.viewports.single.rect.size, const Size(320, 240));
    expect(platform.viewports.single.visible, isTrue);
  });

  test('ignores late viewport reports after controller disposal', () async {
    final controller = await BrowsewellController.create(
      profile: const BrowsewellProfile(directory: '/profiles/coder'),
    );

    await controller.dispose();
    await controller.setViewport(Rect.zero, visible: false);

    expect(platform.viewports, isEmpty);
  });
}

final class _FakeBrowsewellPlatform extends BrowsewellPlatform
    with MockPlatformInterfaceMixin {
  final List<BrowsewellCreateRequest> created = <BrowsewellCreateRequest>[];
  final List<String> disposed = <String>[];
  final List<BrowsewellCommand> commands = <BrowsewellCommand>[];
  final List<({String id, Rect rect, bool visible})> viewports =
      <({String id, Rect rect, bool visible})>[];

  @override
  Future<BrowsewellCreateResult> create(BrowsewellCreateRequest request) async {
    created.add(request);
    return const BrowsewellCreateResult(
      id: 'browser-1',
      capabilities: BrowsewellCapabilities.desktop,
    );
  }

  @override
  Future<void> disposeBrowser(String id) async => disposed.add(id);

  @override
  Stream<BrowsewellEvent> events(String id) =>
      const Stream<BrowsewellEvent>.empty();

  @override
  Future<Object?> execute(String id, BrowsewellCommand command) async {
    commands.add(command);
    return switch (command.name) {
      'snapshot' => <String, Object?>{
        'generation': 1,
        'document': <String, Object?>{'role': 'document', 'name': 'Fixture'},
      },
      'screenshot' => Uint8List.fromList(<int>[1, 2, 3]),
      'logs' => <Object?>[
        <String, Object?>{
          'level': 'info',
          'message': 'ready',
          'timestampMicros': 1,
        },
      ],
      'evaluate' => 'Fixture',
      _ => null,
    };
  }

  @override
  Future<void> setViewport(
    String id, {
    required Rect rect,
    required bool visible,
  }) async => viewports.add((id: id, rect: rect, visible: visible));

  @override
  Widget buildView(String id) => const SizedBox.expand();
}
