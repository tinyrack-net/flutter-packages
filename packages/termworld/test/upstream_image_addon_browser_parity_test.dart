import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_image.dart';
import 'package:termworld/src/addons/qoi_decoder.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('xterm ImageAddon playwright 0', () async {
    expect(await _writeIip(_png(640, 80)), (640, 80));
  });

  test('xterm ImageAddon playwright 1', () async {
    expect(
      await _writeIip(
        _qoi(640, 80),
        header: 'width=20;height=5;preserveAspectRatio=0',
      ),
      (200, 100),
    );
  });

  test('xterm ImageAddon playwright 2', () async {
    expect(
      await _writeIip(
        _qoi(640, 80),
        header: 'width=320px;height=160px;preserveAspectRatio=0',
      ),
      (320, 160),
    );
  });

  test('xterm ImageAddon playwright 3', () async {
    expect(
      await _writeIip(
        _png(640, 80),
        header: 'width=20;height=5;preserveAspectRatio=0',
      ),
      (200, 100),
    );
  });

  testWidgets('xterm ImageAddon playwright 4', (tester) async {
    await tester.runAsync(() async {
      final root = Directory.current.path.endsWith('termworld')
          ? 'test/fixtures/xterm_image/testimages'
          : 'packages/termworld/test/fixtures/xterm_image/testimages';
      final png = await decodeImageFromList(
        File('$root/w3c_home.png').readAsBytesSync(),
      );
      addTearDown(png.dispose);
      final data = await png.toByteData();
      final pixels = data!.buffer.asUint8List();
      final qoi = decodeQoi(_encodeQoi(png.width, png.height, pixels));
      expect((qoi.width, qoi.height), (png.width, png.height));
      expect(qoi.pixels, pixels);
    });
  });

  test('xterm ImageAddon playwright 5', () {
    const options = ImageAddonOptions(
      enableSizeReports: false,
      pixelLimit: 5,
      storageLimit: 10,
      showPlaceholder: false,
      sixelSupport: false,
      sixelScrolling: false,
      sixelPaletteLimit: 1024,
      sixelSizeLimit: 1000,
      iipSupport: false,
      iipSizeLimit: 1000,
      kittySupport: false,
      kittySizeLimit: 1000,
    );
    expect(options.enableSizeReports, isFalse);
    expect(options.pixelLimit, 5);
    expect(options.storageLimit, 10);
    expect(options.showPlaceholder, isFalse);
    expect(options.sixelSupport, isFalse);
    expect(options.sixelScrolling, isFalse);
    expect(options.sixelPaletteLimit, 1024);
    expect(options.sixelSizeLimit, 1000);
    expect(options.iipSupport, isFalse);
    expect(options.iipSizeLimit, 1000);
    expect(options.kittySupport, isFalse);
    expect(options.kittySizeLimit, 1000);
  });

  test('xterm ImageAddon playwright 6', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(_multipartOpen);
    await setup.terminal.writeAndWait(_multipartPart(_pngBase64(1, 1)));
    await setup.terminal.writeAndWait(_iip(_png(148, 148)));
    await setup.terminal.writeAndWait(_multipartEnd);
    expect(setup.addon.images, hasLength(1));
    expect(_size(setup.addon.images.single), (148, 148));
  });

  test('xterm ImageAddon playwright 7', () async {
    expect(
      await _writeIip(_png(640, 80), header: 'width=50%'),
      (400, 50),
    );
  });

  test('xterm ImageAddon playwright 8', () async {
    expect(await _writeIip(_png(72, 48)), (72, 48));
  });

  test('xterm ImageAddon playwright 9', () async {
    final setup = _setup();
    final payload = _pngBase64(640, 80);
    await setup.terminal.writeAndWait(_multipartOpen);
    for (var index = 0; index < payload.length; index += 8) {
      await setup.terminal.writeAndWait(
        _multipartPart(
          payload.substring(index, (index + 8).clamp(0, payload.length)),
        ),
      );
    }
    await setup.terminal.writeAndWait(_multipartEnd);
    expect(_size(setup.addon.images.single), (640, 80));
  });

  test('xterm ImageAddon playwright 10', () async {
    expect(
      await _writeIip(
        _png(640, 80),
        header: 'width=50%;height=30%;preserveAspectRatio=0',
      ),
      (400, 144),
    );
  });

  test('xterm ImageAddon playwright 11', () {
    const options = ImageAddonOptions(sixelPaletteLimit: 512);
    expect(options.enableSizeReports, isTrue);
    expect(options.pixelLimit, 16777216);
    expect(options.storageLimit, 128);
    expect(options.showPlaceholder, isTrue);
    expect(options.sixelSupport, isTrue);
    expect(options.sixelScrolling, isTrue);
    expect(options.sixelPaletteLimit, 512);
    expect(options.sixelSizeLimit, 33554432);
    expect(options.iipSupport, isTrue);
    expect(options.iipSizeLimit, 33554432);
    expect(options.kittySupport, isTrue);
    expect(options.kittySizeLimit, 33554432);
  });

  test('xterm ImageAddon playwright 12', () async {
    final setup = _setup(scrollback: 2);
    await setup.terminal.writeAndWait(_sixel);
    expect(setup.addon.images, hasLength(1));
    await setup.terminal.writeAndWait('\n' * 26);
    expect(setup.addon.images, isEmpty);
  });

  test('xterm ImageAddon playwright 13', () async {
    expect(await _writeIip(_jpeg(72, 48)), (72, 48));
  });

  test('xterm ImageAddon playwright 14', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(_sixel);
    expect(
      (
        setup.terminal.buffer.active.cursorX,
        setup.terminal.buffer.active.cursorY,
      ),
      (0, 4),
    );
    await setup.terminal.writeAndWait('${'#' * 10}$_sixel');
    expect(
      (
        setup.terminal.buffer.active.cursorX,
        setup.terminal.buffer.active.cursorY,
      ),
      (10, 8),
    );
    await setup.terminal.writeAndWait('${'#' * 30}$_sixel');
    expect(
      (
        setup.terminal.buffer.active.cursorX,
        setup.terminal.buffer.active.cursorY,
      ),
      (40, 12),
    );
  });

  test('xterm ImageAddon playwright 15', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(_sixel);
    final image = setup.addon.getImageAtBufferCell(1, 1);
    expect(image, isNotNull);
    expect(
      image!.storageId,
      setup.terminal.buffer.active.getLine(1)!.getCell(1)!.imageId,
    );
  });

  test('xterm ImageAddon playwright 16', () async {
    final setup = _setup(options: const ImageAddonOptions(storageLimit: 10));
    await setup.terminal.writeAndWait('$_sixel$_sixel$_sixel');
    final before = setup.addon.storageUsage;
    setup.addon.storageLimit = 0.5;
    expect(setup.addon.storageUsage, lessThan(before));
    expect(setup.addon.storageUsage, lessThan(0.5));
  });

  test('xterm ImageAddon playwright 17', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('\u001b[H$_sixel');
    final usage = setup.addon.storageUsage;
    await setup.terminal.writeAndWait('\u001b[H$_sixel');
    expect(setup.addon.storageUsage, usage);
  });

  test('xterm ImageAddon playwright 18', () async {
    expect(
      await _writeIip(
        _qoi(640, 80),
        header: 'width=50%;height=30%;preserveAspectRatio=0',
      ),
      (400, 144),
    );
  });

  test('xterm ImageAddon playwright 19', () async {
    expect(await _writeIip(_png(148, 148)), (148, 148));
  });

  test('xterm ImageAddon playwright 20', () async {
    final setup = _setup();
    for (var index = 0; index < 10; index++) {
      await setup.terminal.writeAndWait(_multipartOpen);
    }
    for (var index = 0; index < 5; index++) {
      await setup.terminal.writeAndWait(_multipartEnd);
    }
    await setup.terminal.writeAndWait(_multipartPart(_pngBase64(1, 1)));
    await setup.terminal.writeAndWait(_multipartEnd);
    expect(setup.addon.images, isEmpty);
  });

  test('xterm ImageAddon playwright 21', () async {
    final setup = _setup();
    final payload = _pngBase64(640, 80);
    await setup.terminal.writeAndWait(_multipartOpen);
    for (final unit in payload.split('')) {
      await setup.terminal.writeAndWait(_multipartPart(unit));
    }
    await setup.terminal.writeAndWait(_multipartEnd);
    expect(_size(setup.addon.images.single), (640, 80));
  });

  test('xterm ImageAddon playwright 22', () {
    final setup = _setup();
    expect(setup.addon.storageLimit, 128);
    setup.addon.storageLimit = 1;
    expect(setup.addon.storageLimit, 1);
  });

  test('xterm ImageAddon playwright 23', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(_sixel);
    expect(
      (
        setup.terminal.buffer.active.cursorX,
        setup.terminal.buffer.active.cursorY,
      ),
      (0, 4),
    );
    await setup.terminal.writeAndWait('${'#' * 10}$_sixel');
    expect(
      (
        setup.terminal.buffer.active.cursorX,
        setup.terminal.buffer.active.cursorY,
      ),
      (10, 8),
    );
  });

  test('xterm ImageAddon playwright 24', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('\u001b[?1049h$_sixel');
    expect(setup.addon.storageUsage, greaterThan(0));
    await setup.terminal.writeAndWait('\u001b[?1049l');
    expect(setup.addon.storageUsage, 0);
  });

  test('xterm ImageAddon playwright 25', () async {
    final setup = _setup();
    expect(setup.addon.storageUsage, 0);
    await setup.terminal.writeAndWait(_sixel);
    expect(setup.addon.storageUsage, closeTo(0.2048, 0.0001));
  });

  test('xterm ImageAddon playwright 26', () async {
    final setup = _setup(options: const ImageAddonOptions(storageLimit: 1));
    for (var index = 0; index < 12; index++) {
      await setup.terminal.writeAndWait(_sixel);
    }
    expect(setup.addon.storageUsage, lessThan(1));
  });

  test('xterm ImageAddon playwright 27', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('\u001b[?80h$_sixel$_sixel');
    expect(
      (
        setup.terminal.buffer.active.cursorX,
        setup.terminal.buffer.active.cursorY,
      ),
      (0, 0),
    );
  });

  test('xterm ImageAddon playwright 28', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('\u001b[?1049h');
    for (var index = 0; index < 18; index++) {
      await setup.terminal.writeAndWait(_sixel);
    }
    final usage = setup.addon.storageUsage;
    for (var index = 0; index < 18; index++) {
      await setup.terminal.writeAndWait(_sixel);
    }
    expect(setup.addon.storageUsage, usage);
  });

  test('xterm ImageAddon playwright 29', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(_iip(_png(640, 80), size: 5));
    expect(_size(setup.addon.images.single), (640, 80));
    setup.terminal.reset();
    await setup.terminal.writeAndWait(_iip(_qoi(640, 80), includeSize: false));
    expect(_size(setup.addon.images.single), (640, 80));
  });

  test('xterm ImageAddon playwright 30', () async {
    expect(
      await _writeIip(_qoi(640, 80), header: 'height=200px'),
      (1600, 200),
    );
  });

  test('xterm ImageAddon playwright 31', () async {
    expect(
      await _writeIip(
        _png(640, 80),
        header: 'width=320px;height=160px;preserveAspectRatio=0',
      ),
      (320, 160),
    );
  });

  test('xterm ImageAddon playwright 32', () async {
    expect(await _writeIip(_gif(72, 48)), (72, 48));
  });

  test('xterm ImageAddon playwright 33', () async {
    final setup = _setup();
    var count = 0;
    setup.addon.onImageAdded.listen((_) => count++);
    await setup.terminal.writeAndWait('$_sixel$_sixel$_sixel');
    expect(count, 3);
  });
}

const _sixel = '\u001bPq"1;1;640;80~\u001b\\';
const _multipartOpen = '\u001b]1337;MultipartFile=inline=1\u0007';
const _multipartEnd = '\u001b]1337;FileEnd\u0007';

String _multipartPart(String value) => '\u001b]1337;FilePart=$value\u0007';

String _iip(
  Uint8List bytes, {
  String? header,
  int? size,
  bool includeSize = true,
}) {
  final values = <String>['inline=1'];
  if (includeSize) values.add('size=${size ?? bytes.length}');
  if (header != null) values.add(header);
  return '\u001b]1337;File=${values.join(';')}:${base64.encode(bytes)}\u0007';
}

Future<(int?, int?)> _writeIip(Uint8List bytes, {String? header}) async {
  final setup = _setup();
  await setup.terminal.writeAndWait(_iip(bytes, header: header));
  return _size(setup.addon.images.single);
}

(int?, int?) _size(TerminalImage image) =>
    (image.pixelWidth, image.pixelHeight);

String _pngBase64(int width, int height) => base64.encode(_png(width, height));

Uint8List _png(int width, int height) {
  final bytes = Uint8List(24)
    ..setAll(0, const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    ..setAll(12, const <int>[0x49, 0x48, 0x44, 0x52]);
  _write32(bytes, 16, width);
  _write32(bytes, 20, height);
  return bytes;
}

Uint8List _qoi(int width, int height) {
  final bytes = Uint8List(24)..setAll(0, const <int>[0x71, 0x6f, 0x69, 0x66]);
  _write32(bytes, 4, width);
  _write32(bytes, 8, height);
  return bytes;
}

Uint8List _gif(int width, int height) => Uint8List(24)
  ..setAll(0, const <int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61])
  ..setAll(6, <int>[width & 255, width >> 8, height & 255, height >> 8]);

Uint8List _jpeg(int width, int height) => Uint8List(24)
  ..setAll(0, const <int>[0xff, 0xd8, 0xff, 0xe0, 0x00, 0x02, 0xff, 0xc0])
  ..setAll(11, <int>[height >> 8, height & 255, width >> 8, width & 255]);

void _write32(Uint8List bytes, int offset, int value) {
  bytes[offset] = value >> 24;
  bytes[offset + 1] = value >> 16;
  bytes[offset + 2] = value >> 8;
  bytes[offset + 3] = value;
}

Uint8List _encodeQoi(int width, int height, Uint8List pixels) {
  final output = BytesBuilder(copy: false)
    ..add(const <int>[0x71, 0x6f, 0x69, 0x66]);
  final dimensions = Uint8List(8);
  _write32(dimensions, 0, width);
  _write32(dimensions, 4, height);
  output
    ..add(dimensions)
    ..add(const <int>[4, 0]);
  for (var offset = 0; offset < pixels.length; offset += 4) {
    output.add(<int>[
      0xff,
      pixels[offset],
      pixels[offset + 1],
      pixels[offset + 2],
      pixels[offset + 3],
    ]);
  }
  output.add(const <int>[0, 0, 0, 0, 0, 0, 0, 1]);
  return output.takeBytes();
}

({Terminal terminal, ImageAddon addon}) _setup({
  int scrollback = 1000,
  ImageAddonOptions options = const ImageAddonOptions(sixelPaletteLimit: 512),
}) {
  final terminal =
      Terminal(
        options: TerminalOptions(scrollback: scrollback),
      )..updateDimensions(
        const TerminalRenderDimensions(
          width: 800,
          height: 480,
          cellWidth: 10,
          cellHeight: 20,
          devicePixelRatio: 1,
        ),
      );
  final addon = ImageAddon(options: options);
  terminal.loadAddon(addon);
  addTearDown(terminal.dispose);
  return (terminal: terminal, addon: addon);
}
