import 'dart:convert';
import 'dart:io';

const _commands = <String>{
  'CUU',
  'CUD',
  'CUF',
  'CUB',
  'CNL',
  'CPL',
  'CHA',
  'CUP',
  'HPA',
  'HPR',
  'VPA',
  'VPR',
  'HVP',
};

void main() {
  final package = Directory.current.path.endsWith('packages/termworld')
      ? Directory.current
      : Directory('packages/termworld');
  final reference = jsonDecode(
    File(
      '${package.path}/tool/xterm_reference.json',
    ).readAsStringSync(),
  ) as Map<String, Object?>;
  final mappingsFile = File('${package.path}/tool/xterm_parity_mappings.json');
  final mappings =
      jsonDecode(mappingsFile.readAsStringSync()) as Map<String, Object?>;
  final mappedTests = mappings['tests']! as Map<String, Object?>;
  final cases =
      (reference['tests']! as List<Object?>).cast<Map<String, Object?>>().where(
        (entry) {
          if (entry['file'] != 'test/playwright/InputHandler.test.ts') {
            return false;
          }
          final name = entry['name']! as String;
          return _commands.any((command) => name.contains(' - $command:'));
        },
      ).toList()..sort(
        (left, right) =>
            (left['id']! as String).compareTo(right['id']! as String),
      );

  final source = StringBuffer('''
import 'package:flutter_test/flutter_test.dart';

import 'support/input_handler_cursor_playwright_cases.dart';

void main() {
''');
  for (final entry in cases) {
    final name = entry['name']! as String;
    source.writeln('  test(');
    if (name.length > 73) {
      source
        ..writeln(
          '    // Exact pinned identity must remain one literal for parity.',
        )
        ..writeln('    // ignore: lines_longer_than_80_chars');
    }
    source
      ..writeln('    ${_dartString(name)},')
      ..writeln('    () => verifyInputHandlerCursorPlaywrightCase(');
    final chunks = _chunks(name).toList();
    for (var index = 0; index < chunks.length; index++) {
      final separator = index == chunks.length - 1 ? ',' : '';
      source.writeln('      ${_dartString(chunks[index])}$separator');
    }
    source
      ..writeln('    ),')
      ..writeln('  );');
  }
  source.writeln('}');
  File(
    '${package.path}/test/upstream_input_handler_cursor_playwright_parity_test.dart',
  ).writeAsStringSync(source.toString());

  final additions = StringBuffer();
  for (final entry in cases) {
    final id = entry['id']! as String;
    if (mappedTests.containsKey(id)) continue;
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write(
        '"dartTestFile":'
        '"test/upstream_input_handler_cursor_playwright_parity_test.dart",',
      )
      ..write(
        '"dartTestName":${jsonEncode(entry['name'])},'
        '"dartTestKind":"test"},\n',
      );
  }
  if (additions.isEmpty) return;
  const marker = '  "tests": {\n';
  final original = mappingsFile.readAsStringSync();
  if (!original.contains(marker)) {
    throw StateError('tests mapping marker is missing');
  }
  mappingsFile.writeAsStringSync(
    original.replaceFirst(marker, '$marker$additions'),
  );
}

String _dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

Iterable<String> _chunks(String value) sync* {
  const width = 52;
  var remaining = value;
  while (remaining.length > width) {
    final boundary = remaining.lastIndexOf(' ', width);
    final end = boundary <= 0 ? width : boundary + 1;
    yield remaining.substring(0, end);
    remaining = remaining.substring(end);
  }
  yield remaining;
}
