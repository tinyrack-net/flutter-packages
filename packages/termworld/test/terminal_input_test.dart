import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

void main() {
  testWidgets('commits Hangul and its trailing space exactly once', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalView(emulator: emulator, autofocus: true)),
    );
    await tester.pump();

    for (final value in const <TextEditingValue>[
      TextEditingValue(
        text: 'ㅎ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
      TextEditingValue(
        text: '한',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
      TextEditingValue(
        text: '한ㄱ',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
      TextEditingValue(
        text: '한글',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
      TextEditingValue(
        text: '한글 ',
        selection: TextSelection.collapsed(offset: 3),
      ),
      TextEditingValue(
        text: '한글 ',
        selection: TextSelection.collapsed(offset: 3),
      ),
    ]) {
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
    }

    expect(output.join(), '한글 ');
  });

  testWidgets('commits candidate replacements only when composition ends', (
    tester,
  ) async {
    for (final sequence in const <List<TextEditingValue>>[
      <TextEditingValue>[
        TextEditingValue(
          text: 'にほん',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 0, end: 3),
        ),
        TextEditingValue(
          text: '日本',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
        TextEditingValue(
          text: '日本',
          selection: TextSelection.collapsed(offset: 2),
        ),
      ],
      <TextEditingValue>[
        TextEditingValue(
          text: 'nihao',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
        TextEditingValue(
          text: '你好',
          selection: TextSelection.collapsed(offset: 2),
        ),
      ],
    ]) {
      final output = <String>[];
      final emulator = TerminalEmulator(onOutput: output.add);
      await tester.pumpWidget(
        MaterialApp(home: TerminalView(emulator: emulator, autofocus: true)),
      );
      await tester.pump();
      for (final value in sequence) {
        tester.testTextInput.updateEditingValue(value);
        await tester.pump();
      }
      expect(output.join(), anyOf('日本', '你好'));
      emulator.dispose();
    }
  });

  testWidgets('keeps grapheme clusters intact and does not repeat commits', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(emulator: emulator, autofocus: true)),
    );
    await tester.pump();

    for (final value in const <TextEditingValue>[
      TextEditingValue(
        text: 'e\u0301',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
      TextEditingValue(
        text: 'é',
        selection: TextSelection.collapsed(offset: 1),
      ),
      TextEditingValue(
        text: 'é👩🏽\u200d💻',
        selection: TextSelection.collapsed(offset: 8),
      ),
      TextEditingValue(
        text: 'é👩🏽\u200d💻',
        selection: TextSelection.collapsed(offset: 8),
      ),
    ]) {
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
    }

    expect(output.join(), 'é👩🏽\u200d💻');
  });

  testWidgets('handles Hangul changes, cancellation, and boundary characters', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(emulator: emulator, autofocus: true)),
    );
    await tester.pump();

    for (final value in const <TextEditingValue>[
      TextEditingValue(
        text: '가',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
      TextEditingValue(
        text: '각',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
      TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      ),
      TextEditingValue(
        text: '한',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
      TextEditingValue(
        text: '한글',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
      TextEditingValue(
        text: '한글,\t42!',
        selection: TextSelection.collapsed(offset: 7),
      ),
    ]) {
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
    }

    expect(output.join(), '한글,\t42!');
  });

  testWidgets('commits dead keys, flags, skin tones, and repeats once', (
    tester,
  ) async {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);
    await tester.pumpWidget(
      MaterialApp(home: TerminalView(emulator: emulator, autofocus: true)),
    );
    await tester.pump();

    for (final value in const <TextEditingValue>[
      TextEditingValue(
        text: '´',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
      TextEditingValue(
        text: 'é',
        selection: TextSelection.collapsed(offset: 1),
      ),
      TextEditingValue(
        text: 'é🇰🇷👍🏽aaa',
        selection: TextSelection.collapsed(offset: 12),
      ),
      TextEditingValue(
        text: 'é🇰🇷👍🏽aaa',
        selection: TextSelection.collapsed(offset: 12),
      ),
    ]) {
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
    }

    expect(output.join(), 'é🇰🇷👍🏽aaa');
  });

  test('wraps paste only while bracketed paste mode is enabled', () {
    final output = <String>[];
    final emulator = TerminalEmulator(onOutput: output.add);
    addTearDown(emulator.dispose);

    emulator
      ..paste('plain')
      ..write('\u001b[?2004h')
      ..paste('wrapped')
      ..write('\u001b[?2004l')
      ..paste('plain-again');

    expect(
      output,
      <String>[
        'plain',
        '\u001b[200~wrapped\u001b[201~',
        'plain-again',
      ],
    );
  });
}
