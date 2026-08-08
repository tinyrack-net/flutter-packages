import 'package:browsewell/browsewell.dart';
import 'package:browsewell/browsewell_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('net.tinyrack.browsewell/methods');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'create' => <String, Object?>{
              'id': 'native-1',
              'capabilities': BrowsewellCapabilities.desktop.toJson(),
            },
            'execute' => <String, Object?>{'value': 'ok'},
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('encodes create and command requests without product state', () async {
    final platform = MethodChannelBrowsewell();
    final result = await platform.create(
      BrowsewellCreateRequest(
        profile: const BrowsewellProfile(id: 'net.tinyrack.coder.default'),
        initialUrl: Uri.parse('about:blank'),
        policy: const BrowsewellPolicy(),
      ),
    );
    final value = await platform.execute(
      result.id,
      const BrowsewellCommand('evaluate', <String, Object?>{
        'function': '() => 1',
      }),
    );

    expect(result.id, 'native-1');
    expect(value, <String, Object?>{'value': 'ok'});
    expect(calls.first.method, 'create');
    expect(calls.first.arguments, <String, Object?>{
      'profile': <String, Object?>{'id': 'net.tinyrack.coder.default'},
      'initialUrl': 'about:blank',
      'policy': const BrowsewellPolicy().toJson(),
    });

    await platform.setViewport(
      result.id,
      rect: const Rect.fromLTWH(1, 2, 300, 200),
      visible: true,
    );
    await platform.disposeBrowser(result.id);
    expect(
      calls.map((call) => call.method),
      containsAll(<String>{
        'setViewport',
        'dispose',
      }),
    );
  });

  test('rejects a missing native create result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(
      MethodChannelBrowsewell().create(
        BrowsewellCreateRequest(
          profile: const BrowsewellProfile(id: 'net.tinyrack.test'),
          initialUrl: Uri.parse('about:blank'),
          policy: const BrowsewellPolicy(),
        ),
      ),
      throwsFormatException,
    );
  });
}
