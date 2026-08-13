import 'dart:convert';
import 'dart:io';

const _files = <String>{
  'addons/addon-webgl/test/WebglAtlasOverflow.test.ts',
  'addons/addon-webgl/test/WebglAtlasStress.test.ts',
  'addons/addon-webgl/test/WebglSharedAtlasGarble.test.ts',
};
const _target = 'test/upstream_webgl_atlas_playwright_parity_test.dart';

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
                _files.contains(entry['file']) &&
                (!mapped.containsKey(entry['id']) ||
                    ((mapped[entry['id']]!
                            as Map<String, Object?>)['dartTestFile'] ==
                        _target)),
          )
          .toList()
        ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  final out = StringBuffer(
    "import 'package:flutter_test/flutter_test.dart';\n\n"
    "import 'support/webgl_atlas_playwright_cases.dart';\n\n"
    'void main() {\n',
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
      ..writeln('    () => verifyWebglAtlasPlaywrightCase(');
    final chunks = _chunks(entry['fullName']! as String).toList();
    for (var index = 0; index < chunks.length; index++) {
      final separator = index == chunks.length - 1 ? ',' : '';
      out.writeln('      ${_quote(chunks[index])}$separator');
    }
    out
      ..writeln('    ),')
      ..writeln('  );');
  }
  out.writeln('}');
  File('${package.path}/$_target').writeAsStringSync(out.toString());

  final additions = StringBuffer();
  for (final entry in cases.where(
    (entry) => !mapped.containsKey(entry['id']),
  )) {
    additions
      ..write('    ${jsonEncode(entry['id'])}: {')
      ..write('"dartTestFile":"$_target",')
      ..write('"dartTestName":${jsonEncode(entry['name'])},')
      ..write('"dartTestPath":${jsonEncode(entry['fullName'])},')
      ..write('"dartTestKind":"test"},\n');
  }
  if (additions.isEmpty) return;
  const marker = '  "tests": {\n';
  final original = mappingsFile.readAsStringSync();
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
