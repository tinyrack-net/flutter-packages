import 'package:dropwell/dropwell.dart';
import 'package:dropwell/src/method_channel_dropwell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dropwell.test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void mockHandler(Future<Object?>? Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  MethodChannelDropwell build({
    bool drop = true,
    bool clipboard = true,
  }) => MethodChannelDropwell(
    channel: channel,
    dropPlatforms: drop
        ? <TargetPlatform>{defaultTargetPlatform}
        : <TargetPlatform>{},
    clipboardPlatforms: clipboard
        ? <TargetPlatform>{defaultTargetPlatform}
        : <TargetPlatform>{},
  );

  setUp(calls.clear);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('declares capabilities from the platform sets', () {
    final capable = build();
    final incapable = build(drop: false, clipboard: false);

    expect(capable.supportsDrop, isTrue);
    expect(capable.supportsClipboardFiles, isTrue);
    expect(incapable.supportsDrop, isFalse);
    expect(incapable.supportsClipboardFiles, isFalse);
  });

  test('defaults to the shipped capability sets', () {
    final platform = MethodChannelDropwell(channel: channel);

    expect(
      platform.supportsDrop,
      kDropCapablePlatforms.contains(defaultTargetPlatform),
    );
    expect(
      platform.supportsClipboardFiles,
      kClipboardCapablePlatforms.contains(defaultTargetPlatform),
    );
  });

  test('reads clipboard files through the channel', () async {
    mockHandler(
      (_) async => <Object?>[
        <Object?, Object?>{'fileName': 'a.txt', 'path': '/tmp/a.txt'},
      ],
    );

    final files = await build().readClipboardFiles();

    expect(calls.single.method, 'readClipboardFiles');
    expect(files.single.fileName, 'a.txt');
  });

  test(
    'skips the channel when the platform cannot read the clipboard',
    () async {
      mockHandler((_) async => fail('must not reach platform code'));

      expect(await build(clipboard: false).readClipboardFiles(), isEmpty);
      expect(calls, isEmpty);
    },
  );

  test('publishes regions as flat doubles', () async {
    mockHandler((_) async => null);

    await build().publishDropRegions(const <Rect>[Rect.fromLTRB(1, 2, 3, 4)]);

    expect(calls.single.method, 'publishDropRegions');
    expect(calls.single.arguments, isA<Float64List>());
    expect(calls.single.arguments, <double>[1, 2, 3, 4]);
  });

  test('skips publishing when the platform cannot drop', () async {
    mockHandler((_) async => fail('must not reach platform code'));

    await build(drop: false).publishDropRegions(const <Rect>[Rect.zero]);

    expect(calls, isEmpty);
  });

  test('forwards a native drag call to the event stream', () async {
    final platform = build();
    final received = <DropwellDragEvent>[];
    platform.dragEvents.listen(received.add);

    await _sendNativeCall(
      messenger,
      const MethodCall('drag', <Object?, Object?>{
        'phase': 'enter',
        'x': 4.0,
        'y': 5.0,
      }),
    );
    await pumpEventQueue();

    expect(received.single.phase, DropwellDragPhase.enter);
    expect(received.single.physicalPosition, const Offset(4, 5));
  });

  test('answers an unknown native call as unimplemented', () async {
    final platform = build();
    final received = <DropwellDragEvent>[];
    platform.dragEvents.listen(received.add);

    // A null reply is the channel's "not implemented" signal, so platform code
    // learns the call went nowhere instead of assuming Dart handled it.
    final reply = await _sendNativeCall(
      messenger,
      const MethodCall('mystery'),
    );
    await pumpEventQueue();

    expect(reply, isNull);
    expect(received, isEmpty);
  });
}

Future<ByteData?> _sendNativeCall(
  TestDefaultBinaryMessenger messenger,
  MethodCall call,
) async {
  ByteData? reply;
  await messenger.handlePlatformMessage(
    'dropwell.test',
    const StandardMethodCodec().encodeMethodCall(call),
    (value) => reply = value,
  );
  return reply;
}
