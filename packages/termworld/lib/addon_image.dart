/// Sixel, iTerm2 inline image, and Kitty graphics addon.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/options.dart';
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
    required this.scrolls,
    required this.storageBytes,
    this.pixelWidth,
    this.pixelHeight,
    this.name = 'Unnamed file',
  });

  /// xterm-compatible `protocol` API.
  final TerminalImageProtocol protocol;

  /// xterm-compatible `data` API.
  final Uint8List data;

  /// xterm-compatible `column` API.
  final int column;

  /// xterm-compatible `row` API.
  final int row;

  /// Whether the protocol advances the terminal cursor after display.
  final bool scrolls;

  /// Decoded source width when the protocol exposes image metrics.
  final int? pixelWidth;

  /// Decoded source height when the protocol exposes image metrics.
  final int? pixelHeight;

  /// Decoded iTerm2 file name.
  final String name;

  /// RGBA-equivalent bytes charged against the FIFO storage limit.
  final int storageBytes;
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
  final double storageLimit;

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
  ImageAddon({this.options = const ImageAddonOptions()})
    : _configuredStorageLimit = options.storageLimit,
      showPlaceholder = options.showPlaceholder;

  /// xterm-compatible `options` API.
  final ImageAddonOptions options;
  final List<TerminalImage> _images = <TerminalImage>[];
  final TerminalEventEmitter<TerminalVoid> _onImageAdded =
      TerminalEventEmitter<TerminalVoid>();
  int _storageBytes = 0;
  double _configuredStorageLimit;
  double _effectiveStorageLimit = 10;

  /// xterm-compatible `onImageAdded` API.
  TerminalEvent<TerminalVoid> get onImageAdded => _onImageAdded.event;

  /// xterm-compatible `storageLimit` API.
  double get storageLimit => isActive ? _effectiveStorageLimit : -1;

  /// Changes the FIFO image storage limit in decimal megabytes.
  set storageLimit(double value) {
    _configuredStorageLimit = value;
    if (!isActive) return;
    _setStorageLimit(value);
  }

  /// xterm-compatible `storageUsage` API.
  double get storageUsage => isActive ? _storageBytes / 1000000 : -1;

  /// xterm-compatible `showPlaceholder` API.
  bool showPlaceholder;
  late bool _sixelScrolling;
  late int _sixelPaletteLimit;
  _IipHeader? _multipartHeader;
  StringBuffer? _multipartPayload;

  /// xterm-compatible `unmodifiable` API.
  List<TerminalImage> get images => List<TerminalImage>.unmodifiable(_images);

  @override
  void onActivate(Terminal terminal) {
    _sixelScrolling = options.sixelScrolling;
    _sixelPaletteLimit = options.sixelPaletteLimit;
    if (_configuredStorageLimit >= 0.5 && _configuredStorageLimit <= 1000) {
      _setStorageLimit(_configuredStorageLimit);
    } else {
      // xterm's ImageStorage logs the invalid constructor value and retains
      // its 10 MB fallback rather than failing addon activation.
      _effectiveStorageLimit = 10;
    }
    if (options.enableSizeReports) {
      final current = terminal.options.windowOptions;
      terminal.options.windowOptions = TerminalWindowOptions(
        restoreWin: current.restoreWin,
        minimizeWin: current.minimizeWin,
        setWinPosition: current.setWinPosition,
        setWinSizePixels: current.setWinSizePixels,
        raiseWin: current.raiseWin,
        lowerWin: current.lowerWin,
        refreshWin: current.refreshWin,
        setWinSizeChars: current.setWinSizeChars,
        maximizeWin: current.maximizeWin,
        fullscreenWin: current.fullscreenWin,
        getWinState: current.getWinState,
        getWinPosition: current.getWinPosition,
        getWinSizePixels: true,
        getScreenSizePixels: current.getScreenSizePixels,
        getCellSizePixels: true,
        getWinSizeChars: true,
        getScreenSizeChars: current.getScreenSizeChars,
        getIconTitle: current.getIconTitle,
        getWinTitle: current.getWinTitle,
        pushTitle: current.pushTitle,
        popTitle: current.popTitle,
        setWinLines: current.setWinLines,
      );
    }
    own(
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(prefix: '?', finalByte: 'h'),
        (parameters) {
          if (parameters.contains(80)) _sixelScrolling = false;
          return false;
        },
      ),
    );
    own(
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(prefix: '?', finalByte: 'l'),
        (parameters) {
          if (parameters.contains(80)) _sixelScrolling = true;
          return false;
        },
      ),
    );
    own(
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(finalByte: 'c'),
        (parameters) {
          if (_parameter(parameters, 0) != 0 || !options.sixelSupport) {
            return false;
          }
          terminal.input('\u001b[?62;4;9;22c', wasUserInput: false);
          return true;
        },
      ),
    );
    own(
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(prefix: '?', finalByte: 'S'),
        _graphicsAttributes,
      ),
    );
    own(
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(intermediates: '!', finalByte: 'p'),
        (_) => reset(),
      ),
    );
    own(
      terminal.parser.registerEscHandler(
        const TerminalFunctionIdentifier(finalByte: 'c'),
        reset,
      ),
    );
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
        terminal.parser.registerOscHandler(1337, _handleIip),
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

  bool _handleIip(String data) {
    if (data == 'ReportCellSize') {
      final dimensions = terminal.dimensions;
      final width = dimensions == null ? 7.0 : dimensions.width / terminal.cols;
      final height = dimensions == null
          ? 14.0
          : dimensions.height / terminal.rows;
      final scale = dimensions?.devicePixelRatio ?? 1;
      terminal.input(
        '\u001b]1337;ReportCellSize=${height.toStringAsFixed(3)};'
        '${width.toStringAsFixed(3)};${scale.toStringAsFixed(3)}\u001b\\',
        wasUserInput: false,
      );
      return true;
    }
    if (data == 'FileEnd') {
      final header = _multipartHeader;
      final payload = _multipartPayload;
      _multipartHeader = null;
      _multipartPayload = null;
      if (header != null && payload != null) {
        _addIip(header, payload.toString());
      }
      return true;
    }
    if (data.startsWith('FilePart=')) {
      final payload = _multipartPayload;
      if (payload != null) {
        final part = data.substring(9);
        if (payload.length + part.length <= _iipEncodedLimit) {
          payload.write(part);
        } else {
          _multipartHeader = null;
          _multipartPayload = null;
        }
      }
      return true;
    }
    if (data.startsWith('MultipartFile=')) {
      final header = _parseIipHeader(data.substring(14));
      if (header?.inline == 1) {
        _multipartHeader = header;
        _multipartPayload = StringBuffer();
      } else {
        _multipartHeader = null;
        _multipartPayload = null;
      }
      return true;
    }
    if (!data.startsWith('File=')) return false;
    _multipartHeader = null;
    _multipartPayload = null;
    final separator = data.indexOf(':');
    if (separator < 0) return true;
    final header = _parseIipHeader(data.substring(5, separator));
    if (header?.inline == 1) {
      _addIip(header!, data.substring(separator + 1));
    }
    return true;
  }

  int get _iipEncodedLimit => (options.iipSizeLimit * 4 / 3).ceil();

  _IipHeader? _parseIipHeader(String source) {
    final values = <String, String>{};
    for (final field in source.split(';')) {
      final separator = field.indexOf('=');
      if (separator <= 0) continue;
      values[field.substring(0, separator)] = field.substring(separator + 1);
    }
    final inline = int.tryParse(values['inline'] ?? '0');
    final size = int.tryParse(values['size'] ?? '0');
    final preserve = int.tryParse(values['preserveAspectRatio'] ?? '1');
    if (inline == null || size == null || preserve == null) return null;
    final width = values['width'] ?? 'auto';
    final height = values['height'] ?? 'auto';
    final dimension = RegExp(r'^(?:auto|\d+(?:px|%)?)$');
    if (!dimension.hasMatch(width) || !dimension.hasMatch(height)) return null;
    var name = 'Unnamed file';
    final encodedName = values['name'];
    if (encodedName != null) {
      final decoded = _decodeBase64(encodedName, options.iipSizeLimit);
      if (decoded == null) return null;
      try {
        name = utf8.decode(decoded);
      } on FormatException {
        return null;
      }
    }
    return _IipHeader(
      inline: inline,
      size: size,
      name: name,
      width: width,
      height: height,
      preserveAspectRatio: preserve,
    );
  }

  void _addIip(_IipHeader header, String payload) {
    final bytes = _decodeBase64(payload, options.iipSizeLimit);
    if (bytes == null) return;
    final metrics = _imageMetrics(bytes);
    if (metrics == null ||
        metrics.width == 0 ||
        metrics.height == 0 ||
        metrics.width * metrics.height >= options.pixelLimit) {
      return;
    }
    _add(
      TerminalImageProtocol.iTerm2,
      bytes,
      options.iipSizeLimit,
      pixelWidth: metrics.width,
      pixelHeight: metrics.height,
      name: header.name,
      storageBytes: metrics.width * metrics.height * 4,
    );
  }

  Uint8List? _decodeBase64(String payload, int limit) {
    if (payload.length > (limit * 4 / 3).ceil() ||
        payload.length % 4 == 1 ||
        !RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(payload)) {
      return null;
    }
    try {
      final decoded = base64.decode(base64.normalize(payload));
      return decoded.length > limit ? null : decoded;
    } on FormatException {
      return null;
    }
  }

  int _parameter(List<TerminalParameter> parameters, int index) {
    if (index >= parameters.length) return 0;
    final value = parameters[index];
    return value is int ? value : 0;
  }

  bool _graphicsAttributes(List<TerminalParameter> parameters) {
    if (parameters.length < 2) return true;
    final item = _parameter(parameters, 0);
    final action = _parameter(parameters, 1);
    if (item == 1) {
      switch (action) {
        case 1:
          _reportGraphics(item, 0, _sixelPaletteLimit);
        case 2:
          _sixelPaletteLimit = options.sixelPaletteLimit;
          _reportGraphics(item, 0, _sixelPaletteLimit);
        case 3:
          final requested = _parameter(parameters, 2);
          if (parameters.length > 2 && requested <= 4096) {
            _sixelPaletteLimit = requested;
            _reportGraphics(item, 0, _sixelPaletteLimit);
          } else {
            _reportGraphics(item, 2);
          }
        case 4:
          _reportGraphics(item, 0, 4096);
        default:
          _reportGraphics(item, 2);
      }
      return true;
    }
    if (item == 2) {
      if (action == 1 || action == 4) {
        var width = terminal.dimensions?.width ?? terminal.cols * 7;
        var height = terminal.dimensions?.height ?? terminal.rows * 14;
        if (action == 4 || width * height >= options.pixelLimit) {
          final side = math.sqrt(options.pixelLimit).floorToDouble();
          width = side;
          height = side;
        }
        _reportGraphics(item, 0, width.round(), height.round());
      } else {
        _reportGraphics(item, 2);
      }
      return true;
    }
    _reportGraphics(item, 1);
    return true;
  }

  void _reportGraphics(int item, int status, [int? first, int? second]) {
    final values = <int>[item, status, ?first, ?second].join(';');
    terminal.input('\u001b[?${values}S', wasUserInput: false);
  }

  void _addBase64(TerminalImageProtocol protocol, String payload, int limit) {
    final decoded = _decodeBase64(payload, limit);
    if (decoded != null) _add(protocol, decoded, limit);
  }

  void _add(
    TerminalImageProtocol protocol,
    List<int> bytes,
    int limit, {
    int? pixelWidth,
    int? pixelHeight,
    String name = 'Unnamed file',
    int? storageBytes,
  }) {
    if (bytes.length > limit) return;
    final image = TerminalImage(
      protocol: protocol,
      data: Uint8List.fromList(bytes),
      column: terminal.buffer.active.cursorX,
      row: terminal.buffer.active.baseY + terminal.buffer.active.cursorY,
      scrolls: protocol != TerminalImageProtocol.sixel || _sixelScrolling,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      name: name,
      storageBytes: storageBytes ?? bytes.length,
    );
    _images.add(image);
    _storageBytes += image.storageBytes;
    _evictToLimit();
    _onImageAdded.fire(TerminalVoid.value);
  }

  void _setStorageLimit(double value) {
    if (value < 0.5 || value > 1000) {
      throw RangeError.value(
        value,
        'storageLimit',
        'must be at least 0.5 MB and not exceed 1000 MB',
      );
    }
    _effectiveStorageLimit = (value * 250000).truncate() * 4 / 1000000;
    _evictToLimit();
  }

  void _evictToLimit() {
    final maximumBytes = (_effectiveStorageLimit * 1000000).truncate();
    while (_storageBytes > maximumBytes && _images.isNotEmpty) {
      _storageBytes -= _images.removeAt(0).storageBytes;
    }
  }

  /// xterm-compatible `getImageAtBufferCell` API.
  TerminalImage? getImageAtBufferCell(int column, int row) {
    for (final image in _images.reversed) {
      if (image.column == column && image.row == row) return image;
    }
    return null;
  }

  /// Extracts the image tile represented by one buffer cell.
  ///
  /// The standalone representation retains encoded bytes; Flutter renderers
  /// crop those bytes' decoded image to the requested cell when painting.
  TerminalImage? extractTileAtBufferCell(int column, int row) =>
      getImageAtBufferCell(column, row);

  /// Removes all retained image payloads.
  bool reset() {
    _sixelScrolling = options.sixelScrolling;
    _sixelPaletteLimit = options.sixelPaletteLimit;
    _multipartHeader = null;
    _multipartPayload = null;
    _images.clear();
    _storageBytes = 0;
    return false;
  }

  @override
  void dispose() {
    reset();
    _onImageAdded.dispose();
    super.dispose();
  }
}

final class _IipHeader {
  const _IipHeader({
    required this.inline,
    required this.size,
    required this.name,
    required this.width,
    required this.height,
    required this.preserveAspectRatio,
  });

  final int inline;
  final int size;
  final String name;
  final String width;
  final String height;
  final int preserveAspectRatio;
}

final class _ImageMetrics {
  const _ImageMetrics(this.width, this.height);

  final int width;
  final int height;
}

_ImageMetrics? _imageMetrics(List<int> data) {
  if (data.length < 24) return null;
  if (data[0] == 0x89 &&
      data[1] == 0x50 &&
      data[2] == 0x4e &&
      data[3] == 0x47 &&
      data[4] == 0x0d &&
      data[5] == 0x0a &&
      data[6] == 0x1a &&
      data[7] == 0x0a &&
      data[12] == 0x49 &&
      data[13] == 0x48 &&
      data[14] == 0x44 &&
      data[15] == 0x52) {
    return _ImageMetrics(_bigEndian32(data, 16), _bigEndian32(data, 20));
  }
  if (data[0] == 0x47 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x38 &&
      (data[4] == 0x37 || data[4] == 0x39) &&
      data[5] == 0x61) {
    return _ImageMetrics(
      data[6] | data[7] << 8,
      data[8] | data[9] << 8,
    );
  }
  if (data[0] == 0x71 &&
      data[1] == 0x6f &&
      data[2] == 0x69 &&
      data[3] == 0x66) {
    return _ImageMetrics(_bigEndian32(data, 4), _bigEndian32(data, 8));
  }
  if (data[0] == 0xff && data[1] == 0xd8 && data[2] == 0xff) {
    var offset = 4;
    while (offset + 8 < data.length) {
      final blockLength = data[offset] << 8 | data[offset + 1];
      offset += blockLength;
      if (offset + 8 >= data.length || data[offset] != 0xff) return null;
      final marker = data[offset + 1];
      if (marker == 0xc0 || marker == 0xc2) {
        return _ImageMetrics(
          data[offset + 7] << 8 | data[offset + 8],
          data[offset + 5] << 8 | data[offset + 6],
        );
      }
      offset += 2;
    }
  }
  return null;
}

int _bigEndian32(List<int> data, int offset) =>
    data[offset] << 24 |
    data[offset + 1] << 16 |
    data[offset + 2] << 8 |
    data[offset + 3];
