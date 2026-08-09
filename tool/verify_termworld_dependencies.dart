import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _allowedProductionDependencies = <String>{
  'characters',
  'flutter',
  'web',
  'web_socket_channel',
};

/// Proves that termworld owns its implementation and has no xterm dependency.
void main() {
  final root = File.fromUri(Platform.script).parent.parent.absolute;
  final package = Directory('${root.path}/packages/termworld');
  final failures = <String>[];
  _verifyPubspec(package, failures);
  _verifyPackageConfig(root, failures);
  _verifyPackageGraph(root, failures);
  _verifyProductionSources(package, failures);
  if (failures.isNotEmpty) {
    failures.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln('termworld standalone dependency verification passed.');
}

void _verifyPubspec(Directory package, List<String> failures) {
  final pubspec =
      loadYaml(
            File('${package.path}/pubspec.yaml').readAsStringSync(),
          )
          as YamlMap;
  if (pubspec['version'] != '0.4.0') {
    failures.add('termworld must use the approved breaking version 0.4.0');
  }
  final dependencies = (pubspec['dependencies'] as YamlMap).keys
      .cast<String>()
      .toSet();
  final unexpected = dependencies.difference(_allowedProductionDependencies);
  final missing = _allowedProductionDependencies.difference(dependencies);
  if (unexpected.isNotEmpty) {
    failures.add(
      'unexpected production dependencies: ${unexpected.join(', ')}',
    );
  }
  if (missing.isNotEmpty) {
    failures.add(
      'required production dependencies missing: ${missing.join(', ')}',
    );
  }
}

void _verifyPackageConfig(Directory root, List<String> failures) {
  final file = File('${root.path}/.dart_tool/package_config.json');
  if (!file.existsSync()) {
    failures.add(
      '.dart_tool/package_config.json is missing; run flutter pub get',
    );
    return;
  }
  final config = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final packages = (config['packages']! as List<Object?>)
      .cast<Map<String, Object?>>();
  if (packages.any((package) => package['name'] == 'xterm')) {
    failures.add('xterm is present in the resolved package configuration');
  }
}

void _verifyPackageGraph(Directory root, List<String> failures) {
  final file = File('${root.path}/.dart_tool/package_graph.json');
  if (!file.existsSync()) {
    failures.add(
      '.dart_tool/package_graph.json is missing; run flutter pub get',
    );
    return;
  }
  final graph = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final packages = (graph['packages']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final byName = <String, Map<String, Object?>>{
    for (final package in packages) package['name']! as String: package,
  };
  final pending = <String>['termworld'];
  final reachable = <String>{};
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (!reachable.add(name)) continue;
    final package = byName[name];
    if (package == null) continue;
    pending.addAll(
      (package['dependencies']! as List<Object?>).cast<String>(),
    );
  }
  if (reachable.contains('xterm')) {
    failures.add('xterm is transitively reachable from termworld');
  }
}

void _verifyProductionSources(Directory package, List<String> failures) {
  final banned = <RegExp, String>{
    RegExp("package:xterm(?:/|['\"])"): 'package:xterm import/export',
    RegExp(r'\bXtermParityTerminal\b'): 'xterm parity wrapper',
    RegExp(r'\bxterm\.Terminal\b'): 'xterm terminal delegation',
    RegExp(r'\b_delegate\b'): 'delegate-based implementation',
  };
  final sources = Directory('${package.path}/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  for (final source in sources) {
    final contents = source.readAsStringSync();
    for (final entry in banned.entries) {
      if (entry.key.hasMatch(contents)) {
        failures.add(
          '${source.path.substring(package.path.length + 1)} contains '
          '${entry.value}',
        );
      }
    }
  }
}
