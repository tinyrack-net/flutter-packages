import 'dart:convert';
import 'dart:io';

void main() {
  final package = Directory.current.path.endsWith('packages/termworld')
      ? Directory.current
      : Directory('packages/termworld');
  final reference =
      jsonDecode(
            File(
              '${package.path}/tool/xterm_reference.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final mappingsFile = File(
    '${package.path}/tool/xterm_parity_mappings.json',
  );
  final mappings =
      jsonDecode(mappingsFile.readAsStringSync()) as Map<String, Object?>;
  final mappedTests = mappings['tests']! as Map<String, Object?>;
  final cases =
      (reference['tests']! as List<Object?>).cast<Map<String, Object?>>().where(
        (entry) {
          if (entry['file'] != 'test/playwright/InputHandler.test.ts') {
            return false;
          }
          final fullName = entry['fullName']! as String;
          return fullName.contains('DECSET: Private Mode Set') ||
              fullName.contains('DECRST: DEC Private Mode Reset');
        },
      ).toList()..sort(
        (left, right) => (left['id']! as String).compareTo(
          right['id']! as String,
        ),
      );

  final source = StringBuffer('''
import 'package:flutter_test/flutter_test.dart';

import 'support/input_handler_dec_modes_playwright_cases.dart';

void main() {
''');
  for (final entry in cases) {
    final name = entry['name']! as String;
    final enabled = (entry['fullName']! as String).contains(
      'DECSET: Private Mode Set',
    );
    source.writeln('  test(');
    final ignores = <String>[];
    if (name.length > 73 && !name.contains('/')) {
      source.writeln(
        '    // Exact pinned identity must remain one literal for parity.',
      );
      ignores.add('lines_longer_than_80_chars');
    }
    if (ignores.isNotEmpty) {
      source.writeln('    // ignore: ${ignores.join(', ')}');
    }
    source
      ..writeln('    ${_dartString(name)},')
      ..writeln('    () => verifyInputHandlerDecModePlaywrightCase(');
    final chunks = _chunks(name).toList();
    for (var index = 0; index < chunks.length; index++) {
      final separator = index == chunks.length - 1 ? ',' : '';
      source.writeln('      ${_dartString(chunks[index])}$separator');
    }
    source
      ..writeln('      enabled: $enabled,')
      ..writeln('    ),')
      ..writeln('  );');
  }
  source.writeln('}');
  File(
    '${package.path}/test/upstream_input_handler_dec_modes_playwright_parity_test.dart',
  ).writeAsStringSync(source.toString());

  final additions = StringBuffer();
  for (final entry in cases) {
    final id = entry['id']! as String;
    if (mappedTests.containsKey(id)) continue;
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write(
        '"dartTestFile":'
        '"test/upstream_input_handler_dec_modes_playwright_parity_test.dart",',
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
  if (value.contains("'") && !value.contains('"')) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll(r'$', r'\$');
    return '"$escaped"';
  }
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
