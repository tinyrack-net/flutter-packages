import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all IME transitions cross the text-input boundary once', (
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
        text: '한글',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(controller.output, '한글');

    // Kana composition cancellation must not leak preedit text.
    await _injectEditingValue(
      tester,
      const TextEditingValue(
        text: 'かな',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await _injectEditingValue(tester, TextEditingValue.empty);
    expect(controller.output, '한글');

    // Chinese phonetic input and candidate replacements remain preedit until
    // the final candidate is committed.
    for (final value in const <TextEditingValue>[
      TextEditingValue(
        text: 'zhong',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
      TextEditingValue(
        text: '中國',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
      TextEditingValue(
        text: '中文',
        selection: TextSelection.collapsed(offset: 2),
      ),
    ]) {
      await _injectEditingValue(tester, value);
    }
    expect(controller.output, '한글中文');

    // A dead key plus combining mark is one grapheme payload.
    await _injectEditingValue(
      tester,
      const TextEditingValue(
        text: '\u00b4',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await _injectEditingValue(
      tester,
      const TextEditingValue(
        text: 'e\u0301',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );

    await _injectEditingValue(
      tester,
      const TextEditingValue(
        text: '👩🏽‍💻',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );

    // Focus loss commits an active reconversion exactly once.
    await _injectEditingValue(
      tester,
      const TextEditingValue(
        text: '재변환',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('focus-target')));
    await tester.pumpAndSettle();

    expect(controller.output, '한글中文e\u0301👩🏽‍💻재변환');
  });

  testWidgets('clipboard paste normalizes newlines and brackets once', (
    tester,
  ) async {
    final controller = TermworldExampleController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TermworldExampleApp(controller: controller));
    await tester.pumpAndSettle();
    controller
      ..clearOutput()
      ..setBracketedPaste(enabled: true);
    await tester.pumpAndSettle();
    await Clipboard.setData(const ClipboardData(text: '한글\nかな'));

    await tester.tap(find.byKey(const ValueKey<String>('paste-clipboard')));
    await tester.pumpAndSettle();

    expect(controller.output, '\u001b[200~한글\rかな\u001b[201~');
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
