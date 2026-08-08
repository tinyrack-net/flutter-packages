import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:termworld/addon_attach.dart';
import 'package:termworld/addon_web_fonts.dart';
import 'package:termworld/addon_webgl.dart';
import 'package:termworld/termworld_headless.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('options validate mutable values and report effective changes', () {
    final options = TerminalOptions(
      allowProposedApi: true,
      allowTransparency: true,
      altClickMovesCursor: false,
      convertEol: true,
      cursorBlink: true,
      blinkIntervalDuration: 1,
      cursorStyle: TerminalCursorStyle.bar,
      cursorWidth: 2,
      cursorInactiveStyle: TerminalInactiveCursorStyle.none,
      disableStdin: true,
      drawBoldTextInBrightColors: false,
      fastScrollSensitivity: 2,
      fontSize: 14,
      fontFamily: 'test',
      fontWeight: 500,
      fontWeightBold: '900',
      ignoreBracketedPasteMode: true,
      letterSpacing: 1,
      lineHeight: 2,
      logLevel: TerminalLogLevel.debug,
      macOptionIsMeta: true,
      macOptionClickForcesSelection: true,
      minimumContrastRatio: 2,
      mouseEventsRequireAlt: true,
      reflowCursorLine: true,
      rescaleOverlappingGlyphs: true,
      rightClickSelectsWord: true,
      screenReaderMode: true,
      scrollback: 10,
      scrollOnEraseInDisplay: true,
      scrollOnUserInput: false,
      scrollSensitivity: 2,
      smoothScrollDuration: 10,
      tabStopWidth: 4,
      wordSeparator: ',',
      cols: 2,
      rows: 2,
      showCursorImmediately: true,
    );
    final changes = <String>[];
    options.onChange.listen(changes.add);

    options
      ..blinkIntervalDuration = 2
      ..cursorWidth = 3
      ..fastScrollSensitivity = 3
      ..lineHeight = 3
      ..minimumContrastRatio = 99
      ..scrollback = 20
      ..scrollSensitivity = 3
      ..tabStopWidth = 2
      ..tabStopWidth = 2;

    expect(changes, hasLength(8));
    expect(options.minimumContrastRatio, 21);
    expect(() => options.blinkIntervalDuration = -1, throwsArgumentError);
    expect(() => options.cursorWidth = 0, throwsArgumentError);
    expect(() => options.fastScrollSensitivity = 0, throwsArgumentError);
    expect(() => options.lineHeight = 0, throwsArgumentError);
    expect(() => options.scrollback = -1, throwsArgumentError);
    expect(() => options.scrollSensitivity = 0, throwsArgumentError);
    expect(() => options.tabStopWidth = 0, throwsArgumentError);
    expect(TerminalOptions(cols: -1).cols, 80);
    expect(TerminalOptions(rows: -1).rows, 24);
    expect(TerminalOptions(fontWeight: 0).fontWeight, 'normal');
    expect(TerminalOptions(fontWeightBold: 'invalid').fontWeightBold, 'bold');
  });

  test('unicode registry covers control, combining, wide, and error cases', () {
    final unicode = TerminalUnicodeHandling();
    final provider = unicode.active;

    expect(provider.width(0), 0);
    expect(provider.width(0x1f), 0);
    expect(provider.width(0x7f), 0);
    expect(provider.width(0x301), 0);
    expect(provider.width(0x200d), 0);
    expect(provider.width('A'.codeUnitAt(0)), 1);
    expect(provider.width(0xac00), 2);
    // The built-in core provider is xterm's Unicode 6 table. Applications
    // opt into newer emoji widths through an official Unicode addon.
    expect(provider.width(0x1f600), 1);
    expect(provider.charProperties(0xac00, 0), 4);
    expect(() => unicode.register(provider), throwsArgumentError);
    expect(() => unicode.activeVersion = 'missing', throwsArgumentError);
    unicode
      ..register(const _UnicodeProvider())
      ..activeVersion = 'test';
    expect(unicode.active.width(1), 1);
  });

  test(
    'terminal public APIs preserve events, modes, and error contracts',
    () async {
      final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 2));
      final events = <String>[];
      terminal
        ..onBell.listen((_) => events.add('bell'))
        ..onCursorMove.listen((_) => events.add('cursor'))
        ..onLineFeed.listen((_) => events.add('line'))
        ..onRender.listen((_) => events.add('render'))
        ..onResize.listen((_) => events.add('resize'))
        ..onScroll.listen((_) => events.add('scroll'))
        ..onSelectionChange.listen((_) => events.add('selection'))
        ..onTitleChange.listen(events.add)
        ..onDimensionsChange.listen((_) => events.add('dimensions'));

      await terminal.writeAndWait(
        '\u0007\u001b]0;title\u0007A\n\u001b[4h'
        ' '
        '\u001b[?1;6;7;25;45;66;1000;1004;2004;2026;9001h',
      );
      expect(events, containsAll(<String>['bell', 'title', 'line']));
      // Cursor events compare the position at parser entry and exit. This
      // write returns to its starting position when origin mode is enabled.
      expect(events, isNot(contains('cursor')));
      expect(terminal.modes.applicationCursorKeysMode, isTrue);
      expect(terminal.modes.applicationKeypadMode, isTrue);
      expect(terminal.modes.insertMode, isTrue);
      expect(terminal.modes.originMode, isTrue);
      expect(terminal.modes.showCursor, isTrue);
      expect(terminal.modes.wraparoundMode, isTrue);
      expect(terminal.modes.reverseWraparoundMode, isTrue);
      expect(terminal.modes.sendFocusMode, isTrue);
      expect(terminal.modes.bracketedPasteMode, isTrue);
      expect(terminal.modes.synchronizedOutputMode, isTrue);
      expect(terminal.modes.win32InputMode, isTrue);
      expect(terminal.modes.mouseTrackingMode, 'vt200');

      await terminal.writeAndWait('\u001b[?1000l\u001b[?9h');
      expect(terminal.modes.mouseTrackingMode, 'x10');

      await terminal.writeAndWait('\u001b[?2026l\u001b[?9l\u001b[?1002h');
      expect(events, contains('render'));
      expect(terminal.modes.mouseTrackingMode, 'drag');
      await terminal.writeAndWait('\u001b[?1002l\u001b[?1003h');
      expect(terminal.modes.mouseTrackingMode, 'any');
      await terminal.writeAndWait('\u001b[?1003l');
      expect(terminal.modes.mouseTrackingMode, 'none');

      expect(() => terminal.write(1), throwsArgumentError);
      expect(() => terminal.writeAndWait(1), throwsArgumentError);
      expect(() => terminal.resize(0, 1), throwsArgumentError);
      expect(() => terminal.resize(1, 0), throwsArgumentError);
      terminal
        ..resize(6, 3)
        ..resize(6, 3);

      var focused = false;
      var blurred = false;
      terminal
        ..attachFocusHandlers(
          focus: () => focused = true,
          blur: () => blurred = true,
        )
        ..focus()
        ..blur()
        ..attachCustomKeyEventHandler((event) => event.key != 'blocked')
        ..attachCustomWheelEventHandler((event) => event.deltaY > 0);
      expect(focused && blurred, isTrue);
      expect(
        terminal.handleKeyEvent(
          const TerminalKeyEvent(key: 'blocked', shift: true),
        ),
        isFalse,
      );
      expect(
        terminal.handleWheelEvent(
          const TerminalWheelEvent(deltaX: 0, deltaY: 1, alt: true),
        ),
        isTrue,
      );

      final provider = _LinkProvider();
      final registration = terminal.registerLinkProvider(provider);
      expect(terminal.linkProviders, <TerminalLinkProvider>[provider]);
      registration.dispose();
      expect(terminal.linkProviders, isEmpty);

      final firstJoiner = terminal.registerCharacterJoiner(
        (_) => const <TerminalCharacterJoin>[TerminalCharacterJoin(0, 2)],
      );
      terminal.registerCharacterJoiner(
        (_) => const <TerminalCharacterJoin>[TerminalCharacterJoin(1, 3)],
      );
      expect(terminal.characterJoins('abc').single.end, 3);
      terminal.deregisterCharacterJoiner(firstJoiner);
      expect(
        () => terminal.deregisterCharacterJoiner(999),
        throwsArgumentError,
      );
      final invalidJoiner = terminal.registerCharacterJoiner(
        (_) => const <TerminalCharacterJoin>[TerminalCharacterJoin(-1, 1)],
      );
      expect(() => terminal.characterJoins('abc'), throwsRangeError);
      terminal.deregisterCharacterJoiner(invalidJoiner);

      await terminal.writeAndWait('\rhello\r\nworld\r\nagain');
      final marker = terminal.registerMarker()!;
      expect(terminal.registerMarker(cursorYOffset: 99), isNull);
      final decoration = terminal.registerDecoration(
        marker: marker,
        anchor: TerminalDecorationAnchor.right,
        layer: TerminalDecorationLayer.top,
      )!;
      expect(terminal.decorations, contains(decoration));
      decoration.dispose();
      marker.dispose();
      expect(terminal.registerDecoration(marker: marker), isNull);

      expect(terminal.hasSelection(), isFalse);
      expect(terminal.getSelection(), '');
      terminal.select(0, 0, 8);
      expect(terminal.getSelectionPosition(), isNotNull);
      terminal
        ..clearSelection()
        ..clearSelection();
      expect(() => terminal.select(-1, 0, 1), throwsArgumentError);
      expect(() => terminal.select(0, 999, 1), throwsRangeError);
      expect(() => terminal.selectLines(2, 1), throwsRangeError);
      terminal
        ..selectLines(0, 1)
        ..selectAll()
        ..scrollToTop()
        ..scrollLines(1)
        ..scrollPages(1)
        ..scrollToBottom()
        ..scrollToLine(-1)
        ..clear();
      expect(() => terminal.refresh(-1, 0), throwsRangeError);
      terminal
        ..refresh(0, terminal.rows - 1)
        ..clearTextureAtlas()
        ..reset();

      const dimensions = TerminalRenderDimensions(
        width: 60,
        height: 30,
        cellWidth: 10,
        cellHeight: 10,
        devicePixelRatio: 2,
      );
      terminal
        ..updateDimensions(dimensions)
        ..updateDimensions(dimensions);
      expect(terminal.dimensions?.devicePixelRatio, 2);

      final addon = _Addon();
      terminal.loadAddon(addon);
      expect(() => terminal.loadAddon(addon), throwsStateError);
      terminal
        ..dispose()
        ..dispose();
      expect(() => terminal.write('x'), throwsStateError);
      expect(() => terminal.writeAndWait('x'), throwsStateError);
      terminal.input('ignored');
    },
  );

  test(
    'attach transfers supported socket payloads in both directions',
    () async {
      final socket = _FakeSocket();
      final terminal = Terminal();
      final addon = AttachAddon(socket);
      addTearDown(terminal.dispose);
      terminal
        ..loadAddon(addon)
        ..input('out');
      expect(socket.sent, <Object?>['out']);
      socket
        ..addIncoming('one')
        ..addIncoming(Uint8List.fromList(<int>[0x74, 0x77, 0x6f]))
        ..addIncoming(<int>[0x74, 0x68, 0x72, 0x65, 0x65])
        ..addIncoming(4);
      await Future<void>.delayed(Duration.zero);

      expect(
        terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
        'onetwothree',
      );
      addon.dispose();
      socket.closeIncoming();
    },
  );

  test('non-web addon stubs expose complete capability errors', () async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final fonts = WebFontsAddon(initialRelayout: false);
    expect(fonts.initialRelayout, isFalse);
    expect(() => fonts.loadFonts(<String>['mono']), throwsUnsupportedError);
    expect(fonts.relayout, throwsUnsupportedError);

    final webgl = WebglAddon(
      customGlyphs: false,
      preserveDrawingBuffer: true,
    );
    expect(webgl.customGlyphs, isFalse);
    expect(webgl.preserveDrawingBuffer, isTrue);
    expect(webgl.textureAtlas, isNull);
    expect(webgl.onAddTextureAtlas, isNotNull);
    expect(webgl.onChangeTextureAtlas, isNotNull);
    expect(webgl.onRemoveTextureAtlas, isNotNull);
    expect(webgl.onContextLoss, isNotNull);
    expect(webgl.clearTextureAtlas, throwsStateError);
    webgl
      ..reportContextLoss()
      ..dispose();
    expect(const TerminalTextureAtlas(2).generation, 2);
  }, testOn: '!browser');
}

final class _UnicodeProvider implements TerminalUnicodeProvider {
  const _UnicodeProvider();

  @override
  String get version => 'test';

  @override
  int charProperties(int codePoint, int precedingProperties) => 1;

  @override
  int width(int codePoint) => 1;
}

final class _LinkProvider implements TerminalLinkProvider {
  @override
  List<TerminalLink> provideLinks(int bufferLineNumber) => <TerminalLink>[];
}

final class _Addon implements TerminalAddon {
  bool _isDisposed = false;

  @override
  bool get isDisposed => _isDisposed;

  @override
  void activate(Terminal terminal) {}

  @override
  void dispose() => _isDisposed = true;
}

final class _FakeSocket extends StreamChannelMixin<Object?>
    implements WebSocketChannel {
  final StreamController<Object?> _incoming = StreamController<Object?>();
  final _FakeSocketSink _sink = _FakeSocketSink();

  List<Object?> get sent => _sink.values;

  void addIncoming(Object? value) => _incoming.add(value);

  void closeIncoming() => unawaited(_incoming.close());

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<Object?> get stream => _incoming.stream;
}

final class _FakeSocketSink implements WebSocketSink {
  final List<Object?> values = <Object?>[];
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> get done => _done.future;

  @override
  void add(Object? data) => values.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Object?> stream) async {
    values.addAll(await stream.toList());
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }
}
