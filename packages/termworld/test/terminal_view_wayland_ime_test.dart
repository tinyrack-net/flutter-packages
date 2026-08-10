import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

/// Deterministic replays of `flutter/textinput` delta streams captured on a
/// real Ubuntu GNOME Wayland session while typing 안녕하세요 with ibus-hangul.
///
/// The `wayland_text_input_v3` fixture is the GNOME default path (GTK
/// imwayland → mutter → ibus, `GTK_IM_MODULE` unset). GTK's known
/// text-input-v3 serial bug (GNOME/gtk#1365) delivers each completed
/// syllable's commit *after* the next preedit has started: the commit is
/// inserted to the right of the live composing range and the following
/// preedit overwrites the range in place, so committed syllables pile up in
/// reverse on the platform side. The recorded stream is replayed verbatim —
/// the platform's late application of the terminal's `setEditingState` reset
/// is already baked into each delta's `oldText`, and the reset echo is armed
/// synchronously on send, so no platform round-trip needs to be modelled.
///
/// The `wayland_ibus` fixture is the same sentence over the direct ibus
/// D-Bus path (`GTK_IM_MODULE=ibus`), which was clean on the same machine.
/// It pins the replay rig's fidelity and guards the healthy path.
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

final class _ReplayCase {
  _ReplayCase({
    required this.name,
    required this.typed,
    required this.expectedPty,
    required this.deltas,
    this.recordedBuggyPty,
  });

  final String name;
  final String typed;
  final String expectedPty;
  final String? recordedBuggyPty;
  final List<TextEditingDelta> deltas;
}

List<_ReplayCase> _loadCases(String fixture) {
  final relative = 'test/fixtures/ime/$fixture.json';
  final file = File(
    Directory.current.path.endsWith('termworld')
        ? relative
        : 'packages/termworld/$relative',
  );
  final document = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return (document['cases']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .map(
        (raw) => _ReplayCase(
          name: raw['name']! as String,
          typed: raw['typed']! as String,
          expectedPty: raw['expectedPty']! as String,
          recordedBuggyPty: raw['recordedBuggyPty'] as String?,
          deltas: (raw['deltas']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .map(TextEditingDelta.fromJSON)
              .toList(),
        ),
      )
      .toList();
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

TextEditingDeltaNonTextUpdate _close(String oldText) =>
    TextEditingDeltaNonTextUpdate(
      oldText: oldText,
      selection: TextSelection.collapsed(offset: oldText.length),
      composing: TextRange.empty,
    );

void main() {
  final fixtures = <String, String>{
    'wayland_text_input_v3_hangul_cases':
        'GNOME text-input-v3 reordered-commit capture',
    'wayland_ibus_hangul_cases': 'direct ibus control capture',
  };

  for (final MapEntry(key: fixture, value: label) in fixtures.entries) {
    for (final replay in _loadCases(fixture)) {
      testWidgets('$label: ${replay.name} reaches the pty in typed order', (
        tester,
      ) async {
        final terminal = Terminal();
        addTearDown(terminal.dispose);
        final output = <String>[];
        terminal.onData.listen(output.add);
        await _pumpTerminal(tester, terminal);
        final send = _imeDeltas(tester);

        // One delta per call, matching the recorded wire traffic.
        for (final delta in replay.deltas) {
          send(<TextEditingDelta>[delta]);
          await tester.pump();
        }

        expect(
          output.join(),
          replay.expectedPty,
          reason: replay.recordedBuggyPty == null
              ? 'the healthy ibus path replay must stay clean'
              : 'field capture of typing ${replay.typed}; before the '
                    'arrival-order commit fix this replay emitted '
                    '${replay.recordedBuggyPty}',
        );
        expect(
          find.byKey(const ValueKey<String>('termworld-preedit')),
          findsNothing,
          reason: 'every capture ends with the composition fully closed',
        );
      });
    }
  }

  // Synthetic sequences for the reordered-commit shapes the field captures
  // never hit: retraction of forwarded text, the degrade guards, a commit
  // and preedit sharing one batch, and the fresh-preedit-over-stale-buffer
  // variant of the post-close race.
  testWidgets('retracts a forwarded commit the platform deletes', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    const preedit = TextRange(start: 0, end: 1);
    send(<TextEditingDelta>[_insert('', '가', 0, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[_insert('가', '나', 1, composing: preedit)]);
    await tester.pump();
    expect(
      output.join(),
      '나',
      reason: 'the out-of-band commit is forwarded on arrival',
    );

    send(<TextEditingDelta>[
      _delete('가나', const TextRange(start: 1, end: 2), composing: preedit),
    ]);
    await tester.pump();
    send(<TextEditingDelta>[_close('가')]);
    await tester.pump();
    expect(
      output.join(),
      '나\u007f가',
      reason:
          'deleting forwarded text emits one DEL per cluster, and the '
          'surviving preedit still settles normally',
    );
  });

  testWidgets('ignores platform edits right of the forwarded commit', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    const preedit = TextRange(start: 0, end: 1);
    send(<TextEditingDelta>[_insert('', '가', 0, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[_insert('가', '나', 1, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[
      _delete('가나다', const TextRange(start: 2, end: 3), composing: preedit),
    ]);
    await tester.pump();
    send(<TextEditingDelta>[_close('가나')]);
    await tester.pump();
    expect(
      output.join(),
      '나가',
      reason:
          'an edit entirely right of the forwarded region neither moves it '
          'nor retracts it',
    );
  });

  testWidgets('degrades to a plain flush when the buffer desyncs', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    const preedit = TextRange(start: 0, end: 1);
    send(<TextEditingDelta>[_insert('', '가', 0, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[_insert('가', '나', 1, composing: preedit)]);
    await tester.pump();
    // A delta whose oldText disagrees with the tracked region: last-write-
    // wins rewrites the platform buffer underneath the region.
    send(<TextEditingDelta>[
      _replace(
        '다다',
        const TextRange(start: 0, end: 1),
        'ㅎ',
        composing: preedit,
      ),
    ]);
    await tester.pump();
    send(<TextEditingDelta>[_close('ㅎ다')]);
    await tester.pump();
    expect(
      output.join(),
      '나ㅎ다',
      reason:
          'a desynced region is forgotten and the close falls back to the '
          'plain buffer flush instead of corrupting state',
    );
  });

  testWidgets('degrades when a commit lands disjoint from the region', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    const preedit = TextRange(start: 0, end: 1);
    send(<TextEditingDelta>[_insert('', '가', 0, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[_insert('가', '나', 1, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[_insert('가나다다', '라', 4, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[_close('가나다다라')]);
    await tester.pump();
    expect(
      output.join(),
      '나가나다다라',
      reason:
          'a commit no input method can produce clears the region and the '
          'close falls back to the plain buffer flush',
    );
  });

  testWidgets('keeps a batched commit and preedit in arrival order', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    const preedit = TextRange(start: 0, end: 1);
    send(<TextEditingDelta>[_insert('', '가', 0, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[
      _insert('가', '나', 1, composing: preedit),
      _replace(
        '가나',
        const TextRange(start: 0, end: 1),
        '하',
        composing: preedit,
      ),
    ]);
    await tester.pump();
    send(<TextEditingDelta>[_close('하나')]);
    await tester.pump();
    expect(
      output.join(),
      '나하',
      reason:
          'one batch carrying a reordered commit and the next preedit still '
          'forwards the commit first and settles the preedit at close',
    );
  });

  testWidgets('hides the stale buffer under a fresh preedit after a reset', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    await _pumpTerminal(tester, terminal);
    final send = _imeDeltas(tester);

    const preedit = TextRange(start: 0, end: 1);
    // A settled syllable arms the post-commit reset echo.
    send(<TextEditingDelta>[_insert('', '가', 0, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[_close('가')]);
    await tester.pump();
    expect(output.join(), '가', reason: 'the first syllable settles');

    // The next preedit opens in front of the stale, not-yet-reset buffer.
    send(<TextEditingDelta>[_insert('가', 'ㄴ', 0, composing: preedit)]);
    await tester.pump();
    send(<TextEditingDelta>[
      _replace(
        'ㄴ가',
        const TextRange(start: 0, end: 1),
        '나',
        composing: preedit,
      ),
    ]);
    await tester.pump();
    send(<TextEditingDelta>[_close('나가')]);
    await tester.pump();
    expect(
      output.join(),
      '가나',
      reason:
          'the stale tail is already on the terminal and must not flush '
          'again when the new preedit settles',
    );
  });
}
