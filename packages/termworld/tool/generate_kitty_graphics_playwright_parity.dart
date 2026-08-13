import 'dart:convert';
import 'dart:io';

const _target = 'test/upstream_kitty_graphics_playwright_parity_test.dart';

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
                entry['file'] ==
                'addons/addon-image/test/KittyGraphics.test.ts',
          )
          .toList()
        ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  final out = StringBuffer(
    "import 'package:flutter_test/flutter_test.dart';\n\nimport 'support/kitty_graphics_playwright_cases.dart';\n\nvoid main() {\n",
  );
  for (final entry in cases) {
    final name = entry['name']! as String;
    final behavior = (entry['fullName']! as String).replaceFirst(
      'KittyGraphics.test.js Kitty Graphics Protocol ',
      '',
    );
    out.writeln('  test(');
    if (name.length > 73) {
      out
        ..writeln('    // Exact pinned identity remains one literal.')
        ..writeln('    // ignore: lines_longer_than_80_chars');
    }
    out
      ..writeln('    ${_quote(name)},')
      ..writeln('    () => verifyKittyGraphicsPlaywrightCase(');
    final chunks = _chunks(behavior).toList();
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
  var original = mappingsFile.readAsStringSync();
  for (final entry in cases) {
    final id = entry['id']! as String;
    final mapping = mapped[id] as Map<String, Object?>?;
    if (mapping?['dartTestFile'] != _target ||
        mapping!.containsKey('dartTestPath')) {
      continue;
    }
    final start = original.indexOf('    ${jsonEncode(id)}: {');
    final end = original.indexOf('\n', start);
    if (start < 0 || end < 0) throw StateError('mapping line missing: $id');
    final line = original.substring(start, end);
    final path = jsonEncode(entry['fullName']);
    original = original.replaceRange(
      start,
      end,
      line.replaceFirst(
        '"dartTestKind":',
        '"dartTestPath":$path,"dartTestKind":',
      ),
    );
  }
  mappingsFile.writeAsStringSync(original);
  final additions = StringBuffer();
  for (final entry in cases) {
    final id = entry['id']! as String;
    if (mapped.containsKey(id)) continue;
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write('"dartTestFile":"$_target",')
      ..write(
        '"dartTestName":${jsonEncode(entry['name'])},'
        '"dartTestPath":${jsonEncode(entry['fullName'])},'
        '"dartTestKind":"test"},\n',
      );
  }
  if (additions.isEmpty) return;
  const marker = '  "tests": {\n';
  if (!original.contains(marker)) {
    throw StateError('tests mapping marker missing');
  }
  mappingsFile.writeAsStringSync(
    original.replaceFirst(marker, '$marker$additions'),
  );
}

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
