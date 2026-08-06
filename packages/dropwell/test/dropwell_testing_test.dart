import 'package:dropwell/dropwell.dart';
import 'package:dropwell/dropwell_testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Object? reply;

  setUp(() {
    calls.clear();
    reply = null;
    messenger.setMockMethodCallHandler(kDropwellTestingChannel, (call) async {
      calls.add(call);
      return reply;
    });
  });

  tearDown(
    () => messenger.setMockMethodCallHandler(kDropwellTestingChannel, null),
  );

  test('sends clipboard files as encoded maps', () async {
    await DropwellTesting.setSystemClipboard(<DropwellFile>[
      DropwellFile.bytes(
        fileName: 'pixel.png',
        bytes: Uint8List.fromList(<int>[1]),
        mimeType: 'image/png',
      ),
    ]);

    expect(calls.single.method, 'setSystemClipboard');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments['asBitmap'], isFalse);
    final files = arguments['files']! as List<Object?>;
    final file = files.single! as Map<Object?, Object?>;
    expect(file['fileName'], 'pixel.png');
    expect(file['mimeType'], 'image/png');
    expect(file['bytes'], <int>[1]);
  });

  test('offers a bitmap when asked for one', () async {
    await DropwellTesting.setSystemClipboard(<DropwellFile>[
      DropwellFile.bytes(
        fileName: 'pixel.png',
        bytes: Uint8List.fromList(<int>[1]),
        mimeType: 'image/png',
      ),
    ], asBitmap: true);

    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments['asBitmap'], isTrue);
  });

  test('clears the clipboard without arguments', () async {
    await DropwellTesting.clearSystemClipboard();

    expect(calls.single.method, 'clearSystemClipboard');
    expect(calls.single.arguments, isNull);
  });

  test('sends a drag phase, position, and files', () async {
    await DropwellTesting.synthesizeDrag(
      phase: DropwellDragPhase.perform,
      physicalPosition: const Offset(3, 4),
      files: <DropwellFile>[
        const DropwellFile.path(fileName: 'a.txt', path: '/tmp/a.txt'),
      ],
    );

    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(calls.single.method, 'synthesizeDrag');
    expect(arguments['phase'], 'perform');
    expect(arguments['x'], 3.0);
    expect(arguments['y'], 4.0);
    expect(arguments['files']! as List<Object?>, hasLength(1));
  });

  test('defaults a synthesized drag to the origin with no files', () async {
    await DropwellTesting.synthesizeDrag(phase: DropwellDragPhase.leave);

    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments['x'], 0.0);
    expect(arguments['y'], 0.0);
    expect(arguments['files'], isEmpty);
  });

  test('returns the bytes platform code read back', () async {
    reply = Uint8List.fromList(<int>[7, 8]);

    expect(await DropwellTesting.readFile('/tmp/a.txt'), <int>[7, 8]);
    expect(calls.single.arguments, '/tmp/a.txt');
  });

  test('fails loudly when platform code cannot read a reported path', () async {
    reply = null;

    await expectLater(
      DropwellTesting.readFile('/tmp/missing.txt'),
      throwsA(isA<StateError>()),
    );
  });
}
