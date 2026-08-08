import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_clipboard.dart';
import 'package:termworld/addon_fit.dart';
import 'package:termworld/addon_image.dart';
import 'package:termworld/addon_ligatures.dart';
import 'package:termworld/addon_progress.dart';
import 'package:termworld/addon_search.dart';
import 'package:termworld/addon_serialize.dart';
import 'package:termworld/addon_unicode11.dart';
import 'package:termworld/addon_unicode_graphemes.dart';
import 'package:termworld/addon_web_fonts.dart';
import 'package:termworld/addon_web_links.dart';
import 'package:termworld/addon_webgl.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  test('clipboard handles OSC 52 read and write', () async {
    final provider = _ClipboardProvider('한글');
    final terminal = Terminal();
    final addon = ClipboardAddon(provider: provider);
    addTearDown(terminal.dispose);
    terminal.loadAddon(addon);
    final output = <String>[];
    terminal.onData.listen(output.add);

    await terminal.writeAndWait('\u001b]52;c;?\u0007');
    await terminal.writeAndWait('\u001b]52;c;d3JpdHRlbg==\u0007');

    expect(output.single, '\u001b]52;c;7ZWc6riA\u0007');
    expect(provider.value, 'written');
  });

  test(
    'clipboard preserves synchronous ordering and clears decode errors',
    () async {
      final provider = _SyncClipboardProvider('value');
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      terminal.loadAddon(ClipboardAddon(provider: provider));
      final output = <String>[];
      terminal.onData.listen(output.add);

      await terminal.writeAndWait('\u001b]52;c;?\u0007');
      expect(output, <String>['\u001b]52;c;dmFsdWU=\u0007']);

      terminal.loadAddon(
        ClipboardAddon(codec: const _ThrowingCodec(), provider: provider),
      );
      await terminal.writeAndWait('\u001b]52;c;invalid\u0007');
      expect(provider.value, isEmpty);
    },
  );

  test('fit uses measured cell dimensions', () {
    final terminal = Terminal();
    final addon = FitAddon();
    addTearDown(terminal.dispose);
    expect(addon.proposeDimensions(), isNull);
    addon.fit();
    terminal
      ..loadAddon(addon)
      ..updateDimensions(
        const TerminalRenderDimensions(
          width: 100,
          height: 50,
          cellWidth: 10,
          cellHeight: 10,
          devicePixelRatio: 1,
        ),
      );

    expect(
      addon.proposeDimensions(),
      const TerminalDimensions(rows: 5, cols: 8),
    );
    addon.fit();
    expect((terminal.cols, terminal.rows), (8, 5));
    addon.dispose();
    expect(
      addon.proposeDimensions(),
      const TerminalDimensions(rows: 5, cols: 8),
    );
  });

  test('image consumes iTerm2, sixel, and Kitty payloads', () async {
    final terminal = Terminal();
    final addon = ImageAddon();
    addTearDown(terminal.dispose);
    terminal.loadAddon(addon);

    await terminal.writeAndWait('\u001bPqABC\u001b\\');
    await terminal.writeAndWait(
      '\u001b]1337;File=inline=1:'
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ\u0007',
    );
    await terminal.writeAndWait(
      '\u001b_Ga=T,f=100;'
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ\u001b\\',
    );

    expect(
      addon.images.map((image) => image.protocol),
      TerminalImageProtocol.values,
    );
    expect(addon.storageUsage, greaterThan(0));
  });

  test('ligature joins overlap according to xterm ordering', () {
    final terminal = Terminal();
    final addon = LigaturesAddon(fallbackLigatures: <String>['==', '===']);
    addTearDown(terminal.dispose);
    terminal.loadAddon(addon);

    expect(
      terminal.characterJoins('a===b'),
      hasLength(1),
    );
    expect(terminal.characterJoins('a===b').single.end, 4);
  });

  test('progress parses OSC 9;4 and clamps state values', () async {
    final terminal = Terminal();
    final addon = ProgressAddon();
    addTearDown(terminal.dispose);
    terminal.loadAddon(addon);
    final values = <TerminalProgress>[];
    addon.onChange.listen(values.add);

    await terminal.writeAndWait('\u001b]9;4;1;120\u0007');
    await terminal.writeAndWait('\u001b]9;4;4;0\u0007');

    expect(values.first.value, 100);
    expect(values.last.state, TerminalProgressState.paused);
    expect(values.last.value, 100);
  });

  test('search selects forward and backward matches', () async {
    final terminal = Terminal(options: TerminalOptions(cols: 20, rows: 3));
    final addon = SearchAddon();
    addTearDown(terminal.dispose);
    terminal.loadAddon(addon);
    await terminal.writeAndWait('one two one');

    expect(addon.findNext('one'), isTrue);
    expect(terminal.getSelection(), 'one');
    expect(addon.findPrevious('two'), isTrue);
    expect(terminal.getSelection(), 'two');
  });

  test('serialize produces restorable ANSI and safe HTML', () async {
    final terminal = Terminal(options: TerminalOptions(cols: 20, rows: 2));
    final addon = SerializeAddon();
    addTearDown(terminal.dispose);
    terminal.loadAddon(addon);
    await terminal.writeAndWait('\u001b[1;31mred<text>');

    expect(addon.serialize(), contains('\u001b[31;1mred'));
    expect(addon.serializeAsHtml(), contains('red&lt;text>'));
  });

  test('serialize restores current style, cursor, and scroll region', () async {
    final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 5));
    final addon = SerializeAddon();
    addTearDown(terminal.dispose);
    terminal.loadAddon(addon);
    await terminal.writeAndWait(
      '\u001b[32m> \u001b[0m\u001b[2;4r\u001b[4;3H',
    );

    final serialized = addon.serialize();
    expect(serialized, startsWith('\u001b[32m> '));
    expect(serialized, contains('\u001b[2C\u001b[0m'));
    expect(serialized, endsWith('\u001b[2;4r'));
  });

  test('unicode addons register all pinned providers', () {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    terminal
      ..loadAddon(Unicode11Addon())
      ..loadAddon(UnicodeGraphemesAddon());

    expect(
      terminal.unicode.versions,
      containsAll(<String>['11', '15', '15-graphemes']),
    );
    expect(terminal.unicode.activeVersion, '15-graphemes');
  });

  test('web link provider returns validated ranges', () async {
    final terminal = Terminal(options: TerminalOptions(cols: 40, rows: 3));
    final activated = <String>[];
    final hovered = <TerminalBufferRange>[];
    final left = <String>[];
    final addon = WebLinksAddon(
      handler: (_, uri) => activated.add(uri),
      options: WebLinkProviderOptions(
        hover: (_, _, range) => hovered.add(range),
        leave: (_, text) => left.add(text),
      ),
    );
    addTearDown(terminal.dispose);
    terminal.loadAddon(addon);
    await terminal.writeAndWait(
      'aaa http://example.com aaa http://example.com aaa',
    );

    final provider = terminal.linkProviders.last;
    final firstRowLinks = await provider.provideLinks(1);
    final secondRowLinks = await provider.provideLinks(2);
    expect(firstRowLinks, hasLength(2));
    expect(secondRowLinks, hasLength(2));
    expect(firstRowLinks.first.text, 'http://example.com');
    expect(
      firstRowLinks.first.range,
      const TerminalBufferRange(
        start: TerminalBufferPosition(5, 1),
        end: TerminalBufferPosition(22, 1),
      ),
    );
    expect(
      firstRowLinks.last.range,
      const TerminalBufferRange(
        start: TerminalBufferPosition(28, 1),
        end: TerminalBufferPosition(5, 2),
      ),
    );
    firstRowLinks.first.activate(null, firstRowLinks.first.text);
    firstRowLinks.first.hover?.call(null, firstRowLinks.first.text);
    firstRowLinks.first.leave?.call(null, firstRowLinks.first.text);
    expect(activated.single, firstRowLinks.first.text);
    expect(hovered.single, firstRowLinks.first.range);
    expect(left.single, firstRowLinks.first.text);

    final decorations = TerminalLinkDecorations()..underline = false;
    expect(decorations.pointerCursor, isTrue);
    expect(decorations.underline, isFalse);
  });

  test('browser-only addons expose explicit capabilities', () {
    expect(WebFontsAddon.isSupported, isFalse);
    expect(WebglAddon.isSupported, isFalse);
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    expect(() => terminal.loadAddon(WebFontsAddon()), throwsUnsupportedError);
    expect(() => terminal.loadAddon(WebglAddon()), throwsUnsupportedError);
    expect(loadFonts, throwsUnsupportedError);
  }, testOn: '!browser');

  test('base64 codec round trips malformed-safe UTF-8', () {
    const codec = Base64Codec();
    expect(codec.decodeText(codec.encodeText('한글')), '한글');
    expect(codec.decodeText('!'), '');
  });
}

final class _ClipboardProvider implements TerminalClipboardProvider {
  _ClipboardProvider(this.value);

  String value;

  @override
  Future<String> readText(String selection) async => value;

  @override
  Future<void> writeText(String selection, String text) async {
    value = text;
  }
}

final class _SyncClipboardProvider implements TerminalClipboardProvider {
  _SyncClipboardProvider(this.value);

  String value;

  @override
  String readText(String selection) => value;

  @override
  void writeText(String selection, String text) => value = text;
}

final class _ThrowingCodec implements TerminalBase64Codec {
  const _ThrowingCodec();

  @override
  String decodeText(String data) => throw const FormatException('invalid');

  @override
  String encodeText(String data) => data;
}
