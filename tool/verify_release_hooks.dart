import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Fails when a release build still contains the Debug-only testing channel.
///
/// The conformance suite can put files on the real clipboard and start a real
/// drag session. That power is fine in a Debug build a test harness owns, and
/// unacceptable in a binary shipped to a user, so the channel name must not
/// survive a release compile. Searching the built artifact is the only check
/// that cannot be fooled by a preprocessor guard someone wrote incorrectly.
const Map<String, List<String>> kTestingMarkers = <String, List<String>>{
  'dropwell': <String>['dropwell/testing'],
  'termworld': <String>[
    'termworld/testing',
    'termworld-android-input-connection-driver',
    'DebugMainActivity',
    'termworld-android-input-connection-ime-harness',
    'termworld.testing.INPUT_CONNECTION',
    'TermworldTestInputMethodService',
    'com.example.termworld_ime_harness',
  ],
};

/// Release artifact locations per platform, relative to the example app.
///
/// Directory locations are scanned recursively. Android is intentionally the
/// exact release APK: a Debug build can share the same output directory after
/// native-boundary tests and must neither fail nor satisfy this release gate.
const Map<String, List<String>> kReleaseArtifacts = <String, List<String>>{
  'windows': <String>['build/windows/x64/runner/Release'],
  'macos': <String>['build/macos/Build/Products/Release'],
  'linux': <String>['build/linux/x64/release/bundle'],
  'android': <String>[
    'build/app/outputs/flutter-apk/app-release.apk',
  ],
  'ios': <String>['build/ios/iphoneos'],
};

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('usage: verify_release_hooks.dart <platform>');
    exitCode = 64;
    return;
  }
  final platform = arguments.single;
  final roots = kReleaseArtifacts[platform];
  if (roots == null) {
    stderr.writeln('Unknown platform: $platform');
    exitCode = 64;
    return;
  }
  final root = File.fromUri(Platform.script).parent.parent.absolute.path;

  final searched = <String>[];
  final offenders = <String>[];
  for (final package in kTestingMarkers.entries) {
    final example = p.join(root, 'packages', package.key, 'example');
    for (final artifact in releaseArtifactFiles(example, platform)) {
      searched.add(artifact.path);
      for (final marker in package.value) {
        final containsMarker = platform == 'android'
            ? androidApkContainsTestingMarker(artifact, marker)
            : containsTestingMarker(artifact, marker);
        if (containsMarker) {
          offenders.add(
            '${package.key}/${p.relative(artifact.path, from: example)} '
            'contains "$marker"',
          );
        }
      }
    }
  }

  if (searched.isEmpty) {
    stderr.writeln(
      'No $platform release artifact found under ${roots.join(', ')}; '
      'this check must run after the release build.',
    );
    exitCode = 1;
    return;
  }
  if (offenders.isEmpty) {
    stdout.writeln(
      'No testing hook in ${searched.length} $platform release files.',
    );
    return;
  }
  stderr.writeln('Debug testing channel found in:');
  offenders.forEach(stderr.writeln);
  exitCode = 1;
}

/// Returns the built release files that belong to [platform].
///
/// Android returns only `app-release.apk`, even when a prior Debug test left
/// other APKs beside it. Other platform release outputs are directories and
/// retain their recursive file scan.
List<File> releaseArtifactFiles(String example, String platform) {
  final locations = kReleaseArtifacts[platform];
  if (locations == null) return const <File>[];
  final artifacts = <File>[];
  for (final relative in locations) {
    final location = p.normalize(p.join(example, relative));
    final file = File(location);
    if (file.existsSync()) {
      artifacts.add(file);
      continue;
    }
    final directory = Directory(location);
    if (!directory.existsSync()) continue;
    artifacts.addAll(
      directory.listSync(recursive: true).whereType<File>(),
    );
  }
  return artifacts;
}

/// Returns whether any decompressed file in Android [apk] embeds [marker].
///
/// APKs are ZIP containers whose DEX, manifest, and resource entries are
/// normally compressed. Scanning the outer bytes can therefore miss a Debug
/// channel that will be present in the installed application.
bool androidApkContainsTestingMarker(File apk, String marker) {
  final archive = ZipDecoder().decodeBytes(
    apk.readAsBytesSync(),
    verify: true,
  );
  try {
    return archive
        .where((entry) => entry.isFile)
        .map((entry) => entry.readBytes())
        .whereType<List<int>>()
        .any((bytes) => _bytesContainMarker(bytes, marker));
  } finally {
    archive.clearSync();
  }
}

/// Returns whether [file] embeds an ASCII [marker] reserved for test builds.
bool containsTestingMarker(File file, String marker) {
  return _bytesContainMarker(file.readAsBytesSync(), marker);
}

bool _bytesContainMarker(List<int> bytes, String marker) {
  final needle = marker.codeUnits;
  outer:
  for (var index = 0; index + needle.length <= bytes.length; index++) {
    for (var offset = 0; offset < needle.length; offset++) {
      if (bytes[index + offset] != needle[offset]) continue outer;
    }
    return true;
  }
  return false;
}
