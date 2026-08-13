import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/termworld.dart';

/// A closed-loop fake of the Windows embedder's text input plugin.
///
/// The Win32 embedder differs from GTK in two ways that matter to the
/// terminal. First, its deltas are computed against an engine-side
/// `TextInputModel` that the framework's `TextInput.setEditingState` mutates
/// directly, so a reset the terminal sends after a commit lands *inside* the
/// engine's model rather than being echoed back as a delta. Second,
/// Microsoft's Korean IME closes the composition after every settled syllable
/// (`WM_IME_ENDCOMPOSITION`) and opens a fresh one on the next keystroke, so
/// during ordinary typing the terminal sees a commit-and-close for every
/// syllable while the IME is still mid-word.
///
/// A reset that lands between the close and the next keystroke's
/// `WM_IME_STARTCOMPOSITION` is fine — but one that lands after the next
/// composition has opened clears the model's composing state while the IME
/// keeps sending `GCS_COMPSTR` updates. `TextInputModel::UpdateComposingText`
/// then re-inserts the preedit over a stale selection, the model corrupts,
/// and every subsequent delta arrives without a composing range — which reads
/// as committed text and duplicates in-progress syllables into the PTY.
///
/// This fake ports `TextInputModel` and the `TextInputPlugin` compose hooks
/// (engine `shell/platform/windows`, framework rev 6b182d2c75) and applies
/// the terminal's `setEditingState` messages to the model with a configurable
/// keystroke lag, reproducing the real race deterministically.
final class _WindowsEmbedder {
  _WindowsEmbedder(
    WidgetTester tester, {
    required this.resetLagInKeystrokes,
  }) : _client = tester.allStates.whereType<DeltaTextInputClient>().single {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        if (call.method == 'TextInput.setEditingState') {
          setEditingStateCalls++;
          _pendingResets.add((
            resetLagInKeystrokes,
            Map<Object?, Object?>.from(call.arguments as Map<Object?, Object?>),
          ));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );
  }

  /// How many keystrokes after the terminal sends a reset it reaches the
  /// engine model. One keystroke models ordinary typing: the framework's
  /// reply always lands before the next key, but after the same keystroke's
  /// trailing `WM_IME_STARTCOMPOSITION`/`GCS_COMPSTR` messages.
  final int resetLagInKeystrokes;

  final DeltaTextInputClient _client;
  final List<(int, Map<Object?, Object?>)> _pendingResets =
      <(int, Map<Object?, Object?>)>[];

  int setEditingStateCalls = 0;

  // --- TextInputModel port (UTF-16 code unit semantics) ---
  String _text = '';
  int _selBase = 0;
  int _selExtent = 0;
  int _compStart = 0;
  int _compEnd = 0;
  bool _composing = false;

  int get _selStart => _selBase < _selExtent ? _selBase : _selExtent;
  int get _selLength => (_selExtent - _selBase).abs();

  void _applyReset(Map<Object?, Object?> args) {
    var base = args['selectionBase']! as int;
    var extent = args['selectionExtent']! as int;
    if (base == -1 && extent == -1) {
      base = extent = 0;
    }
    _text = args['text']! as String;
    _selBase = base;
    _selExtent = extent;
    final composingBase = args['composingBase']! as int;
    final composingExtent = args['composingExtent']! as int;
    if (composingBase == -1 && composingExtent == -1) {
      _endComposing();
    } else {
      _composing = true;
      _compStart = composingBase;
      _compEnd = composingExtent;
    }
  }

  void _deleteSelected() {
    if (_selBase == _selExtent) return;
    final start = _selStart;
    _text = _text.replaceRange(start, start + _selLength, '');
    _selBase = _selExtent = start;
    if (_composing) {
      _compStart = start;
      _compEnd = start;
    }
  }

  void _addText(String text) {
    _deleteSelected();
    if (_composing) {
      _text = _text.replaceRange(_compStart, _compEnd, '');
      _selBase = _selExtent = _compStart;
      _compEnd = _compStart + text.length;
    }
    final position = _selExtent;
    _text = _text.replaceRange(position, position, text);
    _selBase = _selExtent = position + text.length;
  }

  void _updateComposingText(String text, int cursorPos) {
    if (text.isEmpty && _compStart == _compEnd) return;
    final deleteStart = _compStart == _compEnd ? _selStart : _compStart;
    final deleteEnd = _compStart == _compEnd
        ? _selStart + _selLength
        : _compEnd;
    _text = _text.replaceRange(deleteStart, deleteEnd, text);
    _compEnd = _compStart + text.length;
    _selBase = _selExtent = cursorPos + _compStart;
  }

  void _commitComposing() {
    if (_compStart == _compEnd) return;
    _compStart = _compEnd;
    _selBase = _selExtent = _compEnd;
  }

  void _endComposing() {
    _composing = false;
    _compStart = 0;
    _compEnd = 0;
  }

  // --- TextInputPlugin compose hook port ---
  void _send({
    required String oldText,
    required String deltaText,
    required int deltaStart,
    required int deltaEnd,
  }) {
    _client.updateEditingValueWithDeltas(<TextEditingDelta>[
      TextEditingDelta.fromJSON(<String, Object?>{
        'oldText': oldText,
        'deltaText': deltaText,
        'deltaStart': deltaStart,
        'deltaEnd': deltaEnd,
        'selectionAffinity': 'TextAffinity.downstream',
        'selectionBase': _selBase,
        'selectionExtent': _selExtent,
        'selectionIsDirectional': false,
        'composingBase': _composing ? _compStart : -1,
        'composingExtent': _composing ? _compEnd : -1,
      }),
    ]);
  }

  void _composeBegin() {
    _composing = true;
    _compStart = _selStart;
    _compEnd = _selStart;
    _send(oldText: _text, deltaText: '', deltaStart: -1, deltaEnd: -1);
  }

  void _composeChange(String text) {
    final before = _text;
    final compStartBefore = _compStart;
    final compEndBefore = _compEnd;
    _addText(text);
    _updateComposingText(text, text.length);
    _send(
      oldText: before,
      deltaText: text,
      deltaStart: compStartBefore,
      deltaEnd: compEndBefore,
    );
  }

  void _composeEnd() {
    _commitComposing();
    _endComposing();
    _send(oldText: _text, deltaText: '', deltaStart: -1, deltaEnd: -1);
  }

  void _textHook(String text) {
    final before = _text;
    final start = _selStart;
    final end = start + _selLength;
    _addText(text);
    _send(
      oldText: before,
      deltaText: text,
      deltaStart: start,
      deltaEnd: end,
    );
  }

  /// Runs one keystroke's burst of window messages, then lets queued
  /// framework resets whose lag has expired reach the engine model — the
  /// same interleaving the Win32 message loop produces.
  void keystroke(List<ImmEvent> events) {
    for (final event in events) {
      switch (event) {
        case ImmBegin():
          _composeBegin();
        case ImmCompose(:final text):
          _composeChange(text);
        case ImmResult(:final text):
          // GCS_RESULTSTR: the engine runs ComposeChange + CommitComposing
          // and deliberately sends no separate state update for the commit.
          _composeChange(text);
          _commitComposing();
        case ImmEnd():
          _composeEnd();
        case ImmChar(:final text):
          _textHook(text);
      }
    }
    for (var i = 0; i < _pendingResets.length;) {
      final (lag, args) = _pendingResets[i];
      if (lag <= 1) {
        _pendingResets.removeAt(i);
        _applyReset(args);
      } else {
        _pendingResets[i] = (lag - 1, args);
        i++;
      }
    }
  }
}

sealed class ImmEvent {
  const ImmEvent();
}

/// `WM_IME_STARTCOMPOSITION`.
final class ImmBegin extends ImmEvent {
  const ImmBegin();
}

/// `WM_IME_COMPOSITION` with `GCS_COMPSTR`.
final class ImmCompose extends ImmEvent {
  const ImmCompose(this.text);
  final String text;
}

/// `WM_IME_COMPOSITION` with `GCS_RESULTSTR`.
final class ImmResult extends ImmEvent {
  const ImmResult(this.text);
  final String text;
}

/// `WM_IME_ENDCOMPOSITION`.
final class ImmEnd extends ImmEvent {
  const ImmEnd();
}

/// A committed character delivered through `WM_CHAR` (`TextHook`).
final class ImmChar extends ImmEvent {
  const ImmChar(this.text);
  final String text;
}

/// Microsoft Korean IME typing 안녕하세요. plus a space, one keystroke per
/// entry: every settled syllable commits and closes its composition, and the
/// next jamo opens a fresh one within the same keystroke. 핫→하세 and 셍→세요
/// are final-consonant redistributions.
const List<List<ImmEvent>> hangulPerSyllableKeystrokes = <List<ImmEvent>>[
  <ImmEvent>[ImmBegin(), ImmCompose('ㅇ')],
  <ImmEvent>[ImmCompose('아')],
  <ImmEvent>[ImmCompose('안')],
  <ImmEvent>[ImmResult('안'), ImmEnd(), ImmBegin(), ImmCompose('ㄴ')],
  <ImmEvent>[ImmCompose('녀')],
  <ImmEvent>[ImmCompose('녕')],
  <ImmEvent>[ImmResult('녕'), ImmEnd(), ImmBegin(), ImmCompose('ㅎ')],
  <ImmEvent>[ImmCompose('하')],
  <ImmEvent>[ImmCompose('핫')],
  <ImmEvent>[ImmResult('하'), ImmEnd(), ImmBegin(), ImmCompose('세')],
  <ImmEvent>[ImmCompose('셍')],
  <ImmEvent>[ImmResult('세'), ImmEnd(), ImmBegin(), ImmCompose('요')],
  <ImmEvent>[ImmResult('요'), ImmEnd(), ImmChar('.')],
  <ImmEvent>[ImmChar(' ')],
];

/// The same phrase from an IME that keeps one composition open and commits
/// with `GCS_RESULTSTR|GCS_COMPSTR` in a single `WM_IME_COMPOSITION`.
const List<List<ImmEvent>> hangulSingleSessionKeystrokes = <List<ImmEvent>>[
  <ImmEvent>[ImmBegin(), ImmCompose('ㅇ')],
  <ImmEvent>[ImmCompose('아')],
  <ImmEvent>[ImmCompose('안')],
  <ImmEvent>[ImmResult('안'), ImmCompose('ㄴ')],
  <ImmEvent>[ImmCompose('녀')],
  <ImmEvent>[ImmCompose('녕')],
  <ImmEvent>[ImmResult('녕'), ImmCompose('ㅎ')],
  <ImmEvent>[ImmCompose('하')],
  <ImmEvent>[ImmCompose('핫')],
  <ImmEvent>[ImmResult('하'), ImmCompose('세')],
  <ImmEvent>[ImmCompose('셍')],
  <ImmEvent>[ImmResult('세'), ImmCompose('요')],
  <ImmEvent>[ImmResult('요'), ImmEnd(), ImmChar('.')],
  <ImmEvent>[ImmChar(' ')],
];

Future<(Terminal, List<String>)> _pumpTerminal(WidgetTester tester) async {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  final output = <String>[];
  terminal.onData.listen(output.add);
  await tester.pumpWidget(
    MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
  );
  await tester.pump();
  return (terminal, output);
}

Future<void> _type(
  WidgetTester tester,
  _WindowsEmbedder embedder,
  List<List<ImmEvent>> keystrokes,
) async {
  for (final events in keystrokes) {
    embedder.keystroke(events);
    await tester.pump();
  }
  await tester.pump();
}

Future<void> _typeSettledHangul(
  WidgetTester tester,
  _WindowsEmbedder embedder,
  String text,
) async {
  for (final rune in text.runes) {
    final syllable = String.fromCharCode(rune);
    embedder.keystroke(<ImmEvent>[
      const ImmBegin(),
      ImmCompose(syllable),
      ImmResult(syllable),
      const ImmEnd(),
    ]);
    await tester.pump();
  }
}

void main() {
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  testWidgets(
    'per-syllable Hangul typing writes each syllable exactly once',
    (tester) async {
      final (_, output) = await _pumpTerminal(tester);
      final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 1);

      await _type(tester, embedder, hangulPerSyllableKeystrokes);

      expect(
        output.join(),
        '안녕하세요. ',
        reason:
            'a reset landing after the next syllable opened its composition '
            'must not duplicate in-progress syllables',
      );
    },
    variant: windows,
  );

  testWidgets(
    'fast per-syllable typing (reset lagging two keystrokes) stays clean',
    (tester) async {
      final (_, output) = await _pumpTerminal(tester);
      final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 2);

      await _type(tester, embedder, hangulPerSyllableKeystrokes);

      expect(output.join(), '안녕하세요. ');
    },
    variant: windows,
  );

  testWidgets('single-session commit-and-recompose stays clean', (
    tester,
  ) async {
    final (_, output) = await _pumpTerminal(tester);
    final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 1);

    await _type(tester, embedder, hangulSingleSessionKeystrokes);

    expect(output.join(), '안녕하세요. ');
  }, variant: windows);

  testWidgets('the preedit renders while a syllable is composing', (
    tester,
  ) async {
    final (_, _) = await _pumpTerminal(tester);
    final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 1)
      ..keystroke(const <ImmEvent>[ImmBegin(), ImmCompose('ㅇ')])
      ..keystroke(const <ImmEvent>[ImmCompose('아')]);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('termworld-preedit')),
      findsOneWidget,
    );

    embedder
      ..keystroke(const <ImmEvent>[ImmCompose('안')])
      ..keystroke(const <ImmEvent>[ImmResult('안'), ImmEnd()]);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('termworld-preedit')),
      findsNothing,
    );
  }, variant: windows);

  testWidgets('mixed Hangul and ASCII stay in typed order', (tester) async {
    final (_, output) = await _pumpTerminal(tester);
    final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 1);

    await _type(tester, embedder, const <List<ImmEvent>>[
      <ImmEvent>[ImmBegin(), ImmCompose('ㅎ')],
      <ImmEvent>[ImmCompose('하')],
      <ImmEvent>[ImmCompose('한')],
      <ImmEvent>[ImmResult('한'), ImmEnd()],
      <ImmEvent>[ImmChar('a')],
      <ImmEvent>[ImmBegin(), ImmCompose('ㄱ')],
      <ImmEvent>[ImmCompose('그')],
      <ImmEvent>[ImmCompose('글')],
      <ImmEvent>[ImmResult('글'), ImmEnd()],
    ]);

    expect(output.join(), '한a글');
  }, variant: windows);

  testWidgets('a cancelled composition writes nothing', (tester) async {
    final (_, output) = await _pumpTerminal(tester);
    final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 1);

    await _type(tester, embedder, const <List<ImmEvent>>[
      <ImmEvent>[ImmBegin(), ImmCompose('ㅁ')],
      // Escape: the IME clears the preedit and closes the composition.
      <ImmEvent>[ImmCompose(''), ImmEnd()],
    ]);

    expect(output.join(), isEmpty);
    expect(
      find.byKey(const ValueKey<String>('termworld-preedit')),
      findsNothing,
    );
  }, variant: windows);

  testWidgets('a space right after a Hangul commit is written once', (
    tester,
  ) async {
    final (_, output) = await _pumpTerminal(tester);
    final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 1);

    await _type(tester, embedder, const <List<ImmEvent>>[
      <ImmEvent>[ImmBegin(), ImmCompose('ㄱ')],
      <ImmEvent>[ImmCompose('그')],
      <ImmEvent>[ImmCompose('글')],
      <ImmEvent>[ImmResult('글'), ImmEnd()],
    ]);

    // The space key reaches the terminal twice on Windows: once through the
    // physical-key bridge and once as the IME's pass-through WM_CHAR.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    embedder.keystroke(const <ImmEvent>[ImmChar(' ')]);
    await tester.pump();

    expect(output.join(), '글 ');
  }, variant: windows);

  testWidgets(
    'a physical-only space survives the next Hangul composition',
    (tester) async {
      final (_, output) = await _pumpTerminal(tester);
      final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 1);

      await _type(
        tester,
        embedder,
        hangulPerSyllableKeystrokes.sublist(
          0,
          hangulPerSyllableKeystrokes.length - 1,
        ),
      );
      for (final word in <String>['저는', '박한솔', '입니다.']) {
        // Microsoft's Korean IME can settle the preceding composition on
        // Space while omitting the pass-through WM_CHAR/text delta. The
        // physical-key bridge is then the only source of the space.
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        await _typeSettledHangul(tester, embedder, word);
      }

      expect(
        output.join(),
        '안녕하세요. 저는 박한솔 입니다.',
        reason:
            'starting the next composition must not reinterpret a '
            'physical-only space as a deletion from the platform editing '
            'buffer',
      );
      expect(output.join(), isNot(contains('\u007f')));
    },
    variant: windows,
  );

  testWidgets('repeated physical-only spaces survive composition', (
    tester,
  ) async {
    final (_, output) = await _pumpTerminal(tester);
    final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await _typeSettledHangul(tester, embedder, '가');

    expect(output.join(), '  가');
    expect(output.join(), isNot(contains('\u007f')));
  }, variant: windows);

  testWidgets(
    'full-value updates on Windows keep the post-commit reset',
    (tester) async {
      final (_, output) = await _pumpTerminal(tester);
      TextInputClient client() =>
          tester.allStates.whereType<DeltaTextInputClient>().single;

      // An embedder that reports whole editing values keeps no cumulative
      // platform-side model: each committed value stands alone, exactly like
      // the conformance harness drives. The reset must survive here or the
      // next standalone value diffs against the previous commit and emits
      // spurious DELs.
      client().updateEditingValue(
        const TextEditingValue(
          text: '한글',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();

      client().updateEditingValue(
        const TextEditingValue(
          text: '가',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();

      expect(output.join(), '한글가');
    },
    variant: windows,
  );

  testWidgets(
    'the terminal does not reset the engine model between syllables',
    (tester) async {
      final (_, output) = await _pumpTerminal(tester);
      final embedder = _WindowsEmbedder(tester, resetLagInKeystrokes: 1);

      await _type(tester, embedder, hangulPerSyllableKeystrokes);

      expect(output.join(), '안녕하세요. ');
      expect(
        embedder.setEditingStateCalls,
        0,
        reason:
            'the Win32 embedder applies setEditingState destructively to its '
            'engine-side model; a reset racing a reopened composition '
            'corrupts it beyond recovery, so Windows must accumulate instead',
      );
    },
    variant: windows,
  );
}
