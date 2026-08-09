import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    stderr.writeln(
      'usage: dart run tool/run_flutter_test_shard.dart '
      '<package> <shard-index> <shard-count>',
    );
    exitCode = 64;
    return;
  }
  final package = arguments[0];
  final shardIndex = int.parse(arguments[1]);
  final shardCount = int.parse(arguments[2]);
  if (shardCount < 1 || shardIndex < 0 || shardIndex >= shardCount) {
    stderr.writeln('invalid shard $shardIndex of $shardCount');
    exitCode = 64;
    return;
  }
  final testDirectory = Directory('$package/test');
  final tests =
      testDirectory
          .listSync()
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => path.endsWith('_test.dart'))
          .toList()
        ..sort();
  final selected = <String>[
    for (var index = 0; index < tests.length; index++)
      if (index % shardCount == shardIndex)
        tests[index].substring(package.length + 1),
  ];
  if (selected.isEmpty) {
    stderr.writeln('shard $shardIndex of $shardCount contains no tests');
    exitCode = 65;
    return;
  }
  stdout.writeln(
    'Running ${selected.length}/${tests.length} tests in shard '
    '$shardIndex of $shardCount',
  );
  final process = await Process.start(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    <String>[
      'test',
      ...selected,
      '--reporter=expanded',
      '--test-randomize-ordering-seed=random',
      '--timeout=30s',
    ],
    workingDirectory: package,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}
