import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

void main() {
  test('onKey', () {
    final terminal = _terminal();
    final events = <TerminalKeyEvent>[];
    terminal.onKey.listen(events.add);
    const event = TerminalKeyEvent(key: 'a', control: true);
    expect(terminal.handleKeyEvent(event), isTrue);
    expect(events, <TerminalKeyEvent>[event]);
  });

  test('resize during write should not throw', () async {
    final terminal = _terminal();
    final parsed = Completer<void>();
    terminal
      ..write('queued', onParsed: parsed.complete)
      ..resize(40, 12);
    await parsed.future;
    expect((terminal.cols, terminal.rows), (40, 12));
    expect(terminal.buffer.active.getLine(0)!.translateToString(), 'queued');
  });

  test('object.keys return the correct number of options', () {
    final terminal = _terminal();
    expect(terminal.options.optionNames.toSet().length, 45);
  });

  test('paste', () async {
    final terminal = _terminal();
    final data = <String>[];
    terminal.onData.listen(data.add);
    terminal.paste('a\r\nb\nc');
    await terminal.writeAndWait('\u001b[?2004h');
    terminal.paste('bracketed');
    expect(data, <String>['a\rb\rc', '\u001b[200~bracketed\u001b[201~']);
  });

  test('selection', () async {
    final terminal = _terminal(cols: 10, rows: 2);
    await terminal.writeAndWait('selection');
    terminal.select(1, 0, 4);
    expect(terminal.hasSelection(), isTrue);
    expect(terminal.getSelection(), 'elec');
    terminal.clearSelection();
    expect(terminal.hasSelection(), isFalse);
  });

  test('should fire for programmatic selection changes', () {
    final terminal = _terminal();
    var changes = 0;
    terminal.onSelectionChange.listen((_) => changes++);
    terminal
      ..select(0, 0, 2)
      ..clearSelection()
      ..selectAll();
    expect(changes, 3);
  });

  test('foreground', () {
    const theme = TerminalColorTheme(foreground: '#010203');
    expect(
      TerminalThemes.resolve(theme).foreground,
      const Color(0xff010203),
    );
  });

  test('background', () {
    const theme = TerminalColorTheme(background: '#040506');
    expect(
      TerminalThemes.resolve(theme).background,
      const Color(0xff040506),
    );
  });

  testWidgets('focus, blur', (tester) async {
    final terminal = _terminal();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(terminal: terminal, focusNode: focus),
      ),
    );
    terminal.focus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    terminal.blur();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('dispose (opened)', (tester) async {
    final terminal = Terminal();
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal: terminal)),
    );
    terminal.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(terminal.isDisposed, isTrue);
  });

  testWidgets('render when visible after hidden', (tester) async {
    final terminal = _terminal();
    await terminal.writeAndWait('visible');
    await tester.pumpWidget(
      MaterialApp(
        home: Offstage(
          child: TerminalView(terminal: terminal),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal: terminal)),
    );
    await tester.pump();
    expect(terminal.dimensions, isNotNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets(
    'should register decorations and render them when terminal open is called',
    (tester) => _decorationCase(tester, _DecorationCase.render),
  );
  testWidgets(
    'should return undefined when the marker has already been disposed of',
    (tester) => _decorationCase(tester, _DecorationCase.disposedMarker),
  );
  testWidgets(
    'should throw when a negative x offset is provided',
    (tester) => _decorationCase(tester, _DecorationCase.negativeOffset),
  );
  testWidgets(
    'should not add an overview ruler when width is not set',
    (tester) => _decorationCase(tester, _DecorationCase.noOverview),
  );
  testWidgets(
    'should add an overview ruler when width is set',
    (tester) => _decorationCase(tester, _DecorationCase.overview),
  );

  testWidgets(
    'should fire provideLinks when hovering cells',
    (tester) => _linkCase(tester, _LinkCase.provide),
  );
  testWidgets(
    'should fire hover and leave events on the link',
    (tester) => _linkCase(tester, _LinkCase.hoverLeave),
  );
  testWidgets(
    'should work fine when hover and leave callbacks are not provided',
    (tester) => _linkCase(tester, _LinkCase.noHoverCallbacks),
  );
  testWidgets(
    'should fire activate events when clicking the link',
    (tester) => _linkCase(tester, _LinkCase.activate),
  );
  testWidgets(
    'should work when multiple links are provided on the same line',
    (tester) => _linkCase(tester, _LinkCase.multiple),
  );
  testWidgets(
    'should dispose links when hovering away',
    (tester) => _linkCase(tester, _LinkCase.dispose),
  );

  testWidgets(
    'should fire on mousedown when clearing selection',
    (
      tester,
    ) => _selectionPointerCase(tester, _SelectionPointerCase.clear),
  );
  testWidgets(
    'should not fire on mousedown when no prior selection',
    (
      tester,
    ) => _selectionPointerCase(tester, _SelectionPointerCase.noPrior),
  );
  testWidgets(
    'should fire once on mousedown to clear, and again on mouseup after drag',
    (tester) => _selectionPointerCase(tester, _SelectionPointerCase.drag),
  );
}

Terminal _terminal({int cols = 80, int rows = 24}) {
  final terminal = Terminal(
    options: TerminalOptions(cols: cols, rows: rows, allowProposedApi: true),
  );
  addTearDown(terminal.dispose);
  return terminal;
}

enum _DecorationCase {
  render,
  disposedMarker,
  negativeOffset,
  noOverview,
  overview,
}

Future<void> _decorationCase(
  WidgetTester tester,
  _DecorationCase selected,
) async {
  final terminal = _terminal(cols: 10, rows: 2);
  final marker = terminal.registerMarker()!;
  if (selected == _DecorationCase.disposedMarker) {
    marker.dispose();
    expect(terminal.registerDecoration(marker: marker), isNull);
    return;
  }
  if (selected == _DecorationCase.negativeOffset) {
    expect(
      () => terminal.registerDecoration(marker: marker, x: -1),
      throwsArgumentError,
    );
    return;
  }
  final rendered = <TerminalDecoration>[];
  final decoration = terminal.registerDecoration(
    marker: marker,
    width: selected == _DecorationCase.overview ? 2 : 1,
    overviewRulerColor: selected == _DecorationCase.noOverview
        ? null
        : '#ff0000',
  )!..onRender.listen(rendered.add);
  await tester.pumpWidget(
    MaterialApp(home: TerminalView(terminal: terminal, autoResize: false)),
  );
  await tester.pump();
  if (selected == _DecorationCase.render) {
    expect(rendered, contains(decoration));
  } else if (selected == _DecorationCase.noOverview) {
    expect(decoration.overviewRulerColor, isNull);
  } else {
    expect(decoration.overviewRulerColor, '#ff0000');
    expect(decoration.width, 2);
  }
}

enum _LinkCase {
  provide,
  hoverLeave,
  noHoverCallbacks,
  activate,
  multiple,
  dispose,
}

Future<void> _linkCase(WidgetTester tester, _LinkCase selected) async {
  final terminal = _terminal(cols: 10, rows: 3);
  final provider = _ViewLinkProvider(
    multiple: selected == _LinkCase.multiple,
    callbacks: selected != _LinkCase.noHoverCallbacks,
  );
  final registration = terminal.registerLinkProvider(provider);
  addTearDown(registration.dispose);
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
  Offset cell(int x, int y) =>
      origin +
      Offset(
        (x + 0.5) * dimensions.cellWidth,
        (y + 0.5) * dimensions.cellHeight,
      );
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: origin);
  await mouse.moveTo(cell(1, 0));
  await tester.pump();
  if (selected == _LinkCase.provide) {
    expect(provider.requested, contains(1));
  } else if (selected == _LinkCase.hoverLeave) {
    await mouse.moveTo(cell(1, 1));
    await tester.pump();
    expect((provider.hovered, provider.left), (1, 1));
  } else if (selected == _LinkCase.noHoverCallbacks) {
    await mouse.moveTo(cell(1, 1));
    await tester.pump();
    expect(provider.errors, isEmpty);
  } else if (selected == _LinkCase.activate) {
    await mouse.down(cell(1, 0));
    await mouse.up();
    await tester.pump();
    expect(provider.activated, 1);
  } else if (selected == _LinkCase.multiple) {
    await mouse.moveTo(cell(6, 0));
    await tester.pump();
    expect(provider.hovered, 2);
  } else {
    await mouse.moveTo(cell(1, 1));
    await tester.pump();
    expect(provider.disposed, greaterThan(0));
  }
  await mouse.removePointer();
}

final class _ViewLinkProvider implements TerminalLinkProvider {
  _ViewLinkProvider({required this.multiple, required this.callbacks});

  final bool multiple;
  final bool callbacks;
  final List<int> requested = <int>[];
  final List<Object> errors = <Object>[];
  int hovered = 0;
  int left = 0;
  int activated = 0;
  int disposed = 0;

  @override
  List<TerminalLink> provideLinks(int bufferLineNumber) {
    requested.add(bufferLineNumber);
    if (bufferLineNumber != 1) return <TerminalLink>[];
    TerminalLink link(int start, int end) => TerminalLink(
      range: TerminalBufferRange(
        start: TerminalBufferPosition(start, 1),
        end: TerminalBufferPosition(end, 1),
      ),
      text: 'link',
      activate: (_, _) => activated++,
      hover: callbacks ? (_, _) => hovered++ : null,
      leave: callbacks ? (_, _) => left++ : null,
      dispose: () => disposed++,
    );
    return <TerminalLink>[
      link(1, 4),
      if (multiple) link(6, 9),
    ];
  }
}

enum _SelectionPointerCase { clear, noPrior, drag }

Future<void> _selectionPointerCase(
  WidgetTester tester,
  _SelectionPointerCase selected,
) async {
  final terminal = _terminal(cols: 10, rows: 2);
  await terminal.writeAndWait('abcdefghij');
  if (selected != _SelectionPointerCase.noPrior) terminal.select(0, 0, 2);
  var changes = 0;
  terminal.onSelectionChange.listen((_) => changes++);
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 60,
          child: TerminalView(terminal: terminal, autoResize: false),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  final dimensions = terminal.dimensions!;
  final origin = tester.getTopLeft(find.byType(TerminalView));
  Offset cell(int x) =>
      origin +
      Offset(
        (x + 0.5) * dimensions.cellWidth,
        dimensions.cellHeight / 2,
      );
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: cell(2));
  await mouse.down(cell(2));
  if (selected == _SelectionPointerCase.drag) await mouse.moveTo(cell(5));
  await mouse.up();
  await tester.pump();
  expect(
    changes,
    switch (selected) {
      _SelectionPointerCase.clear => 1,
      _SelectionPointerCase.noPrior => 0,
      _SelectionPointerCase.drag => 2,
    },
  );
  await mouse.removePointer();
}
