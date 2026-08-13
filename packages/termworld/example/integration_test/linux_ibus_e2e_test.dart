@TestOn('linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('real IBus keeps a redistributing word in typed order', (
    tester,
  ) async {
    final harness = await _ImeHarness.start(tester);
    addTearDown(harness.dispose);

    // 안녕하세요: ㅅ and ㅇ first land as the final consonant of the syllable
    // in progress and are redistributed into the next one, so those keystrokes
    // settle a syllable and reopen the preedit in the same breath. The
    // syllables must still reach the PTY in the order they were typed.
    await harness.keys(<String>[
      ...'dkssudgktpdy'.split(''),
      'period',
      'space',
    ]);
    await harness.waitForOutput('안녕하세요. ');
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
    await harness.waitForOutput('한글 abc-42 ');
    await harness.toggleLanguage();
    await harness.keys(<String>[...'dkssud'.split(''), 'space']);
    await harness.waitForOutput('한글 abc-42 안녕 ');

    harness.clear();
    await harness.keys(<String>['g', 'k', 's']);
    await harness.toggleLanguage();
    await harness.waitForOutput('한');
    await harness.keys(<String>['a', 'b', 'c', 'space']);
    await harness.waitForOutput('한abc ');
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
    const terminalPaste = '붙여넣기 👩🏽\u200d💻 e\u0301\r둘째 줄';
    await harness.paste(pasted);
    await harness.waitForOutput(terminalPaste);

    harness.clear();
    harness.controller.setBracketedPaste(enabled: true);
    await harness.paste(pasted);
    await harness.waitForOutput('\u001b[200~$terminalPaste\u001b[201~');
    harness.controller.setBracketedPaste(enabled: false);

    harness.clear();
    await harness.focusTerminal();
    await harness.keys(<String>['g', 'k', 's']);
    await harness.paste('붙여넣기');
    await harness.waitForOutput('한붙여넣기');
  });

  testWidgets('real hardware Backspace and Alt Backspace emit once', (
    tester,
  ) async {
    final harness = await _ImeHarness.start(tester);
    addTearDown(harness.dispose);
    await harness.toggleLanguage();

    await harness.keys(<String>[...'word'.split('')]);
    await harness.keys(<String>['BackSpace']);
    await harness.chord(<String>['Alt_L'], 'BackSpace');
    await harness.waitForOutput('word\u007f\u001b\u007f');
  });
}

final class _ImeHarness {
  _ImeHarness._(this.tester, this.controller, this.windowId);

  final WidgetTester tester;
  final TermworldExampleController controller;
  final String windowId;
  Process? _clipboard;
  bool _hangulEngine = true;

  String get output => controller.output;

  static Future<_ImeHarness> start(WidgetTester tester) async {
    await _run('gsettings', <String>[
      'set',
      'org.freedesktop.ibus.engine.hangul',
      'disable-latin-mode',
      'false',
    ]);
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
      await harness.enableHangul();
      await harness.keys(<String>['g']);
      expect(harness.output, isEmpty, reason: 'Hangul mode did not activate');
      await harness.keys(<String>['BackSpace']);
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
    await _releaseModifiers();
    for (final key in filtered) {
      await _run('xdotool', <String>[
        'key',
        '--clearmodifiers',
        '--delay',
        '40',
        key,
      ]);
      await tester.pump(const Duration(milliseconds: 20));
    }
    // IBus can enqueue the final key-up/text-input delivery after xdotool has
    // returned. Drain that boundary before a following engine switch so the
    // last committed character cannot be cancelled by the new engine.
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
  }

  Future<void> toggleLanguage() async {
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
    await _releaseModifiers();
    final target = _hangulEngine ? 'xkb:us::eng' : 'hangul';
    await _run('ibus', <String>['engine', target]);
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final current = await _run('ibus', <String>['engine']);
      if (current.stdout.toString().trim() == target) break;
      await tester.pump(const Duration(milliseconds: 20));
    }
    final current = await _run('ibus', <String>['engine']);
    expect(current.stdout.toString().trim(), target);
    _hangulEngine = !_hangulEngine;
    await _releaseModifiers();
    await tester.pumpAndSettle();
  }

  Future<void> _releaseModifiers() async {
    await _run('xdotool', <String>[
      'keyup',
      'Shift_L',
      'keyup',
      'Shift_R',
      'keyup',
      'Control_L',
      'keyup',
      'Control_R',
      'keyup',
      'Alt_L',
      'keyup',
      'Alt_R',
    ]);
    final keyboardState = await _run('xset', <String>['q']);
    if (RegExp(r'Caps Lock:\s+on').hasMatch(keyboardState.stdout as String)) {
      await _run('xdotool', <String>['key', 'Caps_Lock']);
    }
  }

  Future<void> chord(List<String> modifiers, String key) async {
    await _releaseModifiers();
    final arguments = <String>['keydown'];
    for (final modifier in modifiers) {
      arguments.addAll(<String>[modifier, 'sleep', '0.04', 'keydown']);
    }
    arguments
      ..addAll(<String>[key, 'sleep', '0.04', 'keyup', key])
      ..addAll(<String>[
        for (final modifier in modifiers.reversed) ...<String>[
          'keyup',
          modifier,
        ],
      ]);
    await _run('xdotool', arguments);
    await _releaseModifiers();
    await tester.pumpAndSettle();
  }

  Future<void> enableHangul() async {
    await keys(<String>['Hangul']);
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
