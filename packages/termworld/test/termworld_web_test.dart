@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_web_fonts.dart';
import 'package:termworld/addon_webgl.dart';
import 'package:termworld/src/addons/font_family_parser.dart';
import 'package:termworld/termworld.dart';
import 'package:web/web.dart' as web;

@JS('Array.from')
external JSArray<JSAny?> _arrayFrom(JSAny iterable);

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

  test('xterm WebFontsAddon 00', () async {
    _clearFonts();
    addTearDown(_clearFonts);
    final first = _fontFace('Kongtext');
    final second = _fontFace('BPdots');
    final loaded = await loadFonts(<Object>[first, second]);
    expect(loaded, hasLength(2));
    expect(first.status, 'loaded');
    expect(second.status, 'loaded');
  });

  test('xterm WebFontsAddon 01', () async {
    _clearFonts();
    addTearDown(_clearFonts);
    web.document.fonts
      ..add(_fontFace('Kongtext'))
      ..add(_fontFace('BPdots'));
    final loaded = await loadFonts(<String>['Kongtext', 'BPdots']);
    expect(loaded, hasLength(2));
    expect(_fontStatuses(), <String>['Kongtext:loaded', 'BPdots:loaded']);
  });

  test('xterm WebFontsAddon 02', () async {
    _clearFonts();
    addTearDown(_clearFonts);
    web.document.fonts
      ..add(_fontFace('"Kongtext"'))
      ..add(_fontFace("'BPdots'"));
    final loaded = await loadFonts(<String>['Kongtext', 'BPdots']);
    expect(loaded, hasLength(2));
    expect(
      _fontStatuses().map((value) => value.replaceAll('"', '')),
      <String>['Kongtext:loaded', 'BPdots:loaded'],
    );
  });

  test('xterm WebFontsAddon 03', () async {
    _clearFonts();
    addTearDown(_clearFonts);
    final first = _fontFace('Kongtext');
    final second = _fontFace('BPdots');
    await loadFonts(<Object>[first, second]);
    await loadFonts(<Object>[
      _fontFace('Kongtext'),
      _fontFace('BPdots'),
    ]);
    await loadFonts(<Object>[first, second]);
    expect(_fontStatuses(), hasLength(2));
  });

  test('xterm WebFontsAddon 04', () async {
    _clearFonts();
    addTearDown(_clearFonts);
    web.document.fonts.add(_fontFace('Kongtext'));
    final terminal = Terminal(
      options: TerminalOptions(fontFamily: '"Kongtext", monospace'),
    );
    final addon = WebFontsAddon(initialRelayout: false);
    addTearDown(terminal.dispose);
    terminal.loadAddon(addon);
    final changes = <String>[];
    terminal.options.onSpecificOptionChange(
      'fontFamily',
      (value) => changes.add(value! as String),
    );
    await addon.relayout();
    expect(changes, <String>['monospace', '"Kongtext", monospace']);
    expect(_fontStatuses(), <String>['Kongtext:loaded']);
  });

  test('generic font family stops local ligature font resolution', () {
    expect(isTerminalGenericFontFamily('monospace'), isTrue);
    expect(isTerminalGenericFontFamily('Fira Code'), isFalse);
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

web.FontFace _fontFace(String family) => web.FontFace(
  family,
  'url("assets/fonts/MaterialIcons-Regular.otf") format("opentype")'.toJS,
);

List<String> _fontStatuses() => <String>[
  for (final face in _fontFaces()) '${face.family}:${face.status}',
];

List<web.FontFace> _fontFaces() => _arrayFrom(
  web.document.fonts,
).toDart.map((value) => value! as web.FontFace).toList();

void _clearFonts() => web.document.fonts.clear();
