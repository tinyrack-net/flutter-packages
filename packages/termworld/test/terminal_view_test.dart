import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('processes an ordered delta batch without duplicate commits', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);
    await _pumpTerminal(tester, emulator);

    await _sendDeltas(tester, <Map<String, Object>>[
      _delta(old: '', text: 'ㅎ', start: 0, end: 0, composingEnd: 1),
      _delta(old: 'ㅎ', text: '한', start: 0, end: 1, composingEnd: 1),
      _delta(old: '한', text: '', start: -1, end: -1),
      _delta(old: '한', text: ' ', start: 1, end: 1),
    ]);

    expect(output.join(), '한 ');
    expect(tester.testTextInput.setClientArgs?['enableDeltaModel'], isTrue);
    expect(tester.testTextInput.setClientArgs?['viewId'], isNotNull);
  });

  testWidgets('handles committed replacement and deletion by grapheme', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);
    await _pumpTerminal(tester, emulator);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '가👩🏽‍💻',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '나',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();

    expect(output, <String>['가👩🏽‍💻', '\u007f\u007f', '나']);
  });

  testWidgets('does not commit preedit on cancellation or focus loss', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);
    await _pumpTerminal(tester, emulator);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '한',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();
    expect(output, isEmpty);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(output, isEmpty);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets('read-only mode never opens or emits text input', (tester) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);
    await _pumpTerminal(tester, emulator, readOnly: true);

    await tester.tap(find.byType(TerminalView));
    await tester.pump(kDoubleTapTimeout);

    expect(tester.testTextInput.hasAnyClients, isFalse);
    expect(output, isEmpty);
  });

  testWidgets('action and hardware paths have distinct ownership', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);
    await _pumpTerminal(tester, emulator);

    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);

    expect(output, <String>['\r', '\u001b[A', '\u007f']);
  });

  testWidgets('shifted control chords remain available to ancestor shortcuts', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    var shortcuts = 0;
    addTearDown(emulator.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(
              LogicalKeyboardKey.keyB,
              control: true,
              shift: true,
            ): () =>
                shortcuts++,
          },
          child: SizedBox(
            width: 400,
            height: 200,
            child: TerminalView(emulator: emulator, autofocus: true),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(shortcuts, 1);
    expect(output, isEmpty);
  });

  testWidgets('committed text makes deletion delta own Backspace', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);
    await _pumpTerminal(tester, emulator);
    tester.testTextInput.enterText('x');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    tester.testTextInput.enterText('');
    await tester.pump();

    expect(output, <String>['x', '\u007f']);
  });

  testWidgets('renders styled text, preedit, selection, and resizes', (
    tester,
  ) async {
    final sizes = <TerminalSize>[];
    final emulator = TerminalEmulator(columns: 2, rows: 2, onResize: sizes.add)
      ..write('\u001b[1;3;4;7;31;44mA한');
    final controller = TerminalViewController(emulator: emulator)
      ..setSelection(
        const TerminalSelection(TerminalPosition(0, 0), TerminalPosition(2, 0)),
      )
      ..setScrollOffset(1);
    addTearDown(emulator.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 160,
          child: TerminalView(
            emulator: emulator,
            controller: controller,
            autofocus: true,
            semanticLabel: 'shell',
          ),
        ),
      ),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ㅎ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('shell'), findsOneWidget);
    expect(sizes, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection drag and secondary tap invoke view hooks', (
    tester,
  ) async {
    final emulator = TerminalEmulator()..write('select me');
    final controller = TerminalViewController(emulator: emulator);
    var secondaryTaps = 0;
    addTearDown(emulator.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 200,
          child: TerminalView(
            emulator: emulator,
            controller: controller,
            onSecondaryTapDown: (_) => secondaryTaps++,
          ),
        ),
      ),
    );

    await tester.dragFrom(const Offset(10, 10), const Offset(100, 0));
    await tester.tapAt(
      tester.getCenter(find.byType(TerminalView)),
      buttons: kSecondaryButton,
    );
    await tester.pump(kDoubleTapTimeout);

    expect(controller.hasSelection, isTrue);
    expect(secondaryTaps, 1);
  });

  testWidgets('mouse tracking reports pointer input instead of selecting', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add)
      ..write('\u001b[?1000;1006h');
    final controller = TerminalViewController(emulator: emulator);
    var pointerEvents = 0;
    addTearDown(emulator.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 200,
          child: TerminalView(
            emulator: emulator,
            controller: controller,
            onPointerEvent: (_) => pointerEvents++,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TerminalView)),
    );
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);

    expect(output, hasLength(2));
    expect(output.first, startsWith('\u001b[<0;'));
    expect(output.last, startsWith('\u001b[<3;'));
    expect(controller.hasSelection, isFalse);
    expect(pointerEvents, 2);
  });
}

Future<void> _pumpTerminal(
  WidgetTester tester,
  TerminalEmulator emulator, {
  bool readOnly = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 400,
        height: 200,
        child: TerminalView(
          emulator: emulator,
          autofocus: true,
          readOnly: readOnly,
        ),
      ),
    ),
  );
  await tester.pump();
}

Map<String, Object> _delta({
  required String old,
  required String text,
  required int start,
  required int end,
  int composingEnd = -1,
}) {
  final length = start < 0
      ? old.length
      : old.length - (end - start) + text.length;
  return <String, Object>{
    'oldText': old,
    'deltaText': text,
    'deltaStart': start,
    'deltaEnd': end,
    'selectionBase': length,
    'selectionExtent': length,
    'selectionAffinity': 'TextAffinity.downstream',
    'selectionIsDirectional': false,
    'composingBase': composingEnd < 0 ? -1 : 0,
    'composingExtent': composingEnd,
  };
}

Future<void> _sendDeltas(
  WidgetTester tester,
  List<Map<String, Object>> deltas,
) async {
  final setClient = tester.testTextInput.log.lastWhere(
    (call) => call.method == 'TextInput.setClient',
  );
  final client = (setClient.arguments! as List<Object?>).first! as int;
  final message = const JSONMessageCodec().encodeMessage(<String, Object>{
    'method': 'TextInputClient.updateEditingStateWithDeltas',
    'args': <Object>[
      client,
      <String, Object>{'deltas': deltas},
    ],
  });
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        SystemChannels.textInput.name,
        message,
        (_) {},
      );
  await tester.pump();
}
