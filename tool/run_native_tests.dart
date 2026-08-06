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
    'macos' => await _xcodebuild(package, 'macos', 'platform=macOS'),
    'ios' => await _xcodebuild(
      package,
      'ios',
      'platform=iOS Simulator,name=iPhone 16',
      configureArguments: const <String>['--simulator'],
    ),
    // A browser test compiles against its own package root, so it must run
    // from the package directory rather than the workspace root.
    'web' => await _run(
      _flutter,
      <String>['test', 'test/dropwell_web_test.dart', '--platform', 'chrome'],
      package,
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

/// Runs the example project's XCTest target for an Apple platform.
///
/// The example app owns the Xcode project, so its test target is where a Swift
/// unit test can link against the plugin. Code signing is disabled because
/// these tests run on a simulator or the host, where a developer certificate
/// would only be a CI liability; `DROPWELL_XCODE_DESTINATION` lets CI name the
/// simulator it actually booted instead of guessing a device model that a new
/// Xcode release may have dropped.
Future<int> _xcodebuild(
  String package,
  String platform,
  String defaultDestination, {
  List<String> configureArguments = const <String>[],
}) async {
  final directory = p.join(package, 'example', platform);
  final precache = await _run(_flutter, <String>[
    'build',
    platform,
    '--config-only',
    '--debug',
    ...configureArguments,
  ], p.join(package, 'example'));
  if (precache != 0) return precache;
  final destination =
      Platform.environment['DROPWELL_XCODE_DESTINATION'] ?? defaultDestination;
  return _run('xcodebuild', <String>[
    'test',
    '-workspace',
    'Runner.xcworkspace',
    '-scheme',
    'Runner',
    '-destination',
    destination,
    'CODE_SIGNING_ALLOWED=NO',
    'CODE_SIGNING_REQUIRED=NO',
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
