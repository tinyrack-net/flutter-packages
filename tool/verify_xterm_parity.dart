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
  _finish(failures);
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
