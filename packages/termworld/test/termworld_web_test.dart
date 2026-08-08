@TestOn('browser')
library;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_web_fonts.dart';
import 'package:termworld/addon_webgl.dart';
import 'package:termworld/termworld.dart';

void main() {
  test('browser theme parsing accepts opaque CSS color syntax', () {
    expect(
      TerminalThemes.resolve(
        const TerminalColorTheme(
          foreground: 'rebeccapurple',
          background: 'hsl(120, 100%, 25%)',
        ),
      ),
      isA<TerminalTheme>()
          .having(
            (theme) => theme.foreground,
            'foreground',
            const Color(0xff663399),
          )
          .having(
            (theme) => theme.background,
            'background',
            const Color(0xff008000),
          ),
    );
  });

  test('web fonts refresh after browser font readiness', () async {
    final terminal = Terminal();
    final addon = WebFontsAddon(initialRelayout: false);
    addTearDown(terminal.dispose);
    expect(WebFontsAddon.isSupported, isTrue);
    expect(await loadFonts(), isA<List<Object>>());
    await addon.relayout();

    terminal.loadAddon(addon);
    await expectLater(
      addon.loadFonts(<String>['Termworld Missing Font']),
      throwsStateError,
    );
    expect(await addon.loadFonts(), isA<List<Object>>());
    await addon.relayout();
    addon.dispose();
    await addon.relayout();
  });

  test('webgl publishes atlas and context lifecycle in order', () {
    final terminal = Terminal();
    final addon = WebglAddon();
    addTearDown(terminal.dispose);
    final events = <String>[];
    addon
      ..onAddTextureAtlas.listen(
        (atlas) => events.add('add:${atlas.generation}'),
      )
      ..onChangeTextureAtlas.listen(
        (atlas) => events.add('change:${atlas.generation}'),
      )
      ..onRemoveTextureAtlas.listen(
        (atlas) => events.add('remove:${atlas.generation}'),
      )
      ..onContextLoss.listen((_) => events.add('loss'));
    expect(WebglAddon.isSupported, isTrue);
    addon
      ..clearTextureAtlas()
      ..reportContextLoss();

    terminal.loadAddon(addon);
    expect(addon.textureAtlas?.generation, 1);
    expect(addon.textureAtlas?.canvas, isNotNull);
    expect(addon.onAddTextureAtlasCanvas, isNotNull);
    expect(addon.onRemoveTextureAtlasCanvas, isNotNull);
    addon
      ..clearTextureAtlas()
      ..reportContextLoss()
      ..dispose();

    expect(
      events,
      <String>['add:1', 'remove:1', 'add:2', 'change:2', 'loss', 'remove:2'],
    );
  });
}
