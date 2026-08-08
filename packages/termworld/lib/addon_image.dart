/// Sixel, iTerm2 inline image, and Kitty graphics addon.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:termworld/src/addons/iip_header_parser.dart';
import 'package:termworld/src/addons/kitty_graphics_types.dart';
import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/event.dart';
import 'package:termworld/src/core/options.dart';
import 'package:termworld/src/core/parser.dart';
import 'package:termworld/src/core/terminal.dart';

export 'src/addons/iip_header_parser.dart';
export 'src/addons/kitty_graphics_types.dart';

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
    this.kittyId,
    this.placementId,
    this.columns,
    this.rows,
    this.zIndex = 0,
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

  /// Kitty image identifier, when this is a Kitty placement.
  final int? kittyId;

  /// Kitty placement identifier.
  final int? placementId;

  /// Requested placement width in terminal columns.
  final int? columns;

  /// Requested placement height in terminal rows.
  final int? rows;

  /// Kitty placement z-index.
  final int zIndex;
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
  final Map<int, _KittyImageData> _kittyImages = <int, _KittyImageData>{};
  final Map<int, _KittyPending> _kittyPending = <int, _KittyPending>{};
  int _nextKittyId = 1;
  int? _lastKittyPendingKey;

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
    add(
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(prefix: '?', finalByte: 'h'),
        (parameters) {
          if (parameters.contains(80)) _sixelScrolling = false;
          return false;
        },
      ),
    );
    add(
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(prefix: '?', finalByte: 'l'),
        (parameters) {
          if (parameters.contains(80)) _sixelScrolling = true;
          return false;
        },
      ),
    );
    add(
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
    add(
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(prefix: '?', finalByte: 'S'),
        _graphicsAttributes,
      ),
    );
    add(
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(intermediates: '!', finalByte: 'p'),
        (_) => reset(),
      ),
    );
    add(
      terminal.parser.registerEscHandler(
        const TerminalFunctionIdentifier(finalByte: 'c'),
        reset,
      ),
    );
    if (options.sixelSupport) {
      add(
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
      add(
        terminal.parser.registerOscHandler(1337, _handleIip),
      );
    }
    if (options.kittySupport) {
      add(
        terminal.parser.registerApcHandler(
          const TerminalFunctionIdentifier(finalByte: 'G'),
          _handleKitty,
        ),
      );
    }
  }

  bool _handleKitty(String data) {
    final separator = data.indexOf(';');
    final control = separator < 0 ? data : data.substring(0, separator);
    final payload = separator < 0 ? '' : data.substring(separator + 1);
    final command = _KittyCommand.from(parseKittyCommand(control));
    if (command.id != null && command.imageNumber != null) {
      _kittyResponse(
        command.id!,
        'EINVAL:cannot specify both i and I keys',
        command,
      );
      return true;
    }
    final action = command.action ?? 't';
    if (action == 'd') return _deleteKitty(command);
    if (separator < 0) {
      if (action == 'q') {
        _kittyResponse(command.id ?? 0, 'OK', command);
      } else if (action == 'p') {
        _handleKittyPlacement(command);
      } else if (command.id != null) {
        _kittyResponse(command.id!, 'EINVAL:unsupported action', command);
      }
      return true;
    }

    final key = command.id ?? _lastKittyPendingKey ?? 0;
    final pending = _kittyPending[key];
    final encodedLength = (pending?.payload.length ?? 0) + payload.length;
    if (encodedLength > (options.kittySizeLimit * 4 / 3).ceil()) {
      _kittyPending.remove(key);
      if (_lastKittyPendingKey == key) _lastKittyPendingKey = null;
      return true;
    }
    if (command.more == 1) {
      if (pending == null) {
        _kittyPending[key] = _KittyPending(command, StringBuffer(payload));
      } else {
        pending.payload.write(payload);
      }
      _lastKittyPendingKey = key;
      return true;
    }

    var effective = command;
    var encoded = payload;
    if (pending != null) {
      pending.payload.write(payload);
      encoded = pending.payload.toString();
      effective = pending.command;
      _kittyPending.remove(key);
      _lastKittyPendingKey = null;
    }
    final bytes = _decodeBase64(encoded, options.kittySizeLimit);
    final decodeError = bytes == null;
    return _executeKitty(effective, bytes ?? Uint8List(0), decodeError);
  }

  bool _executeKitty(
    _KittyCommand command,
    Uint8List bytes,
    bool decodeError,
  ) {
    final action = command.action ?? 't';
    if (action == 'q') {
      if (command.transmission != null && command.transmission != 'd') {
        _kittyResponse(
          command.id ?? 0,
          'EINVAL:unsupported transmission medium',
          command,
        );
      } else if (decodeError) {
        _kittyResponse(
          command.id ?? 0,
          'EINVAL:invalid base64 data',
          command,
        );
      } else if (!_validKittyPixels(command, bytes)) {
        _kittyResponse(
          command.id ?? 0,
          'EINVAL:width and height required for raw pixel data',
          command,
        );
      } else {
        _kittyResponse(command.id ?? 0, 'OK', command);
      }
      return true;
    }
    if (action == 'p') return _handleKittyPlacement(command);
    if (action != 't' && action != 'T') {
      if (command.id != null) {
        _kittyResponse(command.id!, 'EINVAL:unsupported action', command);
      }
      return true;
    }
    if (command.transmission != null && command.transmission != 'd') {
      if (command.id != null) {
        _kittyResponse(
          command.id!,
          'EINVAL:unsupported transmission medium',
          command,
        );
      }
      return true;
    }
    if (decodeError || bytes.isEmpty) {
      if (command.id != null) {
        _kittyResponse(command.id!, 'EINVAL:invalid base64 data', command);
      }
      return true;
    }
    final id = command.id ?? _nextKittyId++;
    _kittyImages[id] = _KittyImageData(
      id: id,
      bytes: bytes,
      width: command.width ?? 0,
      height: command.height ?? 0,
      format: command.format ?? 32,
    );
    if (_kittyImages.length > 256) {
      _kittyImages.remove(_kittyImages.keys.first);
    }
    if (action == 'T') {
      final placed = _placeKitty(command.copyWith(id: id));
      if (command.id != null) {
        _kittyResponse(
          id,
          placed ? 'OK' : 'EINVAL:image rendering failed',
          command,
        );
      }
    } else if (command.id != null) {
      _kittyResponse(id, 'OK', command);
    }
    return true;
  }

  bool _validKittyPixels(_KittyCommand command, Uint8List bytes) {
    final format = command.format ?? 32;
    if (bytes.isEmpty || format == 100) return true;
    final width = command.width ?? 0;
    final height = command.height ?? 0;
    if (width == 0 || height == 0) return false;
    return bytes.length >= width * height * (format == 24 ? 3 : 4);
  }

  bool _placeKitty(_KittyCommand command) {
    final id = command.id;
    if (id == null) return true;
    final image = _kittyImages[id];
    if (image == null) return false;
    _ImageMetrics? metrics;
    if (image.format == 100) metrics = _imageMetrics(image.bytes);
    final width = metrics?.width ?? image.width;
    final height = metrics?.height ?? image.height;
    if (width <= 0 || height <= 0 || width * height > options.pixelLimit) {
      return false;
    }
    final cellWidth = terminal.dimensions?.cellWidth ?? 7;
    final cellHeight = terminal.dimensions?.cellHeight ?? 14;
    var columns = command.columns;
    var rows = command.rows;
    if (columns != null && rows == null) {
      rows = math.max(
        1,
        (height / width * (columns * cellWidth) / cellHeight).ceil(),
      );
    } else if (rows != null && columns == null) {
      columns = math.max(
        1,
        (width / height * (rows * cellHeight) / cellWidth).ceil(),
      );
    }
    columns ??= math.max(1, (width / cellWidth).ceil());
    rows ??= math.max(1, (height / cellHeight).ceil());
    _add(
      TerminalImageProtocol.kitty,
      image.bytes,
      options.kittySizeLimit,
      pixelWidth: width,
      pixelHeight: height,
      storageBytes: width * height * 4,
      kittyId: id,
      placementId: command.placementId,
      columns: columns,
      rows: rows,
      zIndex: command.zIndex ?? 0,
    );
    if (command.cursorMovement != 1) {
      terminal.buffer.active.cursorX = math.min(
        terminal.buffer.active.cursorX + columns,
        terminal.cols,
      );
    }
    return true;
  }

  bool _handleKittyPlacement(_KittyCommand command) {
    final id = command.id;
    if (id == null) return true;
    if (!_kittyImages.containsKey(id)) {
      _kittyResponse(id, 'ENOENT:image not found', command);
      return true;
    }
    final placed = _placeKitty(command);
    _kittyResponse(
      id,
      placed ? 'OK' : 'EINVAL:image rendering failed',
      command,
    );
    return true;
  }

  bool _deleteKitty(_KittyCommand command) {
    final selector = command.deleteSelector ?? 'a';
    if (selector == 'a' || selector == 'A') {
      _kittyPending.clear();
      _lastKittyPendingKey = null;
      _kittyImages.clear();
      _removeKittyPlacements();
    } else if ((selector == 'i' || selector == 'I') && command.id != null) {
      final id = command.id!;
      _kittyPending.remove(id);
      if (_lastKittyPendingKey == id) _lastKittyPendingKey = null;
      _kittyImages.remove(id);
      _removeKittyPlacements(id);
    }
    return true;
  }

  void _removeKittyPlacements([int? id]) {
    for (var index = _images.length - 1; index >= 0; index--) {
      final image = _images[index];
      if (image.protocol == TerminalImageProtocol.kitty &&
          (id == null || image.kittyId == id)) {
        _storageBytes -= image.storageBytes;
        _images.removeAt(index);
      }
    }
  }

  void _kittyResponse(int id, String message, _KittyCommand command) {
    final quiet = command.quiet ?? 0;
    if (message == 'OK' && quiet >= 1 || message != 'OK' && quiet >= 2) return;
    final placement = command.placementId == null
        ? ''
        : ',p=${command.placementId}';
    terminal.input(
      '\u001b_Gi=$id$placement;$message\u001b\\',
      wasUserInput: false,
    );
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
      final header = _parseIipHeader(data);
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
    final header = _parseIipHeader(data.substring(0, separator + 1));
    if (header?.inline == 1) {
      _addIip(header!, data.substring(separator + 1));
    }
    return true;
  }

  int get _iipEncodedLimit => (options.iipSizeLimit * 4 / 3).ceil();

  _IipHeader? _parseIipHeader(String source) {
    final parser = IipHeaderParser();
    final input = Uint32List.fromList(source.codeUnits);
    var result = parser.parse(input, 0, input.length);
    if (result == -2) result = parser.end();
    if (result < 0 || parser.state != IipHeaderState.end) return null;
    final values = parser.fields;
    final inline = values['inline'] as int? ?? 0;
    final size = values['size'] as int? ?? 0;
    final preserve = values['preserveAspectRatio'] as int? ?? 1;
    final width = values['width'] as String? ?? 'auto';
    final height = values['height'] as String? ?? 'auto';
    final name = values['name'] as String? ?? 'Unnamed file';
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

  void _add(
    TerminalImageProtocol protocol,
    List<int> bytes,
    int limit, {
    int? pixelWidth,
    int? pixelHeight,
    String name = 'Unnamed file',
    int? storageBytes,
    int? kittyId,
    int? placementId,
    int? columns,
    int? rows,
    int zIndex = 0,
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
      kittyId: kittyId,
      placementId: placementId,
      columns: columns,
      rows: rows,
      zIndex: zIndex,
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
    _kittyImages.clear();
    _kittyPending.clear();
    _lastKittyPendingKey = null;
    _nextKittyId = 1;
    _images.clear();
    _storageBytes = 0;
    return false;
  }

  @override
  void dispose() {
    if (isDisposed) return;
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

final class _KittyCommand {
  const _KittyCommand({
    this.action,
    this.format,
    this.id,
    this.imageNumber,
    this.width,
    this.height,
    this.columns,
    this.rows,
    this.more,
    this.quiet,
    this.cursorMovement,
    this.zIndex,
    this.transmission,
    this.deleteSelector,
    this.placementId,
  });

  factory _KittyCommand.from(KittyCommand source) => _KittyCommand(
    action: source.action,
    format: _validKittyInteger(source.format),
    id: _validKittyInteger(source.id),
    imageNumber: _validKittyInteger(source.imageNumber),
    width: _validKittyInteger(source.width),
    height: _validKittyInteger(source.height),
    columns: _validKittyInteger(source.columns),
    rows: _validKittyInteger(source.rows),
    more: _validKittyInteger(source.more),
    quiet: _validKittyInteger(source.quiet),
    cursorMovement: _validKittyInteger(source.cursorMovement),
    zIndex: _validKittyInteger(source.zIndex),
    transmission: source.transmission,
    deleteSelector: source.deleteSelector,
    placementId: _validKittyInteger(source.placementId),
  );

  final String? action;
  final int? format;
  final int? id;
  final int? imageNumber;
  final int? width;
  final int? height;
  final int? columns;
  final int? rows;
  final int? more;
  final int? quiet;
  final int? cursorMovement;
  final int? zIndex;
  final String? transmission;
  final String? deleteSelector;
  final int? placementId;

  _KittyCommand copyWith({int? id}) => _KittyCommand(
    action: action,
    format: format,
    id: id ?? this.id,
    imageNumber: imageNumber,
    width: width,
    height: height,
    columns: columns,
    rows: rows,
    more: more,
    quiet: quiet,
    cursorMovement: cursorMovement,
    zIndex: zIndex,
    transmission: transmission,
    deleteSelector: deleteSelector,
    placementId: placementId,
  );
}

int? _validKittyInteger(num? value) =>
    value == null || value is double && !value.isFinite ? null : value.toInt();

final class _KittyPending {
  const _KittyPending(this.command, this.payload);

  final _KittyCommand command;
  final StringBuffer payload;
}

final class _KittyImageData {
  const _KittyImageData({
    required this.id,
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });

  final int id;
  final Uint8List bytes;
  final int width;
  final int height;
  final int format;
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
