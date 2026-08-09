import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/lcov.dart';

/// Runs `flutter test --coverage` per package and enforces the coverage gate.
///
/// Pass package names to restrict the run; passing none checks every package
/// under `packages/`.
Future<void> main(List<String> arguments) async {
  final root = File.fromUri(Platform.script).parent.parent.absolute.path;
  final packagesRoot = Directory(p.join(root, 'packages'));
  final available =
      packagesRoot
          .listSync()
          .whereType<Directory>()
          .map((entry) => p.basename(entry.path))
          .toList()
        ..sort();
  final requested = arguments.isEmpty ? available : arguments;
  final unknown = requested.where((name) => !available.contains(name)).toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown package: ${unknown.join(', ')}');
    exitCode = 64;
    return;
  }

  const verifier = CoverageVerifier();
  final failures = <String>[];
  for (final name in requested) {
    final directory = p.join(root, 'packages', name);
    final coverage = Directory(p.join(directory, 'coverage'));
    if (coverage.existsSync()) coverage.deleteSync(recursive: true);

    final process = await Process.start(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      <String>[
        'test',
        'test',
        '--coverage',
        '--branch-coverage',
        '--reporter=expanded',
        '--test-randomize-ordering-seed=random',
      ],
      workingDirectory: directory,
      mode: ProcessStartMode.inheritStdio,
    );
    if (await process.exitCode != 0) {
      failures.add('$name: tests failed');
      continue;
    }

    final totals = verifier.calculate(
      directory,
      File(p.join(directory, 'coverage', 'lcov.info')),
    );
    stdout.writeln(
      '$name: line=${CoverageVerifier.percent(totals.lineRate)} '
      'branch=${CoverageVerifier.percent(totals.branchRate)}',
    );
    final failure = verifier.validate(name, totals);
    if (failure != null) failures.add(failure);
  }

  if (failures.isEmpty) {
    stdout.writeln('Coverage verification passed.');
    return;
  }
  failures.forEach(stderr.writeln);
  exitCode = 1;
}
