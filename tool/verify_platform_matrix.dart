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
  'web': <String>[
    'test/dropwell_web_test.dart',
    'test/termworld_web_test.dart',
  ],
};

/// L3 locations for packages that declare platforms through platforms.yaml.
const Map<String, List<String>> kConformanceNativeTestPaths =
    <String, List<String>>{
      'android': <String>['example/android/app/src/test'],
      'ios': <String>['example/ios/RunnerTests'],
      'linux': <String>['example/linux/test'],
      'macos': <String>['example/macos/RunnerTests'],
      'windows': <String>['example/windows/test'],
      'web': <String>['test/termworld_web_test.dart'],
    };

/// Checks every package below `packages/`.
List<String> verifyPackages(String root) {
  final workflow = File(p.join(root, '.github', 'workflows', 'ci.yml'));
  if (!workflow.existsSync()) {
    return <String>['.github/workflows/ci.yml is missing'];
  }
  final steps = _workflowStepNames(workflow);
  final violations = <String>[
    ..._verifyIosSimulatorRecovery(root, workflow),
    ...verifyTermworldAndroidInputBoundary(root, workflow),
  ];
  final ibusRunner = File(p.join(root, 'tool', 'run_linux_ibus_e2e.sh'));
  final workflowText = <String>[
    workflow.readAsStringSync(),
    if (ibusRunner.existsSync()) ibusRunner.readAsStringSync(),
  ].join('\n');
  if (!workflowText.contains('dart test test/tool')) {
    violations.add('tool: CI must execute the repository tooling tests');
  }
  const ibusMarkers = <String>[
    'Linux IBus Hangul E2E',
    'subosito/flutter-action@v2',
    'ibus-gtk3',
    'ibus-hangul',
    'xdotool',
    'xclip',
    'dbus-run-session',
    'linux_ibus_e2e_test.dart',
  ];
  for (final marker in ibusMarkers) {
    if (!workflowText.contains(marker)) {
      violations.add('termworld: Linux IBus CI is missing "$marker"');
    }
  }
  for (final browser in const <String>['chromium', 'firefox', 'webkit']) {
    final marker = '          - $browser';
    if (!workflowText.contains(marker)) {
      violations.add('termworld: browser matrix is missing "$browser"');
    }
  }
  if (!workflowText.contains('L4 web termworld browser conformance')) {
    violations.add('termworld: cross-browser L4 renderer step is missing');
  }
  if (workflowText.contains('mise')) {
    violations.add(
      'termworld: Linux IBus CI must use the workflow-installed Flutter SDK',
    );
  }
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
      final candidates = kConformanceNativeTestPaths[platform];
      if (candidates == null ||
          !candidates.any(
            (candidate) => _exists(p.join(package.path, candidate)),
          )) {
        violations.add('$name: $platform is missing L3 input-boundary tests');
      }
      for (final layer in const <String>['L3', 'L4', 'L5']) {
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

/// Verifies termworld's real Android `FlutterView`/`InputConnection` pyramid.
///
/// The ordinary cross-platform conformance test intentionally drives Dart's
/// `TextInputClient` directly. Android IMEs operate one boundary lower, so the
/// package also owns a Debug-only app driver, a separately installed test IME,
/// a shared transaction fixture, and required API 24/35 emulator evidence. The
/// IME operates on its system-provided `currentInputConnection`; it must not
/// create a second `FlutterView` connection inside the application process.
/// Keeping these requirements here prevents a green CI edit from silently
/// returning to the mocked boundary.
List<String> verifyTermworldAndroidInputBoundary(String root, File workflow) {
  final violations = <String>[];
  final termworld = p.join(root, 'packages', 'termworld');
  final requiredFiles = <String, String>{
    p.join(
      termworld,
      'example',
      'assets',
      'ime',
      'android_input_connection_cases.json',
    ): 'shared Android input transaction fixture',
    p.join(
      termworld,
      'example',
      'integration_test',
      'android_input_connection_test.dart',
    ): 'native-boundary Android E2E',
    p.join(
      termworld,
      'example',
      'android',
      'app',
      'src',
      'debug',
      'kotlin',
      'com',
      'example',
      'termworld_example',
      'DebugMainActivity.kt',
    ): 'Debug-only Android InputConnection driver',
    p.join(
      termworld,
      'example',
      'android',
      'ime_harness',
      'build.gradle.kts',
    ): 'separate Android IME harness application module',
    p.join(
      termworld,
      'example',
      'android',
      'ime_harness',
      'src',
      'main',
      'AndroidManifest.xml',
    ): 'separate Android IME harness manifest',
    p.join(
      termworld,
      'example',
      'android',
      'ime_harness',
      'src',
      'main',
      'kotlin',
      'com',
      'example',
      'termworld_ime_harness',
      'TermworldTestInputMethodService.kt',
    ): 'separate deterministic Android test IME',
    p.join(
      termworld,
      'example',
      'android',
      'ime_harness',
      'src',
      'main',
      'kotlin',
      'com',
      'example',
      'termworld_ime_harness',
      'HarnessInputCommand.kt',
    ): 'Android test IME command contract',
    p.join(
      termworld,
      'example',
      'android',
      'ime_harness',
      'src',
      'test',
      'kotlin',
      'com',
      'example',
      'termworld_ime_harness',
      'HarnessInputCommandTest.kt',
    ): 'Android test IME command contract tests',
    p.join(
      termworld,
      'example',
      'android',
      'ime_harness',
      'src',
      'main',
      'res',
      'xml',
      'termworld_test_input_method.xml',
    ): 'separate Android test IME metadata',
    p.join(
      termworld,
      'example',
      'android',
      'app',
      'src',
      'test',
      'kotlin',
      'com',
      'example',
      'termworld_example',
      'AndroidInputDriverCommandTest.kt',
    ): 'Android driver command contract test',
    p.join(root, 'tool', 'run_android_input_connection_e2e.dart'):
        'deterministic Android InputConnection E2E runner',
    p.join(root, 'tool', 'run_android_termworld_input_ci.sh'):
        'single-shell Android InputConnection CI runner',
  };
  for (final entry in requiredFiles.entries) {
    if (!File(entry.key).existsSync()) {
      violations.add('termworld: missing ${entry.value}');
    }
  }

  final driver = File(
    p.join(
      termworld,
      'example',
      'android',
      'app',
      'src',
      'debug',
      'kotlin',
      'com',
      'example',
      'termworld_example',
      'DebugMainActivity.kt',
    ),
  );
  final fixture = File(
    p.join(
      termworld,
      'example',
      'assets',
      'ime',
      'android_input_connection_cases.json',
    ),
  );
  if (!fixture.existsSync() ||
      !fixture.readAsStringSync().contains('"op": "repeat"')) {
    violations.add(
      'termworld: Android fixture must cover unbarriered repeated input',
    );
  }
  if (driver.existsSync()) {
    final source = driver.readAsStringSync();
    for (final marker in const <String>[
      'completeAfterInputQueue',
      'TextInputClient.onFocusReceived',
      'FIFO_BARRIER_CLIENT_ID = -2',
      'TextInputClient.onConnectionClosed',
      'sendAppPrivateCommand',
      'import android.os.Messenger',
      'replyMessenger',
      'termworld.testing.INPUT_CONNECTION',
      'termworld/testing',
      'JSONMethodCodec.INSTANCE',
      'termworld-android-input-connection-driver',
    ]) {
      if (!source.contains(marker)) {
        violations.add('termworld: Android Debug driver is missing "$marker"');
      }
    }
    if (source.contains('onCreateInputConnection')) {
      violations.add(
        'termworld: Android Debug driver must use the system-owned '
        'InputConnection',
      );
    }
  }

  final commandDriver = File(
    p.join(
      termworld,
      'example',
      'android',
      'app',
      'src',
      'debug',
      'kotlin',
      'com',
      'example',
      'termworld_example',
      'AndroidInputDriverCommand.kt',
    ),
  );
  if (!commandDriver.existsSync() ||
      !commandDriver.readAsStringSync().contains('data class Repeat')) {
    violations.add(
      'termworld: Android driver must repeat commands before its Dart barrier',
    );
  }

  final harnessIme = File(
    p.join(
      termworld,
      'example',
      'android',
      'ime_harness',
      'src',
      'main',
      'kotlin',
      'com',
      'example',
      'termworld_ime_harness',
      'TermworldTestInputMethodService.kt',
    ),
  );
  if (harnessIme.existsSync()) {
    final source = harnessIme.readAsStringSync();
    for (final marker in const <String>[
      'InputMethodService',
      'currentInputConnection',
      'onAppPrivateCommand',
      'import android.os.Message',
      'import android.os.Messenger',
      'replyMessenger',
      'termworld.testing.INPUT_CONNECTION',
      'termworld-android-input-connection-ime-harness',
    ]) {
      if (!source.contains(marker)) {
        violations.add('termworld: Android test IME is missing "$marker"');
      }
    }
  }

  final androidSettings = File(
    p.join(termworld, 'example', 'android', 'settings.gradle.kts'),
  );
  if (!androidSettings.existsSync() ||
      !androidSettings.readAsStringSync().contains(
        'include(":app", ":ime_harness")',
      )) {
    violations.add('termworld: Android must include the separate IME module');
  }

  final harnessBuild = File(
    p.join(termworld, 'example', 'android', 'ime_harness', 'build.gradle.kts'),
  );
  if (!harnessBuild.existsSync() ||
      !harnessBuild.readAsStringSync().contains(
        'applicationId = "com.example.termworld_ime_harness"',
      )) {
    violations.add(
      'termworld: Android test IME must use its isolated application id',
    );
  }

  final harnessManifest = File(
    p.join(
      termworld,
      'example',
      'android',
      'ime_harness',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  if (harnessManifest.existsSync()) {
    final source = harnessManifest.readAsStringSync();
    for (final marker in const <String>[
      '.TermworldTestInputMethodService',
      'android.permission.BIND_INPUT_METHOD',
      'android.view.InputMethod',
      '@xml/termworld_test_input_method',
    ]) {
      if (!source.contains(marker)) {
        violations.add(
          'termworld: Android test IME manifest is missing "$marker"',
        );
      }
    }
  }

  final appDebugManifest = File(
    p.join(
      termworld,
      'example',
      'android',
      'app',
      'src',
      'debug',
      'AndroidManifest.xml',
    ),
  );
  if (appDebugManifest.existsSync() &&
      appDebugManifest.readAsStringSync().contains('<service')) {
    violations.add(
      'termworld: the example app must not embed the Android test IME',
    );
  }

  final releaseVerifier = File(
    p.join(root, 'tool', 'verify_release_hooks.dart'),
  );
  if (!releaseVerifier.existsSync() ||
      !const <String>[
        'termworld-android-input-connection-driver',
        'termworld-android-input-connection-ime-harness',
        'termworld.testing.INPUT_CONNECTION',
        'TermworldTestInputMethodService',
        'com.example.termworld_ime_harness',
      ].every(releaseVerifier.readAsStringSync().contains)) {
    violations.add(
      'termworld: release-hook verification must reject Android test drivers',
    );
  }

  final inputRunner = File(
    p.join(root, 'tool', 'run_android_input_connection_e2e.dart'),
  );
  if (inputRunner.existsSync()) {
    final source = inputRunner.readAsStringSync();
    for (final marker in const <String>[
      'integration_test/android_input_connection_test.dart',
      "'build', 'apk', '--debug'",
      ':ime_harness:assembleDebug',
      'ime_harness-debug.apk',
      "'install', '-r'",
      'get-current-user',
      "Android 7.0's `ime` shell command has no `--user` option",
      'default_input_method',
      'com.example.termworld_ime_harness/.TermworldTestInputMethodService',
      'final installedImes',
      "'enable'",
      "'set'",
      "'dumpsys', 'input_method'",
      'TERMWORLD_ANDROID_IME_ISOLATION=active',
      'TERMWORLD_ANDROID_IME_ISOLATION=restored',
    ]) {
      if (!source.contains(marker)) {
        violations.add(
          'termworld: Android input runner is missing "$marker"',
        );
      }
    }
  }

  final ciRunner = File(
    p.join(root, 'tool', 'run_android_termworld_input_ci.sh'),
  );
  if (ciRunner.existsSync()) {
    final source = ciRunner.readAsStringSync();
    for (final marker in const <String>[
      r'flutter test integration_test/conformance_test.dart -d "$device"',
      r'dart run tool/run_android_input_connection_e2e.dart --device "$device"',
      r'${PIPESTATUS[0]}',
      r'adb -s "$device" logcat -d',
      r'adb -s "$device" shell dumpsys input_method',
      'TERMWORLD_ANDROID_FIXTURE=',
      r'${RUNNER_TEMP:-$repository_root/build}',
    ]) {
      if (!source.contains(marker)) {
        violations.add(
          'termworld: Android CI runner is missing "$marker"',
        );
      }
    }
  }

  final document = loadYaml(workflow.readAsStringSync());
  final jobs = document is YamlMap ? document['jobs'] : null;
  final androidJob = jobs is YamlMap ? jobs['android-termworld'] : null;
  if (androidJob is! YamlMap) {
    return <String>[
      ...violations,
      'termworld: CI has no android-termworld job',
    ];
  }

  final strategy = androidJob['strategy'];
  final matrix = strategy is YamlMap ? strategy['matrix'] : null;
  final apiLevels = matrix is YamlMap ? matrix['api-level'] : null;
  final configuredApiLevels = apiLevels is YamlList
      ? apiLevels.whereType<int>().toSet()
      : const <int>{};
  for (final apiLevel in const <int>[24, 35]) {
    if (!configuredApiLevels.contains(apiLevel)) {
      violations.add(
        'termworld: Android native-boundary CI is missing API $apiLevel',
      );
    }
  }

  final steps = androidJob['steps'];
  if (steps is! YamlList) {
    return <String>[...violations, 'termworld: android-termworld has no steps'];
  }
  final jobSteps = steps.whereType<YamlMap>().toList(growable: false);
  final l3Steps = jobSteps
      .where(
        (step) => step['name'] == 'L3 android termworld input boundary tests',
      )
      .toList(growable: false);
  final l3Script = '${l3Steps.singleOrNull?['run'] ?? ''}';
  if (l3Steps.length != 1 ||
      !l3Script.contains(
        ':app:testDebugUnitTest :ime_harness:testDebugUnitTest',
      )) {
    violations.add(
      'termworld: Android L3 must run the app and IME harness unit tests',
    );
  }

  final l4Steps = jobSteps
      .where(
        (step) => step['name'] == 'L4 android termworld conformance suite',
      )
      .toList(growable: false);
  final l4Inputs = l4Steps.singleOrNull?['with'];
  final l4Script = l4Inputs is YamlMap ? '${l4Inputs['script'] ?? ''}' : '';
  const expectedL4Script =
      'bash ../../../tool/run_android_termworld_input_ci.sh emulator-5554';
  if (l4Script != expectedL4Script || l4Script.contains('\n')) {
    violations.add(
      'termworld: Android L4 must invoke the checked-in CI runner '
      'as one command',
    );
  }

  final artifactSteps = jobSteps.where(
    (step) => '${step['uses'] ?? ''}'.startsWith('actions/upload-artifact@'),
  );
  final hasFailureArtifact = artifactSteps.any((step) {
    final inputs = step['with'];
    return '${step['if'] ?? ''}' == 'failure()' &&
        inputs is YamlMap &&
        '${inputs['name'] ?? ''}' ==
            r'termworld-android-input-api-${{ matrix.api-level }}' &&
        '${inputs['path'] ?? ''}'.contains('termworld-android-input');
  });
  if (!hasFailureArtifact) {
    violations.add(
      'termworld: Android L4 failures must upload per-API input diagnostics',
    );
  }
  return violations;
}

const String _iosRetryAction =
    'nick-fields/retry@ad984534de44a9489a53aefd81eb77f87c70dc60';
const String _resetSelectedIosSimulator =
    r'bash tool/ios_simulator_ci.sh reset "$UDID"';
const String _resetIosSimulator =
    r'bash tool/ios_simulator_ci.sh reset "$SIMULATOR_UDID"';
const String _diagnoseIosSimulator =
    r'bash tool/ios_simulator_ci.sh diagnose "$SIMULATOR_UDID"';

List<String> _verifyIosSimulatorRecovery(String root, File workflow) {
  final helper = File(p.join(root, 'tool', 'ios_simulator_ci.sh'));
  final violations = <String>[];
  if (!helper.existsSync()) {
    violations.add('iOS CI is missing tool/ios_simulator_ci.sh');
  }

  final document = loadYaml(workflow.readAsStringSync());
  if (document is! YamlMap || document['jobs'] is! YamlMap) {
    return <String>[...violations, 'CI workflow has no jobs mapping'];
  }
  final jobs = document['jobs'] as YamlMap;
  // The iOS pyramids run one job per package. Find every iOS job by its
  // simulator boot step instead of a hard-coded job id, so reshaping the job
  // layout cannot silently skip this check.
  final iosSteps = <YamlMap>[];
  for (final job in jobs.values.whereType<YamlMap>()) {
    final steps = job['steps'];
    if (steps is! YamlList) continue;
    final jobSteps = steps.whereType<YamlMap>().toList();
    final bootSteps = jobSteps
        .where((step) => step['name'] == 'Boot an iOS simulator')
        .toList();
    if (bootSteps.isEmpty) continue;
    for (final boot in bootSteps) {
      if (!'${boot['run'] ?? ''}'.contains(_resetSelectedIosSimulator)) {
        violations.add('iOS CI must reset the selected simulator before L3');
      }
    }
    iosSteps.addAll(jobSteps);
  }
  if (iosSteps.isEmpty) {
    return <String>[...violations, 'CI workflow has no iOS job steps'];
  }

  for (final name in const <String>[
    'L4 ios conformance suite',
    'L4 ios termworld conformance suite',
  ]) {
    final matching = iosSteps.where((step) => step['name'] == name).toList();
    if (matching.length != 1) {
      violations.add('iOS CI must contain exactly one "$name" step');
      continue;
    }
    final step = matching.single;
    if (step['uses'] != _iosRetryAction) {
      violations.add('$name must pin $_iosRetryAction');
    }
    final inputs = step['with'];
    if (inputs is! YamlMap) {
      violations.add('$name must configure bounded retry inputs');
      continue;
    }
    const expectedInputs = <String, String>{
      'timeout_minutes': '15',
      'max_attempts': '2',
      'retry_wait_seconds': '5',
      'retry_on': 'timeout',
    };
    for (final entry in expectedInputs.entries) {
      if ('${inputs[entry.key] ?? ''}' != entry.value) {
        violations.add('$name must set ${entry.key} to ${entry.value}');
      }
    }
    final command = '${inputs['command'] ?? ''}';
    if (!command.contains(_resetIosSimulator)) {
      violations.add('$name must reset the simulator before every attempt');
    }
    final onRetry = '${inputs['on_retry_command'] ?? ''}';
    if (!onRetry.contains(_diagnoseIosSimulator)) {
      violations.add('$name must collect diagnostics before retrying');
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
