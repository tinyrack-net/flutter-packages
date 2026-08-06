import 'dart:io';

import 'package:path/path.dart' as p;

/// Fails when a release build still contains the Debug-only testing channel.
///
/// The conformance suite can put files on the real clipboard and start a real
/// drag session. That power is fine in a Debug build a test harness owns, and
/// unacceptable in a binary shipped to a user, so the channel name must not
/// survive a release compile. Searching the built artifact is the only check
/// that cannot be fooled by a preprocessor guard someone wrote incorrectly.
const String kTestingChannel = 'dropwell/testing';

/// Release output roots per platform, relative to the example app.
const Map<String, List<String>> kReleaseArtifacts = <String, List<String>>{
  'windows': <String>['build/windows/x64/runner/Release'],
  'macos': <String>['build/macos/Build/Products/Release'],
  'linux': <String>['build/linux/x64/release/bundle'],
  'android': <String>['build/app/outputs/flutter-apk'],
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
  final example = p.join(
    File.fromUri(Platform.script).parent.parent.absolute.path,
    'packages',
    'dropwell',
    'example',
  );

  final searched = <String>[];
  final offenders = <String>[];
  for (final relative in roots) {
    final directory = Directory(p.join(example, relative));
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File) continue;
      searched.add(entity.path);
      if (_containsChannel(entity)) {
        offenders.add(p.relative(entity.path, from: example));
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
  stderr.writeln('Testing channel "$kTestingChannel" found in:');
  offenders.forEach(stderr.writeln);
  exitCode = 1;
}

bool _containsChannel(File file) {
  final needle = kTestingChannel.codeUnits;
  final bytes = file.readAsBytesSync();
  outer:
  for (var index = 0; index + needle.length <= bytes.length; index++) {
    for (var offset = 0; offset < needle.length; offset++) {
      if (bytes[index + offset] != needle[offset]) continue outer;
    }
    return true;
  }
  return false;
}
