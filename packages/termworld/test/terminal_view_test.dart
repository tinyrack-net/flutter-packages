import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

void main() {
  testWidgets('renders and automatically resizes the headless terminal', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 2));
    addTearDown(terminal.dispose);
    await terminal.writeAndWait('한글 terminal');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 200,
          child: TerminalView(terminal: terminal),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(terminal.dimensions, isNotNull);
    expect(terminal.cols, greaterThan(10));
    expect(find.bySemanticsLabel('terminal'), findsOneWidget);
  });

  testWidgets('commits Hangul, candidate replacement, and emoji once', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
    );
    await tester.pump();

    for (final value in const <TextEditingValue>[
      TextEditingValue(
        text: 'ㅎ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
      TextEditingValue(
        text: '한글',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
      TextEditingValue(
        text: '韓國',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
      TextEditingValue(
        text: '韓國👩🏽\u200d💻',
        selection: TextSelection.collapsed(offset: 9),
      ),
    ]) {
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
      if (!value.composing.isCollapsed) {
        expect(
          find.byKey(const ValueKey<String>('termworld-preedit')),
          findsOneWidget,
        );
      }
    }

    expect(output.join(), '韓國👩🏽\u200d💻');
    expect(
      find.byKey(const ValueKey<String>('termworld-preedit')),
      findsNothing,
    );
  });

  testWidgets('cancels preedit without output and commits it on focus loss', (
    tester,
  ) async {
    final terminal = Terminal();
    final focusNode = FocusNode();
    final nextFocusNode = FocusNode();
    addTearDown(terminal.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(nextFocusNode.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(
                child: TerminalView(
                  terminal: terminal,
                  focusNode: focusNode,
                  autofocus: true,
                ),
              ),
              TextButton(
                key: const ValueKey<String>('next-focus'),
                focusNode: nextFocusNode,
                onPressed: nextFocusNode.requestFocus,
                child: const Text('next'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'かな',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    expect(output, isEmpty);
    expect(find.text('かな'), findsOneWidget);

    tester.testTextInput.updateEditingValue(TextEditingValue.empty);
    await tester.pump();
    expect(output, isEmpty);
    expect(
      find.byKey(const ValueKey<String>('termworld-preedit')),
      findsNothing,
    );

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '中文',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('next-focus')));
    await tester.pump();

    expect(output.join(), '中文');
  });

  testWidgets('commits dead-key combining clusters as one text payload', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
    );
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'e\u0301',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();

    expect(output, <String>['e\u0301']);
  });

  testWidgets('clears committed edit state without emitting duplicate DEL', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
    );
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '한',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(TextEditingValue.empty);
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '글',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();

    expect(output, <String>['한', '글']);
  });

  testWidgets('debug hook injects through the platform channel boundary', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
    );
    await tester.pump();
    final message = const StandardMethodCodec().encodeMethodCall(
      MethodCall(
        'injectEditingValue',
        const TextEditingValue(
          text: '한글',
          selection: TextSelection.collapsed(offset: 2),
        ).toJSON(),
      ),
    );
    final completed = Completer<void>();

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'termworld/testing',
      message,
      (_) => completed.complete(),
    );
    await completed.future;
    await tester.pump();

    expect(output, <String>['한글']);
  });

  testWidgets('controller restores keyboard and synchronizes selection', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 20, rows: 2));
    final controller = TerminalViewController();
    addTearDown(terminal.dispose);
    addTearDown(controller.dispose);
    await terminal.writeAndWait('select this');
    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(
          terminal: terminal,
          controller: controller,
        ),
      ),
    );
    await tester.pump();

    controller
      ..requestKeyboard()
      ..selectLines(0, 0);
    await tester.pump();

    expect(controller.hasSelection, isTrue);
    expect(controller.selectedText, contains('select this'));
    expect(controller.selection, isNotNull);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    controller
      ..clearSelection()
      ..selectAll();
    expect(controller.hasSelection, isTrue);
  });

  testWidgets('renders marker decorations by layer and anchor', (tester) async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 2));
    addTearDown(terminal.dispose);
    await terminal.writeAndWait('decorated');
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 40,
          child: TerminalView(terminal: terminal, autoResize: false),
        ),
      ),
    );
    await tester.pump();

    final marker = terminal.registerMarker()!;
    final rendered = <TerminalDecoration>[];
    final bottom = terminal.registerDecoration(
      marker: marker,
      width: 2,
      height: 2,
      backgroundColor: '#123',
      foregroundColor: '#112233',
      borderColor: '#1234',
    )!..onRender.listen(rendered.add);
    final top = terminal.registerDecoration(
      marker: marker,
      anchor: TerminalDecorationAnchor.right,
      x: 1,
      width: 2,
      backgroundColor: '#11223344',
      borderColor: 'invalid',
      layer: TerminalDecorationLayer.top,
    )!..onRender.listen(rendered.add);
    await tester.pump();

    expect(rendered, containsAll(<TerminalDecoration>[bottom, top]));
    marker.dispose();
    await tester.pump();
    expect(bottom.isDisposed, isTrue);
    expect(top.isDisposed, isTrue);
    expect(terminal.decorations, isEmpty);
  });

  testWidgets('maps the complete navigation keyboard surface to VT', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
    );
    await tester.pump();

    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.backspace,
      LogicalKeyboardKey.tab,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.insert,
      LogicalKeyboardKey.delete,
      LogicalKeyboardKey.pageUp,
      LogicalKeyboardKey.pageDown,
      LogicalKeyboardKey.keyA,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.backspace,
      LogicalKeyboardKey.tab,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.pageDown,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(output, contains('\u007f'));
    expect(output, contains('\u001b[Z'));
    expect(output, contains('\u001b[A'));
    expect(output, contains('\u001b[1;5A'));
    // xterm reserves Ctrl+Insert for host clipboard handling.
    expect(output, isNot(contains('\u001b[2;5~')));
    expect(output, contains('\u001b\r'));
  });

  testWidgets('matches xterm application, function and control key tables', (
    tester,
  ) async {
    final terminal = Terminal();
    terminal.options.macOptionIsMeta = true;
    final output = <String>[];
    addTearDown(terminal.dispose);
    terminal.onData.listen(output.add);
    await terminal.writeAndWait('\u001b[?1h');
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
    );
    await tester.pump();

    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.f1,
      LogicalKeyboardKey.f2,
      LogicalKeyboardKey.f3,
      LogicalKeyboardKey.f4,
      LogicalKeyboardKey.f5,
      LogicalKeyboardKey.f12,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(
      output,
      <String>[
        '\u001bOA',
        '\u001bOD',
        '\u001bOH',
        '\u001bOF',
        '\u001bOP',
        '\u001bOQ',
        '\u001bOR',
        '\u001bOS',
        '\u001b[15~',
        '\u001b[24~',
        '\u0001',
        '\u0000',
        '\u001ba',
        '\u001b[15;2~',
      ],
    );
  });

  testWidgets('uses Shift+Page keys for local scroll and reserves Insert', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(rows: 3));
    final output = <String>[];
    addTearDown(terminal.dispose);
    terminal.onData.listen(output.add);
    await terminal.writeAndWait(
      List<String>.generate(12, (index) => '$index\r\n').join(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(
          terminal: terminal,
          autofocus: true,
          autoResize: false,
        ),
      ),
    );
    await tester.pump();
    final bottom = terminal.viewportY;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(terminal.viewportY, lessThan(bottom));
    expect(output, isEmpty);
  });

  testWidgets(
    'reattaches when terminal, focus, controller, or readonly changes',
    (
      tester,
    ) async {
      final first = Terminal();
      final second = Terminal();
      final focusNode = FocusNode();
      final controller = TerminalViewController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal: first, autofocus: true)),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: second,
            focusNode: focusNode,
            controller: controller,
            readOnly: true,
          ),
        ),
      );
      await tester.pump();
      second.focus();
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal: second)),
      );
      await tester.pump();

      expect(second.dimensions, isNotNull);
    },
  );
}
