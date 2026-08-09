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
    ...Directory('${root.path}/test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.ts')),
  ]..sort((left, right) => left.path.compareTo(right.path));

  final declarations = <Map<String, Object>>[];
  for (final file in typings) {
    final relative = _relative(root, file);
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final normalized = line.trim();
      if (_isContractLine(normalized)) {
        declarations.add(<String, Object>{
          'id': '$relative:${index + 1}',
          'file': relative,
          'line': index + 1,
          'signature': normalized,
        });
      }
    }
  }

  final tests = await _discoverTests(root);

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
    'schemaVersion': 3,
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
    'Wrote ${declarations.length} declarations, '
    '${tests.length} expanded tests, '
    '${hashes.length} source hashes, and ${fixtures.length} fixtures.',
  );
}

Future<List<Map<String, Object>>> _discoverTests(Directory root) async {
  final tests = <Map<String, Object>>[];
  final unit = await _run(
    root,
    'node',
    <String>['bin/test_unit.js', '--dry-run', '--reporter=json'],
  );
  final unitJson = jsonDecode(unit) as Map<String, Object?>;
  final occurrences = <String, int>{};
  for (final item
      in (unitJson['tests']! as List<Object?>).cast<Map<String, Object?>>()) {
    final file = _unitSourcePath(root, item['file']! as String);
    final title = item['title']! as String;
    final fullTitle = item['fullTitle']! as String;
    final baseId = 'unit:$file:$fullTitle';
    final occurrence = occurrences.update(
      baseId,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    tests.add(<String, Object>{
      'id': occurrence == 1 ? baseId : '$baseId#$occurrence',
      'runner': 'unit',
      'file': file,
      'name': title,
      'fullName': fullTitle,
    });
  }

  final integration = await _run(
    root,
    'node',
    <String>[
      'bin/test_integration.js',
      '--list',
      '--project=Chromium',
      '--reporter=json',
    ],
  );
  for (final document in _playwrightDocuments(integration)) {
    final config = document['config']! as Map<String, Object?>;
    final rootDirectory = Directory(config['rootDir']! as String);
    _collectPlaywrightTests(
      root,
      rootDirectory,
      document['suites']! as List<Object?>,
      const <String>[],
      tests,
    );
  }
  tests.sort(
    (left, right) => (left['id']! as String).compareTo(
      right['id']! as String,
    ),
  );
  return tests;
}

String _unitSourcePath(Directory root, String compiledPath) {
  var relative = compiledPath.substring(root.path.length + 1);
  if (relative.startsWith('out-esbuild/')) {
    relative = 'src/${relative.substring('out-esbuild/'.length)}';
  } else {
    relative = relative.replaceFirst('/out-esbuild/', '/src/');
  }
  return relative.replaceFirst(RegExp(r'\.js$'), '.ts');
}

Iterable<Map<String, Object?>> _playwrightDocuments(String output) sync* {
  const marker = '{\n  "config"';
  var start = output.indexOf(marker);
  while (start != -1) {
    final next = output.indexOf('\nRunning suite ', start);
    final json = output.substring(start, next == -1 ? output.length : next);
    yield jsonDecode(json.trim()) as Map<String, Object?>;
    if (next == -1) return;
    start = output.indexOf(marker, next);
  }
}

void _collectPlaywrightTests(
  Directory root,
  Directory rootDirectory,
  List<Object?> suites,
  List<String> parents,
  List<Map<String, Object>> output,
) {
  for (final suite in suites.cast<Map<String, Object?>>()) {
    final title = suite['title']! as String;
    final nextParents = <String>[...parents, title];
    for (final spec
        in (suite['specs']! as List<Object?>).cast<Map<String, Object?>>()) {
      final specTitle = spec['title']! as String;
      final source = File.fromUri(
        rootDirectory.uri.resolve(spec['file']! as String),
      );
      final relative = _relative(root, source);
      output.add(<String, Object>{
        'id': 'playwright:${spec['id']}',
        'runner': 'playwright',
        'file': relative,
        'line': spec['line']! as int,
        'name': specTitle,
        'fullName': <String>[...nextParents, specTitle].join(' '),
      });
    }
    _collectPlaywrightTests(
      root,
      rootDirectory,
      suite['suites'] as List<Object?>? ?? const <Object?>[],
      nextParents,
      output,
    );
  }
}

Future<String> _run(
  Directory root,
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: root.path,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      result.stderr as String,
      result.exitCode,
    );
  }
  return result.stdout as String;
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
