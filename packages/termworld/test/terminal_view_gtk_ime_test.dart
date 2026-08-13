import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/termworld.dart';

/// A port of the GTK embedder's text-input pipeline.
///
/// The hand-written delta tests in `terminal_view_korean_ime_test.dart` assume
/// the embedder's editing model only ever accumulates. It does not: the
/// terminal answers committed input with `TextInput.setEditingState`, and on
/// Linux that runs `FlTextInputHandler`'s `set_editing_state`, which rewrites
/// `flutter::TextInputModel` underneath a composition that GTK still considers
/// live. Every delta after that point is computed against the rewritten model.
///
/// This fake mirrors `shell/platform/common/text_input_model.cc` and the
/// `im_preedit_start` / `im_preedit_changed` / `im_commit` / `im_preedit_end`
/// handlers in `shell/platform/linux/fl_text_input_handler.cc` so the terminal
/// sees exactly what a real ibus session sends it.
final class _GtkEmbedder {
  _GtkEmbedder(this._client);

  final DeltaTextInputClient _client;

  String _text = '';
  _Range _selection = const _Range(0);
  _Range _composingRange = const _Range(0);
  bool _composing = false;

  /// The editing state the framework has asked for but that has not been
  /// applied yet, standing in for the platform-thread hop.
  Map<String, Object?>? pendingFrameworkState;

  /// The embedder's editing model, which the terminal resets through
  /// `TextInput.setEditingState` once input has settled.
  String get text => _text;

  _Range get _textRange => _Range(0, _text.length);
  _Range get _editableRange => _composing ? _composingRange : _textRange;

  // --- flutter::TextInputModel ---------------------------------------------

  void _setText(String value) {
    _text = value;
    _selection = const _Range(0);
    _composingRange = const _Range(0);
    _composing = false;
  }

  void _setSelection(_Range range) {
    if (_composing && !range.collapsed) return;
    if (!_editableRange.contains(range)) return;
    _selection = range;
  }

  void _beginComposing() {
    _composing = true;
    _composingRange = _Range(_selection.start);
  }

  void _updateComposingText(String value) {
    // Preserve selection if we get a no-op update to the composing region.
    if (value.isEmpty && _composingRange.collapsed) return;
    final rangeToDelete = _composingRange.collapsed
        ? _selection
        : _composingRange;
    _text = _text.replaceRange(rangeToDelete.start, rangeToDelete.end, value);
    _composingRange = _Range(
      _composingRange.base,
      _composingRange.start + value.length,
    );
    _selection = _Range(value.length + _composingRange.start);
  }

  void _commitComposing() {
    // Preserve selection if no composing text was entered.
    if (_composingRange.collapsed) return;
    _composingRange = _Range(_composingRange.end);
    _selection = _composingRange;
  }

  void _endComposing() {
    _composing = false;
    _composingRange = const _Range(0);
  }

  void _addText(String value) {
    if (!_selection.collapsed) {
      _text = _text.replaceRange(_selection.start, _selection.end, '');
      _selection = _Range(_selection.start);
      if (_composing) _composingRange = _selection;
    }
    if (_composing) {
      // Delete the current composing text, set the cursor to composing start.
      _text = _text.replaceRange(
        _composingRange.start,
        _composingRange.end,
        '',
      );
      _selection = _Range(_composingRange.start);
      _composingRange = _Range(
        _composingRange.base,
        _composingRange.start + value.length,
      );
    }
    final position = _selection.position;
    _text = _text.replaceRange(position, position, value);
    _selection = _Range(position + value.length);
  }

  // --- FlTextInputHandler signal handlers -----------------------------------

  void preeditStart() => _beginComposing();

  void preeditChanged(String preedit) {
    final textBeforeChange = _text;
    final composingBeforeChange = _composingRange;
    var cursorOffset = preedit.length;
    if (_composing) {
      cursorOffset += _composingRange.start;
    } else {
      cursorOffset += _selection.start;
    }
    _updateComposingText(preedit);
    _setSelection(_Range(cursorOffset));
    _dispatch(textBeforeChange, composingBeforeChange, preedit);
  }

  void commit(String value) {
    final textBeforeChange = _text;
    final composingBeforeChange = _composingRange;
    final selectionBeforeChange = _selection;
    final wasComposing = _composing;
    _addText(value);
    if (_composing) _commitComposing();
    _dispatch(
      textBeforeChange,
      wasComposing ? composingBeforeChange : selectionBeforeChange,
      value,
    );
  }

  void preeditEnd() {
    _endComposing();
    _client.updateEditingValueWithDeltas(<TextEditingDelta>[
      TextEditingDeltaNonTextUpdate(
        oldText: _text,
        selection: _textSelection,
        composing: _textComposing,
      ),
    ]);
  }

  // --- Framework -> platform ------------------------------------------------

  /// Applies a `TextInput.setEditingState` the framework asked for, mirroring
  /// `fl_text_input_handler.cc`'s `set_editing_state`. Tests call this between
  /// key presses, the way a platform-thread hop defers the call past the
  /// signals of the key that triggered it.
  void applyFrameworkState() {
    final state = pendingFrameworkState;
    if (state == null) return;
    pendingFrameworkState = null;
    var selectionBase = state['selectionBase']! as int;
    var selectionExtent = state['selectionExtent']! as int;
    // Flutter uses -1/-1 for invalid; translate that to 0/0 for the model.
    if (selectionBase == -1 && selectionExtent == -1) {
      selectionBase = 0;
      selectionExtent = 0;
    }
    _setText(state['text']! as String);
    _setSelection(_Range(selectionBase, selectionExtent));
    if (state['composingBase'] == -1 && state['composingExtent'] == -1) {
      _endComposing();
    }
  }

  TextSelection get _textSelection => TextSelection(
    baseOffset: _selection.base,
    extentOffset: _selection.extent,
  );

  TextRange get _textComposing => _composingRange.collapsed
      ? TextRange.empty
      : TextRange(start: _composingRange.base, end: _composingRange.extent);

  void _dispatch(String oldText, _Range replaced, String value) {
    final TextEditingDelta delta;
    if (replaced.collapsed) {
      delta = TextEditingDeltaInsertion(
        oldText: oldText,
        textInserted: value,
        insertionOffset: replaced.start,
        selection: _textSelection,
        composing: _textComposing,
      );
    } else if (value.isEmpty) {
      delta = TextEditingDeltaDeletion(
        oldText: oldText,
        deletedRange: TextRange(start: replaced.start, end: replaced.end),
        selection: _textSelection,
        composing: _textComposing,
      );
    } else {
      delta = TextEditingDeltaReplacement(
        oldText: oldText,
        replacementText: value,
        replacedRange: TextRange(start: replaced.start, end: replaced.end),
        selection: _textSelection,
        composing: _textComposing,
      );
    }
    _client.updateEditingValueWithDeltas(<TextEditingDelta>[delta]);
  }
}

/// A `flutter::TextRange`: an ordered base/extent pair over UTF-16 offsets.
final class _Range {
  const _Range(this.base, [int? extent]) : extent = extent ?? base;

  final int base;
  final int extent;

  int get start => base < extent ? base : extent;
  int get end => base < extent ? extent : base;
  int get position => extent;
  bool get collapsed => base == extent;

  bool contains(_Range other) => other.start >= start && other.end <= end;
}

/// One ibus-hangul key press: the syllable it flushes, then the new preedit.
final class _HangulKey {
  const _HangulKey({required this.preedit, this.commits});

  final String? commits;
  final String preedit;
}

Future<_GtkEmbedder> _pumpTerminal(
  WidgetTester tester,
  Terminal terminal,
) async {
  await tester.pumpWidget(
    MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
  );
  await tester.pump();
  final embedder = _GtkEmbedder(
    tester.allStates.whereType<DeltaTextInputClient>().single,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.textInput,
    (call) async {
      if (call.method == 'TextInput.setEditingState') {
        embedder.pendingFrameworkState = Map<String, Object?>.from(
          call.arguments as Map<Object?, Object?>,
        );
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
  return embedder;
}

/// Types [keys] the way ibus-hangul drives GTK: the engine commits the settled
/// syllable and then repaints the preedit, and the framework's answering
/// `setEditingState` only reaches the platform between key presses.
Future<void> _typeHangul(
  WidgetTester tester,
  _GtkEmbedder embedder,
  List<_HangulKey> keys,
) async {
  var started = false;
  for (final key in keys) {
    embedder.applyFrameworkState();
    if (key.commits case final committed?) embedder.commit(committed);
    if (!started && key.preedit.isNotEmpty) {
      embedder.preeditStart();
      started = true;
    }
    embedder.preeditChanged(key.preedit);
    await tester.pump();
  }
}

void main() {
  testWidgets('writes a multi-syllable Hangul word in typed order', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    final embedder = await _pumpTerminal(tester, terminal);

    // 안녕하세요 on the 2-set keyboard. ㅅ and ㅇ first land as the final
    // consonant of the syllable in progress and are redistributed into the
    // next one, which is where the terminal's post-commit editing-state reset
    // lands in the middle of a live composition.
    await _typeHangul(tester, embedder, const <_HangulKey>[
      _HangulKey(preedit: 'ㅇ'),
      _HangulKey(preedit: '아'),
      _HangulKey(preedit: '안'),
      _HangulKey(commits: '안', preedit: 'ㄴ'),
      _HangulKey(preedit: '녀'),
      _HangulKey(preedit: '녕'),
      _HangulKey(commits: '녕', preedit: 'ㅎ'),
      _HangulKey(preedit: '하'),
      _HangulKey(preedit: '핫'),
      _HangulKey(commits: '하', preedit: '세'),
      _HangulKey(preedit: '셍'),
      _HangulKey(commits: '세', preedit: '요'),
    ]);

    // A period is not a jamo: the engine flushes 요, drops the preedit and
    // lets GTK commit the punctuation itself.
    embedder
      ..applyFrameworkState()
      ..commit('요')
      ..preeditChanged('')
      ..preeditEnd();
    await tester.pump();
    embedder
      ..applyFrameworkState()
      ..commit('.');
    await tester.pump();
    embedder
      ..applyFrameworkState()
      ..commit(' ');
    await tester.pump();

    expect(output.join(), '안녕하세요. ');
    embedder.applyFrameworkState();
    expect(
      embedder.text,
      isEmpty,
      reason:
          'once the preedit is really over the terminal clears the hidden '
          'buffer again, so it cannot grow for the life of the session',
    );
  });

  testWidgets('writes repeated bare jamo one keystroke at a time', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    final embedder = await _pumpTerminal(tester, terminal);

    // asdfasdf on the 2-set keyboard: ㄹ and ㅁ cluster into ㄻ, every other
    // jamo commits on its own as the next one starts composing.
    await _typeHangul(tester, embedder, const <_HangulKey>[
      _HangulKey(preedit: 'ㅁ'),
      _HangulKey(commits: 'ㅁ', preedit: 'ㄴ'),
      _HangulKey(commits: 'ㄴ', preedit: 'ㅇ'),
      _HangulKey(commits: 'ㅇ', preedit: 'ㄹ'),
      _HangulKey(preedit: 'ㄻ'),
      _HangulKey(commits: 'ㄻ', preedit: 'ㄴ'),
      _HangulKey(commits: 'ㄴ', preedit: 'ㅇ'),
      _HangulKey(commits: 'ㅇ', preedit: 'ㄹ'),
    ]);

    expect(
      output.join(),
      'ㅁㄴㅇㄻㄴㅇ',
      reason: 'the trailing ㄹ is still composing',
    );
  });

  testWidgets('writes a Space that the input method never echoes once', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    final embedder = await _pumpTerminal(tester, terminal);

    await _typeHangul(tester, embedder, const <_HangulKey>[
      _HangulKey(preedit: 'ㅎ'),
      _HangulKey(preedit: '하'),
      _HangulKey(preedit: '한'),
    ]);

    // Space settles the syllable and closes the preedit. IBus can then keep
    // the space to itself, so the physical key bridge writes it.
    embedder
      ..applyFrameworkState()
      ..commit('한')
      ..preeditChanged('')
      ..preeditEnd();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(output.join(), '한 ');
  });

  testWidgets('resets the hidden buffer for input that never composes', (
    tester,
  ) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final output = <String>[];
    terminal.onData.listen(output.add);
    final embedder = await _pumpTerminal(tester, terminal);

    for (final letter in <String>['l', 's', '\n']) {
      embedder.commit(letter);
      await tester.pump();
      embedder.applyFrameworkState();
      expect(
        embedder.text,
        isEmpty,
        reason: 'uncomposed input is safe to reset immediately',
      );
    }

    expect(output.join(), 'ls\n');
  });
}
