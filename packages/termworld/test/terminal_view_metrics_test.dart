import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

/// The FlutterTest font advances exactly one em per glyph, so the measured
/// cell width equals the font size and every expectation below is exact.
void main() {
  testWidgets('reports exactly the columns the width can draw', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 2));
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
              style: const TerminalStyle(fontSize: 20, height: 1.5),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(terminal.dimensions?.cellWidth, 20);
    expect(terminal.cols, 20, reason: '400px / 20px per measured cell');
    expect(terminal.rows, 10, reason: '300px / 30px per cell');
  });

  testWidgets('wraps a long line at the reported column count', (
    tester,
  ) async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 2));
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
              style: const TerminalStyle(fontSize: 20, height: 1.5),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(terminal.cols, 20);

    await tester.runAsync(() => terminal.writeAndWait('x' * 25));
    await tester.pump();

    final buffer = terminal.buffer.active;
    expect(
      buffer.getLine(0)!.translateToString(trimRight: true),
      'x' * 20,
      reason: 'the first row fills every reported column before wrapping',
    );
    expect(
      buffer.getLine(1)!.translateToString(trimRight: true),
      'x' * 5,
    );
    expect(
      buffer.getLine(1)!.isWrapped,
      isTrue,
      reason: 'the continuation row belongs to the same logical line',
    );
    // Canonical line translation owns xterm's 15-second string-cache timer.
    // Dispose before Flutter's pending-timer invariant runs.
    terminal.dispose();
  });

  testWidgets('padding comes out of the drawable area', (tester) async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 2));
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
              padding: const EdgeInsets.all(10),
              style: const TerminalStyle(fontSize: 20, height: 1.5),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(terminal.cols, 19, reason: '(400 - 20)px / 20px per cell');
    expect(terminal.rows, 9, reason: '(300 - 20)px / 30px per cell');
  });
}
