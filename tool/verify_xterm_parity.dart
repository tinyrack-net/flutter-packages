import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Verifies the pinned xterm contract and every implementation mapping.
void main() {
  final root = File.fromUri(Platform.script).parent.parent.absolute;
  final package = Directory('${root.path}/packages/termworld');
  final manifestFile = File('${package.path}/xterm_parity.yaml');
  final snapshotFile = File('${package.path}/tool/xterm_reference.json');
  final failures = <String>[];
  if (!manifestFile.existsSync()) failures.add('xterm_parity.yaml is missing');
  if (!snapshotFile.existsSync()) {
    failures.add('xterm_reference.json is missing');
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
  if (snapshot['schemaVersion'] != 1 || snapshot['license'] != 'MIT') {
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
  _checkCount(snapshot, 'tests', 2381, failures);
  _checkCount(snapshot, 'sourceBlobHashes', 308, failures);
  _checkCount(snapshot, 'fixtureBlobHashes', 162, failures);

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

  final terminalSource = File(
    '${package.path}/lib/src/core/terminal.dart',
  ).readAsStringSync();
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
  _finish(failures);
}

void _checkSnapshotIdentity(File snapshot, List<String> failures) {
  const expectedBlob = '1fae3f671a2f25fbe5b18542de67111f71d1a081';
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
  if (!File('${package.path}/$path').existsSync()) {
    failures.add('$path is missing');
  }
}

Never _finish(List<String> failures) {
  if (failures.isEmpty) {
    stdout.writeln('xterm parity contract verification passed.');
    exit(0);
  }
  failures.forEach(stderr.writeln);
  exit(1);
}
