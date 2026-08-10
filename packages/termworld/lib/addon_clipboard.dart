/// OSC 52 clipboard addon.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:vtworld/vtworld.dart';

/// UTF-8 base64 codec used by OSC 52.
abstract interface class TerminalBase64Codec {
  /// Encodes [data] as UTF-8 base64.
  String encodeText(String data);

  /// Decodes UTF-8 base64. Invalid input produces an empty string.
  String decodeText(String data);
}

/// Default UTF-8 base64 codec.
final class Base64Codec implements TerminalBase64Codec {
  /// xterm-compatible `Base64Codec` API.
  const Base64Codec();

  @override
  String encodeText(String data) => base64.encode(utf8.encode(data));

  @override
  String decodeText(String data) {
    try {
      return utf8.decode(base64.decode(data), allowMalformed: true);
    } on FormatException {
      return '';
    }
  }
}

/// Platform clipboard abstraction. `selection` is the OSC 52 selection code.
abstract interface class TerminalClipboardProvider {
  /// Reads text from [selection].
  FutureOr<String> readText(String selection);

  /// Replaces [selection] with [text].
  FutureOr<void> writeText(String selection, String text);
}

/// Clipboard provider backed by Flutter's platform clipboard channel.
final class FlutterClipboardProvider implements TerminalClipboardProvider {
  /// xterm-compatible `FlutterClipboardProvider` API.
  const FlutterClipboardProvider();

  @override
  Future<String> readText(String selection) async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';

  @override
  Future<void> writeText(String selection, String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

/// Handles clipboard read and write requests over OSC 52.
final class ClipboardAddon extends ManagedTerminalAddon {
  /// Creates a clipboard addon with injectable security boundaries.
  ClipboardAddon({
    this._codec = const Base64Codec(),
    this._provider = const FlutterClipboardProvider(),
  });

  final TerminalBase64Codec _codec;
  final TerminalClipboardProvider _provider;

  @override
  void onActivate(Terminal terminal) {
    add(
      terminal.parser.registerOscHandler(52, (data) {
        final arguments = data.split(';');
        if (arguments.length < 2) return true;
        final selection = arguments[0];
        final payload = arguments[1];
        if (payload == '?') {
          final text = _provider.readText(selection);
          if (text is Future<String>) {
            return text.then((value) {
              _reportClipboard(terminal, selection, value);
              return true;
            });
          }
          _reportClipboard(terminal, selection, text);
          return true;
        }
        var text = '';
        try {
          text = _codec.decodeText(payload);
          // Custom codecs may throw arbitrary decoding failures.
          // ignore: avoid_catches_without_on_clauses
        } catch (_) {}
        final result = _provider.writeText(selection, text);
        if (result is Future<void>) return result.then((_) => true);
        return true;
      }),
    );
  }

  void _reportClipboard(Terminal terminal, String selection, String text) {
    terminal.input(
      '\u001b]52;$selection;${_codec.encodeText(text)}\u0007',
      wasUserInput: false,
    );
  }
}
