import 'dart:io';

import 'package:path/path.dart' as p;

/// Runs the L3 native unit tests for one platform.
///
/// Each platform's parsing and marshalling code is compiled and run in its own
/// language, without Flutter. That is deliberate: the bugs this layer catches —
/// a mis-parsed `text/uri-list`, a wrong pasteboard type priority, a
/// `CF_HDROP` walked with the wrong stride — are invisible from Dart until a
/// user drops a file with a space in its name.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('usage: run_native_tests.dart <platform>');
    exitCode = 64;
    return;
  }
  final platform = arguments.single;
  final root = File.fromUri(Platform.script).parent.parent.absolute.path;
  final package = p.join(root, 'packages', 'dropwell');

  final example = p.join(package, 'example');
  final code = switch (platform) {
    'windows' => await _gtest(
      example,
      'windows',
      'build/windows/x64/plugins/dropwell/Debug/dropwell_test.exe',
    ),
    'linux' => await _gtest(
      example,
      'linux',
      'build/linux/x64/debug/plugins/dropwell/dropwell_test',
    ),
    'android' => await _gradle(example),
    'macos' => await _xcodebuild(package, 'macos', 'macOS'),
    'ios' => await _xcodebuild(
      package,
      'ios',
      'iOS Simulator,name=iPhone 16',
    ),
    'web' => await _run(
      _flutter,
      <String>[
        'test',
        'packages/dropwell/test/dropwell_web_test.dart',
        '--platform',
        'chrome',
      ],
      root,
    ),
    _ => _unknown(platform),
  };
  exitCode = code;
}

int _unknown(String platform) {
  stderr.writeln('Unknown platform: $platform');
  return 64;
}

String get _flutter => Platform.isWindows ? 'flutter.bat' : 'flutter';

/// Builds the example in Debug and runs the plugin's googletest binary.
///
/// The plugin's own `CMakeLists.txt` only adds its test target when the
/// example configures it, so the example Debug build is what compiles the
/// native tests; there is no second CMake project to keep in sync. The binary
/// is run directly rather than through `ctest`, which is not on `PATH` in a
/// Visual Studio install.
Future<int> _gtest(
  String example,
  String platform,
  String binaryPath,
) async {
  final build = await _run(_flutter, <String>[
    'build',
    platform,
    '--debug',
  ], example);
  if (build != 0) return build;
  final binary = p.join(example, binaryPath);
  if (!File(binary).existsSync()) {
    stderr.writeln('Native test binary not built: $binary');
    return 1;
  }
  return _run(binary, const <String>[], example);
}

Future<int> _gradle(String example) async {
  // `--config-only` writes the Gradle wiring that makes the plugin module
  // buildable without also producing an APK.
  final configure = await _run(_flutter, <String>[
    'build',
    'apk',
    '--config-only',
    '--debug',
  ], example);
  if (configure != 0) return configure;
  return _run(
    Platform.isWindows ? 'gradlew.bat' : './gradlew',
    <String>[':dropwell:testDebugUnitTest'],
    p.join(example, 'android'),
  );
}

Future<int> _xcodebuild(
  String package,
  String platform,
  String destination,
) async {
  // The example app owns the Xcode project, so its test target is where a
  // Swift unit test can link against the plugin.
  final directory = p.join(package, 'example', platform);
  final precache = await _run(_flutter, <String>[
    'build',
    platform,
    '--config-only',
    '--debug',
  ], p.join(package, 'example'));
  if (precache != 0) return precache;
  return _run('xcodebuild', <String>[
    'test',
    '-workspace',
    'Runner.xcworkspace',
    '-scheme',
    'Runner',
    '-destination',
    'platform=$destination',
  ], directory);
}

Future<int> _run(
  String executable,
  List<String> arguments,
  String workingDirectory,
) async {
  stdout.writeln('> $executable ${arguments.join(' ')}  ($workingDirectory)');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  return process.exitCode;
}
