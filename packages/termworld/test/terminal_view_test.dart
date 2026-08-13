import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/termworld.dart';

void main() {
  test('resolves xterm browser theme defaults and overrides', () {
    final defaults = TerminalThemes.resolve(const TerminalColorTheme());
    expect(defaults.foreground, const Color(0xffffffff));
    expect(defaults.background, const Color(0xff000000));
    expect(defaults.palette.first, const Color(0xff2e3436));

    final overridden = TerminalThemes.resolve(
      const TerminalColorTheme(
        foreground: '#123456',
        cursor: '#ffffff80',
        cursorAccent: '#010203',
        selectionBackground: 'rgba(1, 2, 3, 0.5)',
        selectionForeground: '#040506',
        selectionInactiveBackground: '#112233',
        red: '#abc',
      ),
    );
    expect(overridden.foreground, const Color(0xff123456));
    expect(overridden.selection, const Color(0x80010203));
    expect(overridden.selectionForeground, const Color(0xff040506));
    expect(overridden.selectionInactive.a, closeTo(0.3, 0.000001));
    expect(overridden.selectionInactive.r, closeTo(0x11 / 255, 0.000001));
    expect(overridden.selectionInactive.g, closeTo(0x22 / 255, 0.000001));
    expect(overridden.selectionInactive.b, closeTo(0x33 / 255, 0.000001));
    expect(overridden.cursorAccent, const Color(0xff010203));
    expect(overridden.cursor, const Color(0xff808080));
    expect(overridden.palette[1], const Color(0xffaabbcc));

    final dynamic = TerminalThemes.resolve(
      const TerminalColorTheme(),
      overrides: TerminalColorOverrides(
        indexed: const <int, int>{1: 0x010203},
        foreground: 0x112233,
        background: 0x445566,
        cursor: 0x778899,
      ),
    );
    expect(dynamic.palette[1], const Color(0xff010203));
    expect(dynamic.foreground, const Color(0xff112233));
    expect(dynamic.background, const Color(0xff445566));
    expect(dynamic.cursor, const Color(0xff778899));

    expect(
      TerminalThemes.ensureContrast(
        const Color(0xff000000),
        const Color(0xff606060),
        4,
      ),
      const Color(0xff707070),
    );
    expect(
      TerminalThemes.ensureContrast(
        const Color(0xffffffff),
        const Color(0xff606060),
        7,
      ),
      const Color(0xff565656),
    );
    expect(
      TerminalThemes.ensureContrast(
        const Color(0xff000000),
        const Color(0xffffffff),
        4.5,
      ),
      const Color(0xffffffff),
    );
    expect(
      TerminalThemes.ensureContrast(
        const Color(0xff123456),
        const Color(0xff654321),
        1,
      ),
      const Color(0xff654321),
    );
    expect(
      TerminalThemes.ensureContrast(
        const Color(0xff000000),
        const Color(0xff606060),
        100,
      ),
      const Color(0xffffffff),
    );
    expect(
      TerminalThemes.ensureContrast(
        const Color(0xffffffff),
        const Color(0xff606060),
        100,
      ),
      const Color(0xff000000),
    );
    expect(
      TerminalThemes.blend(
        const Color(0xff000000),
        const Color(0xffffffff),
      ),
      const Color(0xffffffff),
    );
    expect(
      TerminalThemes.blend(
        const Color(0xff000000),
        const Color(0x80ffffff),
      ),
      const Color(0xff808080),
    );
    expect(
      TerminalThemes.resolve(
        const TerminalColorTheme(foreground: 'transparent'),
      ).foreground,
      const Color(0x00000000),
    );
    final extended = List<String>.filled(241, '#123456');
    expect(
      TerminalThemes.resolve(
        TerminalColorTheme(
          foreground: 'not-a-color',
          background: '#not-hex',
          extendedAnsi: extended,
        ),
      ).palette,
      hasLength(256),
    );
  });

  test('detached controller methods are safe no-ops', () {
    final controller = TerminalViewController();
    addTearDown(controller.dispose);
    controller
      ..requestKeyboard()
      ..clearSelection()
      ..selectAll()
      ..selectLines(0, 1)
      ..select(0, 0, 1)
      ..scrollLines(1)
      ..scrollPages(1)
      ..scrollToTop()
      ..scrollToBottom();
    expect(controller.hasSelection, isFalse);
    expect(controller.selectedText, isNull);
    expect(controller.selection, isNull);
  });

  testWidgets('exposes visible terminal rows in screen reader mode', (
    tester,
  ) async {
    final terminal = Terminal(
      options: TerminalOptions(cols: 10, rows: 2, screenReaderMode: true),
    );
    addTearDown(terminal.dispose);
    final previousStrings = Terminal.strings;
    addTearDown(() => Terminal.strings = previousStrings);
    Terminal.strings = const TerminalLocalizableStrings(
      promptLabel: 'Localized terminal input',
      tooMuchOutput: 'Localized output warning',
    );
    await _writeAndPump(tester, terminal, 'first\r\nsecond');
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(
          terminal: terminal,
          semanticLabel: Terminal.strings.promptLabel,
        ),
      ),
    );
    await tester.pump();

    final semanticSurface = find.bySemanticsLabel('Localized terminal input');
    expect(semanticSurface, findsOneWidget);
    final node = tester.getSemantics(semanticSurface);
    expect(node.label, 'Localized terminal input');
    expect(node.value, 'first\nsecond');

    await _writeAndPump(tester, terminal, ' third');
    expect(find.bySemanticsLabel(' third'), findsOneWidget);
    semantics.dispose();
    // Canonical line translation owns xterm's 15-second string-cache timer.
    // Dispose before Flutter's pending-timer invariant runs.
    terminal.dispose();
  });

  testWidgets('renders and automatically resizes the headless terminal', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 2));
    addTearDown(terminal.dispose);
    await _writeAndPump(tester, terminal, '한글 terminal');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 200,
          child: TerminalView(terminal: terminal),
        ),
      ),
    );
    // Layout reports dimensions in a post-frame callback. Two bounded pumps
    // execute that callback and the resulting resize frame without waiting on
    // unrelated renderer timers.
    await tester.pump();
    await tester.pump();

    expect(terminal.dimensions, isNotNull);
    expect(terminal.cols, greaterThan(10));
    expect(find.bySemanticsLabel('terminal'), findsOneWidget);
  });

  testWidgets('derives renderer metrics from xterm terminal options', (
    tester,
  ) async {
    final terminal = Terminal(
      options: TerminalOptions(
        cols: 10,
        rows: 2,
        fontFamily: 'Termworld Test',
        fontSize: 20,
        fontWeight: 500,
        fontWeightBold: 800,
        letterSpacing: 2,
        lineHeight: 1.5,
        cursorStyle: TerminalCursorStyle.bar,
        cursorWidth: 3,
      ),
    );
    addTearDown(terminal.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 100,
          child: TerminalView(terminal: terminal, autoResize: false),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The FlutterTest font advances exactly one em per glyph, so a cell is
    // the measured 20px advance plus the configured 2px letter spacing —
    // not the old fontSize * 0.6 estimate that disagreed with the painter.
    expect(terminal.dimensions?.cellWidth, 22);
    expect(terminal.dimensions?.cellHeight, 30);
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

  testWidgets('suppresses a platform commit echo across Hangul syllables', (
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
        text: '한',
        selection: TextSelection.collapsed(offset: 1),
      ),
      TextEditingValue(
        text: '한',
        selection: TextSelection.collapsed(offset: 1),
      ),
      TextEditingValue(
        text: '한ㄱ',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
      TextEditingValue(
        text: '한글',
        selection: TextSelection.collapsed(offset: 2),
      ),
      TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    ]) {
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
    }

    expect(output.join(), '한글 ');
  });

  testWidgets('bridges a physical Latin space and absorbs its text echo', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();

    expect(output, <String>[' ']);
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
    await _writeAndPump(tester, terminal, 'select this');
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
    await _writeAndPump(tester, terminal, 'decorated');
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
    expect(bottom.element, same(bottom));
    bottom.options
      ..color = '#abcdef'
      ..position = TerminalOverviewRulerPosition.right;
    expect(bottom.overviewRulerColor, '#abcdef');
    expect(
      bottom.overviewRulerPosition,
      TerminalOverviewRulerPosition.right,
    );
    marker.dispose();
    await tester.pump();
    expect(bottom.isDisposed, isTrue);
    expect(top.isDisposed, isTrue);
    expect(terminal.decorations, isEmpty);
  });

  testWidgets('maps document override objects across the view lifecycle', (
    tester,
  ) async {
    final terminal = Terminal(
      options: TerminalOptions(documentOverride: _DocumentOverride()),
    );
    addTearDown(terminal.dispose);
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal: terminal)),
    );
    await tester.pump();

    expect(terminal.element, 'element');
    expect(terminal.screenElement, 'screen');
    expect(terminal.textarea, 'textarea');

    await tester.pumpWidget(const SizedBox.shrink());
    expect(terminal.element, isNull);
    expect(terminal.screenElement, isNull);
    expect(terminal.textarea, isNull);
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
    await _writeAndPump(tester, terminal, '\u001b[?1h');
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
    await _writeAndPump(
      tester,
      terminal,
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

  testWidgets('resolves, decorates, activates, and disposes links', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 3));
    final provider = _TrackingLinkProvider();
    final registration = terminal.registerLinkProvider(provider);
    addTearDown(registration.dispose);
    addTearDown(terminal.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 100,
            child: TerminalView(terminal: terminal, autoResize: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final dimensions = terminal.dimensions!;
    final origin = tester.getTopLeft(find.byType(TerminalView));
    final linkedCell =
        origin +
        Offset(dimensions.cellWidth * 1.5, dimensions.cellHeight * 0.5);
    final nextLine =
        origin +
        Offset(dimensions.cellWidth * 1.5, dimensions.cellHeight * 1.5);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: origin);

    await mouse.moveTo(linkedCell);
    await tester.pump();
    expect(provider.requestedLines, <int>[1]);
    expect(provider.hovered, 1);
    expect(
      tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .any((region) => region.cursor == SystemMouseCursors.click),
      isTrue,
    );
    provider.decorations.pointerCursor = false;
    await tester.pump();
    expect(
      tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .any((region) => region.cursor == SystemMouseCursors.click),
      isFalse,
    );

    await mouse.down(linkedCell);
    await tester.pump();
    await mouse.up();
    await tester.pump();
    expect(provider.activated, 1);

    await mouse.moveTo(nextLine);
    await tester.pump();
    expect(provider.requestedLines, <int>[1, 2]);
    expect(provider.left, 1);
    expect(provider.disposed, 1);

    await mouse.removePointer();
  });

  testWidgets('routes tracked mouse events and local drag selection', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 3));
    addTearDown(terminal.dispose);
    await _writeAndPump(tester, terminal, 'abcdefghij');
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 100,
            child: TerminalView(terminal: terminal, autoResize: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final dimensions = terminal.dimensions!;
    final origin = tester.getTopLeft(find.byType(TerminalView));
    final start =
        origin +
        Offset(dimensions.cellWidth * 0.5, dimensions.cellHeight * 0.5);
    final end =
        origin +
        Offset(dimensions.cellWidth * 3.5, dimensions.cellHeight * 0.5);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: start);
    await mouse.down(start);
    await mouse.moveTo(end);
    await mouse.up();
    await tester.pump();
    expect(terminal.getSelection(), 'abcd');

    final reports = <String>[];
    terminal.onData.listen(reports.add);
    await _writeAndPump(tester, terminal, '\u001b[?1000h\u001b[?1006h');
    await mouse.down(start);
    await mouse.up();
    await tester.pump();
    expect(reports, <String>['\u001b[<0;1;1M', '\u001b[<0;1;1m']);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: start,
        scrollDelta: const Offset(0, 100),
      ),
    );
    await tester.pump();
    expect(reports.last, '\u001b[<65;1;1M');

    await _writeAndPump(
      tester,
      terminal,
      '\u001b[?1000lone\r\ntwo\r\nthree\r\nfour',
    );
    final bottom = terminal.viewportY;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: start,
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.pump();
    expect(terminal.viewportY, lessThan(bottom));

    reports.clear();
    await _writeAndPump(tester, terminal, '\u001b[?1049h');
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: start,
        scrollDelta: const Offset(0, 100),
      ),
    );
    await tester.pump();
    expect(reports, <String>['\u001b[B']);
    await mouse.removePointer();
  });

  testWidgets('double and triple clicks select words and wrapped lines', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 8, rows: 3));
    addTearDown(terminal.dispose);
    await _writeAndPump(tester, terminal, 'one two');
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 100,
            child: TerminalView(terminal: terminal, autoResize: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final dimensions = terminal.dimensions!;
    final origin = tester.getTopLeft(find.byType(TerminalView));
    final word =
        origin +
        Offset(dimensions.cellWidth * 5.5, dimensions.cellHeight * 0.5);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: word);
    for (var count = 0; count < 2; count++) {
      await mouse.down(word);
      await mouse.up();
    }
    await tester.pump();
    expect(terminal.getSelection(), 'two');

    await mouse.down(word);
    await mouse.up();
    await tester.pump();
    expect(terminal.getSelection(), 'one two');
    await mouse.removePointer();

    terminal
      ..clearSelection()
      ..reset();
    await _writeAndPump(tester, terminal, 'abcdefghijk');
    final wrapped =
        origin +
        Offset(dimensions.cellWidth * 1.5, dimensions.cellHeight * 1.5);
    final wrappedMouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await wrappedMouse.addPointer(location: wrapped);
    for (var count = 0; count < 3; count++) {
      await wrappedMouse.down(wrapped);
      await wrappedMouse.up();
    }
    await tester.pump();
    expect(terminal.getSelection(), 'abcdefghijk');
    await tester.pump(const Duration(milliseconds: 600));
    terminal.clearSelection();
    for (var count = 0; count < 2; count++) {
      await wrappedMouse.down(wrapped);
      await wrappedMouse.up();
    }
    await tester.pump();
    expect(terminal.getSelection(), 'abcdefghijk');
    await wrappedMouse.removePointer();
  });

  testWidgets('word selection follows separators and word drag boundaries', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 20, rows: 2));
    addTearDown(terminal.dispose);
    await _writeAndPump(tester, terminal, '(cd)[ef] one two three');
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 80,
            child: TerminalView(terminal: terminal, autoResize: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final dimensions = terminal.dimensions!;
    final origin = tester.getTopLeft(find.byType(TerminalView));
    Offset cell(int column) =>
        origin +
        Offset(
          (column + 0.5) * dimensions.cellWidth,
          dimensions.cellHeight / 2,
        );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: cell(0));

    for (final expectation in <(int, String)>[
      (0, '(cd'),
      (1, 'cd'),
      (3, 'cd)'),
      (4, '[ef'),
      (7, 'ef]'),
    ]) {
      await tester.pump(const Duration(milliseconds: 600));
      await mouse.moveTo(cell(expectation.$1));
      for (var count = 0; count < 2; count++) {
        await mouse.down(cell(expectation.$1));
        await mouse.up();
      }
      await tester.pump();
      expect(terminal.getSelection(), expectation.$2);
    }

    await tester.pump(const Duration(milliseconds: 600));
    await mouse.moveTo(cell(9));
    await mouse.down(cell(9));
    await mouse.up();
    await mouse.down(cell(9));
    await mouse.moveTo(cell(17));
    await mouse.up();
    await tester.pump();
    expect(terminal.getSelection(), 'one two three');
    await mouse.removePointer();
  });

  testWidgets('alt drag selects columns and dragging outside scrolls', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 3));
    addTearDown(terminal.dispose);
    await _writeAndPump(
      tester,
      terminal,
      'abcdefghij\r\nklmnopqrst\r\nuvwxyzABCD\r\n0123456789\r\nABCDEFGHIJ',
    );
    terminal.scrollToTop();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 100,
            child: TerminalView(terminal: terminal, autoResize: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final dimensions = terminal.dimensions!;
    final origin = tester.getTopLeft(find.byType(TerminalView));
    Offset cell(int column, int row) =>
        origin +
        Offset(
          (column + 0.5) * dimensions.cellWidth,
          (row + 0.5) * dimensions.cellHeight,
        );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: cell(2, 0));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await mouse.down(cell(2, 0));
    await mouse.moveTo(cell(3, 2));
    await mouse.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(terminal.selectionColumnMode, isTrue);
    expect(terminal.getSelection(), 'cd\nmn\nwx');

    terminal
      ..clearSelection()
      ..scrollToTop();
    await mouse.moveTo(cell(0, 0));
    await mouse.down(cell(0, 0));
    await mouse.moveTo(
      origin + Offset(dimensions.cellWidth, dimensions.cellHeight * 5),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(terminal.viewportY, greaterThan(0));
    await mouse.up();
    await mouse.removePointer();
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

Future<void> _writeAndPump(
  WidgetTester tester,
  Terminal terminal,
  String data,
) async {
  await tester.runAsync(() => terminal.writeAndWait(data));
  await tester.pump();
}

final class _TrackingLinkProvider implements TerminalLinkProvider {
  final TerminalLinkDecorations decorations = TerminalLinkDecorations();
  final List<int> requestedLines = <int>[];
  int activated = 0;
  int hovered = 0;
  int left = 0;
  int disposed = 0;

  @override
  List<TerminalLink> provideLinks(int bufferLineNumber) {
    requestedLines.add(bufferLineNumber);
    if (bufferLineNumber != 1) return <TerminalLink>[];
    return <TerminalLink>[
      TerminalLink(
        range: const TerminalBufferRange(
          start: TerminalBufferPosition(1, 1),
          end: TerminalBufferPosition(4, 1),
        ),
        text: 'link',
        decorations: decorations,
        activate: (_, _) => activated++,
        hover: (_, _) => hovered++,
        leave: (_, _) => left++,
        dispose: () => disposed++,
      ),
    ];
  }
}

final class _DocumentOverride implements TerminalDocumentOverride {
  @override
  Object resolveElement(Object? element) => 'element';

  @override
  Object resolveScreenElement(Object? screenElement) => 'screen';

  @override
  Object resolveTextarea(Object? textarea) => 'textarea';
}
