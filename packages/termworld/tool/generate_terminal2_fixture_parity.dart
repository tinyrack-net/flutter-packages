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
          .where((entry) => entry['file'] == 'src/browser/Terminal2.test.ts')
          .toList()
        ..sort(
          (left, right) => (left['name']! as String).compareTo(
            right['name']! as String,
          ),
        );

  final source = StringBuffer(_header);
  for (final entry in cases) {
    final name = entry['name']! as String;
    final fixture = name.substring(0, name.length - '.in'.length);
    source.writeln("    test('$name', () => _verifyFixture('$fixture')); ");
  }
  source.write(_footer);
  File(
    '${package.path}/test/upstream_terminal2_fixture_parity_test.dart',
  ).writeAsStringSync(source.toString());

  final additions = StringBuffer();
  for (final entry in cases) {
    final id = entry['id']! as String;
    if (mappedTests.containsKey(id)) continue;
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write(
        '"dartTestFile":"test/upstream_terminal2_fixture_parity_test.dart",',
      )
      ..write(
        '"dartTestName":${jsonEncode(entry['name'])},'
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

const _header = '''
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('Escape Sequence Files pinned upstream corpus', () {
''';

const _footer = r'''
  });
}

Future<void> _verifyFixture(String name) async {
  final root = Directory(
    Directory.current.path.endsWith('termworld')
        ? 'test/fixtures/xterm/escape_sequence_files'
        : 'packages/termworld/test/fixtures/xterm/escape_sequence_files',
  );
  final input = File('${root.path}/$name.in');
  final pinnedRoot = Directory.current.path.endsWith('termworld')
      ? 'test/fixtures/xterm_pinned_outputs'
      : 'packages/termworld/test/fixtures/xterm_pinned_outputs';
  final pinned = File('$pinnedRoot/$name.text');
  final expected = pinned.existsSync()
      ? pinned
      : File('${root.path}/$name.text');
  expect(input.existsSync(), isTrue, reason: '$name input fixture is missing');
  expect(
    expected.existsSync(),
    isTrue,
    reason: '$name expected fixture is missing',
  );

  final terminal = Terminal(
    options: TerminalOptions(rows: 25, scrollback: 0),
  );
  try {
    await terminal.writeAndWait(
      input.readAsStringSync().replaceAll('\n', '\r\n'),
    );
    final actual = StringBuffer();
    final start = terminal.buffer.active.baseY;
    for (var row = 0; row < 25; row++) {
      actual.writeln(
        terminal.buffer.active
            .getLine(start + row)!
            .translateToString(trimRight: true)
            .trimRight(),
      );
    }
    final expectedRightTrimmed = expected
        .readAsStringSync()
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n');
    expect(actual.toString(), expectedRightTrimmed);
  } finally {
    terminal.dispose();
  }
}
''';
