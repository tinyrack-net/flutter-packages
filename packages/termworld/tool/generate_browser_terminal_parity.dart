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
          .where((entry) => entry['file'] == 'src/browser/Terminal.test.ts')
          .where((entry) {
            final existing = mappedTests[entry['id']];
            if (existing == null) return true;
            return (existing as Map<String, Object?>)['dartTestFile'] ==
                'test/upstream_browser_terminal_parity_test.dart';
          })
          .toList()
        ..sort(
          (left, right) => (left['id']! as String).compareTo(
            right['id']! as String,
          ),
        );

  final source = StringBuffer('''
import 'package:flutter_test/flutter_test.dart';

import 'support/browser_terminal_cases.dart';

void main() {
''');
  for (final entry in cases) {
    final id = entry['id']! as String;
    const prefix = 'unit:src/browser/Terminal.test.ts:';
    final name = id.substring(prefix.length);
    source.writeln('  test(');
    if (name.length > 73 && !name.contains('/')) {
      source
        ..writeln(
          '    // Exact pinned identity must remain one literal for parity.',
        )
        ..writeln('    // ignore: lines_longer_than_80_chars');
    }
    source
      ..writeln('    ${_dartString(name)},')
      ..writeln('    () => verifyBrowserTerminalCase(');
    for (final chunk in _chunks(name)) {
      source.writeln('      ${_dartString(chunk)}');
    }
    source
      ..writeln('    ),')
      ..writeln('  );');
  }
  source.writeln('}');
  File(
    '${package.path}/test/upstream_browser_terminal_parity_test.dart',
  ).writeAsStringSync(source.toString());

  final additions = StringBuffer();
  for (final entry in cases) {
    final id = entry['id']! as String;
    if (mappedTests.containsKey(id)) continue;
    const prefix = 'unit:src/browser/Terminal.test.ts:';
    final name = id.substring(prefix.length);
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write(
        '"dartTestFile":'
        '"test/upstream_browser_terminal_parity_test.dart",',
      )
      ..write(
        '"dartTestName":${jsonEncode(name)},"dartTestKind":"test"},\n',
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
  if (value.contains(r'\') && !value.contains("'") && !value.contains(r'$')) {
    return "r'$value'";
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
