@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_web_fonts.dart';
import 'package:termworld/addon_webgl.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  test('web fonts refresh after browser font readiness', () async {
    final terminal = Terminal();
    final addon = WebFontsAddon(initialRelayout: false);
    addTearDown(terminal.dispose);
    expect(WebFontsAddon.isSupported, isTrue);
    expect(addon.relayout, throwsStateError);

    terminal.loadAddon(addon);
    expect(await addon.loadFonts(<String>['Mono', 'CJK']), <String>[
      'Mono',
      'CJK',
    ]);
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
    expect(addon.clearTextureAtlas, throwsStateError);
    addon.reportContextLoss();

    terminal.loadAddon(addon);
    expect(addon.textureAtlas?.generation, 1);
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
