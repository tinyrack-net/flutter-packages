import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../tool/verify_platform_matrix.dart';

void main() {
  final repository = Directory.current.absolute.path;

  test(
    'Android termworld owns a real InputConnection conformance boundary',
    () {
      final fixture = File(
        p.join(
          repository,
          'packages',
          'termworld',
          'example',
          'assets',
          'ime',
          'android_input_connection_cases.json',
        ),
      );
      final driver = File(
        p.join(
          repository,
          'packages',
          'termworld',
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
      final nativeBoundaryTest = File(
        p.join(
          repository,
          'packages',
          'termworld',
          'example',
          'integration_test',
          'android_input_connection_test.dart',
        ),
      );
      final isolatedRunner = File(
        p.join(repository, 'tool', 'run_android_input_connection_e2e.dart'),
      );
      final ciRunner = File(
        p.join(repository, 'tool', 'run_android_termworld_input_ci.sh'),
      );
      final harnessIme = File(
        p.join(
          repository,
          'packages',
          'termworld',
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
      final harnessManifest = File(
        p.join(
          repository,
          'packages',
          'termworld',
          'example',
          'android',
          'ime_harness',
          'src',
          'main',
          'AndroidManifest.xml',
        ),
      );
      final harnessCommandTest = File(
        p.join(
          repository,
          'packages',
          'termworld',
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
        ),
      );
      final androidSettings = File(
        p.join(
          repository,
          'packages',
          'termworld',
          'example',
          'android',
          'settings.gradle.kts',
        ),
      );
      final appDebugManifest = File(
        p.join(
          repository,
          'packages',
          'termworld',
          'example',
          'android',
          'app',
          'src',
          'debug',
          'AndroidManifest.xml',
        ),
      );

      expect(
        fixture.existsSync(),
        isTrue,
        reason: 'shared transaction fixture',
      );
      expect(
        fixture.readAsStringSync(),
        contains('"op": "repeat"'),
        reason: 'unbarriered repeated native transaction',
      );
      expect(driver.existsSync(), isTrue, reason: 'Debug-only native driver');
      expect(
        harnessIme.existsSync(),
        isTrue,
        reason: 'separately installed deterministic test IME',
      );
      expect(
        harnessCommandTest.existsSync(),
        isTrue,
        reason: 'typed IME transaction contract tests',
      );
      expect(
        androidSettings.readAsStringSync(),
        contains('include(":app", ":ime_harness")'),
        reason: 'test IME is an isolated application module',
      );
      expect(
        appDebugManifest.readAsStringSync(),
        isNot(contains('<service')),
        reason: 'the example application does not embed the test IME',
      );
      expect(
        harnessManifest.readAsStringSync(),
        allOf(
          contains('.TermworldTestInputMethodService'),
          contains('android.permission.BIND_INPUT_METHOD'),
          contains('@xml/termworld_test_input_method'),
        ),
        reason: 'separate APK declares the system input method',
      );
      expect(
        nativeBoundaryTest.existsSync(),
        isTrue,
        reason: 'real FlutterView/InputConnection E2E',
      );
      expect(
        nativeBoundaryTest.readAsStringSync(),
        allOf(<Matcher>[
          contains('final finalStatus = await _nativeStatus();'),
          contains('deterministic FIFO boundary'),
        ]),
        reason: 'fixture-level native-to-Dart FIFO processing barrier',
      );
      expect(
        driver.readAsStringSync(),
        allOf(<Matcher>[
          contains('TextInputClient.onFocusReceived'),
          contains('FIFO_BARRIER_CLIENT_ID = -2'),
          contains('TextInputClient.onConnectionClosed'),
          contains('JSONMethodCodec.INSTANCE'),
          contains('sendAppPrivateCommand'),
          contains('import android.os.Messenger'),
          contains('replyMessenger'),
          isNot(contains('ResultReceiver')),
          isNot(contains('onCreateInputConnection')),
        ]),
        reason:
            'app bridges into the active system IME and uses a FIFO barrier',
      );
      expect(
        harnessIme.readAsStringSync(),
        allOf(<Matcher>[
          contains('onAppPrivateCommand'),
          contains('currentInputConnection'),
          contains('import android.os.Message'),
          contains('import android.os.Messenger'),
          contains('replyMessenger'),
          isNot(contains('ResultReceiver')),
          contains('termworld-android-input-connection-ime-harness'),
        ]),
        reason: 'test IME operates on the system-owned Flutter InputConnection',
      );
      expect(
        isolatedRunner.existsSync(),
        isTrue,
        reason: 'live IME isolation runner',
      );
      expect(ciRunner.existsSync(), isTrue, reason: 'single-shell CI runner');
    },
  );

  test('API 24 and 35 run the native boundary and retain diagnostics', () {
    final workflow = File(
      p.join(repository, '.github', 'workflows', 'ci.yml'),
    ).readAsStringSync();
    final runner = File(
      p.join(repository, 'tool', 'run_android_termworld_input_ci.sh'),
    ).readAsStringSync();

    expect(
      workflow,
      contains(
        'script: bash ../../../tool/run_android_termworld_input_ci.sh '
        'emulator-5554',
      ),
    );
    expect(
      workflow,
      contains(
        ':app:testDebugUnitTest :ime_harness:testDebugUnitTest',
      ),
      reason: 'both debug APK boundaries retain typed JVM coverage',
    );
    expect(runner, contains('run_android_input_connection_e2e.dart'));
    expect(runner, contains(r'--device "$device"'));
    expect(runner, contains(r'adb -s "$device" logcat -d'));
    expect(
      runner,
      contains(r'adb -s "$device" shell dumpsys input_method'),
    );
    expect(runner, contains(r'${PIPESTATUS[0]}'));
    expect(runner, contains('TERMWORLD_ANDROID_FIXTURE'));
    expect(workflow, contains('actions/upload-artifact@'));
    expect(
      workflow,
      contains(r'termworld-android-input-api-${{ matrix.api-level }}'),
    );
  });

  test('platform verifier rejects removal of the isolated E2E runner', () {
    final workflow = File(
      p.join(repository, '.github', 'workflows', 'ci.yml'),
    );
    final temporary = Directory.systemTemp.createTempSync(
      'termworld-platform-matrix-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final weakenedWorkflow =
        File(
          p.join(temporary.path, 'ci.yml'),
        )..writeAsStringSync(
          workflow.readAsStringSync().replaceAll(
            'bash ../../../tool/run_android_termworld_input_ci.sh '
                'emulator-5554',
            'flutter test integration_test/conformance_test.dart',
          ),
        );

    expect(
      verifyTermworldAndroidInputBoundary(repository, weakenedWorkflow),
      contains(
        'termworld: Android L4 must invoke the checked-in CI runner '
        'as one command',
      ),
    );
  });

  test('platform verifier rejects a multiline emulator action script', () {
    final workflow = File(
      p.join(repository, '.github', 'workflows', 'ci.yml'),
    );
    final temporary = Directory.systemTemp.createTempSync(
      'termworld-platform-matrix-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final weakenedWorkflow = File(p.join(temporary.path, 'ci.yml'))
      ..writeAsStringSync(
        workflow.readAsStringSync().replaceAll(
          'script: bash ../../../tool/run_android_termworld_input_ci.sh '
              'emulator-5554',
          'script: |\n'
              '            bash ../../../tool/run_android_termworld_input_ci.sh '
              'emulator-5554\n'
              '            echo split-shell',
        ),
      );

    expect(
      verifyTermworldAndroidInputBoundary(repository, weakenedWorkflow),
      contains(
        'termworld: Android L4 must invoke the checked-in CI runner '
        'as one command',
      ),
    );
  });

  test('runner installs a separate test IME and restores emulator state', () {
    final runner = File(
      p.join(repository, 'tool', 'run_android_input_connection_e2e.dart'),
    ).readAsStringSync();

    expect(runner, contains('default_input_method'));
    expect(
      runner,
      contains(
        'com.example.termworld_ime_harness/'
        '.TermworldTestInputMethodService',
      ),
    );
    expect(runner, contains(':ime_harness:assembleDebug'));
    expect(runner, contains('ime_harness-debug.apk'));
    expect(runner, contains("'dumpsys', 'input_method'"));
    expect(runner, contains("'enable'"));
    expect(runner, contains("'set'"));
    expect(runner, contains('TERMWORLD_ANDROID_IME_ISOLATION=active'));
    expect(runner, contains('TERMWORLD_ANDROID_IME_ISOLATION=restored'));
  });
}
