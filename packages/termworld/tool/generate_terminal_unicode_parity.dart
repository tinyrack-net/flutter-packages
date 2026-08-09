import 'dart:convert';
import 'dart:io';

void main() {
  final package = Directory.current.path.endsWith('packages/termworld')
      ? Directory.current
      : Directory('packages/termworld');
  final referenceFile = File('${package.path}/tool/xterm_reference.json');
  final mappingsFile = File(
    '${package.path}/tool/xterm_parity_mappings.json',
  );
  final reference =
      jsonDecode(referenceFile.readAsStringSync()) as Map<String, Object?>;
  final mappings =
      jsonDecode(mappingsFile.readAsStringSync()) as Map<String, Object?>;
  final mappedTests = mappings['tests']! as Map<String, Object?>;
  final cases =
      (reference['tests']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .where(
            (entry) =>
                entry['file'] == 'src/browser/Terminal.test.ts' &&
                (entry['fullName']! as String).startsWith('Terminal unicode'),
          )
          .toList()
        ..sort(
          (left, right) => (left['fullName']! as String).compareTo(
            right['fullName']! as String,
          ),
        );

  final source = StringBuffer(_header);
  for (final entry in cases) {
    final fullName = entry['fullName']! as String;
    final name = fullName.substring('Terminal '.length);
    final surrogate = RegExp(
      r'0x(DC[0-9A-F]0)-0xDC[0-9A-F]F: (.*)$',
    ).firstMatch(name);
    if (surrogate != null) {
      final start = surrogate.group(1)!;
      final variant = switch (surrogate.group(2)!) {
        '2 characters per cell' => 'perCell',
        '2 characters at last cell' => 'lastCell',
        '2 characters per cell over line end with autowrap' => 'autowrap',
        '2 characters per cell over line end without autowrap' => 'noWrap',
        'splitted surrogates' => 'splitWrites',
        final value => throw StateError('Unknown surrogate variant: $value'),
      };
      source
        ..writeln('    test(')
        ..write(_longNameComment(name))
        ..writeln("      '$name',")
        ..writeln('      () => _verifySurrogates(')
        ..writeln('        0x$start,')
        ..writeln('        _SurrogateCase.$variant,')
        ..writeln('      ),')
        ..writeln('    );');
    } else {
      source
        ..writeln('    test(')
        ..write(_longNameComment(name))
        ..writeln("      '$name',")
        ..writeln('      ${_helperFor(name)},')
        ..writeln('    );');
    }
  }
  source.write(_footer);
  File(
    '${package.path}/test/upstream_terminal_unicode_parity_test.dart',
  ).writeAsStringSync(source.toString());

  final additions = StringBuffer();
  for (final entry in cases) {
    final id = entry['id']! as String;
    if (mappedTests.containsKey(id)) continue;
    final fullName = entry['fullName']! as String;
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write(
        '"dartTestFile":"test/upstream_terminal_unicode_parity_test.dart",',
      )
      ..write(
        '"dartTestName":${jsonEncode(fullName.substring('Terminal '.length))},'
        '"dartTestKind":"test"},\n',
      );
  }
  if (additions.isNotEmpty) {
    const marker = '  "tests": {\n';
    final original = mappingsFile.readAsStringSync();
    if (!original.contains(marker)) {
      throw StateError('tests mapping marker is missing');
    }
    mappingsFile.writeAsStringSync(
      original.replaceFirst(marker, '$marker$additions'),
    );
  }
}

String _longNameComment(String name) => name.length > 65
    ? '      // Exact pinned identity must remain one literal for parity.\n'
          '      // ignore: lines_longer_than_80_chars\n'
    : '';

String _helperFor(String name) => switch (name) {
  'unicode - combining characters café' => '_combiningCafe',
  'unicode - combining characters café - end of line' => '_combiningAtEnd',
  'unicode - combining characters multiple combined é' => '_multipleCombining',
  'unicode - combining characters multiple surrogate with combined' =>
    '_multipleSurrogateCombining',
  'unicode - fullwidth characters cursor movement even' =>
    '_fullwidthCursorEven',
  'unicode - fullwidth characters cursor movement odd' => '_fullwidthCursorOdd',
  'unicode - fullwidth characters line of ￥ even' => '_fullwidthLineEven',
  'unicode - fullwidth characters line of ￥ odd' => '_fullwidthLineOdd',
  'unicode - fullwidth characters line of ￥ with combining even' =>
    '_fullwidthCombiningEven',
  'unicode - fullwidth characters line of ￥ with combining odd' =>
    '_fullwidthCombiningOdd',
  'unicode - fullwidth characters line of surrogate fullwidth '
      'with combining even' =>
    '_surrogateFullwidthCombiningEven',
  'unicode - fullwidth characters line of surrogate fullwidth '
      'with combining odd' =>
    '_surrogateFullwidthCombiningOdd',
  _ => throw StateError('Unknown unicode case: $name'),
};

const _header = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('Terminal unicode pinned upstream corpus', () {
''';

const _footer = r'''
  });
}

enum _SurrogateCase { perCell, lastCell, autowrap, noWrap, splitWrites }

Future<void> _verifySurrogates(int lowStart, _SurrogateCase variant) async {
  final terminal = Terminal(options: TerminalOptions(rows: 40));
  try {
    final values = <String>[
      for (var low = lowStart; low <= lowStart + 0x0f; low++)
        String.fromCharCode(0x10000 + low - 0xdc00),
    ];
    switch (variant) {
      case _SurrogateCase.perCell:
        await terminal.writeAndWait(values.join('\r\n'));
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index, 0, values[index], 1);
          _expectCell(terminal, index, 1, '', 1);
        }
      case _SurrogateCase.lastCell:
        await terminal.writeAndWait([
          for (var index = 0; index < values.length; index++)
            '\x1b[${index + 1};${terminal.cols}H${values[index]}',
        ].join());
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index, terminal.cols - 1, values[index], 1);
          _expectCell(terminal, index + 1, 0, '', 1);
        }
      case _SurrogateCase.autowrap:
        await terminal.writeAndWait([
          for (var index = 0; index < values.length; index++)
            '\x1b[${index * 2 + 1};${terminal.cols}Ha${values[index]}',
        ].join());
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index * 2, terminal.cols - 1, 'a', 1);
          _expectCell(terminal, index * 2 + 1, 0, values[index], 1);
          _expectCell(terminal, index * 2 + 1, 1, '', 1);
        }
      case _SurrogateCase.noWrap:
        final writes = StringBuffer('\x1b[?7l');
        for (var index = 0; index < values.length; index++) {
          writes.write(
            _cursorWrite(index + 1, terminal.cols, 'a${values[index]}'),
          );
        }
        await terminal.writeAndWait(writes.toString());
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index, terminal.cols - 1, values[index], 1);
        }
      case _SurrogateCase.splitWrites:
        for (var index = 0; index < values.length; index++) {
          final units = values[index].codeUnits;
          await terminal.writeAndWait(String.fromCharCode(units[0]));
          await terminal.writeAndWait(String.fromCharCode(units[1]));
          if (index != values.length - 1) await terminal.writeAndWait('\r\n');
        }
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index, 0, values[index], 1);
          _expectCell(terminal, index, 1, '', 1);
        }
    }
  } finally {
    terminal.dispose();
  }
}

Future<void> _combiningCafe() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('cafe\u0301');
    _expectCell(terminal, 0, 3, 'e\u0301', 1);
  } finally {
    terminal.dispose();
  }
}

Future<void> _combiningAtEnd() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('\x1b[1;77Hcafe\u0301');
    _expectCell(terminal, 0, 79, 'e\u0301', 1);
    _expectCell(terminal, 0, 1, '', 1);
  } finally {
    terminal.dispose();
  }
}

Future<void> _multipleCombining() => _verifyRepeated('e\u0301', 1);

Future<void> _multipleSurrogateCombining() =>
    _verifyRepeated('${String.fromCharCode(0x10000)}\u0301', 1);

Future<void> _fullwidthCursorEven() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('￥');
    expect(terminal.buffer.active.cursorX, 2);
  } finally {
    terminal.dispose();
  }
}

Future<void> _fullwidthCursorOdd() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('\x1b[1;2H￥');
    expect(terminal.buffer.active.cursorX, 3);
  } finally {
    terminal.dispose();
  }
}

Future<void> _fullwidthLineEven() => _verifyWideLine('￥', odd: false);
Future<void> _fullwidthLineOdd() => _verifyWideLine('￥', odd: true);
Future<void> _fullwidthCombiningEven() =>
    _verifyWideLine('￥\u0301', odd: false);
Future<void> _fullwidthCombiningOdd() =>
    _verifyWideLine('￥\u0301', odd: true);
Future<void> _surrogateFullwidthCombiningEven() =>
    _verifyWideLine('${String.fromCharCode(0x20e6d)}\u0301', odd: false);
Future<void> _surrogateFullwidthCombiningOdd() =>
    _verifyWideLine('${String.fromCharCode(0x20e6d)}\u0301', odd: true);

Future<void> _verifyRepeated(String value, int width) async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait(List<String>.filled(99, value).join());
    for (var column = 0; column < terminal.cols; column++) {
      _expectCell(terminal, 0, column, value, width);
    }
    _expectCell(terminal, 1, 0, value, width);
  } finally {
    terminal.dispose();
  }
}

Future<void> _verifyWideLine(String value, {required bool odd}) async {
  final terminal = Terminal();
  try {
    if (odd) await terminal.writeAndWait('\x1b[1;2H');
    await terminal.writeAndWait(List<String>.filled(49, value).join());
    final first = odd ? 1 : 0;
    final last = odd ? terminal.cols - 1 : terminal.cols;
    for (var column = first; column < last; column++) {
      if ((column - first).isOdd) {
        _expectCell(terminal, 0, column, '', 0);
      } else {
        _expectCell(terminal, 0, column, value, 2);
      }
    }
    if (odd) _expectCell(terminal, 0, terminal.cols - 1, '', 1);
    _expectCell(terminal, 1, 0, value, 2);
  } finally {
    terminal.dispose();
  }
}

void _expectCell(
  Terminal terminal,
  int row,
  int column,
  String chars,
  int width,
) {
  final cell = terminal.buffer.active.getLine(row)!.getCell(column)!;
  expect(cell.chars, chars);
  expect(cell.width, width);
}

String _cursorWrite(int row, int column, String value) =>
    '\x1b[$row;${column}H$value';
''';
