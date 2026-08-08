/// Sixel, iTerm2 inline image, and Kitty graphics addon.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/parser.dart';
import 'package:termworld/src/core/terminal.dart';

/// Supported inline image protocol.
/// xterm-compatible `TerminalImageProtocol` API.
enum TerminalImageProtocol {
  /// DEC sixel graphics.
  sixel,

  /// iTerm2 OSC 1337 inline images.
  iTerm2,

  /// Kitty graphics protocol.
  kitty,
}

/// Stored image payload anchored to a buffer cell.
final class TerminalImage {
  /// xterm-compatible `TerminalImage` API.
  const TerminalImage({
    required this.protocol,
    required this.data,
    required this.column,
    required this.row,
  });

  /// xterm-compatible `protocol` API.
  final TerminalImageProtocol protocol;

  /// xterm-compatible `data` API.
  final Uint8List data;

  /// xterm-compatible `column` API.
  final int column;

  /// xterm-compatible `row` API.
  final int row;
}

/// Image protocol limits and feature flags.
final class ImageAddonOptions {
  /// xterm-compatible `ImageAddonOptions` API.
  const ImageAddonOptions({
    this.enableSizeReports = true,
    this.pixelLimit = 16777216,
    this.storageLimit = 128,
    this.showPlaceholder = true,
    this.sixelSupport = true,
    this.sixelScrolling = true,
    this.sixelPaletteLimit = 4096,
    this.sixelSizeLimit = 33554432,
    this.iipSupport = true,
    this.iipSizeLimit = 33554432,
    this.kittySupport = true,
    this.kittySizeLimit = 33554432,
  });

  /// xterm-compatible `enableSizeReports` API.
  final bool enableSizeReports;

  /// xterm-compatible `pixelLimit` API.
  final int pixelLimit;

  /// xterm-compatible `storageLimit` API.
  final int storageLimit;

  /// xterm-compatible `showPlaceholder` API.
  final bool showPlaceholder;

  /// xterm-compatible `sixelSupport` API.
  final bool sixelSupport;

  /// xterm-compatible `sixelScrolling` API.
  final bool sixelScrolling;

  /// xterm-compatible `sixelPaletteLimit` API.
  final int sixelPaletteLimit;

  /// xterm-compatible `sixelSizeLimit` API.
  final int sixelSizeLimit;

  /// xterm-compatible `iipSupport` API.
  final bool iipSupport;

  /// xterm-compatible `iipSizeLimit` API.
  final int iipSizeLimit;

  /// xterm-compatible `kittySupport` API.
  final bool kittySupport;

  /// xterm-compatible `kittySizeLimit` API.
  final int kittySizeLimit;
}

/// Parses and stores images emitted by terminal applications.
final class ImageAddon extends ManagedTerminalAddon {
  /// Creates an image addon.
  ImageAddon({this.options = const ImageAddonOptions()}) {
    if (options.storageLimit < 0) {
      throw ArgumentError.value(options.storageLimit, 'storageLimit');
    }
  }

  /// xterm-compatible `options` API.
  final ImageAddonOptions options;
  final List<TerminalImage> _images = <TerminalImage>[];
  final TerminalEventEmitter<TerminalImage> _onImageAdded =
      TerminalEventEmitter<TerminalImage>();
  int _storageBytes = 0;

  /// xterm-compatible `onImageAdded` API.
  TerminalEvent<TerminalImage> get onImageAdded => _onImageAdded.event;

  /// xterm-compatible `storageLimit` API.
  int get storageLimit => options.storageLimit;

  /// xterm-compatible `storageUsage` API.
  int get storageUsage => _storageBytes;

  /// xterm-compatible `showPlaceholder` API.
  bool get showPlaceholder => options.showPlaceholder;

  /// xterm-compatible `unmodifiable` API.
  List<TerminalImage> get images => List<TerminalImage>.unmodifiable(_images);

  @override
  void onActivate(Terminal terminal) {
    if (options.sixelSupport) {
      own(
        terminal.parser.registerDcsHandler(
          const TerminalFunctionIdentifier(finalByte: 'q'),
          (data, parameters) {
            _add(
              TerminalImageProtocol.sixel,
              latin1.encode(data),
              options.sixelSizeLimit,
            );
            return true;
          },
        ),
      );
    }
    if (options.iipSupport) {
      own(
        terminal.parser.registerOscHandler(1337, (data) {
          final separator = data.indexOf(':');
          if (!data.startsWith('File=') || separator < 0) return false;
          _addBase64(
            TerminalImageProtocol.iTerm2,
            data.substring(separator + 1),
            options.iipSizeLimit,
          );
          return true;
        }),
      );
    }
    if (options.kittySupport) {
      own(
        terminal.parser.registerApcHandler(
          const TerminalFunctionIdentifier(finalByte: 'G'),
          (data) {
            final separator = data.indexOf(';');
            if (separator < 0) return true;
            final control = data.substring(0, separator);
            if (control.split(',').contains('a=d')) {
              reset();
            } else {
              _addBase64(
                TerminalImageProtocol.kitty,
                data.substring(separator + 1),
                options.kittySizeLimit,
              );
            }
            return true;
          },
        ),
      );
    }
  }

  void _addBase64(TerminalImageProtocol protocol, String payload, int limit) {
    try {
      _add(protocol, base64.decode(payload), limit);
    } on FormatException {
      // xterm ignores invalid image payloads after consuming the sequence.
    }
  }

  void _add(TerminalImageProtocol protocol, List<int> bytes, int limit) {
    if (bytes.length > limit) return;
    final image = TerminalImage(
      protocol: protocol,
      data: Uint8List.fromList(bytes),
      column: terminal.buffer.active.cursorX,
      row: terminal.buffer.active.baseY + terminal.buffer.active.cursorY,
    );
    _images.add(image);
    _storageBytes += image.data.length;
    final maximumBytes = storageLimit * 1024 * 1024;
    while (_storageBytes > maximumBytes && _images.isNotEmpty) {
      _storageBytes -= _images.removeAt(0).data.length;
    }
    _onImageAdded.fire(image);
  }

  /// xterm-compatible `getImageAtBufferCell` API.
  TerminalImage? getImageAtBufferCell(int column, int row) {
    for (final image in _images.reversed) {
      if (image.column == column && image.row == row) return image;
    }
    return null;
  }

  /// Removes all retained image payloads.
  bool reset() {
    _images.clear();
    _storageBytes = 0;
    return true;
  }

  @override
  void dispose() {
    reset();
    _onImageAdded.dispose();
    super.dispose();
  }
}
