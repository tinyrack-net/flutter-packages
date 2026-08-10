import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Verifies the pinned xterm contract and every implementation mapping.
void main() {
  final root = File.fromUri(Platform.script).parent.parent.absolute;
  final package = Directory('${root.path}/packages/termworld');
  final manifestFile = File('${package.path}/xterm_parity.yaml');
  final snapshotFile = File('${package.path}/tool/xterm_reference.json');
  final mappingsFile = File('${package.path}/tool/xterm_parity_mappings.json');
  final failures = <String>[];
  if (!manifestFile.existsSync()) failures.add('xterm_parity.yaml is missing');
  if (!snapshotFile.existsSync()) {
    failures.add('xterm_reference.json is missing');
  }
  if (!mappingsFile.existsSync()) {
    failures.add('xterm_parity_mappings.json is missing');
  }
  if (failures.isNotEmpty) {
    _finish(failures);
  }

  final manifest = loadYaml(manifestFile.readAsStringSync()) as YamlMap;
  final snapshot =
      jsonDecode(snapshotFile.readAsStringSync()) as Map<String, Object?>;
  const revision = '904ae935269eef5ec6a1415b64463c3d02eff1eb';
  if ((manifest['reference'] as YamlMap)['revision'] != revision) {
    failures.add('manifest revision is not the approved xterm SHA');
  }
  if (snapshot['revision'] != revision) {
    failures.add('snapshot revision is not the approved xterm SHA');
  }
  if (snapshot['schemaVersion'] != 3 || snapshot['license'] != 'MIT') {
    failures.add('snapshot schema or license metadata changed');
  }
  _checkSnapshotIdentity(snapshotFile, failures);
  if (manifest.containsKey('upstream_fixture_exclusions')) {
    failures.add('upstream fixture exclusions are forbidden');
  }
  for (final key in const <String>[
    'declarations',
    'tests',
    'sourceBlobHashes',
    'fixtureBlobHashes',
  ]) {
    final value = snapshot[key];
    if (value is Iterable && value.isEmpty || value is Map && value.isEmpty) {
      failures.add('snapshot $key is empty');
    }
  }
  _checkCount(snapshot, 'declarations', 695, failures);
  _checkCount(snapshot, 'tests', 3771, failures);
  _checkCount(snapshot, 'sourceBlobHashes', 321, failures);
  _checkCount(snapshot, 'fixtureBlobHashes', 162, failures);
  _checkMappings(package, snapshot, mappingsFile, failures);
  _checkNoParityPlaceholders(package, failures);

  final contracts = manifest['contracts'] as YamlMap;
  for (final contractName in const <String>['core', 'flutter']) {
    final contract = contracts[contractName] as YamlMap;
    _checkPath(package, contract['entrypoint'] as String, failures);
    for (final path in contract['implementation'] as YamlList) {
      _checkPath(package, path as String, failures);
    }
    for (final path in contract['tests'] as YamlList) {
      _checkPath(package, path as String, failures);
    }
  }
  final addons = contracts['addons'] as YamlMap;
  final declarations = snapshot['declarations']! as List<Object?>;
  final snapshotAddons = declarations
      .cast<Map<String, Object?>>()
      .map((item) => item['file']! as String)
      .where((path) => path.startsWith('addons/'))
      .map(
        (path) =>
            path.split('/').firstWhere((part) => part.startsWith('addon-')),
      )
      .toSet();
  for (final addon in snapshotAddons) {
    if (!addons.containsKey(addon)) {
      failures.add('$addon has no parity mapping');
    }
  }
  for (final entry in addons.entries) {
    final mapping = entry.value as YamlMap;
    _checkPath(package, mapping['entrypoint'] as String, failures);
    _checkPath(package, mapping['test'] as String, failures);
    if (mapping.containsKey('platform') && mapping['platform'] != 'web') {
      failures.add('${entry.key} uses an undeclared platform adaptation');
    }
  }

  final terminalFile = _resolveParityFile(
    package,
    'lib/src/core/terminal.dart',
  );
  if (terminalFile == null) {
    _finish([...failures, 'lib/src/core/terminal.dart is missing']);
  }
  final terminalSource = terminalFile.readAsStringSync();
  for (final api in manifest['required_terminal_api'] as YamlList) {
    if (!RegExp(
      '\\b${RegExp.escape(api as String)}\\b',
    ).hasMatch(terminalSource)) {
      failures.add('Terminal API $api is missing');
    }
  }
  final fixtureDirectory = Directory(
    '${package.path}/test/fixtures/xterm/escape_sequence_files',
  );
  final expectedFixtures =
      (snapshot['fixtureBlobHashes']! as Map<String, Object?>).length;
  final actualFixtures = fixtureDirectory.existsSync()
      ? fixtureDirectory.listSync(recursive: true).whereType<File>().length
      : 0;
  if (actualFixtures != expectedFixtures) {
    failures.add('expected $expectedFixtures fixtures, found $actualFixtures');
  }
  _checkFixtureHashes(package, snapshot, failures);
  _checkPinnedLigatureFonts(package, failures);
  _checkPinnedKittyKeyboardCases(package, failures);
  _checkPinnedWin32InputModeCases(package, failures);
  _checkPinnedKeyboardCases(package, failures);
  _checkPinnedIipMetricsCases(package, failures);
  _finish(failures);
}

void _checkPinnedIipMetricsCases(
  Directory package,
  List<String> failures,
) {
  final manifest = File(
    '${package.path}/test/fixtures/xterm_image/image_metrics_cases.json',
  );
  if (!manifest.existsSync()) {
    failures.add('pinned IIP metrics cases are missing');
    return;
  }
  final manifestHash = Process.runSync('git', <String>[
    'hash-object',
    '--no-filters',
    manifest.path,
  ]);
  if (manifestHash.exitCode != 0 ||
      (manifestHash.stdout as String).trim() !=
          '09da36eb320e6841c72060306533a104c58a1c66') {
    failures.add('pinned IIP metrics manifest changed');
  }
  final document = jsonDecode(manifest.readAsStringSync());
  if (document is! Map<String, Object?> ||
      document['revision'] != '904ae935269eef5ec6a1415b64463c3d02eff1eb' ||
      document['license'] != 'MIT' ||
      document['cases'] is! List<Object?> ||
      (document['cases']! as List<Object?>).length != 20) {
    failures.add('pinned IIP metrics case identity changed');
    return;
  }
  for (final raw in document['cases']! as List<Object?>) {
    if (raw is! Map<String, Object?> ||
        raw['file'] is! String ||
        raw['blob'] is! String) {
      failures.add('invalid pinned IIP metrics case');
      continue;
    }
    final fixture = File(
      '${package.path}/test/fixtures/xterm_image/testimages/${raw['file']}',
    );
    if (!fixture.existsSync()) {
      failures.add('pinned IIP metrics image is missing: ${raw['file']}');
      continue;
    }
    final result = Process.runSync('git', <String>[
      'hash-object',
      '--no-filters',
      fixture.path,
    ]);
    if (result.exitCode != 0 ||
        (result.stdout as String).trim() != raw['blob']) {
      failures.add('pinned IIP metrics image changed: ${raw['file']}');
    }
  }
}

void _checkPinnedKeyboardCases(Directory package, List<String> failures) {
  final fixture = File(
    '${package.path}/test/fixtures/xterm/keyboard_cases.json',
  );
  if (!fixture.existsSync()) {
    failures.add('pinned keyboard cases are missing');
    return;
  }
  final result = Process.runSync('git', <String>[
    'hash-object',
    '--no-filters',
    fixture.path,
  ]);
  if (result.exitCode != 0 ||
      (result.stdout as String).trim() !=
          'c89dbbb10866621f5210d1655a862d79f4c0a604') {
    failures.add('pinned keyboard cases changed');
  }
  final document = jsonDecode(fixture.readAsStringSync());
  if (document is! Map<String, Object?> ||
      document['revision'] != '904ae935269eef5ec6a1415b64463c3d02eff1eb' ||
      document['cases'] is! List<Object?> ||
      (document['cases']! as List<Object?>).length != 61) {
    failures.add('pinned keyboard case identity changed');
  }
}

void _checkPinnedWin32InputModeCases(
  Directory package,
  List<String> failures,
) {
  final fixture = File(
    '${package.path}/test/fixtures/xterm/win32_input_mode_cases.json',
  );
  if (!fixture.existsSync()) {
    failures.add('pinned Win32 input mode cases are missing');
    return;
  }
  final result = Process.runSync('git', <String>[
    'hash-object',
    '--no-filters',
    fixture.path,
  ]);
  if (result.exitCode != 0 ||
      (result.stdout as String).trim() !=
          '26ace6e49e5206e4d2739b85597230e4b61627d7') {
    failures.add('pinned Win32 input mode cases changed');
  }
  final document = jsonDecode(fixture.readAsStringSync());
  if (document is! Map<String, Object?> ||
      document['revision'] != '904ae935269eef5ec6a1415b64463c3d02eff1eb' ||
      document['cases'] is! List<Object?> ||
      (document['cases']! as List<Object?>).length != 64) {
    failures.add('pinned Win32 input mode case identity changed');
  }
}

void _checkPinnedKittyKeyboardCases(
  Directory package,
  List<String> failures,
) {
  final fixture = File(
    '${package.path}/test/fixtures/xterm/kitty_keyboard_cases.json',
  );
  if (!fixture.existsSync()) {
    failures.add('pinned Kitty keyboard cases are missing');
    return;
  }
  final result = Process.runSync('git', <String>[
    'hash-object',
    '--no-filters',
    fixture.path,
  ]);
  if (result.exitCode != 0 ||
      (result.stdout as String).trim() !=
          'bcba2f6407bbc2db87b5b1fc1c6309b36cbb72cb') {
    failures.add('pinned Kitty keyboard cases changed');
  }
  final document = jsonDecode(fixture.readAsStringSync());
  if (document is! Map<String, Object?> ||
      document['revision'] != '904ae935269eef5ec6a1415b64463c3d02eff1eb' ||
      document['cases'] is! List<Object?> ||
      (document['cases']! as List<Object?>).length != 165) {
    failures.add('pinned Kitty keyboard case identity changed');
  }
}

void _checkPinnedLigatureFonts(Directory package, List<String> failures) {
  const expected = <String, String>{
    'FiraCode-Regular.otf.gz.b64': 'e7a9fda69dad82c508e6374a053e6d3f1b82f6c0',
    'Monoid-Regular.ttf.gz.b64': 'a09e9faff2c39c9dc56f6a0101a300851922e78d',
    'UbuntuMono-Regular.ttf.gz.b64': 'fdd309d716629f4e5339d5e5508225ed857a3ede',
    'iosevka-regular.ttf.gz.b64': '963cbe2a654a8e5ab284a622575c57464e8f1b35',
  };
  final directory = Directory(
    '${package.path}/test/fixtures/xterm_ligatures',
  );
  final temporary = Directory.systemTemp.createTempSync(
    'termworld-ligature-hash-',
  );
  try {
    for (final entry in expected.entries) {
      final encoded = File('${directory.path}/${entry.key}');
      if (!encoded.existsSync()) {
        failures.add('pinned ligature font is missing: ${entry.key}');
        continue;
      }
      final decoded = gzip.decode(
        base64.decode(encoded.readAsStringSync().replaceAll(RegExp(r'\s'), '')),
      );
      final target = File('${temporary.path}/${entry.key}')
        ..writeAsBytesSync(decoded);
      final result = Process.runSync('git', <String>[
        'hash-object',
        '--no-filters',
        target.path,
      ]);
      if (result.exitCode != 0 ||
          (result.stdout as String).trim() != entry.value) {
        failures.add('pinned ligature font hash changed: ${entry.key}');
      }
    }
  } on Object catch (error) {
    failures.add('could not verify pinned ligature fonts: $error');
  } finally {
    temporary.deleteSync(recursive: true);
  }
  final casesFile = File('${directory.path}/index_cases.json');
  if (!casesFile.existsSync()) {
    failures.add('ligature corpus cases are missing');
    return;
  }
  final cases = jsonDecode(casesFile.readAsStringSync());
  if (cases is! Map<String, Object?> ||
      cases['revision'] != '904ae935269eef5ec6a1415b64463c3d02eff1eb' ||
      cases['cases'] is! List<Object?> ||
      (cases['cases']! as List<Object?>).length != 216) {
    failures.add('ligature corpus identity changed');
  }
}

void _checkSnapshotIdentity(File snapshot, List<String> failures) {
  const expectedBlob = 'b486a976f736f0ac4d164d72f62cb68ecd45d77f';
  final result = Process.runSync('git', <String>[
    'hash-object',
    '--no-filters',
    snapshot.path,
  ]);
  if (result.exitCode != 0 ||
      (result.stdout as String).trim() != expectedBlob) {
    failures.add('xterm reference snapshot content does not match its lock');
  }
}

void _checkMappings(
  Directory package,
  Map<String, Object?> snapshot,
  File mappingsFile,
  List<String> failures,
) {
  if (!mappingsFile.existsSync()) return;
  final mappings =
      jsonDecode(mappingsFile.readAsStringSync()) as Map<String, Object?>;
  if (mappings['schemaVersion'] != 1) {
    failures.add('parity mappings schema changed');
    return;
  }
  final declarations = _mappingMap(mappings, 'declarations', failures);
  final sources = _mappingMap(mappings, 'sources', failures);
  final tests = _mappingMap(mappings, 'tests', failures);
  if (declarations == null || sources == null || tests == null) return;

  final declarationIds = (snapshot['declarations']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .map((entry) => entry['id']! as String)
      .toSet();
  final testIds = (snapshot['tests']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .map((entry) => entry['id']! as String)
      .toSet();
  final sourceIds = (snapshot['sourceBlobHashes']! as Map<String, Object?>).keys
      .toSet();
  _checkMappingIdentity('declarations', declarationIds, declarations, failures);
  _checkMappingIdentity('sources', sourceIds, sources, failures);
  _checkMappingIdentity('tests', testIds, tests, failures);

  for (final entry in declarations.entries) {
    final mapping = _objectMap(entry.value);
    final implementation = mapping?['implementation'];
    final symbol = mapping?['symbol'];
    if (implementation is! String || symbol is! String || symbol.isEmpty) {
      failures.add('invalid declaration mapping: ${entry.key}');
      continue;
    }
    _checkPath(package, implementation, failures);
    final source = _resolveParityFile(package, implementation);
    if (source != null && !source.readAsStringSync().contains(symbol)) {
      failures.add('mapped declaration symbol is missing: ${entry.key}');
    }
  }

  for (final entry in sources.entries) {
    final mapping = _objectMap(entry.value);
    final implementation = mapping?['implementation'];
    final mappedTests = mapping?['tests'];
    if (implementation is! List ||
        implementation.isEmpty ||
        mappedTests is! List ||
        mappedTests.isEmpty) {
      failures.add('invalid source mapping: ${entry.key}');
      continue;
    }
    for (final path in <Object?>[...implementation, ...mappedTests]) {
      if (path is! String) {
        failures.add('non-string source mapping path: ${entry.key}');
      } else {
        _checkPath(package, path, failures);
      }
    }
    for (final path in implementation.whereType<String>()) {
      if (!path.startsWith('lib/') || !path.endsWith('.dart')) {
        failures.add('source implementation is not production Dart: $path');
      }
    }
    for (final path in mappedTests.whereType<String>()) {
      final isUnitTest =
          path.startsWith('test/') && path.endsWith('_test.dart');
      final isConformance =
          path == 'example/integration_test/conformance_test.dart';
      if (!isUnitTest && !isConformance) {
        failures.add('source evidence is not an executable Dart test: $path');
      }
    }
  }

  final dartTests = <String>{};
  for (final entry in tests.entries) {
    final mapping = _objectMap(entry.value);
    final file = mapping?['dartTestFile'];
    final name = mapping?['dartTestName'];
    final kind = mapping?['dartTestKind'];
    final path = mapping?['dartTestPath'];
    if (file is! String ||
        name is! String ||
        name.isEmpty ||
        (kind != 'test' && kind != 'testWidgets' && kind != 'group')) {
      failures.add('invalid test mapping: ${entry.key}');
      continue;
    }
    if (path != null && (path is! String || path.isEmpty)) {
      failures.add('invalid Dart test path: ${entry.key}');
      continue;
    }
    final identity = '$file::${path ?? '$kind::$name'}';
    if (!dartTests.add(identity)) {
      failures.add('multiple upstream tests map to $identity');
    }
    _checkPath(package, file, failures);
    if (!file.startsWith('test/') ||
        !file.endsWith('_test.dart') ||
        file.substring('test/'.length).contains('/')) {
      failures.add('mapped test is outside the CI shard discovery: $file');
    }
    final source = File('${package.path}/$file');
    if (source.existsSync()) {
      final quotedCandidates = <String>[
        _quotedDartString(name, "'"),
        _quotedDartString(name, '"'),
        if (!name.contains("'")) "r'$name'",
        if (!name.contains('"')) 'r"$name"',
      ];
      final quotedName = quotedCandidates.map(RegExp.escape).join('|');
      final literal = RegExp(
        '\\b${RegExp.escape(kind! as String)}\\s*\\('
        r'(?:\s|//[^\n]*(?:\n|$)|/\*[\s\S]*?\*/)*'
        '(?:$quotedName)',
      );
      if (!literal.hasMatch(source.readAsStringSync())) {
        failures.add('mapped Dart test is not executable: ${entry.key}');
      }
    }
  }
}

void _checkNoParityPlaceholders(Directory package, List<String> failures) {
  final roots = <Directory>[
    Directory('${package.path}/lib'),
    Directory('${package.path}/test/support'),
  ];
  final banned = <RegExp, String>{
    RegExp(r'\bUnimplementedError\b'): 'UnimplementedError',
    RegExp(r'\b[Tt][Oo][Dd][Oo]\b'): 'TODO marker',
    RegExp(r'\b[Uu]nimplemented\b'): 'unimplemented marker',
    RegExp(r'\b[Nn]ot[Ii]mplemented\b'): 'notImplemented marker',
  };
  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final file
        in root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final entry in banned.entries) {
        if (!entry.key.hasMatch(source)) continue;
        failures.add(
          '${file.path.substring(package.path.length + 1)} contains '
          '${entry.value}',
        );
      }
    }
  }
}

String _quotedDartString(String value, String quote) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll(r'$', r'\$')
      .replaceAll(quote, '\\$quote');
  return '$quote$escaped$quote';
}

Map<String, Object?>? _mappingMap(
  Map<String, Object?> mappings,
  String key,
  List<String> failures,
) {
  final value = mappings[key];
  if (value is! Map<String, Object?>) {
    failures.add('parity mappings $key must be an object');
    return null;
  }
  return value;
}

Map<String, Object?>? _objectMap(Object? value) =>
    value is Map<String, Object?> ? value : null;

void _checkMappingIdentity(
  String name,
  Set<String> expected,
  Map<String, Object?> actual,
  List<String> failures,
) {
  final missing = expected.difference(actual.keys.toSet());
  final extra = actual.keys.toSet().difference(expected);
  if (missing.isNotEmpty) {
    failures.add('$name mappings missing ${missing.length} pinned entries');
  }
  if (extra.isNotEmpty) {
    failures.add('$name mappings contain ${extra.length} unknown entries');
  }
}

void _checkCount(
  Map<String, Object?> snapshot,
  String key,
  int expected,
  List<String> failures,
) {
  final value = snapshot[key]!;
  final actual = value is Map ? value.length : (value as List<Object?>).length;
  if (actual != expected) {
    failures.add('snapshot $key expected $expected entries, found $actual');
  }
}

void _checkFixtureHashes(
  Directory package,
  Map<String, Object?> snapshot,
  List<String> failures,
) {
  final hashes = snapshot['fixtureBlobHashes']! as Map<String, Object?>;
  for (final entry in hashes.entries) {
    final fixture = File(
      '${package.path}/test/fixtures/xterm/escape_sequence_files/${entry.key}',
    );
    if (!fixture.existsSync()) continue;
    final result = Process.runSync('git', <String>[
      'hash-object',
      '--no-filters',
      fixture.path,
    ]);
    if (result.exitCode != 0 ||
        (result.stdout as String).trim() != entry.value) {
      failures.add('fixture hash mismatch: ${entry.key}');
    }
  }
}

void _checkPath(Directory package, String path, List<String> failures) {
  if (_resolveParityFile(package, path) == null) {
    failures.add('$path is missing');
  }
}

/// Finds a manifest path in termworld or in the package its core moved to.
///
/// The parser and cell grid now live in `vtworld` so a plain Dart server can
/// hold the same screen model. The parity contract still covers both halves as
/// one port, so a mapping resolves against whichever package now owns the file
/// rather than being split across two manifests.
File? _resolveParityFile(Directory package, String path) {
  final local = File('${package.path}/$path');
  if (local.existsSync()) return local;
  final root = _vtworldRoot(package);
  if (root == null) return null;
  final moved = File('${root.path}/$path');
  return moved.existsSync() ? moved : null;
}

Directory? _vtworldRoot(Directory package) {
  final config = File(
    '${package.parent.parent.path}/.dart_tool/package_config.json',
  );
  if (!config.existsSync()) return null;
  final decoded = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  final packages = (decoded['packages']! as List<Object?>)
      .cast<Map<String, Object?>>();
  for (final entry in packages) {
    if (entry['name'] != 'vtworld') continue;
    return Directory.fromUri(
      config.uri.resolve(entry['rootUri']! as String),
    );
  }
  return null;
}

Never _finish(List<String> failures) {
  if (failures.isEmpty) {
    stdout.writeln('xterm parity contract verification passed.');
    exit(0);
  }
  failures.forEach(stderr.writeln);
  exit(1);
}
