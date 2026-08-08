import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_image.dart';
import 'package:termworld/addon_progress.dart';
import 'package:termworld/addon_serialize.dart';
import 'package:termworld/addon_unicode11.dart';
import 'package:termworld/addon_unicode_graphemes.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('addon-progress/test/ProgressAddon.test.ts ProgressAddon', () {
    late Terminal terminal;
    late ProgressAddon addon;
    late List<TerminalProgress> changes;

    setUp(() {
      terminal = Terminal();
      addon = ProgressAddon();
      changes = <TerminalProgress>[];
      terminal.loadAddon(addon);
      addon.onChange.listen(changes.add);
    });

    tearDown(() => terminal.dispose());

    test('initial values should be 0;0', () {
      _expectProgress(addon.progress, TerminalProgressState.remove, 0);
    });

    test('state 0: remove', () async {
      await _write(terminal, 0);
      await _write(terminal, 0, '12');
      expect(changes, hasLength(2));
      for (final change in changes) {
        _expectProgress(change, TerminalProgressState.remove, 0);
      }
    });

    test('state 1: set', () async {
      await _write(terminal, 1, '10');
      await _write(terminal, 1, '50');
      await _write(terminal, 1, '23');
      expect(changes.map((change) => change.value), <int>[10, 50, 23]);
    });

    test('state 1: set - special sequence handling', () async {
      await _write(terminal, 1);
      await _write(terminal, 1, '12x');
      await _write(terminal, 1, '123');
      expect(changes.map((change) => change.value), <int>[0, 100]);
    });

    test('state 2: error - preserve previous value on empty/0', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 2);
      await _write(terminal, 2, '');
      await _write(terminal, 2, '0');
      expect(changes.map((change) => change.value), <int>[12, 12, 12, 12]);
    });

    test('state 2: error - with new value', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 2, '25');
      await _write(terminal, 2, '123');
      expect(changes.map((change) => change.value), <int>[12, 25, 100]);
    });

    test('state 3: indeterminate - keeps value untouched', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 3);
      await _write(terminal, 3, '123');
      expect(changes.map((change) => change.value), <int>[12, 12, 12]);
    });

    test('state 4: pause - preserve previous value on empty/0', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 4);
      await _write(terminal, 4, '');
      await _write(terminal, 4, '0');
      expect(changes.map((change) => change.value), <int>[12, 12, 12, 12]);
    });

    test('state 4: pause - with new value', () async {
      await _write(terminal, 1, '12');
      await _write(terminal, 4, '25');
      await _write(terminal, 4, '123');
      expect(changes.map((change) => change.value), <int>[12, 25, 100]);
    });

    test('invalid sequences should not emit anything', () async {
      await _write(terminal, 5, '12');
      await _write(terminal, 1, ' 123xxxx');
      await terminal.writeAndWait('\u001b]9;4;1;2;3\u001b\\');
      expect(changes, isEmpty);
    });
  });

  test('addon-unicode11 wcwidth V11 emoji test', () {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    terminal.loadAddon(Unicode11Addon());
    expect(terminal.unicode.versions, contains('11'));
    terminal.unicode.activeVersion = '11';
    expect(
      _stringCellWidth(terminal, List<String>.filled(10, '🤣').join()),
      20,
    );
  });

  group('addon-image/test/ImageAddon.test.ts public accessors', () {
    test('storage accessors are unavailable before activation', () {
      final addon = ImageAddon();
      addTearDown(addon.dispose);
      expect(addon.storageLimit, -1);
      expect(addon.storageUsage, -1);
      addon
        ..storageLimit = 1
        ..showPlaceholder = false;
      expect(addon.showPlaceholder, isFalse);
    });

    test('get/set storage limit and synchronous pressure eviction', () async {
      final terminal = Terminal();
      final addon = ImageAddon(
        options: const ImageAddonOptions(
          storageLimit: 0.5,
          iipSizeLimit: 1000000,
        ),
      );
      addTearDown(terminal.dispose);
      terminal.loadAddon(addon);
      expect(addon.storageLimit, 0.5);
      expect(addon.storageUsage, 0);
      expect(() => addon.storageLimit = 0.49, throwsRangeError);
      expect(() => addon.storageLimit = 1000.1, throwsRangeError);

      final payload = base64.encode(List<int>.filled(300000, 1));
      await terminal.writeAndWait(
        '\u001b]1337;File=inline=1:$payload\u0007',
      );
      await terminal.writeAndWait(
        '\u001b]1337;File=inline=1:$payload\u0007',
      );
      expect(addon.images, hasLength(1));
      expect(addon.storageUsage, closeTo(0.3, 0.000001));
      expect(addon.extractTileAtBufferCell(0, 0), same(addon.images.single));
      addon.storageLimit = 0.5;
      expect(addon.storageLimit, 0.5);
    });

    test('invalid constructor limit retains 10 MB storage fallback', () {
      final terminal = Terminal();
      final addon = ImageAddon(
        options: const ImageAddonOptions(storageLimit: 0.1),
      );
      addTearDown(terminal.dispose);
      terminal.loadAddon(addon);
      expect(addon.storageLimit, 10);
    });

    test(
      'image event is void and reset preserves mutable placeholder',
      () async {
        final terminal = Terminal();
        final addon = ImageAddon();
        final changes = <TerminalVoid>[];
        addTearDown(terminal.dispose);
        terminal.loadAddon(addon);
        addon.onImageAdded.listen(changes.add);
        addon.showPlaceholder = false;
        await terminal.writeAndWait(
          '\u001b]1337;File=inline=1:UE5H\u0007',
        );
        expect(changes, <TerminalVoid>[TerminalVoid.value]);
        expect(addon.reset(), isFalse);
        expect(addon.showPlaceholder, isFalse);
        expect(addon.storageUsage, 0);
      },
    );
  });

  test('addon-unicode-graphemes wcwidth V15 emoji test', () {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    terminal.loadAddon(UnicodeGraphemesAddon());
    expect(terminal.unicode.versions, <String>['6', '15', '15-graphemes']);
    expect(
      _stringCellWidth(terminal, List<String>.filled(10, '🤣').join()),
      20,
    );
    expect(_stringCellWidth(terminal, '👶🏿👶'), 4);
    expect(_stringCellWidth(terminal, '👩‍👩‍👦'), 2);
    expect(_stringCellWidth(terminal, '=🏋️=\u{f3cb}🏾‍♀='), 7);
    expect(_stringCellWidth(terminal, '👩👩‍🎓👨🏿‍🎓'), 6);
    expect(_stringCellWidth(terminal, '🇳🇴/'), 3);
    expect(_stringCellWidth(terminal, '🇳/🇴'), 3);
    expect(_stringCellWidth(terminal, 'á'), 1);
    expect(_stringCellWidth(terminal, '{각가}'), 6);
    expect(_stringCellWidth(terminal, '가=횅='), 6);
    expect(_stringCellWidth(terminal, '(⚰︎)'), 3);
    expect(_stringCellWidth(terminal, '(⚰️)'), 4);
    expect(_stringCellWidth(terminal, '<É️g️a️l️i️️t️é️>'), 16);
  });

  test(
    'addon-serialize preserves attributes, ranges, modes and safe HTML',
    () async {
      final terminal = Terminal(options: TerminalOptions(cols: 12, rows: 3));
      final addon = SerializeAddon();
      addTearDown(terminal.dispose);
      terminal.loadAddon(addon);
      await terminal.writeAndWait(
        <String>[
          '\u001b[1;2;3;4;5;7;8;9;38;2;1;2;3;48;5;200mstyled',
          '\u001b[0m\r\nplain\r\nlast',
          '\u001b[?1;6h\u001b[?25;7l\u001b[4h\u001b=\u001b[?2004h',
          '\u001b[2;1H',
        ].join(),
      );

      final serialized = addon.serialize();
      expect(serialized, contains('1;2;3;4;5;7;8;9'));
      expect(serialized, contains('38;2;1;2;3'));
      expect(serialized, contains('48;5;200'));
      expect(serialized, endsWith('\u001b[?7l'));
      expect(
        addon.serialize(
          options: const TerminalSerializeOptions(
            range: TerminalSerializeRange(start: 1, end: 1),
            excludeModes: true,
          ),
        ),
        startsWith('plain'),
      );

      final marker = terminal.registerMarker()!;
      expect(
        addon.serialize(
          options: TerminalSerializeOptions(
            range: TerminalSerializeRange(start: marker, end: marker),
            excludeModes: true,
          ),
        ),
        startsWith('plain'),
      );
      expect(
        () => addon.serialize(
          options: const TerminalSerializeOptions(
            range: TerminalSerializeRange(start: 'bad', end: 1),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => addon.serialize(
          options: const TerminalSerializeOptions(
            range: TerminalSerializeRange(start: 2, end: 1),
          ),
        ),
        throwsRangeError,
      );
      expect(
        () => addon.serialize(
          options: const TerminalSerializeOptions(scrollback: -1),
        ),
        throwsArgumentError,
      );

      terminal.select(0, 1, 5);
      expect(
        addon.serializeAsHtml(
          options: const TerminalHtmlSerializeOptions(
            onlySelection: true,
            includeGlobalBackground: true,
          ),
        ),
        '<pre style="background:#000;color:#fff">plain</pre>',
      );
      terminal.clearSelection();
      expect(
        addon.serializeAsHtml(
          options: const TerminalHtmlSerializeOptions(
            startLine: 1,
            endLine: 2,
            startColumn: 1,
          ),
        ),
        contains('lain\nlast'),
      );
      expect(
        addon.serializeAsHtml(
          options: const TerminalHtmlSerializeOptions(scrollback: 0),
        ),
        startsWith('<pre>'),
      );
    },
  );

  test('Marker and decoration lifecycle follows tracked line changes', () {
    final factory = TerminalMarkerFactory();
    final marker = factory.create(2);
    final disposed = <String>[];
    marker.onDispose.listen((_) => disposed.add('marker'));
    marker.move(3);
    expect((marker.id, marker.line), (1, 5));
    TerminalDecoration(
        marker: marker,
        anchor: TerminalDecorationAnchor.right,
        x: 1,
        width: 2,
        height: 2,
        backgroundColor: '#000000',
        foregroundColor: '#ffffff',
        layer: TerminalDecorationLayer.top,
      )
      ..onRender.listen((_) => disposed.add('render'))
      ..onDispose.listen((_) => disposed.add('decoration'))
      ..rendered()
      ..dispose()
      ..rendered()
      ..dispose();
    marker
      ..move(-10)
      ..move(1)
      ..dispose();
    expect(disposed, <String>['render', 'decoration', 'marker']);
    expect(marker.line, -1);
    expect(factory.create(0).id, 2);
    expect(
      () => TerminalDecoration(marker: marker, x: -1),
      throwsArgumentError,
    );
    expect(
      () => TerminalDecoration(marker: marker, width: 0),
      throwsArgumentError,
    );
  });
}

Future<void> _write(Terminal terminal, int state, [String? value]) {
  final suffix = value == null ? '' : ';$value';
  return terminal.writeAndWait('\u001b]9;4;$state$suffix\u001b\\');
}

void _expectProgress(
  TerminalProgress progress,
  TerminalProgressState state,
  int value,
) {
  expect(progress.state, state);
  expect(progress.value, value);
}

int _stringCellWidth(Terminal terminal, String value) {
  var state = 0;
  var width = 0;
  for (final codePoint in value.runes) {
    final next = terminal.unicode.active.charProperties(codePoint, state);
    final nextWidth = TerminalUnicodeHandling.extractWidth(next);
    width += TerminalUnicodeHandling.extractShouldJoin(next)
        ? nextWidth - TerminalUnicodeHandling.extractWidth(state)
        : nextWidth;
    state = next;
  }
  return width;
}
