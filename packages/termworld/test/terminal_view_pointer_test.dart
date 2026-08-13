import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/termworld.dart';

Future<Terminal> _pumpTerminal(
  WidgetTester tester, {
  void Function(TapDownDetails, TerminalCellOffset)? onSecondaryTapDown,
  bool rightClickSelectsWord = false,
}) async {
  final terminal = Terminal(
    options: TerminalOptions(
      cols: 20,
      rows: 5,
      rightClickSelectsWord: rightClickSelectsWord,
    ),
  );
  addTearDown(terminal.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 300,
          child: TerminalView(
            terminal: terminal,
            autofocus: true,
            style: const TerminalStyle(fontSize: 20, height: 1.5),
            onSecondaryTapDown: onSecondaryTapDown,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return terminal;
}

void main() {
  testWidgets('forwards a right-click to the host in cell coordinates', (
    tester,
  ) async {
    final taps = <TerminalCellOffset>[];
    final terminal = await _pumpTerminal(
      tester,
      onSecondaryTapDown: (details, cell) => taps.add(cell),
    );
    await tester.runAsync(() => terminal.writeAndWait('hello world'));
    await tester.pump();

    // Cell (6, 0) is the 'w' of 'world': 6 columns of 20px, centered.
    await tester.tapAt(
      const Offset(6 * 20 + 10, 15),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();

    expect(taps, const <TerminalCellOffset>[TerminalCellOffset(6, 0)]);
    expect(
      terminal.hasSelection(),
      isFalse,
      reason: 'rightClickSelectsWord is off, so the click selects nothing',
    );
  });

  testWidgets('right-click selects the word under it when opted in', (
    tester,
  ) async {
    final terminal = await _pumpTerminal(tester, rightClickSelectsWord: true);
    await tester.runAsync(() => terminal.writeAndWait('hello world'));
    await tester.pump();

    await tester.tapAt(
      const Offset(6 * 20 + 10, 15),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();

    expect(terminal.getSelection(), 'world');
  });

  testWidgets(
    'a right-click whose release was swallowed leaves interaction intact',
    (tester) async {
      // A host context menu can take the pointer grab on secondary tap-down,
      // so the matching up event never reaches the terminal. Everything —
      // keyboard focus, left-click selection, timers — must survive that.
      var menuOpened = 0;
      final terminal = await _pumpTerminal(
        tester,
        onSecondaryTapDown: (details, cell) => menuOpened++,
      );
      await tester.runAsync(() => terminal.writeAndWait('hello world'));
      await tester.pump();

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.down(tester.getCenter(find.byType(TerminalView)));
      await tester.pump();
      // The host's menu grab swallows the release.
      await gesture.cancel();
      await tester.pump();
      expect(menuOpened, 1);

      // A later double-click drag still selects normally.
      final select = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await select.down(const Offset(10, 15));
      await select.up();
      await select.down(const Offset(10, 15));
      await tester.pump();
      await select.moveTo(const Offset(3 * 20 + 10, 15));
      await select.up();
      await tester.pump();

      expect(terminal.getSelection(), 'hello');
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
