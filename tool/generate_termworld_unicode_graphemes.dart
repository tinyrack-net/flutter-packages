import 'dart:convert';
import 'dart:io';

/// Generates the dependency-free Unicode 15 property table from pinned xterm.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/generate_termworld_unicode_graphemes.dart <xterm-root>',
    );
    exitCode = 64;
    return;
  }
  final xterm = Directory(arguments.single).absolute;
  const revision = '904ae935269eef5ec6a1415b64463c3d02eff1eb';
  final actualRevision = await _run('git', <String>[
    'rev-parse',
    'HEAD',
  ], xterm);
  if (actualRevision.trim() != revision) {
    stderr.writeln('Expected $revision, found ${actualRevision.trim()}');
    exitCode = 65;
    return;
  }

  final temporary = await Directory.systemTemp.createTemp(
    'termworld-unicode15-',
  );
  try {
    final source =
        '${xterm.path}/addons/addon-unicode-graphemes/src/third-party';
    await _run(
      '${xterm.path}/node_modules/.bin/tsc',
      <String>[
        '--target',
        'ES2020',
        '--module',
        'commonjs',
        '--outDir',
        temporary.path,
        '--skipLibCheck',
        '$source/UnicodeProperties.ts',
        '$source/unicode-trie.ts',
        '$source/tiny-inflate.ts',
      ],
      xterm,
    );
    final modulePath = jsonEncode('${temporary.path}/UnicodeProperties.js');
    final encoded = await _run(
      'node',
      <String>[
        '-e',
        '''const u=require($modulePath);const r=[];let s=0,v=u.getInfo(0);for(let c=1;c<=0x10ffff;c++){const n=u.getInfo(c);if(n!==v){r.push([s,c-1,v]);s=c;v=n;}}r.push([s,0x10ffff,v]);process.stdout.write(JSON.stringify(r));''',
      ],
      xterm,
    );
    final ranges = jsonDecode(encoded) as List<Object?>;
    final output = StringBuffer()
      ..writeln("part of 'addon_unicode_graphemes.dart';")
      ..writeln()
      ..writeln('// Generated from xterm.js $revision. Do not edit.')
      ..writeln(
        'const List<(int, int, int)> _unicode15Properties = <(int, int, int)>[',
      );
    for (final item in ranges.cast<List<Object?>>()) {
      output.writeln('  (${item[0]}, ${item[1]}, ${item[2]}),');
    }
    output.writeln('];');
    final repository = File.fromUri(Platform.script).parent.parent;
    File(
      '${repository.path}/packages/termworld/lib/unicode15_properties.g.dart',
    ).writeAsStringSync(output.toString());
    stdout.writeln('Generated ${ranges.length} Unicode 15 property ranges.');
  } finally {
    temporary.deleteSync(recursive: true);
  }
}

Future<String> _run(
  String executable,
  List<String> arguments, [
  Directory? workingDirectory,
]) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory?.path,
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
