import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_clipboard.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('ClipboardAddon', () {
    late Terminal terminal;
    late _MemoryClipboard provider;
    late List<String> data;

    setUp(() {
      terminal = Terminal();
      provider = _MemoryClipboard();
      data = <String>[];
      terminal
        ..loadAddon(ClipboardAddon(provider: provider))
        ..onData.listen(data.add);
    });
    tearDown(() => terminal.dispose());

    group('write data', () {
      test('simple string', () async {
        await _osc(terminal, 'c', 'aGVsbG8gd29ybGQ=');
        expect(provider.value, 'hello world');
      });

      test('primary selection', () async {
        await _osc(terminal, 'p', 'aGVsbG8gd29ybGQ=');
        expect((provider.selection, provider.value), ('p', 'hello world'));
      });

      test('empty selection (default)', () async {
        await _osc(terminal, '', 'aGVsbG8gd29ybGQ=');
        expect((provider.selection, provider.value), ('', 'hello world'));
      });

      test('invalid base64 string', () async {
        await _osc(terminal, 'c', 'aGVsbG8gd29ybGQ=invalid');
        expect(provider.value, isEmpty);
      });

      test('empty string', () async {
        await _osc(terminal, 'c', 'aGVsbG8gd29ybGQ=');
        await _osc(terminal, 'c', '');
        expect(provider.value, isEmpty);
      });
    });

    group('read data', () {
      test('simple string', () async {
        provider.value = 'hello world';
        await _osc(terminal, 'c', '?');
        expect(data, <String>['\u001b]52;c;aGVsbG8gd29ybGQ=\u0007']);
      });

      test('primary selection', () async {
        provider.value = 'hello world';
        await _osc(terminal, 'p', '?');
        expect(data, <String>['\u001b]52;p;aGVsbG8gd29ybGQ=\u0007']);
      });

      test('clear clipboard', () async {
        provider.value = 'hello world';
        await _osc(terminal, 'c', '!');
        await _osc(terminal, 'c', '?');
        expect(provider.value, isEmpty);
        expect(data, <String>['\u001b]52;c;\u0007']);
      });
    });

    group('non-ASCII', () {
      test('write simple string', () async {
        await _osc(terminal, 'c', '4oKsbWzDpMO8dMOf');
        expect(provider.value, '€mläütß');
      });

      test('read simple string', () async {
        provider.value = '€mläütß';
        await _osc(terminal, 'c', '?');
        expect(data, <String>['\u001b]52;c;4oKsbWzDpMO8dMOf\u0007']);
      });
    });
  });
}

Future<void> _osc(Terminal terminal, String selection, String payload) =>
    terminal.writeAndWait('\u001b]52;$selection;$payload\u0007');

final class _MemoryClipboard implements TerminalClipboardProvider {
  String selection = '';
  String value = '';

  @override
  FutureOr<String> readText(String selection) {
    this.selection = selection;
    return value;
  }

  @override
  FutureOr<void> writeText(String selection, String text) {
    this.selection = selection;
    value = text;
  }
}
