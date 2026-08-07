@TestOn('linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termworld_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real IBus composition commits graphemes once', (tester) async {
    final harness = await _ImeHarness.start(tester);
    addTearDown(harness.dispose);

    await harness.keys(<String>['g', 'k', 's']);
    expect(harness.output, isEmpty, reason: 'active preedit reached the PTY');

    await harness.keys(<String>['r']);
    await harness.waitForOutput('한');
    await harness.keys(<String>['m', 'f']);
    expect(harness.output, '한');
    await harness.keys(<String>['space']);
    await harness.waitForOutput('한글 ');
  });

  testWidgets('real IBus handles words, correction, and boundaries', (
    tester,
  ) async {
    final harness = await _ImeHarness.start(tester);
    addTearDown(harness.dispose);

    await harness.keys(<String>[
      ...'gksrmf'.split(''),
      'space',
      ...'dlqfur'.split(''),
      'space',
      ...'dkssud'.split(''),
      'space',
    ]);
    await harness.waitForOutput('한글 입력 안녕 ');

    harness.clear();
    await harness.keys(<String>['r', 'k', 'r', 'BackSpace', 's', 'space']);
    await harness.waitForOutput('간 ');

    harness.clear();
    await harness.keys(<String>[
      'g',
      'k',
      's',
      'r',
      'm',
      'f',
      'comma',
      'period',
      '4',
      '2',
      'space',
      'Tab',
      'Return',
    ]);
    await harness.waitForOutput('한글,.42 \t\r');
  });

  testWidgets('real IBus switches to Latin and back without ghost commits', (
    tester,
  ) async {
    final harness = await _ImeHarness.start(tester);
    addTearDown(harness.dispose);

    await harness.keys(<String>[...'gksrmf'.split(''), 'space']);
    await harness.toggleLanguage();
    await harness.keys('a b c minus 4 2 space'.split(' '));
    await harness.toggleLanguage();
    await harness.keys(<String>[...'dkssud'.split(''), 'space']);
    await harness.waitForOutput('한글 abc-42 안녕 ');

    harness.clear();
    await harness.keys(<String>['g', 'k', 's']);
    await harness.toggleLanguage();
    await harness.waitForOutput('한');
    await harness.keys(<String>['a', 'b', 'c', 'space']);
    await harness.toggleLanguage();
    await harness.keys(<String>['d', 'k', 's', 'space']);
    await harness.waitForOutput('한abc 안 ');

    for (var index = 0; index < 4; index++) {
      await harness.toggleLanguage();
    }
    expect(harness.output, '한abc 안 ');
  });

  testWidgets('focus and real clipboard paste do not duplicate composition', (
    tester,
  ) async {
    final harness = await _ImeHarness.start(tester);
    addTearDown(harness.dispose);

    await harness.keys(<String>['g', 'k', 's']);
    await harness.click(find.byKey(const ValueKey<String>('focus-target')));
    await harness.focusTerminal();
    expect(harness.output, '한');
    await harness.keys(<String>['space']);
    await harness.waitForOutput('한 ');

    harness.clear();
    const pasted = '붙여넣기 👩🏽\u200d💻 e\u0301\n둘째 줄';
    await harness.paste(pasted);
    await harness.waitForOutput(pasted);

    harness.clear();
    harness.controller.setBracketedPaste(enabled: true);
    await harness.paste(pasted);
    await harness.waitForOutput('\u001b[200~$pasted\u001b[201~');
    harness.controller.setBracketedPaste(enabled: false);

    harness.clear();
    await harness.focusTerminal();
    await harness.keys(<String>['g', 'k', 's']);
    await harness.paste('붙여넣기');
    await harness.waitForOutput('한붙여넣기');
  });
}

final class _ImeHarness {
  _ImeHarness._(this.tester, this.controller, this.windowId);

  final WidgetTester tester;
  final TermworldExampleController controller;
  final String windowId;
  Process? _clipboard;

  String get output => controller.output;

  static Future<_ImeHarness> start(WidgetTester tester) async {
    await _run('gsettings', <String>[
      'set',
      'org.freedesktop.ibus.engine.hangul',
      'disable-latin-mode',
      'false',
    ]);
    await _run('ibus', <String>['restart']);
    var engineAvailable = false;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final engines = await Process.run('ibus', <String>['list-engine']);
      if (engines.exitCode == 0 &&
          engines.stdout.toString().contains('hangul')) {
        engineAvailable = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(engineAvailable, isTrue, reason: 'IBus Hangul engine unavailable');
    var hangulEngineActive = false;
    final engineDeadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(engineDeadline)) {
      final selected = await Process.run('ibus', <String>[
        'engine',
        'hangul',
      ]);
      final current = await Process.run('ibus', <String>['engine']);
      if (selected.exitCode == 0 &&
          current.exitCode == 0 &&
          current.stdout.toString().trim() == 'hangul') {
        hangulEngineActive = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(hangulEngineActive, isTrue, reason: 'IBus engine did not activate');

    final controller = TermworldExampleController();
    await tester.pumpWidget(TermworldExampleApp(controller: controller));
    await tester.pumpAndSettle();
    final search = await _run('xdotool', <String>[
      'search',
      '--onlyvisible',
      '--name',
      'termworld',
    ]);
    final ids = search.stdout.toString().trim().split(RegExp(r'\s+'));
    final id = ids.last;
    final harness = _ImeHarness._(tester, controller, id);
    await harness.focusTerminal();
    await harness.keys(<String>['g']);
    if (harness.output == 'g') {
      harness.clear();
      await harness.toggleLanguage();
    } else {
      expect(harness.output, isEmpty, reason: 'IBus mode probe was ambiguous');
      await harness.keys(<String>['BackSpace']);
    }
    return harness;
  }

  Future<void> focusTerminal() async {
    await tester.tap(find.byKey(const ValueKey<String>('terminal')));
    await tester.pumpAndSettle();
    await _run('xdotool', <String>['windowfocus', '--sync', windowId]);
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (FocusManager.instance.primaryFocus?.debugLabel !=
            'termworld-terminal-input' &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'termworld-terminal-input',
    );
  }

  Future<void> keys(List<String> keys) async {
    final filtered = keys.where((key) => key.isNotEmpty).toList();
    if (filtered.isEmpty) return;
    for (final key in filtered) {
      await _run('xdotool', <String>[
        'keydown',
        '--clearmodifiers',
        key,
        'sleep',
        '0.04',
        'keyup',
        key,
      ]);
    }
    await tester.pumpAndSettle();
  }

  Future<void> toggleLanguage() async {
    await _run('xdotool', <String>[
      'keydown',
      '--clearmodifiers',
      'Shift_L',
      'sleep',
      '0.04',
      'keydown',
      'space',
      'sleep',
      '0.04',
      'keyup',
      'space',
      'keyup',
      'Shift_L',
    ]);
    await tester.pumpAndSettle();
  }

  Future<void> click(Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> paste(String text) async {
    _clipboard?.kill();
    final clipboard = await Process.start('xclip', <String>[
      '-selection',
      'clipboard',
      '-silent',
    ]);
    _clipboard = clipboard;
    clipboard.stdin.write(text);
    await clipboard.stdin.close();
    var clipboardReady = false;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final read = await Process.run('xclip', <String>[
        '-selection',
        'clipboard',
        '-out',
      ]);
      if (read.exitCode == 0 && read.stdout == text) {
        clipboardReady = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(clipboardReady, isTrue, reason: 'X clipboard was not populated');
    await click(find.byKey(const ValueKey<String>('paste-clipboard')));
  }

  void clear() => controller.clearOutput();

  Future<void> waitForOutput(String expected) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (output != expected && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      output,
      expected,
      reason: 'PTY bytes: ${utf8.encode(output).map(_hex).join(' ')}',
    );
  }

  Future<void> dispose() async {
    _clipboard?.kill();
    controller.dispose();
  }
}

String _hex(int value) => value.toRadixString(16).padLeft(2, '0');

Future<ProcessResult> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
  return result;
}
