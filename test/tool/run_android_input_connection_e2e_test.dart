import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../tool/run_android_input_connection_e2e.dart';

const _harnessIme =
    'com.example.termworld_ime_harness/.TermworldTestInputMethodService';

void main() {
  test(
    'activates the installed harness IME and restores the default',
    () async {
      final commands = <String>[];
      final messages = <String>[];
      final executor = _FakeAndroidCommandExecutor(
        commands: commands,
        testExitCode: 23,
      );
      final debugApk = p.join(
        r'C:\workspace\packages\termworld\example',
        'build',
        'app',
        'outputs',
        'flutter-apk',
        'app-debug.apk',
      );
      final harnessApk = p.join(
        r'C:\workspace\packages\termworld\example',
        'build',
        'ime_harness',
        'outputs',
        'apk',
        'debug',
        'ime_harness-debug.apk',
      );
      final gradleWrapper = p.join(
        r'C:\workspace\packages\termworld\example',
        'android',
        Platform.isWindows ? 'gradlew.bat' : 'gradlew',
      );

      final result = await runAndroidInputConnectionE2e(
        device: 'emulator-5554',
        exampleDirectory: r'C:\workspace\packages\termworld\example',
        executor: executor,
        emit: messages.add,
        activeImePollDelay: Duration.zero,
      );

      expect(result, 23);
      expect(
        commands,
        containsAllInOrder(<String>[
          'flutter build apk --debug',
          '$gradleWrapper :ime_harness:assembleDebug',
          'adb -s emulator-5554 install -r $debugApk',
          'adb -s emulator-5554 install -r $harnessApk',
          'adb -s emulator-5554 shell am get-current-user',
          'adb -s emulator-5554 shell ime list -a -s',
          'adb -s emulator-5554 shell ime list -s',
          [
            'adb -s emulator-5554 shell settings --user 0 get secure',
            'default_input_method',
          ].join(' '),
          'adb -s emulator-5554 shell ime enable $_harnessIme',
          'adb -s emulator-5554 shell ime set $_harnessIme',
          'adb -s emulator-5554 shell dumpsys input_method',
          [
            'flutter test integration_test/android_input_connection_test.dart',
            '-d emulator-5554',
          ].join(' '),
          'adb -s emulator-5554 shell ime set ime.beta/.Ime',
          'adb -s emulator-5554 shell dumpsys input_method',
          'adb -s emulator-5554 shell ime disable $_harnessIme',
          'adb -s emulator-5554 shell ime list -s',
        ]),
      );
      expect(
        messages,
        containsAllInOrder(<Matcher>[
          contains('TERMWORLD_ANDROID_IME_ISOLATION=active'),
          contains('TERMWORLD_ANDROID_IME_ISOLATION=restored'),
        ]),
      );
      expect(
        commands.where(
          (command) =>
              command.contains(' ime disable ') ||
              command.contains(' ime enable '),
        ),
        <String>[
          'adb -s emulator-5554 shell ime enable $_harnessIme',
          'adb -s emulator-5554 shell ime disable $_harnessIme',
        ],
        reason: 'the original enabled IME set must otherwise stay untouched',
      );
      expect(
        commands.where((command) => command.contains(' shell ime ')),
        everyElement(isNot(contains('--user'))),
        reason: 'Android API 24 ime CLI has no --user option',
      );
    },
  );

  test(
    'restores the default and enabled state when test startup throws',
    () async {
      final commands = <String>[];
      final executor = _FakeAndroidCommandExecutor(
        commands: commands,
        testError: StateError('could not start Flutter'),
      );

      await expectLater(
        runAndroidInputConnectionE2e(
          device: 'emulator-5554',
          exampleDirectory: r'C:\workspace\packages\termworld\example',
          executor: executor,
          emit: (_) {},
          activeImePollDelay: Duration.zero,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        commands.takeLast(4),
        <String>[
          'adb -s emulator-5554 shell ime set ime.beta/.Ime',
          'adb -s emulator-5554 shell dumpsys input_method',
          'adb -s emulator-5554 shell ime disable $_harnessIme',
          'adb -s emulator-5554 shell ime list -s',
        ],
      );
    },
  );

  test('does not disable a harness IME that was already enabled', () async {
    final commands = <String>[];
    final executor = _FakeAndroidCommandExecutor(
      commands: commands,
      harnessInitiallyEnabled: true,
    );

    await runAndroidInputConnectionE2e(
      device: 'emulator-5554',
      exampleDirectory: r'C:\workspace\packages\termworld\example',
      executor: executor,
      emit: (_) {},
      activeImePollDelay: Duration.zero,
    );

    expect(
      commands.where((command) => command.contains('shell ime enable')),
      isEmpty,
    );
    expect(
      commands.where((command) => command.contains('shell ime disable')),
      isEmpty,
    );
    expect(
      commands.takeLast(3),
      <String>[
        'adb -s emulator-5554 shell ime set ime.beta/.Ime',
        'adb -s emulator-5554 shell dumpsys input_method',
        'adb -s emulator-5554 shell ime list -s',
      ],
    );
  });

  test(
    'does not disable the harness when restoring the default fails',
    () async {
      final commands = <String>[];
      final messages = <String>[];
      final executor = _FakeAndroidCommandExecutor(
        commands: commands,
        failOriginalSet: true,
      );

      await expectLater(
        runAndroidInputConnectionE2e(
          device: 'emulator-5554',
          exampleDirectory: r'C:\workspace\packages\termworld\example',
          executor: executor,
          emit: messages.add,
          activeImePollDelay: Duration.zero,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Failed to restore Android IME state'),
          ),
        ),
      );

      expect(
        commands.where((command) => command.contains('shell ime disable')),
        isEmpty,
      );
      expect(messages, isNot(contains(contains('ISOLATION=restored'))));
    },
  );

  test(
    'does not disable the harness when default activation times out',
    () async {
      final commands = <String>[];
      final messages = <String>[];
      final executor = _FakeAndroidCommandExecutor(
        commands: commands,
        originalActivationTimeout: true,
      );

      await expectLater(
        runAndroidInputConnectionE2e(
          device: 'emulator-5554',
          exampleDirectory: r'C:\workspace\packages\termworld\example',
          executor: executor,
          emit: messages.add,
          activeImePollAttempts: 3,
          activeImePollDelay: Duration.zero,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('Failed to restore Android IME state'),
              contains('ime.beta/.Ime did not become active'),
            ),
          ),
        ),
      );

      expect(
        commands.where((command) => command.contains('shell ime disable')),
        isEmpty,
      );
      expect(messages, isNot(contains(contains('ISOLATION=restored'))));
    },
  );

  test(
    'reports a harness disable failure only after verified restore',
    () async {
      final commands = <String>[];
      final messages = <String>[];
      final executor = _FakeAndroidCommandExecutor(
        commands: commands,
        failHarnessDisable: true,
      );

      await expectLater(
        runAndroidInputConnectionE2e(
          device: 'emulator-5554',
          exampleDirectory: r'C:\workspace\packages\termworld\example',
          executor: executor,
          emit: messages.add,
          activeImePollDelay: Duration.zero,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Failed to restore Android IME state'),
          ),
        ),
      );

      expect(
        commands.takeLast(3),
        <String>[
          'adb -s emulator-5554 shell ime set ime.beta/.Ime',
          'adb -s emulator-5554 shell dumpsys input_method',
          'adb -s emulator-5554 shell ime disable $_harnessIme',
        ],
      );
      expect(messages, isNot(contains(contains('ISOLATION=restored'))));
    },
  );

  test(
    'rejects a successful disable that leaves the harness enabled',
    () async {
      final commands = <String>[];
      final messages = <String>[];
      final executor = _FakeAndroidCommandExecutor(
        commands: commands,
        ineffectiveHarnessDisable: true,
      );

      await expectLater(
        runAndroidInputConnectionE2e(
          device: 'emulator-5554',
          exampleDirectory: r'C:\workspace\packages\termworld\example',
          executor: executor,
          emit: messages.add,
          activeImePollDelay: Duration.zero,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('Failed to restore Android IME state'),
              contains('enabled state was not restored'),
            ),
          ),
        ),
      );

      expect(
        commands.takeLast(2),
        <String>[
          'adb -s emulator-5554 shell ime disable $_harnessIme',
          'adb -s emulator-5554 shell ime list -s',
        ],
      );
      expect(messages, isNot(contains(contains('ISOLATION=restored'))));
    },
  );

  test('keeps both the body and restoration failures in diagnostics', () async {
    final commands = <String>[];
    final executor = _FakeAndroidCommandExecutor(
      commands: commands,
      testError: StateError('could not start Flutter'),
      failOriginalSet: true,
    );

    await expectLater(
      runAndroidInputConnectionE2e(
        device: 'emulator-5554',
        exampleDirectory: r'C:\workspace\packages\termworld\example',
        executor: executor,
        emit: (_) {},
        activeImePollDelay: Duration.zero,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('could not start Flutter'),
            contains('Failed to restore Android IME state'),
          ),
        ),
      ),
    );
    expect(
      commands.where((command) => command.contains('shell ime disable')),
      isEmpty,
    );
  });

  test('keeps both a nonzero test exit and restoration failure', () async {
    final commands = <String>[];
    final executor = _FakeAndroidCommandExecutor(
      commands: commands,
      testExitCode: 23,
      failOriginalSet: true,
    );

    await expectLater(
      runAndroidInputConnectionE2e(
        device: 'emulator-5554',
        exampleDirectory: r'C:\workspace\packages\termworld\example',
        executor: executor,
        emit: (_) {},
        activeImePollDelay: Duration.zero,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('exited with 23'),
            contains('Failed to restore Android IME state'),
          ),
        ),
      ),
    );
  });

  test('restores after harness activation times out', () async {
    final commands = <String>[];
    final executor = _FakeAndroidCommandExecutor(
      commands: commands,
      harnessActivationTimeout: true,
    );

    await expectLater(
      runAndroidInputConnectionE2e(
        device: 'emulator-5554',
        exampleDirectory: r'C:\workspace\packages\termworld\example',
        executor: executor,
        emit: (_) {},
        activeImePollAttempts: 3,
        activeImePollDelay: Duration.zero,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('$_harnessIme did not become active'),
        ),
      ),
    );

    expect(
      commands,
      containsAllInOrder(<String>[
        'adb -s emulator-5554 shell ime set $_harnessIme',
        'adb -s emulator-5554 shell ime set ime.beta/.Ime',
        'adb -s emulator-5554 shell dumpsys input_method',
        'adb -s emulator-5554 shell ime disable $_harnessIme',
      ]),
    );
  });

  test('does not mutate IME state when the Debug build fails', () async {
    final commands = <String>[];
    final executor = _FakeAndroidCommandExecutor(
      commands: commands,
      buildExitCode: 17,
    );

    final result = await runAndroidInputConnectionE2e(
      device: 'emulator-5554',
      exampleDirectory: r'C:\workspace\packages\termworld\example',
      executor: executor,
      emit: (_) {},
    );

    expect(result, 17);
    expect(commands, <String>['flutter build apk --debug']);
  });

  test('does not mutate IME state when the harness build fails', () async {
    final commands = <String>[];
    final executor = _FakeAndroidCommandExecutor(
      commands: commands,
      harnessBuildExitCode: 18,
    );
    final gradleWrapper = p.join(
      r'C:\workspace\packages\termworld\example',
      'android',
      Platform.isWindows ? 'gradlew.bat' : 'gradlew',
    );

    final result = await runAndroidInputConnectionE2e(
      device: 'emulator-5554',
      exampleDirectory: r'C:\workspace\packages\termworld\example',
      executor: executor,
      emit: (_) {},
    );

    expect(result, 18);
    expect(
      commands,
      <String>[
        'flutter build apk --debug',
        '$gradleWrapper :ime_harness:assembleDebug',
      ],
    );
  });

  test('rejects a device value that could be interpreted by a shell', () async {
    final commands = <String>[];
    final executor = _FakeAndroidCommandExecutor(commands: commands);

    await expectLater(
      runAndroidInputConnectionE2e(
        device: 'emulator-5554; reboot',
        exampleDirectory: r'C:\workspace\packages\termworld\example',
        executor: executor,
        emit: (_) {},
      ),
      throwsArgumentError,
    );
    expect(commands, isEmpty);
  });
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) => skip(length - count);
}

final class _FakeAndroidCommandExecutor implements AndroidCommandExecutor {
  _FakeAndroidCommandExecutor({
    required this.commands,
    this.buildExitCode = 0,
    this.harnessBuildExitCode = 0,
    this.testExitCode = 0,
    this.testError,
    this.harnessInitiallyEnabled = false,
    this.failOriginalSet = false,
    this.originalActivationTimeout = false,
    this.failHarnessDisable = false,
    this.harnessActivationTimeout = false,
    this.ineffectiveHarnessDisable = false,
  }) : _harnessEnabled = harnessInitiallyEnabled;

  final List<String> commands;
  final int buildExitCode;
  final int harnessBuildExitCode;
  final int testExitCode;
  final Error? testError;
  final bool harnessInitiallyEnabled;
  final bool failOriginalSet;
  final bool originalActivationTimeout;
  final bool failHarnessDisable;
  final bool harnessActivationTimeout;
  final bool ineffectiveHarnessDisable;
  String _activeIme = 'ime.beta/.Ime';
  bool _harnessEnabled;

  @override
  Future<AndroidCommandResult> capture(
    String executable,
    List<String> arguments,
  ) async {
    commands.add('$executable ${arguments.join(' ')}');
    final command = arguments.join(' ');
    if (command.endsWith('shell am get-current-user')) {
      return const AndroidCommandResult(exitCode: 0, stdout: '0\n');
    }
    if (command.contains('shell ime list -a -s')) {
      return const AndroidCommandResult(
        exitCode: 0,
        stdout: 'ime.alpha/.Ime\nime.beta/.Ime\n$_harnessIme\n',
      );
    }
    if (command.contains('shell ime list -s')) {
      return AndroidCommandResult(
        exitCode: 0,
        stdout:
            'ime.alpha/.Ime\nime.beta/.Ime\n'
            '${_harnessEnabled ? '$_harnessIme\n' : ''}',
      );
    }
    if (command.contains('shell settings --user')) {
      return const AndroidCommandResult(
        exitCode: 0,
        stdout: 'ime.beta/.Ime\n',
      );
    }
    if (command.contains('shell dumpsys input_method')) {
      return AndroidCommandResult(
        exitCode: 0,
        stdout: '  mCurImeId=$_activeIme\n',
      );
    }
    if (command.endsWith('shell ime set $_harnessIme')) {
      if (!harnessActivationTimeout) _activeIme = _harnessIme;
      return const AndroidCommandResult(exitCode: 0, stdout: 'ok\n');
    }
    if (command.endsWith('shell ime enable $_harnessIme')) {
      _harnessEnabled = true;
      return const AndroidCommandResult(exitCode: 0, stdout: 'ok\n');
    }
    if (command.endsWith('shell ime set ime.beta/.Ime')) {
      if (failOriginalSet) {
        return const AndroidCommandResult(
          exitCode: 19,
          stdout: '',
          stderr: 'cannot restore',
        );
      }
      if (!originalActivationTimeout) _activeIme = 'ime.beta/.Ime';
      return const AndroidCommandResult(exitCode: 0, stdout: 'ok\n');
    }
    if (command.endsWith('shell ime disable $_harnessIme') &&
        failHarnessDisable) {
      return const AndroidCommandResult(
        exitCode: 20,
        stdout: '',
        stderr: 'cannot disable',
      );
    }
    if (command.endsWith('shell ime disable $_harnessIme')) {
      if (!ineffectiveHarnessDisable) _harnessEnabled = false;
      return const AndroidCommandResult(exitCode: 0, stdout: 'ok\n');
    }
    return const AndroidCommandResult(exitCode: 0, stdout: 'ok\n');
  }

  @override
  Future<int> stream(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    commands.add('$executable ${arguments.join(' ')}');
    if (arguments.first == 'build') return buildExitCode;
    if (arguments.first == ':ime_harness:assembleDebug') {
      return harnessBuildExitCode;
    }
    if (testError case final error?) throw error;
    return testExitCode;
  }
}
