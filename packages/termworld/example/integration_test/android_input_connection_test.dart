import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld_example/main.dart';

const _testingChannel = MethodChannel('termworld/testing');
const _fixtureAsset = 'assets/ime/android_input_connection_cases.json';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shared transactions cross the real Android InputConnection', (
    tester,
  ) async {
    final fixture = await _AndroidInputFixture.load();
    expect(fixture.version, 1);
    expect(fixture.guard, '  ');

    for (final fixtureCase in fixture.cases) {
      // This marker is retained in the CI transcript artifact so the exact
      // transaction that failed is available beside logcat and dumpsys.
      // ignore: avoid_print
      print('TERMWORLD_ANDROID_FIXTURE=${fixtureCase.name}');
      final controller = TermworldExampleController();
      await tester.pumpWidget(TermworldExampleApp(controller: controller));
      await tester.pumpAndSettle();
      controller.clearOutput();

      int? baselineConnectionCount;
      for (final step in fixtureCase.steps) {
        final operation = step['op']! as String;
        if (operation == 'pumpFrame') {
          final milliseconds = step['milliseconds'] as int? ?? 0;
          final delay = Duration(milliseconds: milliseconds);
          await tester.runAsync(() => Future<void>.delayed(delay));
          await tester.pump();
          continue;
        }
        if (operation == 'focus') {
          await _setTerminalFocus(
            tester,
            focused: step['value']! as bool,
          );
          continue;
        }

        final response = await _executeNativeStep(step);
        expect(
          response['accepted'],
          isTrue,
          reason: '${fixtureCase.name}: $operation',
        );
        expect(
          response['driverMarker'],
          'termworld-android-input-connection-driver',
          reason: '${fixtureCase.name}: Debug native driver',
        );
        baselineConnectionCount ??= response['connectionCount']! as int;
        // Immediate vendor calls remain a single burst. The fixture-level
        // status request below supplies the deterministic FIFO boundary.
        await _settleNativeStep(tester, step);
        // The CI transcript preserves the last accepted native transaction.
        // ignore: avoid_print
        print(
          'TERMWORLD_ANDROID_STEP=${fixtureCase.name} '
          'operation=$operation output=${jsonEncode(controller.output)}',
        );
      }
      final finalStatus = await _nativeStatus();
      await tester.pump(Duration.zero);

      expect(
        controller.output,
        fixtureCase.expectedPty,
        reason: '${fixtureCase.family}: ${fixtureCase.name}',
      );
      if (fixtureCase.expectedReconnections case final expected?) {
        final finalConnectionCount = finalStatus['connectionCount']! as int;
        expect(
          finalConnectionCount - (baselineConnectionCount ?? 0),
          expected,
          reason: '${fixtureCase.name}: connection recovery count',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      controller.dispose();
    }
  });
}

Future<void> _setTerminalFocus(
  WidgetTester tester, {
  required bool focused,
}) async {
  await tester.tap(
    find.byKey(
      ValueKey<String>(focused ? 'terminal' : 'focus-target'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<Map<String, Object?>> _executeNativeStep(
  Map<String, Object?> step,
) async {
  final response = await _testingChannel.invokeMapMethod<String, Object?>(
    'androidInputConnection.execute',
    step,
  );
  return response ??
      (throw StateError('Android input driver returned no transaction status'));
}

Future<void> _settleNativeStep(
  WidgetTester tester,
  Map<String, Object?> step,
) async {
  final operation = step['op']! as String;
  if (operation != 'sendKeyEvent' && operation != 'dispatchKeyEvent') {
    await tester.pump(Duration.zero);
    return;
  }

  final key = switch (step['keyCode']! as int) {
    62 => LogicalKeyboardKey.space,
    66 => LogicalKeyboardKey.enter,
    67 => LogicalKeyboardKey.backspace,
    160 => LogicalKeyboardKey.numpadEnter,
    final keyCode => throw UnsupportedError(
      'Unknown Android key code in native fixture: $keyCode',
    ),
  };
  final shouldBePressed = step['action']! as int == 0;
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(Duration.zero);
    final isPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(
      key,
    );
    if (isPressed == shouldBePressed) return;
  }
  fail(
    'Android $operation did not reach HardwareKeyboard: '
    '${key.keyLabel} pressed=$shouldBePressed',
  );
}

Future<Map<String, Object?>> _nativeStatus() async {
  final response = await _testingChannel.invokeMapMethod<String, Object?>(
    'androidInputConnection.status',
  );
  return response ??
      (throw StateError('Android input driver returned no connection status'));
}

final class _AndroidInputFixture {
  const _AndroidInputFixture({
    required this.version,
    required this.guard,
    required this.cases,
  });

  final int version;
  final String guard;
  final List<_AndroidInputFixtureCase> cases;

  static Future<_AndroidInputFixture> load() async {
    final source = await rootBundle.loadString(_fixtureAsset);
    final document = jsonDecode(source) as Map<String, dynamic>;
    return _AndroidInputFixture(
      version: document['version']! as int,
      guard: document['guard']! as String,
      cases: <_AndroidInputFixtureCase>[
        for (final value in document['cases']! as List<dynamic>)
          _AndroidInputFixtureCase.fromJson(
            Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
          ),
      ],
    );
  }
}

final class _AndroidInputFixtureCase {
  const _AndroidInputFixtureCase({
    required this.name,
    required this.family,
    required this.steps,
    required this.expectedPty,
    required this.expectedReconnections,
  });

  factory _AndroidInputFixtureCase.fromJson(Map<String, dynamic> json) =>
      _AndroidInputFixtureCase(
        name: json['name']! as String,
        family: json['family']! as String,
        steps: <Map<String, Object?>>[
          for (final value in json['steps']! as List<dynamic>)
            Map<String, Object?>.from(value as Map<dynamic, dynamic>),
        ],
        expectedPty: json['expectedPty']! as String,
        expectedReconnections: json['expectedReconnections'] as int?,
      );

  final String name;
  final String family;
  final List<Map<String, Object?>> steps;
  final String expectedPty;
  final int? expectedReconnections;
}
