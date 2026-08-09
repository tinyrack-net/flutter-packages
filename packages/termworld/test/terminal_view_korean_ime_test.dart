import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

/// The delta-mode text-input client the terminal view attaches.
///
/// Linux delivers IME input as [TextEditingDelta]s, and the GTK embedder
/// computes each delta against its own editing model — which lags the
/// terminal's post-commit reset until `setEditingState` round-trips. These
/// tests drive that exact contract.
void Function(List<TextEditingDelta>) _imeDeltas(WidgetTester tester) => tester
    .allStates
    .whereType<DeltaTextInputClient>()
    .single
    .updateEditingValueWithDeltas;

Future<void> _pumpTerminal(WidgetTester tester, Terminal terminal) async {
  await tester.pumpWidget(
    MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
  );
  await tester.pump();
}

TextEditingDeltaInsertion _insert(
  String oldText,
  String inserted,
  int offset, {
  TextRange composing = TextRange.empty,
}) => TextEditingDeltaInsertion(
  oldText: oldText,
  textInserted: inserted,
  insertionOffset: offset,
  selection: TextSelection.collapsed(offset: offset + inserted.length),
  composing: composing,
);

TextEditingDeltaReplacement _replace(
  String oldText,
  TextRange range,
  String replacement, {
  TextRange composing = TextRange.empty,
}) => TextEditingDeltaReplacement(
  oldText: oldText,
  replacementText: replacement,
  replacedRange: range,
  selection: TextSelection.collapsed(
    offset: range.start + replacement.length,
  ),
  composing: composing,
);

TextEditingDeltaDeletion _delete(
  String oldText,
  TextRange range, {
  TextRange composing = TextRange.empty,
}) => TextEditingDeltaDeletion(
  oldText: oldText,
  deletedRange: range,
  selection: TextSelection.collapsed(offset: range.start),
  composing: composing,
);

void main() {
  testWidgets('writes each repeated jamo as it is committed', (tester) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    // IBus Hangul typing ㅁ ㄴ ㅇ ㄹ: each key commits the previous jamo and
    // starts a new preedit. The embedder's oldText keeps accumulating,
    // because the terminal's post-commit reset has not round-tripped yet.
    send(<TextEditingDelta>[
      _insert('', 'ㅁ', 0, composing: const TextRange(start: 0, end: 1)),
    ]);
    await tester.pump();
    expect(output.join(), isEmpty, reason: 'ㅁ is still being composed');

    send(<TextEditingDelta>[
      _replace('ㅁ', const TextRange(start: 0, end: 1), 'ㅁ'),
    ]);
    await tester.pump();
    expect(output.join(), 'ㅁ', reason: 'the first jamo committed');

    send(<TextEditingDelta>[
      _insert('ㅁ', 'ㄴ', 1, composing: const TextRange(start: 1, end: 2)),
    ]);
    await tester.pump();
    expect(output.join(), 'ㅁ', reason: 'ㄴ is still being composed');

    send(<TextEditingDelta>[
      _replace('ㅁㄴ', const TextRange(start: 1, end: 2), 'ㄴ'),
    ]);
    await tester.pump();
    expect(output.join(), 'ㅁㄴ', reason: 'the second jamo committed');

    send(<TextEditingDelta>[
      _insert('ㅁㄴ', 'ㅇ', 2, composing: const TextRange(start: 2, end: 3)),
    ]);
    send(<TextEditingDelta>[
      _replace('ㅁㄴㅇ', const TextRange(start: 2, end: 3), 'ㅇ'),
    ]);
    send(<TextEditingDelta>[
      _insert('ㅁㄴㅇ', 'ㄹ', 3, composing: const TextRange(start: 3, end: 4)),
    ]);
    send(<TextEditingDelta>[
      _replace('ㅁㄴㅇㄹ', const TextRange(start: 3, end: 4), 'ㄹ'),
    ]);
    await tester.pump();

    expect(
      output.join(),
      'ㅁㄴㅇㄹ',
      reason:
          'every jamo reaches the terminal as it commits, never in a '
          'burst on the next space',
    );
    expect(
      find.byKey(const ValueKey<String>('termworld-preedit')),
      findsNothing,
    );
  });

  testWidgets('grows one syllable in place and commits it once', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    // ㅎ ㅏ ㄴ composes 한 in place; nothing commits until the next word.
    send(<TextEditingDelta>[
      _insert('', 'ㅎ', 0, composing: const TextRange(start: 0, end: 1)),
    ]);
    send(<TextEditingDelta>[
      _replace(
        'ㅎ',
        const TextRange(start: 0, end: 1),
        '하',
        composing: const TextRange(start: 0, end: 1),
      ),
    ]);
    send(<TextEditingDelta>[
      _replace(
        '하',
        const TextRange(start: 0, end: 1),
        '한',
        composing: const TextRange(start: 0, end: 1),
      ),
    ]);
    await tester.pump();
    expect(output.join(), isEmpty);
    expect(find.text('한'), findsOneWidget);

    send(<TextEditingDelta>[
      _replace('한', const TextRange(start: 0, end: 1), '한'),
    ]);
    await tester.pump();

    expect(output.join(), '한');
  });

  testWidgets('redistributes a final consonant into the next syllable', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    // ㅎ ㅏ ㄴ ㅡ: the trailing ㄴ moves into the next syllable, so 한 becomes
    // the committed 하 while 느 starts composing.
    send(<TextEditingDelta>[
      _insert('', '한', 0, composing: const TextRange(start: 0, end: 1)),
    ]);
    send(<TextEditingDelta>[
      _replace('한', const TextRange(start: 0, end: 1), '하'),
    ]);
    await tester.pump();
    expect(output.join(), '하');

    send(<TextEditingDelta>[
      _insert('하', '느', 1, composing: const TextRange(start: 1, end: 2)),
    ]);
    await tester.pump();
    expect(output.join(), '하', reason: '느 is still being composed');

    send(<TextEditingDelta>[
      _replace('하느', const TextRange(start: 1, end: 2), '느'),
    ]);
    await tester.pump();

    expect(output.join(), '하느');
  });

  testWidgets('a backspace inside the composition never reaches the shell', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    send(<TextEditingDelta>[
      _insert('', '한', 0, composing: const TextRange(start: 0, end: 1)),
    ]);
    send(<TextEditingDelta>[
      _replace(
        '한',
        const TextRange(start: 0, end: 1),
        '하',
        composing: const TextRange(start: 0, end: 1),
      ),
    ]);
    await tester.pump();
    expect(output.join(), isEmpty);

    send(<TextEditingDelta>[
      _replace('하', const TextRange(start: 0, end: 1), '하'),
    ]);
    await tester.pump();

    expect(output.join(), '하', reason: 'only the final shape commits');
  });

  testWidgets('a cancelled composition writes nothing', (tester) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    send(<TextEditingDelta>[
      _insert('', 'ㅁ', 0, composing: const TextRange(start: 0, end: 1)),
    ]);
    send(<TextEditingDelta>[
      _delete('ㅁ', const TextRange(start: 0, end: 1)),
    ]);
    await tester.pump();

    expect(output.join(), isEmpty);
    expect(
      find.byKey(const ValueKey<String>('termworld-preedit')),
      findsNothing,
    );
  });

  testWidgets('mixed Hangul and ASCII stay in typed order', (tester) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    send(<TextEditingDelta>[
      _insert('', '한', 0, composing: const TextRange(start: 0, end: 1)),
    ]);
    send(<TextEditingDelta>[
      _replace('한', const TextRange(start: 0, end: 1), '한'),
    ]);
    await tester.pump();
    expect(output.join(), '한');

    // Switching to Latin: the ASCII key arrives as a plain insertion whose
    // oldText still carries the committed Hangul the terminal already reset.
    send(<TextEditingDelta>[
      _insert('한', 'a', 1),
    ]);
    await tester.pump();
    expect(output.join(), '한a');

    // And back: a fresh composition after the Latin commit.
    send(<TextEditingDelta>[
      _insert('한a', '글', 2, composing: const TextRange(start: 2, end: 3)),
    ]);
    send(<TextEditingDelta>[
      _replace('한a글', const TextRange(start: 2, end: 3), '글'),
    ]);
    await tester.pump();

    expect(output.join(), '한a글');
  });

  testWidgets('a composition still open on focus loss commits once', (
    tester,
  ) async {
    final terminal = Terminal();
    final focusNode = FocusNode();
    final nextFocusNode = FocusNode();
    addTearDown(terminal.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(nextFocusNode.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(
                child: TerminalView(
                  terminal: terminal,
                  focusNode: focusNode,
                  autofocus: true,
                ),
              ),
              TextButton(
                key: const ValueKey<String>('next-focus'),
                focusNode: nextFocusNode,
                onPressed: nextFocusNode.requestFocus,
                child: const Text('next'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final send = _imeDeltas(tester);

    send(<TextEditingDelta>[
      _insert('', '한', 0, composing: const TextRange(start: 0, end: 1)),
    ]);
    await tester.pump();
    expect(output.join(), isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('next-focus')));
    await tester.pump();

    expect(output.join(), '한');
  });

  testWidgets('a space right after a Hangul commit is written once', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    send(<TextEditingDelta>[
      _insert('', '글', 0, composing: const TextRange(start: 0, end: 1)),
    ]);
    send(<TextEditingDelta>[
      _replace('글', const TextRange(start: 0, end: 1), '글'),
    ]);
    await tester.pump();

    // IBus commits the composition on Space and GTK omits the space's own
    // delta, so the physical key bridge writes it — exactly once, even
    // though the platform text still carries the committed syllable.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    send(<TextEditingDelta>[
      _insert('글', ' ', 1),
    ]);
    await tester.pump();

    expect(output.join(), '글 ');
  });
}
