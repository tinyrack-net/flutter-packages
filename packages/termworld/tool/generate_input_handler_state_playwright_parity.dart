import 'dart:convert';
import 'dart:io';

bool _selected(Map<String, Object?> entry) {
  if (entry['file'] != 'test/playwright/InputHandler.test.ts') return false;
  final name = entry['name']! as String;
  return name.startsWith('should save the absolute') ||
      name.contains('Request ANSI mode') ||
      name.contains('Request DEC private mode') ||
      name.contains('SM: Set Mode') ||
      name.contains('RM: Reset Mode') ||
      name.contains('Soft terminal reset') ||
      name.contains('Set cursor style') ||
      name.contains('protection attribute') ||
      name.contains('Scrolling Region') ||
      name.startsWith('CSI s -') ||
      name.startsWith('CSI u -');
}

void main() {
  final p = Directory.current.path.endsWith('packages/termworld')
      ? Directory.current
      : Directory('packages/termworld');
  final reference =
      jsonDecode(File('${p.path}/tool/xterm_reference.json').readAsStringSync())
          as Map<String, Object?>;
  final mf = File('${p.path}/tool/xterm_parity_mappings.json');
  final mappings = jsonDecode(mf.readAsStringSync()) as Map<String, Object?>;
  final mapped = mappings['tests']! as Map<String, Object?>;
  final cases =
      (reference['tests']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .where(_selected)
          .toList()
        ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  final out = StringBuffer(
    "import 'package:flutter_test/flutter_test.dart';\n\nimport 'support/input_handler_state_playwright_cases.dart';\n\nvoid main() {\n",
  );
  for (final e in cases) {
    final n = e['name']! as String;
    out.writeln('  test(');
    if (n.length > 73) {
      out
        ..writeln('    // Exact pinned identity remains one literal.')
        ..writeln('    // ignore: lines_longer_than_80_chars');
    }
    out
      ..writeln('    ${_q(n)},')
      ..writeln('    () => verifyInputHandlerStatePlaywrightCase(');
    for (final chunk in _chunks(n)) {
      out.writeln('      ${_q(chunk)}');
    }
    out
      ..writeln('      ,')
      ..writeln('    ),')
      ..writeln('  );');
  }
  out.writeln('}');
  File(
    '${p.path}/test/upstream_input_handler_state_playwright_parity_test.dart',
  ).writeAsStringSync(out.toString());
  final add = StringBuffer();
  for (final e in cases) {
    final id = e['id']! as String;
    if (mapped.containsKey(id)) continue;
    add
      ..write('    ${jsonEncode(id)}: {')
      ..write(
        '"dartTestFile":"test/upstream_input_handler_state_playwright_parity_test.dart",',
      )
      ..write(
        '"dartTestName":${jsonEncode(e['name'])},"dartTestKind":"test"},\n',
      );
  }
  if (add.isEmpty) return;
  const marker = '  "tests": {\n';
  mf.writeAsStringSync(
    mf.readAsStringSync().replaceFirst(marker, '$marker$add'),
  );
}

String _q(String value) {
  if (value.contains(r'$') && !value.contains("'")) return "r'$value'";
  final escaped = value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
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
