import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/termworld.dart';

final class _FixtureCase {
  const _FixtureCase({
    required this.name,
    required this.family,
    required this.steps,
    required this.expectedPty,
    required this.expectedReconnections,
  });

  factory _FixtureCase.fromJson(Map<String, Object?> json) => _FixtureCase(
    name: json['name']! as String,
    family: json['family']! as String,
    steps: (json['steps']! as List<Object?>)
        .cast<Map<Object?, Object?>>()
        .map((step) => step.cast<String, Object?>())
        .toList(growable: false),
    expectedPty: json['expectedPty']! as String,
    expectedReconnections: (json['expectedReconnections'] as int?) ?? 0,
  );

  final String name;
  final String family;
  final List<Map<String, Object?>> steps;
  final String expectedPty;
  final int expectedReconnections;
}

List<_FixtureCase> _loadFixtureCases() {
  const relative = 'example/assets/ime/android_input_connection_cases.json';
  final candidates = <File>[
    File('packages/termworld/$relative'),
    File(relative),
  ];
  final file = candidates.firstWhere(
    (candidate) => candidate.existsSync(),
    orElse: () => throw StateError(
      'Android InputConnection fixture was not found from '
      '${Directory.current.path}',
    ),
  );
  final root = jsonDecode(file.readAsStringSync())! as Map<String, Object?>;
  if (root['version'] != 1 || root['guard'] != '  ') {
    throw const FormatException('Unsupported Android IME fixture contract');
  }
  return (root['cases']! as List<Object?>)
      .cast<Map<Object?, Object?>>()
      .map((json) => _FixtureCase.fromJson(json.cast<String, Object?>()))
      .toList(growable: false);
}

/// A closed-loop port of the editing parts of Android's
/// `InputConnectionAdaptor` and `ListenableEditingState`.
///
/// It accepts the same transaction fixture as the native Android driver. The
/// framework's `TextInput.setEditingState` calls update this fake's editable,
/// and every InputConnection mutation returns delta-model updates to the real
/// [DeltaTextInputClient] owned by [TerminalView]. This catches reset races and
/// empty-buffer deletion gaps that direct `updateEditingValue` tests bypass.
final class _AndroidInputConnectionFake {
  _AndroidInputConnectionFake(this.tester, this.focusNode) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      _handleFrameworkCall,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      );
    });
  }

  final WidgetTester tester;
  final FocusNode focusNode;
  late DeltaTextInputClient _client;
  TextEditingValue _value = TextEditingValue.empty;
  final List<TextEditingDelta> _batch = <TextEditingDelta>[];
  var _batchDepth = 0;
  int setEditingStateCalls = 0;
  int connectionCount = 0;
  bool _ignoreNextSetEditingState = false;
  bool _deferSetEditingState = false;
  TextEditingValue? _deferredEditingState;

  Future<Object?> _handleFrameworkCall(MethodCall call) async {
    if (call.method == 'TextInput.setClient') connectionCount++;
    if (call.method == 'TextInput.setEditingState') {
      setEditingStateCalls++;
      if (_ignoreNextSetEditingState) {
        _ignoreNextSetEditingState = false;
        return null;
      }
      final value = TextEditingValue.fromJSON(
        Map<String, Object?>.from(call.arguments! as Map<Object?, Object?>),
      );
      if (_deferSetEditingState) {
        _deferredEditingState = value;
      } else {
        _value = value;
      }
    }
    return null;
  }

  void attachClient() {
    _client = tester.allStates.whereType<DeltaTextInputClient>().single;
  }

  void ignoreNextSetEditingState() {
    _ignoreNextSetEditingState = true;
  }

  Future<void> run(Map<String, Object?> step) async {
    switch (step['op']! as String) {
      case 'resetConnection':
        attachClient();
      case 'beginBatchEdit':
        _batchDepth++;
      case 'endBatchEdit':
        _batchDepth--;
        if (_batchDepth == 0) _flushBatch();
      case 'setComposingText':
        _replaceSelectionOrComposition(
          step['text']! as String,
          step['newCursorPosition']! as int,
          composing: true,
        );
      case 'commitText':
        _replaceSelectionOrComposition(
          step['text']! as String,
          step['newCursorPosition']! as int,
          composing: false,
        );
      case 'finishComposingText':
        _finishComposing();
      case 'deleteSurroundingText':
        _deleteSurrounding(
          step['beforeLength']! as int,
          step['afterLength']! as int,
          codePoints: false,
        );
      case 'deleteSurroundingTextInCodePoints':
        _deleteSurrounding(
          step['beforeLength']! as int,
          step['afterLength']! as int,
          codePoints: true,
        );
      case 'sendKeyEvent':
      case 'dispatchKeyEvent':
        await _sendKeyEvent(step);
      case 'performEditorAction':
        _client.performAction(_action(step['actionId']! as int));
      case 'repeat':
        final count = step['count']! as int;
        final command = Map<String, Object?>.from(
          step['command']! as Map<Object?, Object?>,
        );
        _deferSetEditingState = true;
        try {
          for (var iteration = 0; iteration < count; iteration++) {
            await run(command);
          }
        } finally {
          _deferSetEditingState = false;
          if (_deferredEditingState case final value?) {
            _value = value;
            _deferredEditingState = null;
          }
        }
      case 'closeConnection':
        _client.connectionClosed();
      case 'pumpFrame':
        await tester.pump(
          Duration(milliseconds: (step['milliseconds'] as int?) ?? 0),
        );
      case 'focus':
        if (step['value']! as bool) {
          focusNode.requestFocus();
        } else {
          focusNode.unfocus();
        }
        await tester.pump();
      case 'show':
      case 'hide':
        // Showing and hiding the IME does not mutate InputConnection state.
        break;
      default:
        throw UnsupportedError('Unknown fixture operation: ${step['op']}');
    }
  }

  TextInputAction _action(int actionId) => switch (actionId) {
    0 => TextInputAction.newline,
    1 => TextInputAction.none,
    2 => TextInputAction.go,
    3 => TextInputAction.search,
    4 => TextInputAction.send,
    5 => TextInputAction.next,
    6 => TextInputAction.done,
    7 => TextInputAction.previous,
    _ => throw UnsupportedError('Unknown Android editor action: $actionId'),
  };

  Future<void> _sendKeyEvent(Map<String, Object?> step) async {
    final key = switch (step['keyCode']! as int) {
      62 => LogicalKeyboardKey.space,
      66 => LogicalKeyboardKey.enter,
      67 => LogicalKeyboardKey.backspace,
      160 => LogicalKeyboardKey.numpadEnter,
      final keyCode => throw UnsupportedError(
        'Unknown Android key code: $keyCode',
      ),
    };
    if (step['action']! as int == 0) {
      await tester.sendKeyDownEvent(key);
    } else {
      await tester.sendKeyUpEvent(key);
    }
  }

  void _replaceSelectionOrComposition(
    String replacement,
    int newCursorPosition, {
    required bool composing,
  }) {
    final old = _value;
    final range = old.composing.isValid && !old.composing.isCollapsed
        ? old.composing
        : TextRange(
            start: old.selection.start < 0 ? 0 : old.selection.start,
            end: old.selection.end < 0 ? 0 : old.selection.end,
          );
    final text = old.text.replaceRange(range.start, range.end, replacement);
    final replacementEnd = range.start + replacement.length;
    final cursor = newCursorPosition > 0
        ? replacementEnd + newCursorPosition - 1
        : range.start + newCursorPosition;
    final next = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor.clamp(0, text.length)),
      composing: composing && replacement.isNotEmpty
          ? TextRange(start: range.start, end: replacementEnd)
          : TextRange.empty,
    );
    _value = next;
    final replacementDelta = TextEditingDeltaReplacement(
      oldText: old.text,
      replacementText: replacement,
      replacedRange: range,
      selection: next.selection,
      // BaseInputConnection mutates the Editable text before it applies the
      // new composing spans. The span state arrives as a second delta in the
      // same framework callback.
      composing: TextRange.empty,
    );
    _sendDeltas(<TextEditingDelta>[
      replacementDelta,
      if (composing)
        TextEditingDeltaNonTextUpdate(
          oldText: next.text,
          selection: next.selection,
          composing: next.composing,
        ),
    ]);
  }

  void _finishComposing() {
    final old = _value;
    _value = old.copyWith(composing: TextRange.empty);
    _sendDelta(
      TextEditingDeltaNonTextUpdate(
        oldText: old.text,
        selection: _value.selection,
        composing: TextRange.empty,
      ),
    );
  }

  void _deleteSurrounding(
    int beforeLength,
    int afterLength, {
    required bool codePoints,
  }) {
    final old = _value;
    var selectionStart = old.selection.start < 0 ? 0 : old.selection.start;
    var selectionEnd = old.selection.end < 0 ? 0 : old.selection.end;
    if (selectionEnd < selectionStart) {
      final temporary = selectionStart;
      selectionStart = selectionEnd;
      selectionEnd = temporary;
    }
    final composing = old.composing;
    if (composing.isValid && !composing.isCollapsed) {
      selectionStart = composing.start < selectionStart
          ? composing.start
          : selectionStart;
      selectionEnd = composing.end > selectionEnd
          ? composing.end
          : selectionEnd;
    }
    final start = codePoints
        ? _offsetByCodePoints(old.text, selectionStart, -beforeLength)
        : (selectionStart - beforeLength).clamp(0, old.text.length);
    final end = codePoints
        ? _offsetByCodePoints(old.text, selectionEnd, afterLength)
        : (selectionEnd + afterLength).clamp(0, old.text.length);
    final deltas = <TextEditingDelta>[];
    var next = old;
    final removedBefore = selectionStart - start;
    if (removedBefore > 0) {
      next = _deleteRange(next, start, selectionStart);
      deltas.add(
        TextEditingDeltaDeletion(
          oldText: old.text,
          deletedRange: TextRange(start: start, end: selectionStart),
          selection: next.selection,
          composing: next.composing,
        ),
      );
    }
    final adjustedAfterStart = selectionEnd - removedBefore;
    final adjustedAfterEnd = end - removedBefore;
    if (adjustedAfterEnd > adjustedAfterStart) {
      final beforeAfterDeletion = next;
      next = _deleteRange(next, adjustedAfterStart, adjustedAfterEnd);
      deltas.add(
        TextEditingDeltaDeletion(
          oldText: beforeAfterDeletion.text,
          deletedRange: TextRange(
            start: adjustedAfterStart,
            end: adjustedAfterEnd,
          ),
          selection: next.selection,
          composing: next.composing,
        ),
      );
    }
    if (deltas.isEmpty) return;
    _value = next;
    _sendDeltas(deltas);
  }

  TextEditingValue _deleteRange(TextEditingValue value, int start, int end) {
    final removed = end - start;
    int adjusted(int position) {
      if (position < 0 || position <= start) return position;
      if (position >= end) return position - removed;
      return start;
    }

    return TextEditingValue(
      text: value.text.replaceRange(start, end, ''),
      selection: TextSelection(
        baseOffset: adjusted(value.selection.baseOffset),
        extentOffset: adjusted(value.selection.extentOffset),
        affinity: value.selection.affinity,
        isDirectional: value.selection.isDirectional,
      ),
      composing: _adjustRangeAfterDeletion(value.composing, start, end),
    );
  }

  int _offsetByCodePoints(String text, int offset, int delta) {
    var result = offset;
    if (delta < 0) {
      for (var count = 0; count < -delta && result > 0; count++) {
        result--;
        if (result > 0 && _isLowSurrogate(text.codeUnitAt(result))) result--;
      }
    } else {
      for (var count = 0; count < delta && result < text.length; count++) {
        if (_isHighSurrogate(text.codeUnitAt(result)) &&
            result + 1 < text.length) {
          result++;
        }
        result++;
      }
    }
    return result;
  }

  bool _isHighSurrogate(int unit) => unit >= 0xd800 && unit <= 0xdbff;
  bool _isLowSurrogate(int unit) => unit >= 0xdc00 && unit <= 0xdfff;

  TextRange _adjustRangeAfterDeletion(TextRange range, int start, int end) {
    if (!range.isValid || range.isCollapsed) return TextRange.empty;
    final removed = end - start;
    if (end <= range.start) {
      return TextRange(
        start: range.start - removed,
        end: range.end - removed,
      );
    }
    if (start >= range.end) return range;
    final adjustedStart = range.start.clamp(0, start);
    final adjustedEnd = (range.end - removed).clamp(adjustedStart, start);
    return adjustedStart == adjustedEnd
        ? TextRange.empty
        : TextRange(start: adjustedStart, end: adjustedEnd);
  }

  void _sendDelta(TextEditingDelta delta) =>
      _sendDeltas(<TextEditingDelta>[delta]);

  void _sendDeltas(List<TextEditingDelta> deltas) {
    if (_batchDepth > 0) {
      _batch.addAll(deltas);
      return;
    }
    _client.updateEditingValueWithDeltas(deltas);
  }

  void _flushBatch() {
    if (_batch.isEmpty) return;
    _client.updateEditingValueWithDeltas(List<TextEditingDelta>.of(_batch));
    _batch.clear();
  }
}

void main() {
  final cases = _loadFixtureCases();
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  for (final fixture in cases) {
    testWidgets(
      '${fixture.family}: ${fixture.name}',
      (tester) async {
        final terminal = Terminal();
        final focusNode = FocusNode(debugLabel: fixture.name);
        final output = <String>[];
        addTearDown(terminal.dispose);
        addTearDown(focusNode.dispose);
        terminal.onData.listen(output.add);
        final input = _AndroidInputConnectionFake(tester, focusNode);

        await tester.pumpWidget(
          MaterialApp(
            home: TerminalView(
              terminal: terminal,
              focusNode: focusNode,
              autofocus: true,
            ),
          ),
        );
        await tester.pump();
        input.attachClient();
        final initialConnections = input.connectionCount;

        for (final step in fixture.steps) {
          await input.run(step);
        }
        await tester.pump();

        expect(output.join(), fixture.expectedPty);
        expect(
          input.connectionCount - initialConnections,
          fixture.expectedReconnections,
        );
      },
      variant: android,
    );
  }

  testWidgets(
    'Android interleaved physical controls retain delayed companions',
    (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();
      final output = <String>[];
      addTearDown(terminal.dispose);
      addTearDown(focusNode.dispose);
      terminal.onData.listen(output.add);
      final input = _AndroidInputConnectionFake(tester, focusNode);
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: terminal,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();
      input.attachClient();

      await input.run(const <String, Object?>{
        'op': 'dispatchKeyEvent',
        'action': 0,
        'keyCode': 66,
      });
      await input.run(const <String, Object?>{
        'op': 'dispatchKeyEvent',
        'action': 1,
        'keyCode': 66,
      });
      await tester.pump(const Duration(milliseconds: 75));
      await input.run(const <String, Object?>{
        'op': 'dispatchKeyEvent',
        'action': 0,
        'keyCode': 67,
      });
      await input.run(const <String, Object?>{
        'op': 'dispatchKeyEvent',
        'action': 1,
        'keyCode': 67,
      });
      await tester.pump(const Duration(milliseconds: 75));
      await input.run(const <String, Object?>{
        'op': 'performEditorAction',
        'actionId': 6,
      });
      await input.run(const <String, Object?>{
        'op': 'deleteSurroundingText',
        'beforeLength': 1,
        'afterLength': 0,
      });

      expect(output.join(), '\r\u007f');
    },
    variant: android,
  );

  testWidgets(
    'Android preserves legacy modifiers on physical control keys',
    (tester) async {
      final terminal = Terminal();
      final output = <String>[];
      addTearDown(terminal.dispose);
      terminal.onData.listen(output.add);
      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(output.join(), '\u001b\u007f\u001b\r');
    },
    variant: android,
  );

  testWidgets(
    'Android preserves Kitty protocol physical control sequences',
    (tester) async {
      final terminal = Terminal(
        options: TerminalOptions(
          vtExtensions: const TerminalVtExtensions(kittyKeyboard: true),
        ),
      );
      final focusNode = FocusNode();
      final output = <String>[];
      addTearDown(terminal.dispose);
      addTearDown(focusNode.dispose);
      final input = _AndroidInputConnectionFake(tester, focusNode);
      await tester.runAsync(() => terminal.writeAndWait('\u001b[=1u'));
      terminal.onData.listen(output.add);
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: terminal,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();
      input.attachClient();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      input._client.performAction(TextInputAction.done);

      expect(output.join(), '\u001b[57443;3u\u001b[13;3u');
    },
    variant: android,
  );

  testWidgets(
    'Android preserves Win32 physical control sequences',
    (tester) async {
      final terminal = Terminal(
        options: TerminalOptions(
          vtExtensions: const TerminalVtExtensions(win32InputMode: true),
        ),
      );
      final focusNode = FocusNode();
      final output = <String>[];
      addTearDown(terminal.dispose);
      addTearDown(focusNode.dispose);
      final input = _AndroidInputConnectionFake(tester, focusNode);
      await tester.runAsync(() => terminal.writeAndWait('\u001b[?9001h'));
      terminal.onData.listen(output.add);
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: terminal,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();
      input.attachClient();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      input._client.performAction(TextInputAction.done);

      expect(
        output.join(),
        '\u001b[13;0;13;1;0;1_\u001b[13;0;13;0;0;1_',
      );
    },
    variant: android,
  );

  testWidgets(
    'Android exposes a guarded platform model without exposing guard text',
    (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();
      addTearDown(terminal.dispose);
      addTearDown(focusNode.dispose);
      final input = _AndroidInputConnectionFake(tester, focusNode);

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: terminal,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();

      expect(input._value.text, '  ');
      expect(input._value.selection, const TextSelection.collapsed(offset: 2));
      expect(
        find.byKey(const ValueKey<String>('termworld-preedit')),
        findsNothing,
      );

      input.attachClient();
      await input.run(const <String, Object?>{
        'op': 'setComposingText',
        'text': '한',
        'newCursorPosition': 1,
      });
      await tester.pump();

      expect(input._value.text, '  한');
      expect(input._value.selection, const TextSelection.collapsed(offset: 3));
      expect(input._value.composing, const TextRange(start: 2, end: 3));
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('termworld-preedit')),
            )
            .data,
        '한',
      );
    },
    variant: android,
  );

  testWidgets(
    'Android reopens a fresh guarded model when the terminal changes',
    (tester) async {
      final firstTerminal = Terminal();
      final secondTerminal = Terminal();
      final focusNode = FocusNode();
      final firstOutput = <String>[];
      final secondOutput = <String>[];
      addTearDown(firstTerminal.dispose);
      addTearDown(secondTerminal.dispose);
      addTearDown(focusNode.dispose);
      firstTerminal.onData.listen(firstOutput.add);
      secondTerminal.onData.listen(secondOutput.add);
      final input = _AndroidInputConnectionFake(tester, focusNode);

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: firstTerminal,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();
      input.attachClient();
      await input.run(const <String, Object?>{
        'op': 'commitText',
        'text': 'a',
        'newCursorPosition': 1,
      });
      expect(firstOutput.join(), 'a');
      final connectionsBeforeReplacement = input.connectionCount;

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: secondTerminal,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();
      input.attachClient();

      expect(input.connectionCount, connectionsBeforeReplacement + 1);
      expect(
        input._value,
        const TextEditingValue(
          text: '  ',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await input.run(const <String, Object?>{
        'op': 'commitText',
        'text': 'b',
        'newCursorPosition': 1,
      });

      expect(firstOutput.join(), 'a');
      expect(secondOutput.join(), 'b');
    },
    variant: android,
  );

  testWidgets(
    'Android does not reset the delta model after committed syllables',
    (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();
      addTearDown(terminal.dispose);
      addTearDown(focusNode.dispose);
      final input = _AndroidInputConnectionFake(tester, focusNode);
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: terminal,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();
      input.attachClient();
      final initialSetEditingStateCalls = input.setEditingStateCalls;

      await input.run(const <String, Object?>{
        'op': 'commitText',
        'text': '한',
        'newCursorPosition': 1,
      });
      await input.run(const <String, Object?>{
        'op': 'commitText',
        'text': '글',
        'newCursorPosition': 1,
      });
      await tester.pump();

      expect(input._value.text, '  한글');
      expect(input.setEditingStateCalls, initialSetEditingStateCalls);
    },
    variant: android,
  );

  testWidgets(
    'Android observes repeated deletion while a guard repair is delayed',
    (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();
      final output = <String>[];
      addTearDown(terminal.dispose);
      addTearDown(focusNode.dispose);
      terminal.onData.listen(output.add);
      final input = _AndroidInputConnectionFake(tester, focusNode);
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: terminal,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();
      input
        ..attachClient()
        ..ignoreNextSetEditingState();
      await input.run(const <String, Object?>{
        'op': 'deleteSurroundingText',
        'beforeLength': 1,
        'afterLength': 0,
      });
      expect(input._value.text, ' ');
      await input.run(const <String, Object?>{
        'op': 'deleteSurroundingText',
        'beforeLength': 1,
        'afterLength': 0,
      });

      expect(output.join(), '\u007f\u007f');
      expect(input._value.text, '  ');
    },
    variant: android,
  );

  testWidgets(
    'Android whole-value input preserves two leading user spaces',
    (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();
      final output = <String>[];
      addTearDown(terminal.dispose);
      addTearDown(focusNode.dispose);
      terminal.onData.listen(output.add);
      final input = _AndroidInputConnectionFake(tester, focusNode);
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(
            terminal: terminal,
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();
      input.attachClient();

      input._client.updateEditingValue(
        const TextEditingValue(
          text: '  a',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );

      expect(output.join(), '  a');
      expect(input._value.text, '  ');
    },
    variant: android,
  );
}
