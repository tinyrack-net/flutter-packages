import 'dart:convert';
import 'dart:io';

const _source = 'test/playwright/SharedRendererTests.ts';
const _target =
    'test/upstream_shared_renderer_webgl_playwright_parity_test.dart';

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
          .where(
            (entry) =>
                entry['file'] == _source &&
                (entry['fullName']! as String).startsWith(
                  'WebglRenderer.test.js ',
                ) &&
                (!mapped.containsKey(entry['id']) ||
                    ((mapped[entry['id']]!
                            as Map<String, Object?>)['dartTestFile'] ==
                        _target)),
          )
          .toList()
        ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));

  final out = StringBuffer(
    "import 'package:flutter_test/flutter_test.dart';\n\n"
    "import 'support/shared_renderer_webgl_playwright_cases.dart';\n\n"
    'void main() {\n',
  );
  for (final entry in cases) {
    final name = entry['name']! as String;
    final behavior = (entry['fullName']! as String).replaceFirst(
      'WebglRenderer.test.js WebGL Renderer Integration Tests ',
      '',
    );
    final widget = _isWidgetBehavior(behavior);
    out.writeln('  ${widget ? 'testWidgets' : 'test'}(');
    if (name.length > 73) {
      out
        ..writeln('    // Exact pinned identity remains one literal.')
        ..writeln('    // ignore: lines_longer_than_80_chars');
    }
    out
      ..writeln('    ${_quote(name)},')
      ..writeln(
        widget
            ? '    (tester) => verifyWebglSharedRendererPlaywrightCase('
            : '    () => verifyWebglSharedRendererPlaywrightCase(',
      );
    final chunks = _chunks(behavior).toList();
    for (var index = 0; index < chunks.length; index++) {
      final separator = index == chunks.length - 1 ? ',' : '';
      out.writeln('      ${_quote(chunks[index])}$separator');
    }
    if (widget) out.writeln('      tester: tester,');
    out
      ..writeln('    ),')
      ..writeln('  );');
  }
  out.writeln('}');
  File('${package.path}/$_target').writeAsStringSync(out.toString());

  var original = mappingsFile.readAsStringSync();
  for (final entry in cases) {
    final mapping = mapped[entry['id']] as Map<String, Object?>?;
    if (mapping?['dartTestFile'] != _target) continue;
    final behavior = (entry['fullName']! as String).replaceFirst(
      'WebglRenderer.test.js WebGL Renderer Integration Tests ',
      '',
    );
    final kind = _isWidgetBehavior(behavior) ? 'testWidgets' : 'test';
    final id = jsonEncode(entry['id']);
    final start = original.indexOf('    $id: {');
    final end = original.indexOf('\n', start);
    if (start < 0 || end < 0) throw StateError('mapping line missing: $id');
    final line = original.substring(start, end);
    original = original.replaceRange(
      start,
      end,
      line.replaceFirst(
        RegExp('"dartTestKind":"(?:test|testWidgets)"'),
        '"dartTestKind":"$kind"',
      ),
    );
  }
  mappingsFile.writeAsStringSync(original);

  if (cases.isEmpty) return;
  final additions = StringBuffer();
  for (final entry in cases.where(
    (entry) => !mapped.containsKey(entry['id']),
  )) {
    final behavior = (entry['fullName']! as String).replaceFirst(
      'WebglRenderer.test.js WebGL Renderer Integration Tests ',
      '',
    );
    final kind = _isWidgetBehavior(behavior) ? 'testWidgets' : 'test';
    additions
      ..write('    ${jsonEncode(entry['id'])}: {')
      ..write('"dartTestFile":"$_target",')
      ..write('"dartTestName":${jsonEncode(entry['name'])},')
      ..write('"dartTestPath":${jsonEncode(entry['fullName'])},')
      ..write('"dartTestKind":"$kind"},\n');
  }
  const marker = '  "tests": {\n';
  mappingsFile.writeAsStringSync(
    original.replaceFirst(marker, '$marker$additions'),
  );
}

bool _isWidgetBehavior(String behavior) =>
    behavior.contains('cursor') ||
    behavior.contains('selection should not be displayed');

String _quote(String value) {
  if (value.contains(r'$') && !value.contains("'")) return "r'$value'";
  if (value.contains("'") && !value.contains('"')) return '"$value"';
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

Iterable<String> _chunks(String value) sync* {
  const width = 54;
  var remaining = value;
  while (remaining.length > width) {
    final boundary = remaining.lastIndexOf(' ', width);
    final end = boundary <= 0 ? width : boundary + 1;
    yield remaining.substring(0, end);
    remaining = remaining.substring(end);
  }
  yield remaining;
}
