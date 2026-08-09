import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

void main() {
  group('SharedRendererTests DOM cursor regressions', () {
    testWidgets('DOM regression 4773 cursor renders above selection', (
      tester,
    ) async {
      final fixture = await _mount(
        tester,
        theme: const TerminalColorTheme(
          cursor: '#0000FF',
          selectionBackground: '#FF0000',
        ),
      );
      fixture.terminal.selectAll();
      fixture.focusNode.requestFocus();
      await tester.pump();
      final image = await _capture(tester, fixture);
      expect(_cellContains(image, 0, 0, _blue), isTrue);
    });

    testWidgets('DOM regression 4799 cursor follows viewport', (tester) async {
      final fixture = await _mount(
        tester,
        theme: const TerminalColorTheme(cursor: '#0000FF'),
      );
      await tester.runAsync(
        () => fixture.terminal.writeAndWait(
          '${List<String>.filled(160, '\r\n').join()}'
          '\x1b[A\x1b[A',
        ),
      );
      fixture.terminal.scrollLines(-2);
      fixture.focusNode.requestFocus();
      await tester.pump();
      var image = await _capture(tester, fixture);
      expect(_cellContains(image, 0, 4, _blue), isTrue);
      expect(_cellContains(image, 0, 2, _blue), isFalse);

      fixture.focusNode.unfocus();
      await tester.pump();
      image = await _capture(tester, fixture);
      expect(_cellContains(image, 0, 4, _blue), isTrue);
      expect(_cellCenter(image, 0, 4), _black);
    });

    testWidgets('DOM regression 4917 offscreen selection is not painted', (
      tester,
    ) async {
      final fixture = await _mount(
        tester,
        theme: const TerminalColorTheme(selectionBackground: '#FF0000'),
      );
      await tester.runAsync(
        () => fixture.terminal.writeAndWait(
          List<String>.filled(160, '\r\n').join(),
        ),
      );
      fixture.terminal
        ..scrollToBottom()
        ..selectLines(
          fixture.terminal.buffer.active.length - 1,
          fixture.terminal.buffer.active.length - 1,
        )
        ..scrollLines(-2);
      await tester.pump();
      final image = await _capture(tester, fixture);
      expect(_cellContains(image, 0, 0, _red), isFalse);
      expect(_cellCenter(image, 0, 0), _black);
    });

    testWidgets('DOM regression 5241 cursor alpha blends with background', (
      tester,
    ) async {
      final fixture = await _mount(
        tester,
        theme: const TerminalColorTheme(cursor: '#FF000080'),
      );
      fixture.focusNode.requestFocus();
      await tester.pump();
      final image = await _capture(tester, fixture);
      expect(_cellCenter(image, 0, 0), const Color(0xff800000));
    });

    testWidgets(
      'DOM regression 5241 cursor accent alpha blends with background',
      (tester) async {
        final fixture = await _mount(
          tester,
          theme: const TerminalColorTheme(cursorAccent: '#FF000080'),
        );
        await tester.runAsync(
          () => fixture.terminal.writeAndWait('■\x1b[1D'),
        );
        fixture.focusNode.requestFocus();
        await tester.pump();
        final image = await _capture(tester, fixture);
        expect(_cellContains(image, 0, 0, const Color(0xff800000)), isTrue);
      },
    );

    testWidgets('DOM regression 4790 hides cursor before first focus', (
      tester,
    ) async {
      final fixture = await _mount(tester);
      final image = await _capture(tester, fixture);
      expect(_cellContains(image, 0, 0, _white), isFalse);
      expect(_cellCenter(image, 0, 0), _black);
    });

    testWidgets('DOM shadow-root regression 4790 hides cursor initially', (
      tester,
    ) async {
      final fixture = await _mount(tester, nestedSurface: true);
      final image = await _capture(tester, fixture);
      expect(_cellContains(image, 0, 0, _white), isFalse);
      expect(_cellCenter(image, 0, 0), _black);
    });
  });
}

const _black = Color(0xff000000);
const _white = Color(0xffffffff);
const _red = Color(0xffff0000);
const _blue = Color(0xff0000ff);
const _cellWidth = 6;
const _cellHeight = 10;

final class _Fixture {
  const _Fixture({
    required this.terminal,
    required this.focusNode,
    required this.boundaryKey,
  });

  final Terminal terminal;
  final FocusNode focusNode;
  final GlobalKey boundaryKey;

  Future<_Pixels> capture() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData();
      return _Pixels(image.width, image.height, data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  TerminalColorTheme theme = const TerminalColorTheme(),
  bool nestedSurface = false,
}) async {
  final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 5));
  final focusNode = FocusNode();
  final boundaryKey = GlobalKey();
  addTearDown(terminal.dispose);
  addTearDown(focusNode.dispose);
  final surface = RepaintBoundary(
    key: boundaryKey,
    child: SizedBox(
      width: 30,
      height: 50,
      child: TerminalView(
        terminal: terminal,
        focusNode: focusNode,
        autoResize: false,
        theme: TerminalThemes.resolve(theme),
        style: const TerminalStyle(fontSize: 10, height: 1),
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: nestedSurface
            ? Material(type: MaterialType.transparency, child: surface)
            : surface,
      ),
    ),
  );
  await tester.pump();
  return _Fixture(
    terminal: terminal,
    focusNode: focusNode,
    boundaryKey: boundaryKey,
  );
}

final class _Pixels {
  const _Pixels(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final List<int> bytes;

  Color colorAt(int x, int y) {
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      bytes[offset + 3],
      bytes[offset],
      bytes[offset + 1],
      bytes[offset + 2],
    );
  }
}

Future<_Pixels> _capture(WidgetTester tester, _Fixture fixture) async =>
    (await tester.runAsync(fixture.capture))!;

Color _cellCenter(_Pixels image, int column, int row) => image.colorAt(
  column * _cellWidth + _cellWidth ~/ 2,
  row * _cellHeight + _cellHeight ~/ 2,
);

bool _cellContains(_Pixels image, int column, int row, Color color) {
  for (var y = row * _cellHeight; y < (row + 1) * _cellHeight; y++) {
    for (var x = column * _cellWidth; x < (column + 1) * _cellWidth; x++) {
      if (image.colorAt(x, y) == color) return true;
    }
  }
  return false;
}
