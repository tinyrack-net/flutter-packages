import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../tool/verify_release_hooks.dart';

void main() {
  test('release verifier knows every termworld Android Debug marker', () {
    expect(
      kTestingMarkers['termworld'],
      containsAll(<String>[
        'termworld/testing',
        'termworld-android-input-connection-driver',
        'DebugMainActivity',
        'termworld-android-input-connection-ime-harness',
        'termworld.testing.INPUT_CONNECTION',
        'TermworldTestInputMethodService',
        'com.example.termworld_ime_harness',
      ]),
    );
  });

  test('marker scan detects embedded and boundary-aligned values', () {
    final temporary = Directory.systemTemp.createTempSync(
      'termworld-release-hook-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final artifact = File('${temporary.path}${Platform.pathSeparator}app.apk')
      ..writeAsBytesSync(<int>[
        0,
        ...'termworld-android-input-connection-driver'.codeUnits,
        0xff,
      ]);

    expect(
      containsTestingMarker(
        artifact,
        'termworld-android-input-connection-driver',
      ),
      isTrue,
    );
    expect(containsTestingMarker(artifact, 'termworld/testing'), isFalse);
  });

  test('Android release scan decompresses APK entries before matching', () {
    final temporary = Directory.systemTemp.createTempSync(
      'termworld-release-apk-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    const marker = 'termworld-android-input-connection-ime-harness';
    final apk = File(p.join(temporary.path, 'app-release.apk'));
    _writeApk(apk, <String, String>{'classes.dex': 'prefix-$marker-suffix'});

    expect(androidApkContainsTestingMarker(apk, marker), isTrue);
    expect(androidApkContainsTestingMarker(apk, 'termworld/testing'), isFalse);
  });

  test('Android release scan selects only the exact release APK', () {
    final example = Directory.systemTemp.createTempSync(
      'termworld-release-selection-',
    );
    addTearDown(() => example.deleteSync(recursive: true));
    final output = Directory(
      p.join(example.path, 'build', 'app', 'outputs', 'flutter-apk'),
    )..createSync(recursive: true);
    const marker = 'TermworldTestInputMethodService';
    _writeApk(
      File(p.join(output.path, 'app-debug.apk')),
      <String, String>{'classes.dex': marker},
    );
    final release = File(p.join(output.path, 'app-release.apk'));
    _writeApk(
      release,
      <String, String>{'classes.dex': 'production bytecode'},
    );

    final artifacts = releaseArtifactFiles(example.path, 'android');

    expect(artifacts.map((file) => file.path), <String>[release.path]);
    expect(androidApkContainsTestingMarker(artifacts.single, marker), isFalse);
  });
}

void _writeApk(File target, Map<String, String> entries) {
  target.parent.createSync(recursive: true);
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  target.writeAsBytesSync(ZipEncoder().encode(archive));
}
