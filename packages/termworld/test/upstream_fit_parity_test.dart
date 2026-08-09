import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_fit.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('FitAddon', () {
    test('no terminal', () {
      final addon = FitAddon();
      addTearDown(addon.dispose);
      expect(addon.proposeDimensions(), isNull);
    });

    group('proposeDimensions', () {
      test('default', () {
        final fixture = _fitFixture(width: 800, height: 450);
        expect(fixture.addon.proposeDimensions(), _dimensions(87, 26));
      });

      test('width', () {
        final fixture = _fitFixture(width: 1008, height: 450);
        expect(fixture.addon.proposeDimensions(), _dimensions(110, 26));
      });

      test('small', () {
        final fixture = _fitFixture(width: 1, height: 1);
        expect(fixture.addon.proposeDimensions(), _dimensions(2, 1));
      });

      test('hidden', () {
        final terminal = Terminal();
        final addon = FitAddon();
        addTearDown(terminal.dispose);
        terminal.loadAddon(addon);
        expect(addon.proposeDimensions(), isNull);
      });
    });

    group('fit', () {
      test('default', () {
        final fixture = _fitFixture(width: 800, height: 450);
        fixture.addon.fit();
        expect((fixture.terminal.cols, fixture.terminal.rows), (87, 26));
      });

      test('width', () {
        final fixture = _fitFixture(width: 1008, height: 450);
        fixture.addon.fit();
        expect((fixture.terminal.cols, fixture.terminal.rows), (110, 26));
      });

      test('small', () {
        final fixture = _fitFixture(width: 1, height: 1);
        fixture.addon.fit();
        expect((fixture.terminal.cols, fixture.terminal.rows), (2, 1));
      });

      test('same dimensions', () {
        final fixture = _fitFixture(width: 800, height: 450);
        fixture.addon
          ..fit()
          ..fit();
        expect((fixture.terminal.cols, fixture.terminal.rows), (87, 26));
      });
    });
  });
}

({Terminal terminal, FitAddon addon}) _fitFixture({
  required double width,
  required double height,
}) {
  final terminal = Terminal();
  final addon = FitAddon();
  addTearDown(terminal.dispose);
  terminal
    ..loadAddon(addon)
    ..updateDimensions(
      TerminalRenderDimensions(
        width: width,
        height: height,
        cellWidth: 9,
        cellHeight: 17,
        devicePixelRatio: 1,
      ),
    );
  return (terminal: terminal, addon: addon);
}

TerminalDimensions _dimensions(int cols, int rows) =>
    TerminalDimensions(cols: cols, rows: rows);
