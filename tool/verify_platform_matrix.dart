import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Fails when a declared platform is missing a verification layer.
///
/// Declaring a platform in `flutter.plugin.platforms` is a promise that the
/// package behaves the same there. The layers below are what make that promise
/// checkable, and the most likely way to break it is not writing bad code — it
/// is adding a platform and forgetting one job. This tool makes that omission
/// a build failure instead of a silently green matrix.
///
/// Every declared platform needs:
///
/// * **L3** a native unit-test target in its own language;
/// * **L4** a CI step running the conformance suite on that platform;
/// * **L5** a CI step building the example app for that platform.
void main() {
  final root = File.fromUri(Platform.script).parent.parent.absolute.path;
  final violations = <String>[
    ...verifyPackages(root),
  ];
  if (violations.isEmpty) {
    stdout.writeln('Platform matrix verification passed.');
    return;
  }
  violations.forEach(stderr.writeln);
  exitCode = 1;
}

/// Native unit-test locations, relative to a package directory.
///
/// Web has no native language, so its L3 obligation is a Dart test dedicated
/// to the browser implementation rather than a foreign-language target.
const Map<String, List<String>> kNativeTestPaths = <String, List<String>>{
  'android': <String>['android/src/test'],
  'ios': <String>['ios/Tests', 'example/ios/RunnerTests'],
  'linux': <String>['linux/test'],
  'macos': <String>['macos/Tests', 'example/macos/RunnerTests'],
  'windows': <String>['windows/test'],
  'web': <String>['test/dropwell_web_test.dart'],
};

/// Checks every package below `packages/`.
List<String> verifyPackages(String root) {
  final workflow = File(p.join(root, '.github', 'workflows', 'ci.yml'));
  if (!workflow.existsSync()) {
    return <String>['.github/workflows/ci.yml is missing'];
  }
  final steps = _workflowStepNames(workflow);
  final violations = <String>[];
  final packages =
      Directory(
          p.join(root, 'packages'),
        ).listSync().whereType<Directory>().toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));

  for (final package in packages) {
    final name = p.basename(package.path);
    final manifest = File(p.join(package.path, 'pubspec.yaml'));
    if (!manifest.existsSync()) continue;
    final platforms = _declaredPlatforms(manifest);
    final conformancePlatforms = _conformancePlatforms(package);

    for (final platform in platforms) {
      final candidates = kNativeTestPaths[platform];
      if (candidates == null) {
        violations.add('$name: $platform has no known native test location');
        continue;
      }
      final hasNativeTests = candidates.any(
        (candidate) => _exists(p.join(package.path, candidate)),
      );
      if (!hasNativeTests) {
        violations.add(
          '$name: $platform is missing L3 native tests '
          '(expected one of ${candidates.join(', ')})',
        );
      }
      for (final layer in const <String>['L4', 'L5']) {
        final marker = '$layer $platform';
        if (!steps.any((step) => step.startsWith(marker))) {
          violations.add(
            '$name: $platform is missing a CI step named "$marker …"',
          );
        }
      }
    }
    for (final platform in conformancePlatforms) {
      for (final layer in const <String>['L4', 'L5']) {
        final marker = '$layer $platform $name';
        if (!steps.any((step) => step.startsWith(marker))) {
          violations.add(
            '$name: $platform is missing a CI step named "$marker …"',
          );
        }
      }
    }
  }
  return violations;
}

Set<String> _conformancePlatforms(Directory package) {
  final declaration = File(p.join(package.path, 'platforms.yaml'));
  if (!declaration.existsSync()) return const <String>{};
  final document = loadYaml(declaration.readAsStringSync());
  if (document is! YamlMap || document['platforms'] is! YamlList) {
    return const <String>{};
  }
  return (document['platforms'] as YamlList).whereType<String>().toSet();
}

Set<String> _declaredPlatforms(File manifest) {
  final document = loadYaml(manifest.readAsStringSync());
  if (document is! YamlMap) return const <String>{};
  final flutter = document['flutter'];
  if (flutter is! YamlMap) return const <String>{};
  final plugin = flutter['plugin'];
  if (plugin is! YamlMap) return const <String>{};
  final platforms = plugin['platforms'];
  if (platforms is! YamlMap) return const <String>{};
  return platforms.keys.whereType<String>().toSet();
}

List<String> _workflowStepNames(File workflow) {
  final document = loadYaml(workflow.readAsStringSync());
  if (document is! YamlMap) return const <String>[];
  final jobs = document['jobs'];
  if (jobs is! YamlMap) return const <String>[];
  return <String>[
    for (final job in jobs.values)
      if (job is YamlMap)
        for (final step
            in job['steps'] is YamlList
                ? job['steps'] as YamlList
                : const <Object?>[])
          if (step is YamlMap && step['name'] is String) step['name'] as String,
  ];
}

bool _exists(String path) =>
    File(path).existsSync() || Directory(path).existsSync();
