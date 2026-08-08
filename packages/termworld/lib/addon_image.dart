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
      scrolls: protocol != TerminalImageProtocol.sixel || _sixelScrolling,
    );
    _images.add(image);
    _storageBytes += image.data.length;
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
      _storageBytes -= _images.removeAt(0).data.length;
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
