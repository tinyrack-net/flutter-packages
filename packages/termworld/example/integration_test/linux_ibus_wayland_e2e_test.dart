@TestOn('linux')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termworld/termworld.dart';
import 'package:termworld_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real Wayland IBus keeps Hangul commits in typed order', (
    tester,
  ) async {
    final controller = TermworldExampleController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TermworldExampleApp(controller: controller));
    await tester.pumpAndSettle();
    await _waitForTerminalFocus(tester);
    await _activateHangulEngine();
    await _ensureHangulMode(tester, controller);

    const expected = '한글 abc 안녕 안녕하세요. ㅁㄴㅇㄻㄴㅇㄹ ';
    await _keys(<String>['g', 'k', ...'srmf'.split(''), 'space']);
    await _toggleLanguage();
    await _keys(<String>['a', 'b', 'c', 'space']);
    await _toggleLanguage();
    await _keys(<String>[...'dkssud'.split(''), 'space']);
    await _keys(<String>[...'dkssudgktpdy'.split(''), 'period', 'space']);
    await _keys(<String>[...'asdfasdf'.split(''), 'space']);

    await _waitForOutput(tester, controller, expected);
    final actual = controller.output;
    final artifactDirectory =
        Platform.environment['TERMWORLD_IBUS_ARTIFACT_DIR'];
    if (artifactDirectory != null) {
      final directory = Directory(artifactDirectory)
        ..createSync(recursive: true);
      File(
        '${directory.path}/pty-input.bin',
      ).writeAsBytesSync(utf8.encode(actual));
    }
    expect(
      actual,
      expected,
      reason: 'PTY bytes: ${utf8.encode(actual).map(_hex).join(' ')}',
    );
  });
}

final String _wlkey = Platform.environment['TERMWORLD_WLKEY'] ?? 'wlkey';

Future<void> _waitForTerminalFocus(WidgetTester tester) async {
  bool terminalHasFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null &&
        context.findAncestorWidgetOfExactType<TerminalView>() != null;
  }

  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!terminalHasFocus() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(terminalHasFocus(), isTrue);
}

Future<void> _keys(List<String> keys) async {
  await _run(_wlkey, <String>['-g', '80', ...keys]);
  await Future<void>.delayed(const Duration(milliseconds: 80));
}

Future<void> _toggleLanguage() async {
  await _keys(<String>['shift+space']);
}

Future<void> _ensureHangulMode(
  WidgetTester tester,
  TermworldExampleController controller,
) async {
  controller.clearOutput();
  await _keys(<String>['g']);
  await tester.pump(const Duration(milliseconds: 100));
  final latin = await _waitForOptional(
    () => controller.output.isNotEmpty,
    const Duration(seconds: 2),
  );
  if (latin) {
    expect(controller.output, 'g');
    controller.clearOutput();
    await _toggleLanguage();
  } else {
    await _keys(<String>['BackSpace']);
  }
  controller.clearOutput();
}

Future<void> _activateHangulEngine() async {
  final engines = await _run('ibus', <String>['list-engine']);
  const latinEngine = 'xkb:us::eng';
  expect(
    engines.stdout.toString(),
    contains(latinEngine),
    reason: 'The deterministic IBus Latin engine is unavailable',
  );
  await _selectEngineByState(latinEngine);
  await _selectEngineByState('hangul');
}

Future<void> _selectEngineByState(String engine) => _waitUntil(() async {
  await Process.run('ibus', <String>['engine', engine]);
  final current = await Process.run('ibus', <String>['engine']);
  return current.exitCode == 0 && current.stdout.toString().trim() == engine;
}, 'the focused GTK input context to activate the IBus engine "$engine"');

Future<void> _waitForOutput(
  WidgetTester tester,
  TermworldExampleController controller,
  String expected,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (controller.output != expected && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _waitUntil(
  FutureOr<bool> Function() predicate,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!await predicate() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(
    await predicate(),
    isTrue,
    reason: 'Timed out waiting for $description',
  );
}

Future<bool> _waitForOptional(
  bool Function() predicate,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return predicate();
}

String _hex(int value) => value.toRadixString(16).padLeft(2, '0');

Future<ProcessResult> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
  return result;
}
