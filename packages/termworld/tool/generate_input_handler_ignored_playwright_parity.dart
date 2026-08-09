import 'dart:convert';
import 'dart:io';

const _target =
    'test/upstream_input_handler_ignored_playwright_parity_test.dart';

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
  final mappingsFile = File('${package.path}/tool/xterm_parity_mappings.json');
  final mappings =
      jsonDecode(mappingsFile.readAsStringSync()) as Map<String, Object?>;
  final mapped = mappings['tests']! as Map<String, Object?>;
  final cases =
      (reference['tests']! as List<Object?>).cast<Map<String, Object?>>().where(
          (entry) {
            if (entry['file'] != 'test/playwright/InputHandler.test.ts') {
              return false;
            }
            final mapping = mapped[entry['id']] as Map<String, Object?>?;
            return mapping == null || mapping['dartTestFile'] == _target;
          },
        ).toList()
        ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  final out = StringBuffer(
    "import 'package:flutter_test/flutter_test.dart';\n\nimport 'support/input_handler_ignored_playwright_cases.dart';\n\nvoid main() {\n",
  );
  for (final entry in cases) {
    final name = entry['name']! as String;
    out.writeln('  test(');
    if (name.length > 73) {
      out
        ..writeln('    // Exact pinned identity remains one literal.')
        ..writeln('    // ignore: lines_longer_than_80_chars');
    }
    out
      ..writeln('    ${_quote(name)},')
      ..writeln('    () => verifyInputHandlerIgnoredPlaywrightCase(');
    final chunks = _chunks(name).toList();
    for (var i = 0; i < chunks.length; i++) {
      final separator = i == chunks.length - 1 ? ',' : '';
      out.writeln('      ${_quote(chunks[i])}$separator');
    }
    out
      ..writeln('    ),')
      ..writeln('  );');
  }
  out.writeln('}');
  File('${package.path}/$_target').writeAsStringSync(out.toString());
  final additions = StringBuffer();
  for (final entry in cases) {
    final id = entry['id']! as String;
    if (mapped.containsKey(id)) continue;
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write('"dartTestFile":"$_target",')
      ..write(
        '"dartTestName":${jsonEncode(entry['name'])},"dartTestKind":"test"},\n',
      );
  }
  if (additions.isEmpty) return;
  const marker = '  "tests": {\n';
  final original = mappingsFile.readAsStringSync();
  if (!original.contains(marker)) {
    throw StateError('tests mapping marker missing');
  }
  mappingsFile.writeAsStringSync(
    original.replaceFirst(marker, '$marker$additions'),
  );
}

String _quote(String value) {
  if (value.contains(r'$') && !value.contains("'")) {
    return "r'$value'";
  }
  if (value.contains("'") && !value.contains('"')) {
    return '"$value"';
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
