import 'dart:convert';
import 'dart:io';

bool _selected(Map<String, Object?> entry) {
  if (entry['file'] != 'test/playwright/InputHandler.test.ts') return false;
  final name = entry['name']! as String;
  return name == 'CSI Ps c - ' ||
      name == 'CSI > Ps c - ' ||
      name == 'CSI = Ps c - ' ||
      name.contains('XTVERSION') ||
      name.startsWith('Status Report') ||
      name.startsWith('Report Cursor Position') ||
      name.startsWith('Color Scheme Query') ||
      name == 'should be disabled by default' ||
      name == '14 - GetWinSizePixels' ||
      name == '16 - GetCellSizePixels';
}

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
  final mapped = mappings['tests']! as Map<String, Object?>;
  final cases =
      (reference['tests']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .where(_selected)
          .toList()
        ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  final source = StringBuffer(
    "import 'package:flutter_test/flutter_test.dart';\n\nimport 'support/input_handler_report_playwright_cases.dart';\n\nvoid main() {\n",
  );
  for (final entry in cases) {
    final name = entry['name']! as String;
    source
      ..writeln('  test(')
      ..writeln('    ${_dartString(name)},')
      ..writeln('    () => verifyInputHandlerReportPlaywrightCase(')
      ..writeln('      ${_dartString(name)},')
      ..writeln('    ),')
      ..writeln('  );');
  }
  source.writeln('}');
  File(
    '${package.path}/test/upstream_input_handler_report_playwright_parity_test.dart',
  ).writeAsStringSync(source.toString());
  final additions = StringBuffer();
  for (final entry in cases) {
    final id = entry['id']! as String;
    if (mapped.containsKey(id)) continue;
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write(
        '"dartTestFile":"test/upstream_input_handler_report_playwright_parity_test.dart",',
      )
      ..write(
        '"dartTestName":${jsonEncode(entry['name'])},"dartTestKind":"test"},\n',
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
