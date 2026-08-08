import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termworld_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('committed graphemes cross the text-input boundary once', (
    tester,
  ) async {
    final controller = TermworldExampleController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TermworldExampleApp(controller: controller));
    await tester.pumpAndSettle();
    controller.clearOutput();

    await _injectEditingValue(
      tester,
      const TextEditingValue(
        text: 'ㅎ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    expect(controller.output, isEmpty);
    await _injectEditingValue(
      tester,
      const TextEditingValue(
        text: '한글 👩🏽‍💻 ',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.output, '한글 👩🏽‍💻 ');
    expect(find.text('한글 👩🏽‍💻 ', findRichText: true), findsOneWidget);
  });

  testWidgets('hardware keys produce the same VT sequences', (tester) async {
    final controller = TermworldExampleController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TermworldExampleApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('terminal')));
    await tester.pumpAndSettle();
    controller.clearOutput();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(controller.output, '\u007f\u001b\u007f\u001b[Z\u001b[1;5D');
  });
}

Future<void> _injectEditingValue(
  WidgetTester tester,
  TextEditingValue value,
) async {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall('injectEditingValue', value.toJSON()),
  );
  final completed = Completer<void>();
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'termworld/testing',
    message,
    (_) => completed.complete(),
  );
  await completed.future;
  await tester.pump();
}
