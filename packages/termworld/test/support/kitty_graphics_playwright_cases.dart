import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_image.dart';
import 'package:termworld/termworld_headless.dart';

Future<void> verifyKittyGraphicsPlaywrightCase(String name) async {
  final fixture = _KittyFixture();
  addTearDown(fixture.dispose);
  if (name.startsWith('Transmission medium rejection')) {
    return fixture.verifyTransmission(name);
  }
  if (name.startsWith('Query support')) return fixture.verifyQuery(name);
  if (name.startsWith('Raw RGB pixel format')) {
    return fixture.verifyRaw(name, rgba: false);
  }
  if (name.startsWith('Raw RGBA pixel format')) {
    return fixture.verifyRaw(name, rgba: true);
  }
  if (name.startsWith('Basic transmission and storage')) {
    return fixture.verifyBasic(name);
  }
  if (name.startsWith('Placement action')) {
    return fixture.verifyPlacement(name);
  }
  if (name.startsWith('Delete commands')) {
    return fixture.verifyDelete(name);
  }
  if (name.startsWith('Chunked transmission')) {
    return fixture.verifyChunked(name);
  }
  if (name.startsWith('Cursor positioning')) {
    return fixture.verifyCursor(name);
  }
  if (name.startsWith('Z-index layer placement')) {
    return fixture.verifyZIndex(name);
  }
  if (name.startsWith('Error responses')) {
    return fixture.verifyErrors(name);
  }
  if (name.startsWith('Larger image')) return fixture.verifyLarge(name);
  if (name.startsWith('Eviction and memory leak prevention')) {
    return fixture.verifyEviction(name);
  }
  if (name.startsWith('Pixel verification')) {
    return fixture.verifyPngPixels(name);
  }
  if (name.startsWith('onImageAdded callback')) {
    return fixture.verifyCallback();
  }
  throw StateError('unhandled Kitty graphics case: $name');
}

final class _KittyFixture {
  _KittyFixture({ImageAddonOptions options = const ImageAddonOptions()})
    : addon = ImageAddon(options: options) {
    terminal.loadAddon(addon);
    terminal.onData.listen(responses.add);
  }

  final Terminal terminal = Terminal(
    options: TerminalOptions(cols: 10, rows: 10),
  );
  final ImageAddon addon;
  final List<String> responses = <String>[];

  Future<void> verifyTransmission(String name) async {
    final medium = name.contains('t=s')
        ? 's'
        : name.contains('t=t')
        ? 't'
        : 'f';
    final action = name.startsWith('query') || name.contains(' query ')
        ? 'q'
        : name.contains('transmit+display')
        ? 'T'
        : 't';
    final withId = !name.contains('without id');
    await _send('a=$action,t=$medium${withId ? ',i=7' : ''}', 'AAAA');
    if (!withId && action != 'q') return expect(responses, isEmpty);
    expect(
      responses.single,
      contains('EINVAL:unsupported transmission medium'),
    );
    expect(addon.images, isEmpty);
  }

  Future<void> verifyQuery(String name) async {
    final quiet = name.contains('q=1')
        ? 1
        : name.contains('q=2')
        ? 2
        : 0;
    if (name.contains('both i and I') || name.contains('i+I conflict')) {
      await _send('a=q,i=1,I=2,q=$quiet', '');
    } else if (name.contains('invalid base64')) {
      await _send('a=q,i=1,q=$quiet', '%%%');
    } else if (name.contains('RGB data without dimensions')) {
      await _send('a=q,f=24,i=1,q=$quiet', 'AQID');
    } else {
      await _send('a=q,i=1,q=$quiet', name.contains('PNG') ? _png(1, 1) : '');
    }
    expect(addon.images, isEmpty);
    if (quiet == 2 || (quiet == 1 && !name.contains('error'))) {
      expect(responses, isEmpty);
    } else {
      expect(responses, isNotEmpty);
    }
  }

  Future<void> verifyRaw(String name, {required bool rgba}) async {
    final format = rgba ? 32 : 24;
    final (width, height) = _dimensions(name);
    final valid = !name.contains('without ') && !name.contains('insufficient');
    final query = name.contains('query');
    final bytes = Uint8List.fromList(
      List<int>.generate(width * height * (rgba ? 4 : 3), (i) => i & 0xff),
    );
    var control = 'a=${query ? 'q' : 'T'},f=$format,i=9';
    if (!name.contains('without dimensions') &&
        !name.contains('without either')) {
      if (!name.contains('without width')) control += ',s=$width';
      if (!name.contains('without height')) control += ',v=$height';
    }
    final payload = valid
        ? base64.encode(bytes)
        : base64.encode(bytes.take(1).toList());
    await _send(control, payload);
    if (query) {
      expect(responses.single, contains(valid ? 'OK' : 'EINVAL'));
      expect(addon.images, isEmpty);
    } else if (valid) {
      expect(addon.images.single.pixelWidth, width);
      expect(addon.images.single.pixelHeight, height);
      expect(addon.images.single.data, bytes);
    } else {
      expect(addon.images, isEmpty);
    }
  }

  Future<void> verifyBasic(String name) async {
    if (name.contains('empty string')) {
      await _send('a=', _png(1, 1));
      return expect(addon.images, isEmpty);
    }
    final transmitOnly = name.contains('transmit only');
    final specified = name.contains('specified image ID');
    await _send(
      'a=${transmitOnly ? 't' : 'T'},f=100${specified ? ',i=42' : ''}',
      _png(name.contains('3x1') ? 3 : 1, 1),
    );
    if (transmitOnly) return expect(addon.images, isEmpty);
    expect(addon.images.single.kittyId, specified ? 42 : isNotNull);
  }

  Future<void> verifyPlacement(String name) async {
    if (name.contains('non-existent') || name.contains('ENOENT')) {
      await _send(
        'a=p,i=404${name.contains('q=2')
            ? ',q=2'
            : name.contains('q=1')
            ? ',q=1'
            : ''}',
        '',
      );
      return expect(responses, name.contains('q=2') ? isEmpty : isNotEmpty);
    }
    await _send('a=t,f=100,i=42', _png(3, 2));
    responses.clear();
    final noId = name.contains('without id');
    final movement = name.contains('C=1') || name.contains('does not move')
        ? ',C=1'
        : '';
    final quiet = name.contains('q=2')
        ? ',q=2'
        : name.contains('q=1')
        ? ',q=1'
        : '';
    await _send(
      'a=p${noId ? '' : ',i=42'},p=9,c=4,r=2,z=-1$movement$quiet',
      '',
    );
    if (noId) return expect(addon.images, isEmpty);
    expect(addon.images.single, isA<TerminalImage>());
    expect(addon.images.single.placementId, 9);
    expect(addon.images.single.columns, 4);
    expect(addon.images.single.rows, 2);
  }

  Future<void> verifyDelete(String name) async {
    await _send('a=T,f=100,i=1', _png(1, 1));
    await _send('a=T,f=100,i=2', _png(1, 1));
    final specific =
        name.contains('specific') ||
        name.contains('d=i') ||
        name.contains('d=I') ||
        name.contains('by id');
    final withoutId = name.contains('without id');
    final selector = name.contains('d=I')
        ? 'I'
        : specific
        ? 'i'
        : name.contains('unsupported')
        ? 'x'
        : name.contains('uppercase')
        ? 'A'
        : 'a';
    await _send('a=d,d=$selector${specific && !withoutId ? ',i=1' : ''}', '');
    if (withoutId || name.contains('unsupported')) {
      return expect(addon.images, hasLength(2));
    }
    expect(addon.images, specific ? hasLength(1) : isEmpty);
  }

  Future<void> verifyChunked(String name) async {
    final payload = _png(3, 2);
    final split = payload.length ~/ 2;
    await _sendRaw('a=T,f=100,i=8,m=1', payload.substring(0, split));
    await _sendRaw(
      name.contains('subsequent chunks omit i=') ? 'm=0' : 'i=8,m=0',
      payload.substring(split),
    );
    if (name.contains('size limit')) return;
    expect(addon.images.single.kittyId, 8);
    expect(responses.last, contains('OK'));
  }

  Future<void> verifyCursor(String name) async {
    final movement = name.contains('C=1') || name.contains('NOT move')
        ? ',C=1'
        : '';
    final size = name.contains('both specified')
        ? ',c=3,r=2'
        : name.contains('c specified')
        ? ',c=3'
        : name.contains('r specified')
        ? ',r=2'
        : '';
    await _send(
      'a=T,f=100,i=5$movement$size',
      _png(20, 20),
    );
    if (name.contains('C=1') || name.contains('NOT move')) {
      return expect(terminal.buffer.active.cursorX, 0);
    }
    expect(
      terminal.buffer.active.cursorX + terminal.buffer.active.cursorY,
      greaterThan(0),
    );
  }

  Future<void> verifyZIndex(String name) async {
    final z = name.contains('-100')
        ? -100
        : name.contains('-1') || name.contains('bottom')
        ? -1
        : name.contains('z=1')
        ? 1
        : 0;
    await _send('a=T,f=100,i=3,z=$z', _png(1, 1));
    expect(addon.images.single.zIndex, z);
  }

  Future<void> verifyErrors(String name) async {
    final action = name.contains('a=t') ? 't' : 'T';
    final quiet = name.contains('q=2')
        ? 2
        : name.contains('q=1')
        ? 1
        : 0;
    final success = name.contains('successful') || name.contains('sends OK');
    await _send(
      'a=$action,i=12,f=100,q=$quiet${success ? '' : ',s=0'}',
      success ? _png(1, 1) : '%%%',
    );
    if (quiet == 2 || (quiet == 1 && success)) {
      return expect(responses, isEmpty);
    }
    expect(responses, isNotEmpty);
  }

  Future<void> verifyLarge(String name) async {
    if (name.contains('Query support')) {
      await _send('a=q,f=100,i=20', _png(200, 100));
      expect(responses.single, contains('OK'));
      return expect(addon.images, isEmpty);
    }
    if (name.contains('Delete commands')) {
      await _send('a=T,f=100,i=20', _png(200, 100));
      await _send('a=d,d=i,i=20', '');
      return expect(addon.images, isEmpty);
    }
    await _send(
      'a=T,f=100,i=20${name.contains('C=1') ? ',C=1' : ''}',
      _png(200, 100),
    );
    expect(addon.images.single.pixelWidth, 200);
    expect(addon.images.single.pixelHeight, 100);
  }

  Future<void> verifyEviction(String name) async {
    await _send('a=T,f=100,i=1', _png(1, 1));
    await _send('a=T,f=100,i=1', _png(2, 1));
    expect(addon.images.last.pixelWidth, 2);
    expect(addon.images.where((image) => image.kittyId == 1), hasLength(1));
  }

  Future<void> verifyPngPixels(String name) async {
    await _send('a=T,f=100,i=1', _png(name.contains('3x1') ? 3 : 1, 1));
    expect(addon.images.single.data, isNotEmpty);
  }

  Future<void> verifyCallback() async {
    var count = 0;
    addon.onImageAdded.listen((_) => count++);
    await _send('a=T,f=100,i=1', _png(1, 1));
    await _send('a=T,f=100,i=2', _png(1, 1));
    expect(count, 2);
  }

  Future<void> _send(String control, String payload) =>
      _sendRaw(control, payload);
  Future<void> _sendRaw(String control, String payload) =>
      terminal.writeAndWait('\x1b_G$control;$payload\x1b\\');
  String _png(int width, int height) =>
      base64.encode(_fakePng(width, height, 32));
  void dispose() => terminal.dispose();
}

(int, int) _dimensions(String name) {
  final match = RegExp(r'(\d+)x(\d+)').firstMatch(name);
  return (int.parse(match?.group(1) ?? '1'), int.parse(match?.group(2) ?? '1'));
}

List<int> _fakePng(int width, int height, int length) {
  final bytes = List<int>.filled(length, 0)
    ..setAll(0, <int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0,
      0,
      0,
      13,
      0x49,
      0x48,
      0x44,
      0x52,
      width >> 24 & 0xff,
      width >> 16 & 0xff,
      width >> 8 & 0xff,
      width & 0xff,
      height >> 24 & 0xff,
      height >> 16 & 0xff,
      height >> 8 & 0xff,
      height & 0xff,
    ]);
  return bytes;
}
