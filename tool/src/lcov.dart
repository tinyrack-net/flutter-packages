import 'dart:io';

import 'package:path/path.dart' as p;

/// Coverage totals for one package.
final class CoverageTotals {
  /// Creates totals.
  const CoverageTotals({
    required this.linesFound,
    required this.linesHit,
    required this.branchesFound,
    required this.branchesHit,
    required this.missingFiles,
  });

  /// Executable lines in the report.
  final int linesFound;

  /// Executable lines hit by tests.
  final int linesHit;

  /// Branches in the report.
  final int branchesFound;

  /// Branches hit by tests.
  final int branchesHit;

  /// Production sources absent from the report.
  final List<String> missingFiles;

  /// Fraction of executable lines hit.
  double get lineRate => linesFound == 0 ? 0 : linesHit / linesFound;

  /// Fraction of branches hit.
  double get branchRate => branchesFound == 0 ? 0 : branchesHit / branchesFound;
}

/// Reads an LCOV report and enforces per-package thresholds.
///
/// A production source missing from the report counts as zero, not as absent.
/// Otherwise deleting a test would raise the reported rate, which is the one
/// way a coverage gate can reward the wrong thing.
final class CoverageVerifier {
  /// Creates a verifier.
  const CoverageVerifier({
    this.minimumLineRate = 0.9,
    this.minimumBranchRate = 0.8,
  });

  /// Minimum accepted line-coverage fraction.
  final double minimumLineRate;

  /// Minimum accepted branch-coverage fraction.
  final double minimumBranchRate;

  /// Calculates totals for the package rooted at [packageDirectory].
  CoverageTotals calculate(String packageDirectory, File lcov) {
    final root = p.normalize(p.absolute(packageDirectory));
    if (!lcov.existsSync()) {
      throw StateError('Coverage report not found: ${lcov.path}');
    }
    final records = _parseLcov(lcov.readAsLinesSync(), root);
    var linesFound = 0;
    var linesHit = 0;
    var branchesFound = 0;
    var branchesHit = 0;
    final missing = <String>[];
    for (final source in _productionSources(root)) {
      final record = records[source];
      if (record == null) {
        final estimated = _estimatedExecutableLines(File(source));
        if (estimated > 0) {
          missing.add(p.relative(source, from: root));
          linesFound += estimated;
        }
        continue;
      }
      linesFound += record.linesFound;
      linesHit += record.linesHit;
      branchesFound += record.branchesFound;
      branchesHit += record.branchesHit;
    }
    return CoverageTotals(
      linesFound: linesFound,
      linesHit: linesHit,
      branchesFound: branchesFound,
      branchesHit: branchesHit,
      missingFiles: missing,
    );
  }

  /// Returns an error message when [totals] miss a threshold.
  String? validate(String packageName, CoverageTotals totals) {
    if (totals.lineRate >= minimumLineRate &&
        totals.branchRate >= minimumBranchRate &&
        totals.missingFiles.isEmpty) {
      return null;
    }
    final missing = totals.missingFiles.isEmpty
        ? ''
        : ' missing=${totals.missingFiles.join(',')}';
    return '$packageName: line=${percent(totals.lineRate)} '
        'branch=${percent(totals.branchRate)}$missing';
  }

  /// Formats [value] as a percentage.
  static String percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

  Map<String, _CoverageRecord> _parseLcov(List<String> lines, String root) {
    final records = <String, _CoverageRecord>{};
    String? source;
    var linesFound = 0;
    var linesHit = 0;
    var branchesFound = 0;
    var branchesHit = 0;

    void finish() {
      final current = source;
      if (current == null) return;
      records[p.normalize(
        p.isAbsolute(current) ? current : p.join(root, current),
      )] = _CoverageRecord(
        linesFound: linesFound,
        linesHit: linesHit,
        branchesFound: branchesFound,
        branchesHit: branchesHit,
      );
      source = null;
      linesFound = 0;
      linesHit = 0;
      branchesFound = 0;
      branchesHit = 0;
    }

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        finish();
        source = line.substring(3);
      } else if (line.startsWith('LF:')) {
        linesFound = int.parse(line.substring(3));
      } else if (line.startsWith('LH:')) {
        linesHit = int.parse(line.substring(3));
      } else if (line.startsWith('BRDA:')) {
        branchesFound += 1;
        final count = line.substring(line.lastIndexOf(',') + 1);
        if (count != '-' && int.parse(count) > 0) branchesHit += 1;
      } else if (line == 'end_of_record') {
        finish();
      }
    }
    finish();
    return records;
  }

  /// Production sources whose coverage the Dart VM can measure.
  ///
  /// A `lib/*_web.dart` entry point imports `dart:ui_web` transitively and can
  /// only load in a browser, where `flutter test --coverage` collects nothing.
  /// Counting it as zero would punish having a web implementation at all, so it
  /// is excluded here and covered instead by its mandatory browser-only L3
  /// suite, which tool/verify_platform_matrix.dart requires to exist.
  List<String> _productionSources(String root) {
    final lib = Directory(p.join(root, 'lib'));
    if (!lib.existsSync()) return const <String>[];
    return <String>[
      for (final entity in lib.listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !entity.path.endsWith('.g.dart') &&
            !entity.path.endsWith('.freezed.dart') &&
            !entity.path.endsWith('_web.dart'))
          p.normalize(p.absolute(entity.path)),
    ]..sort();
  }

  /// Estimates the executable lines of a source the report never mentioned.
  ///
  /// A library that only re-exports has nothing to execute and nothing to
  /// cover, so counting its directives as uncovered lines would turn an entry
  /// point into a coverage liability. Anything with a real body still counts
  /// in full: an untested file must not be able to hide by being absent.
  int _estimatedExecutableLines(File file) {
    final executable = file
        .readAsLinesSync()
        .where(_isExecutableLine)
        .toList(growable: false);
    if (executable.isEmpty) return 0;
    final hasBody = RegExp(
      r'=>|\b(await|return|throw|if|switch|try|for|while)\b|\bmain\s*\(',
    ).hasMatch(executable.join('\n'));
    return hasBody ? executable.length : 0;
  }

  bool _isExecutableLine(String line) {
    final trimmed = line.trim();
    return trimmed.isNotEmpty &&
        !trimmed.startsWith('//') &&
        !trimmed.startsWith('///') &&
        trimmed != '{' &&
        trimmed != '}' &&
        trimmed != ');' &&
        !trimmed.startsWith('library') &&
        !trimmed.startsWith('import ') &&
        !trimmed.startsWith('export ') &&
        !trimmed.startsWith('part ');
  }
}

final class _CoverageRecord {
  const _CoverageRecord({
    required this.linesFound,
    required this.linesHit,
    required this.branchesFound,
    required this.branchesHit,
  });

  final int linesFound;
  final int linesHit;
  final int branchesFound;
  final int branchesHit;
}
