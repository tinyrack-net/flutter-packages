import 'dart:typed_data';

import 'package:browsewell/browsewell.dart';
import 'package:browsewell/browsewell_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  test('model codecs preserve browser contract values', () {
    final capabilities = BrowsewellCapabilities.fromJson(
      BrowsewellCapabilities.desktop.toJson(),
    );
    expect(capabilities.trustedInput, isTrue);
    expect(capabilities.fullPageScreenshot, isTrue);
    expect(capabilities.fileUpload, isTrue);
    expect(capabilities.multipleInstances, isTrue);
    expect(capabilities.persistentProfile, isTrue);
    expect(capabilities.crossOriginFrames, isTrue);
    expect(
      const BrowsewellProfile(id: 'net.tinyrack.coder.default').toJson(),
      <String, Object?>{'id': 'net.tinyrack.coder.default'},
    );

    final create = BrowsewellCreateResult.fromJson(<String, Object?>{
      'id': 'browser',
      'capabilities': capabilities.toJson(),
    });
    expect(create.id, 'browser');
    expect(
      const BrowsewellCommand('reload').toJson(),
      <String, Object?>{
        'name': 'reload',
        'arguments': <String, Object?>{},
      },
    );

    final event = BrowsewellEvent.fromJson(const <String, Object?>{
      'id': 'browser',
      'type': 'loadEnd',
      'url': 'https://example.test',
      'title': 'Fixture',
      'message': 'done',
    });
    expect(event.url, Uri.parse('https://example.test'));
    expect(event.title, 'Fixture');

    final snapshot = BrowsewellSnapshot.fromJson(const <String, Object?>{
      'generation': 4,
      'document': <String, Object?>{
        'role': 'document',
        'name': 'Fixture',
        'children': <Object?>[
          <String, Object?>{
            'role': 'button',
            'name': 'Save',
            'ref': '@4:1',
            'value': 'yes',
          },
          'ignored',
        ],
      },
    });
    expect(snapshot.document.children.single.ref, '@4:1');

    final log = BrowsewellLogEntry.fromJson(const <String, Object?>{
      'level': 'warning',
      'message': 'slow',
      'timestampMicros': 10,
    });
    expect(log.level, 'warning');
    expect(
      const BrowsewellException(BrowsewellErrorCode.busy, 'busy').toString(),
      'BrowsewellException(busy): busy',
    );
    expect(
      browsewellBytes(const <Object?>[1, 2]),
      Uint8List.fromList(<int>[1, 2]),
    );
    expect(browsewellBytes(Uint8List(1)), Uint8List(1));
  });

  test('model codecs reject malformed platform values', () {
    expect(
      () => BrowsewellCreateResult.fromJson(const <String, Object?>{}),
      throwsFormatException,
    );
    expect(
      () => BrowsewellEvent.fromJson(const <String, Object?>{}),
      throwsFormatException,
    );
    expect(
      () => BrowsewellSnapshot.fromJson(const <String, Object?>{}),
      throwsFormatException,
    );
    expect(() => browsewellBytes('invalid'), throwsFormatException);
  });

  test('platform defaults fail explicitly', () {
    final platform = _BarePlatform();
    final request = BrowsewellCreateRequest(
      profile: const BrowsewellProfile(id: 'net.tinyrack.test'),
      initialUrl: Uri.parse('about:blank'),
      policy: const BrowsewellPolicy(),
    );
    expect(() => platform.create(request), throwsUnimplementedError);
    expect(
      () => platform.execute('missing', const BrowsewellCommand('reload')),
      throwsUnimplementedError,
    );
    expect(() => platform.events('missing'), throwsUnimplementedError);
    expect(
      () => platform.setViewport('missing', rect: Rect.zero, visible: false),
      throwsUnimplementedError,
    );
    expect(
      () => platform.disposeBrowser('missing'),
      throwsUnimplementedError,
    );
    expect(() => platform.buildView('missing'), throwsUnimplementedError);
  });
}

final class _BarePlatform extends BrowsewellPlatform
    with MockPlatformInterfaceMixin {}
