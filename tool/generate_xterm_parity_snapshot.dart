import 'dart:convert';
import 'dart:io';

/// Generates the committed, offline xterm.js contract snapshot.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/generate_xterm_parity_snapshot.dart <xterm-root>',
    );
    exitCode = 64;
    return;
  }
  final root = Directory(arguments.single).absolute;
  if (!File('${root.path}/typings/xterm.d.ts').existsSync()) {
    stderr.writeln('${root.path} is not an xterm.js checkout');
    exitCode = 66;
    return;
  }
  final revision = await _git(root, <String>['rev-parse', 'HEAD']);
  const expected = '904ae935269eef5ec6a1415b64463c3d02eff1eb';
  if (revision != expected) {
    stderr.writeln('Expected $expected, found $revision');
    exitCode = 65;
    return;
  }

  final repository = File.fromUri(Platform.script).parent.parent.absolute;
  final package = Directory('${repository.path}/packages/termworld');
  final typings = <File>[
    File('${root.path}/typings/xterm.d.ts'),
    File('${root.path}/typings/xterm-headless.d.ts'),
    ...Directory('${root.path}/addons')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.d.ts')),
  ]..sort((left, right) => left.path.compareTo(right.path));
  final sourceFiles = <File>[
    ...Directory('${root.path}/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.ts')),
    ...Directory('${root.path}/addons')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.ts')),
  ]..sort((left, right) => left.path.compareTo(right.path));

  final declarations = <Map<String, String>>[];
  for (final file in typings) {
    final relative = _relative(root, file);
    for (final line in file.readAsLinesSync()) {
      final normalized = line.trim();
      if (_isContractLine(normalized)) {
        declarations.add(<String, String>{
          'file': relative,
          'signature': normalized,
        });
      }
    }
  }

  final tests = <Map<String, String>>[];
  final testPattern = RegExp(
    r'''\b(?:test|it|describe)\s*\(\s*['"`]([^'"`]+)['"`]''',
  );
  for (final file in sourceFiles.where(
    (file) => file.path.endsWith('.test.ts'),
  )) {
    final contents = file.readAsStringSync();
    for (final match in testPattern.allMatches(contents)) {
      tests.add(<String, String>{
        'file': _relative(root, file),
        'name': match.group(1)!,
      });
    }
  }

  final hashes = <String, String>{};
  for (final file in <File>[...typings, ...sourceFiles]) {
    hashes[_relative(root, file)] = await _git(root, <String>[
      'hash-object',
      file.path,
    ]);
  }

  final fixtureSource = Directory(
    '${root.path}/test/fixtures/escape_sequence_files',
  );
  final fixtureTarget = Directory(
    '${package.path}/test/fixtures/xterm/escape_sequence_files',
  )..createSync(recursive: true);
  final fixtures = <String, String>{};
  for (final file
      in fixtureSource.listSync(recursive: true).whereType<File>()) {
    final relative = file.path.substring(fixtureSource.path.length + 1);
    File('${fixtureTarget.path}/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(file.readAsBytesSync());
    fixtures[relative] = await _git(root, <String>['hash-object', file.path]);
  }

  final snapshot = <String, Object>{
    'schemaVersion': 1,
    'repository': 'https://github.com/xtermjs/xterm.js',
    'revision': revision,
    'packageVersion': '6.0.0',
    'license': 'MIT',
    'declarations': declarations,
    'tests': tests,
    'sourceBlobHashes': hashes,
    'fixtureBlobHashes': fixtures,
  };
  final output = File('${package.path}/tool/xterm_reference.json')
    ..parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  output.writeAsStringSync('${encoder.convert(snapshot)}\n');
  stdout.writeln(
    'Wrote ${declarations.length} declarations, ${tests.length} test names, '
    '${hashes.length} source hashes, and ${fixtures.length} fixtures.',
  );
}

bool _isContractLine(String line) {
  if (line.isEmpty || line.startsWith('//') || line.startsWith('*')) {
    return false;
  }
  return RegExp(
        r'^(?:export )?(?:interface|class|type|enum|namespace)\b',
      ).hasMatch(line) ||
      RegExp(
        r'^(?:readonly )?[A-Za-z_$][A-Za-z0-9_$]*[?]?(?:<[^;]+>)?[(:].*;$',
      ).hasMatch(line) ||
      RegExp(
        r'^(?:readonly )?[A-Za-z_$][A-Za-z0-9_$]*[?]?:.*;$',
      ).hasMatch(line);
}

String _relative(Directory root, File file) =>
    file.path.substring(root.path.length + 1).replaceAll(r'\', '/');

Future<String> _git(Directory root, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: root.path,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      arguments,
      result.stderr as String,
      result.exitCode,
    );
  }
  return (result.stdout as String).trim();
}
