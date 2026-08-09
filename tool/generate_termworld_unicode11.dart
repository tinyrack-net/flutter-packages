import 'dart:io';

/// Ports the pinned xterm Unicode 11 interval tables into dependency-free Dart.
void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/generate_termworld_unicode11.dart <xterm-root>',
    );
    exitCode = 64;
    return;
  }
  final xterm = Directory(arguments.single).absolute;
  const revision = '904ae935269eef5ec6a1415b64463c3d02eff1eb';
  final actual = Process.runSync(
    'git',
    const <String>['rev-parse', 'HEAD'],
    workingDirectory: xterm.path,
  );
  if (actual.exitCode != 0 || (actual.stdout as String).trim() != revision) {
    stderr.writeln('xterm checkout is not at the approved revision');
    exitCode = 65;
    return;
  }
  final source = File(
    '${xterm.path}/addons/addon-unicode11/src/UnicodeV11.ts',
  ).readAsStringSync();
  final output = StringBuffer()
    ..writeln('// Generated from xterm.js $revision; do not edit.')
    ..writeln('// Copyright xterm.js authors; MIT license.')
    ..writeln("part of 'unicode.dart';")
    ..writeln();
  for (final mapping in const <(String, String)>[
    ('BMP_COMBINING', '_unicode11BmpCombining'),
    ('HIGH_COMBINING', '_unicode11HighCombining'),
    ('BMP_WIDE', '_unicode11BmpWide'),
    ('HIGH_WIDE', '_unicode11HighWide'),
  ]) {
    final body = RegExp(
      'const ${mapping.$1} = \\[(.*?)\\];',
      dotAll: true,
    ).firstMatch(source)?.group(1);
    if (body == null) {
      throw StateError('Missing ${mapping.$1} in UnicodeV11.ts');
    }
    final ranges = RegExp(
      r'\[(0x[0-9A-Fa-f]+),\s*(0x[0-9A-Fa-f]+)\]',
    ).allMatches(body);
    output.writeln('const ${mapping.$2} = <(int, int)>[');
    for (final range in ranges) {
      output.writeln('  (${range.group(1)}, ${range.group(2)}),');
    }
    output
      ..writeln('];')
      ..writeln();
  }
  final unicode6Source = File(
    '${xterm.path}/src/common/input/UnicodeV6.ts',
  ).readAsStringSync();
  for (final mapping in const <(String, String)>[
    ('BMP_COMBINING', '_unicode6BmpCombining'),
    ('HIGH_COMBINING', '_unicode6HighCombining'),
  ]) {
    final body = RegExp(
      'const ${mapping.$1} = \\[(.*?)\\];',
      dotAll: true,
    ).firstMatch(unicode6Source)?.group(1);
    if (body == null) {
      throw StateError('Missing ${mapping.$1} in UnicodeV6.ts');
    }
    final ranges = RegExp(
      r'\[(0x[0-9A-Fa-f]+),\s*(0x[0-9A-Fa-f]+)\]',
    ).allMatches(body);
    output.writeln('const ${mapping.$2} = <(int, int)>[');
    for (final range in ranges) {
      output.writeln('  (${range.group(1)}, ${range.group(2)}),');
    }
    output
      ..writeln('];')
      ..writeln();
  }
  final repository = File.fromUri(Platform.script).parent.parent.absolute;
  File(
    '${repository.path}/packages/termworld/lib/src/core/'
    'unicode11_tables.g.dart',
  ).writeAsStringSync(output.toString());
}
