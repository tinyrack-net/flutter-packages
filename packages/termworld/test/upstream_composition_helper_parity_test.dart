import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

void main() {
  testWidgets('xterm CompositionHelper 00', (tester) async {
    expect(
      await _enter(tester, <TextEditingValue>[
        _composing('ㅇ'),
        _composing('아'),
        _composing('앙'),
        _committed('앙'),
        _composing('앙ㅇ', start: 1),
        _composing('앙아', start: 1),
        _composing('앙앙', start: 1),
        _committed('앙앙'),
      ]),
      '앙앙',
    );
  });

  testWidgets('xterm CompositionHelper 01', (tester) async {
    expect(
      await _enter(tester, <TextEditingValue>[
        _composing('ㅇ'),
        _composing('아'),
        _composing('앙'),
        _composing('아아', start: 1),
        _committed('아아'),
      ]),
      '아아',
    );
  });

  testWidgets('xterm CompositionHelper 02', (tester) async {
    expect(
      await _enter(tester, <TextEditingValue>[
        const TextEditingValue(
          text: '一一二',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
        _committed('一一1二', selection: 3),
      ]),
      '一1',
    );
  });

  testWidgets('xterm CompositionHelper 03', (tester) async {
    expect(
      await _enter(tester, <TextEditingValue>[
        _composing('い'),
        _composing('いm'),
        _composing('いま'),
        _composing('今'),
        _committed('今'),
      ]),
      '今',
    );
  });

  testWidgets('xterm CompositionHelper 04', (tester) async {
    expect(
      await _enter(tester, <TextEditingValue>[
        _composing('d'),
        _composing('だ'),
        _composing('だー'),
        _composing('ダー'),
        _committed('ダー'),
      ]),
      'ダー',
    );
  });

  testWidgets('xterm CompositionHelper 05', (tester) async {
    expect(
      await _enter(tester, <TextEditingValue>[
        _composing('d'),
        _composing('だ'),
        _composing('だあ'),
        _committed('だあ'),
      ]),
      'だあ',
    );
  });

  testWidgets('xterm CompositionHelper 06', (tester) async {
    expect(
      await _enter(tester, <TextEditingValue>[
        _composing('ㅇ'),
        _committed('ㅇ1'),
      ]),
      'ㅇ1',
    );
  });

  testWidgets('xterm CompositionHelper 07', (tester) async {
    expect(
      await _enter(tester, <TextEditingValue>[
        _composing('ㅇ'),
        _committed('ㅇ'),
        _composing('ㅇㅇ', start: 1),
        _committed('ㅇㅇ'),
      ]),
      'ㅇㅇ',
    );
  });
}

Future<String> _enter(
  WidgetTester tester,
  List<TextEditingValue> values,
) async {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  final output = StringBuffer();
  terminal.onData.listen(output.write);
  await tester.pumpWidget(
    MaterialApp(home: TerminalView(terminal: terminal, autofocus: true)),
  );
  await tester.pump();
  for (final value in values) {
    tester.testTextInput.updateEditingValue(value);
    await tester.pump();
  }
  return output.toString();
}

TextEditingValue _composing(String text, {int start = 0}) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
  composing: TextRange(start: start, end: text.length),
);

TextEditingValue _committed(String text, {int? selection}) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: selection ?? text.length),
);
