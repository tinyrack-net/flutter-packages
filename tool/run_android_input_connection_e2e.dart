import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

const _harnessIme =
    'com.example.termworld_ime_harness/.TermworldTestInputMethodService';

/// Captured result of an Android harness command.
final class AndroidCommandResult {
  /// Creates a captured command result.
  const AndroidCommandResult({
    required this.exitCode,
    required this.stdout,
    this.stderr = '',
  });

  /// Process exit code.
  final int exitCode;

  /// Captured standard output.
  final String stdout;

  /// Captured standard error.
  final String stderr;
}

/// Process boundary used by the Android InputConnection E2E runner.
abstract interface class AndroidCommandExecutor {
  /// Runs a command and captures its output.
  Future<AndroidCommandResult> capture(
    String executable,
    List<String> arguments,
  );

  /// Runs a command while forwarding its output to the caller's stdio.
  Future<int> stream(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  });
}

/// Runs termworld's native Android `InputConnection` transaction fixture.
///
/// A vendor IME receives `updateSelection` callbacks from the same engine
/// connection and can asynchronously mutate composing spans created by the
/// deterministic driver. The runner first builds the example and its separate
/// Debug-only IME harness APK, installs both, and makes the harness Android's
/// active input method. It waits until `dumpsys input_method` confirms the
/// component.
/// Every exit path attempts to restore and verify the original default before
/// disabling the harness, while the user's enabled IME set is otherwise left
/// untouched.
Future<int> runAndroidInputConnectionE2e({
  required String device,
  required String exampleDirectory,
  required AndroidCommandExecutor executor,
  void Function(String message) emit = print,
  int activeImePollAttempts = 100,
  Duration activeImePollDelay = const Duration(milliseconds: 100),
}) async {
  if (!RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(device)) {
    throw ArgumentError.value(device, 'device', 'invalid adb serial');
  }
  if (activeImePollAttempts <= 0) {
    throw ArgumentError.value(
      activeImePollAttempts,
      'activeImePollAttempts',
      'must be positive',
    );
  }
  if (activeImePollDelay.isNegative) {
    throw ArgumentError.value(
      activeImePollDelay,
      'activeImePollDelay',
      'must not be negative',
    );
  }

  final buildExitCode = await executor.stream(
    'flutter',
    const <String>['build', 'apk', '--debug'],
    workingDirectory: exampleDirectory,
  );
  if (buildExitCode != 0) return buildExitCode;

  final androidDirectory = p.join(exampleDirectory, 'android');
  final gradleWrapper = p.join(
    androidDirectory,
    Platform.isWindows ? 'gradlew.bat' : 'gradlew',
  );
  final harnessBuildExitCode = await executor.stream(
    gradleWrapper,
    const <String>[':ime_harness:assembleDebug'],
    workingDirectory: androidDirectory,
  );
  if (harnessBuildExitCode != 0) return harnessBuildExitCode;

  final debugApk = p.join(
    exampleDirectory,
    'build',
    'app',
    'outputs',
    'flutter-apk',
    'app-debug.apk',
  );
  final harnessApk = p.join(
    exampleDirectory,
    'build',
    'ime_harness',
    'outputs',
    'apk',
    'debug',
    'ime_harness-debug.apk',
  );
  await _checkedCapture(
    executor,
    'adb',
    <String>['-s', device, 'install', '-r', debugApk],
  );
  await _checkedCapture(
    executor,
    'adb',
    <String>['-s', device, 'install', '-r', harnessApk],
  );

  String? user;
  String? defaultIme;
  var harnessWasEnabled = false;
  var isolationAttempted = false;
  Object? bodyError;
  StackTrace? bodyStackTrace;
  int? testExitCode;
  final restoreErrors = <Object>[];

  try {
    user = (await _checkedCapture(
      executor,
      'adb',
      <String>['-s', device, 'shell', 'am', 'get-current-user'],
    )).stdout.trim();
    if (user.isEmpty) {
      throw StateError('adb returned an empty Android user identifier');
    }

    // Android 7.0's `ime` shell command has no `--user` option. These commands
    // intentionally target adb's current user; the explicit user identifier
    // remains necessary only for the secure-settings query and diagnostics.
    final installedImes = _nonEmptyLines(
      (await _checkedCapture(
        executor,
        'adb',
        <String>[
          '-s',
          device,
          'shell',
          'ime',
          'list',
          '-a',
          '-s',
        ],
      )).stdout,
    );
    if (!installedImes.contains(_harnessIme)) {
      throw StateError(
        'Debug IME harness is not installed: $_harnessIme',
      );
    }

    final enabledImes = _nonEmptyLines(
      (await _checkedCapture(
        executor,
        'adb',
        <String>[
          '-s',
          device,
          'shell',
          'ime',
          'list',
          '-s',
        ],
      )).stdout,
    );
    harnessWasEnabled = enabledImes.contains(_harnessIme);

    final defaultValue = (await _checkedCapture(
      executor,
      'adb',
      <String>[
        '-s',
        device,
        'shell',
        'settings',
        '--user',
        user,
        'get',
        'secure',
        'default_input_method',
      ],
    )).stdout.trim();
    if (defaultValue.isEmpty || defaultValue == 'null') {
      throw StateError('Android has no default input method to restore');
    }
    defaultIme = defaultValue;

    isolationAttempted = true;
    if (!harnessWasEnabled) {
      await _checkedCapture(
        executor,
        'adb',
        <String>[
          '-s',
          device,
          'shell',
          'ime',
          'enable',
          _harnessIme,
        ],
      );
    }
    await _checkedCapture(
      executor,
      'adb',
      <String>[
        '-s',
        device,
        'shell',
        'ime',
        'set',
        _harnessIme,
      ],
    );
    await _waitForActiveIme(
      executor: executor,
      device: device,
      expectedComponent: _harnessIme,
      attempts: activeImePollAttempts,
      delay: activeImePollDelay,
    );
    emit(
      'TERMWORLD_ANDROID_IME_ISOLATION=active '
      'device=$device user=$user component=$_harnessIme',
    );

    testExitCode = await executor.stream(
      'flutter',
      <String>[
        'test',
        'integration_test/android_input_connection_test.dart',
        '-d',
        device,
      ],
      workingDirectory: exampleDirectory,
    );
  } on Object catch (error, stackTrace) {
    bodyError = error;
    bodyStackTrace = stackTrace;
  } finally {
    if (isolationAttempted) {
      final capturedUser = user!;
      final capturedDefault = defaultIme!;
      try {
        await _checkedCapture(
          executor,
          'adb',
          <String>[
            '-s',
            device,
            'shell',
            'ime',
            'set',
            capturedDefault,
          ],
        );
        await _waitForActiveIme(
          executor: executor,
          device: device,
          expectedComponent: capturedDefault,
          attempts: activeImePollAttempts,
          delay: activeImePollDelay,
        );
        if (!harnessWasEnabled) {
          await _checkedCapture(
            executor,
            'adb',
            <String>[
              '-s',
              device,
              'shell',
              'ime',
              'disable',
              _harnessIme,
            ],
          );
        }
        final restoredEnabledImes = _nonEmptyLines(
          (await _checkedCapture(
            executor,
            'adb',
            <String>['-s', device, 'shell', 'ime', 'list', '-s'],
          )).stdout,
        );
        final harnessIsEnabled = restoredEnabledImes.contains(_harnessIme);
        if (harnessIsEnabled != harnessWasEnabled) {
          throw StateError(
            'Android IME enabled state was not restored: '
            'harnessWasEnabled=$harnessWasEnabled '
            'harnessIsEnabled=$harnessIsEnabled',
          );
        }
        emit(
          'TERMWORLD_ANDROID_IME_ISOLATION=restored '
          'device=$device user=$capturedUser component=$capturedDefault '
          'harnessWasEnabled=$harnessWasEnabled',
        );
      } on Object catch (error) {
        restoreErrors.add(error);
      }
    }
  }

  if (restoreErrors.isNotEmpty) {
    final restoreFailure = StateError(
      'Failed to restore Android IME state: ${restoreErrors.join('; ')}',
    );
    if (bodyError case final error?) {
      Error.throwWithStackTrace(
        StateError(
          'Android InputConnection E2E failed: $error; $restoreFailure',
        ),
        bodyStackTrace!,
      );
    }
    if (testExitCode case final code? when code != 0) {
      throw StateError(
        'Android InputConnection E2E exited with $code; $restoreFailure',
      );
    }
    throw restoreFailure;
  }
  if (bodyError case final error?) {
    Error.throwWithStackTrace(error, bodyStackTrace!);
  }
  return testExitCode!;
}

Future<void> _waitForActiveIme({
  required AndroidCommandExecutor executor,
  required String device,
  required String expectedComponent,
  required int attempts,
  required Duration delay,
}) async {
  String? lastDump;
  for (var attempt = 0; attempt < attempts; attempt++) {
    lastDump = (await _checkedCapture(
      executor,
      'adb',
      <String>['-s', device, 'shell', 'dumpsys', 'input_method'],
    )).stdout;
    if (_isImeActive(lastDump, expectedComponent)) return;
    if (attempt + 1 < attempts) await Future<void>.delayed(delay);
  }
  final currentLines = _nonEmptyLines(lastDump ?? '')
      .where(
        (line) =>
            line.contains('mCurImeId=') ||
            line.contains('mCurMethodId=') ||
            line.contains('mCurId='),
      )
      .join('; ');
  throw StateError(
    'Android IME $expectedComponent did not become active '
    '(current: $currentLines)',
  );
}

bool _isImeActive(String dumpsys, String expectedComponent) =>
    _nonEmptyLines(dumpsys).any(
      (line) =>
          (line.contains('mCurImeId=') ||
              line.contains('mCurMethodId=') ||
              line.contains('mCurId=')) &&
          line.contains(expectedComponent),
    );

Future<AndroidCommandResult> _checkedCapture(
  AndroidCommandExecutor executor,
  String executable,
  List<String> arguments,
) async {
  final result = await executor.capture(executable, arguments);
  if (result.exitCode == 0) return result;
  throw StateError(
    '$executable ${arguments.join(' ')} failed with ${result.exitCode}: '
    '${result.stderr.trim()}',
  );
}

List<String> _nonEmptyLines(String value) => value
    .split(RegExp(r'\r?\n'))
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2 || arguments.first != '--device') {
    stderr.writeln(
      'usage: dart run tool/run_android_input_connection_e2e.dart '
      '--device <adb-serial>',
    );
    exitCode = 64;
    return;
  }
  final device = arguments.last.trim();
  if (device.isEmpty) {
    stderr.writeln('--device must not be empty');
    exitCode = 64;
    return;
  }

  final root = File.fromUri(Platform.script).parent.parent.absolute.path;
  final example = p.join(root, 'packages', 'termworld', 'example');
  try {
    exitCode = await runAndroidInputConnectionE2e(
      device: device,
      exampleDirectory: example,
      executor: const _ProcessAndroidCommandExecutor(),
    );
  } on Object catch (error, stackTrace) {
    stderr
      ..writeln(error)
      ..writeln(stackTrace);
    exitCode = 1;
  }
}

final class _ProcessAndroidCommandExecutor implements AndroidCommandExecutor {
  const _ProcessAndroidCommandExecutor();

  @override
  Future<AndroidCommandResult> capture(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(
      executable,
      arguments,
      runInShell: Platform.isWindows,
    );
    return AndroidCommandResult(
      exitCode: result.exitCode,
      stdout: '${result.stdout}',
      stderr: '${result.stderr}',
    );
  }

  @override
  Future<int> stream(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    return process.exitCode;
  }
}
