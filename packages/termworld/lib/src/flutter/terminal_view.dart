import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:termworld/addon_image.dart';
import 'package:termworld/src/addons/qoi_decoder.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/keyboard.dart';
import 'package:termworld/src/core/kitty_keyboard.dart';
import 'package:termworld/src/core/marker.dart';
import 'package:termworld/src/core/options.dart';
import 'package:termworld/src/core/selection_service.dart';
import 'package:termworld/src/core/terminal.dart';
import 'package:termworld/src/flutter/cell_color_resolver.dart';
import 'package:termworld/src/flutter/terminal_theme.dart';
import 'package:termworld/src/flutter/terminal_view_controller.dart';

enum _PointerSelectionMode { normal, word, line, column }

/// Flutter renderer and input surface for a headless [Terminal].
class TerminalView extends StatefulWidget {
  /// Creates a terminal view. The caller retains ownership of [terminal].
  const TerminalView({
    required this.terminal,
    super.key,
    this.controller,
    this.theme,
    this.style,
    this.padding,
    this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.autoResize = true,
    this.backgroundOpacity = 1,
    this.semanticLabel = 'terminal',
    this.onTapUp,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
  });

  /// Terminal model to render.
  final Terminal terminal;

  /// Optional externally owned controller.
  final TerminalViewController? controller;

  /// Renderer color theme.
  final TerminalTheme? theme;

  /// Renderer font style.
  final TerminalStyle? style;

  /// Space around the terminal viewport.
  final EdgeInsets? padding;

  /// Optional externally owned focus node.
  final FocusNode? focusNode;

  /// Whether this view requests initial focus.
  final bool autofocus;

  /// Whether user input is disabled.
  final bool readOnly;

  /// Whether measured cell dimensions resize [terminal].
  final bool autoResize;

  /// Opacity of the terminal background.
  final double backgroundOpacity;

  /// Accessibility label for the terminal surface.
  final String semanticLabel;

  /// Tap callback in terminal cell coordinates.
  final void Function(TapUpDetails, TerminalCellOffset)? onTapUp;

  /// Secondary pointer-down callback in terminal cell coordinates.
  final void Function(TapDownDetails, TerminalCellOffset)? onSecondaryTapDown;

  /// Secondary pointer-up callback in terminal cell coordinates.
  final void Function(TapUpDetails, TerminalCellOffset)? onSecondaryTapUp;

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

final class _TerminalViewState extends State<TerminalView> {
  final GlobalKey<_TerminalTextInputState> _inputKey =
      GlobalKey<_TerminalTextInputState>();
  late FocusNode _focusNode =
      widget.focusNode ?? FocusNode(debugLabel: 'termworld-terminal-input');
  late TerminalViewController _controller =
      widget.controller ?? TerminalViewController();
  MethodChannel? _testingChannel;
  Disposable? _renderListener;
  Disposable? _cursorMoveListener;
  Disposable? _scrollListener;
  Disposable? _selectionListener;
  Disposable? _imageListener;
  ImageAddon? _imageAddon;
  final Map<int, ({ui.Image raster, TerminalImage source})> _decodedImages =
      <int, ({ui.Image raster, TerminalImage source})>{};
  var _imageDecodeGeneration = 0;
  Disposable? _a11yCharListener;
  Disposable? _a11yTabListener;
  Disposable? _a11yLineFeedListener;
  Disposable? _a11yKeyListener;
  TerminalLink? _hoveredLink;
  Disposable? _linkDecorationListener;
  TerminalLink? _pointerDownLink;
  List<List<TerminalLink>>? _activeLinkReplies;
  int _activeLinkLine = -1;
  int _linkRequestGeneration = 0;
  Timer? _cursorBlinkTimer;
  Timer? _cursorBlinkIdleTimer;
  bool _cursorVisible = true;
  bool _cursorBlinkIdle = false;
  bool _hasBeenFocused = false;
  TerminalMouseButton _pressedMouseButton = TerminalMouseButton.none;
  TerminalCellOffset? _selectionAnchor;
  TerminalCellOffset? _selectionAnchorEnd;
  _PointerSelectionMode _pointerSelectionMode = _PointerSelectionMode.normal;
  TerminalCellOffset? _lastClickCell;
  Timer? _clickResetTimer;
  int _clickCount = 0;
  double _wheelPartialScroll = 0;
  Timer? _dragScrollTimer;
  int _dragScrollAmount = 0;
  int _dragSelectionColumn = 0;
  final List<String> _a11yCharsToConsume = <String>[];
  final StringBuffer _a11yCharsToAnnounce = StringBuffer();
  String _a11yAnnouncement = '';
  int _a11yLineCount = 0;
  bool _a11yFlushScheduled = false;

  @override
  void initState() {
    super.initState();
    _hasBeenFocused = _focusNode.hasFocus;
    _focusNode.addListener(_handleFocusChange);
    _attach();
    if (kDebugMode) {
      _testingChannel = const MethodChannel('termworld/testing')
        ..setMethodCallHandler(_handleTestingCall);
    }
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) _syncCursorBlink();
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode =
          widget.focusNode ?? FocusNode(debugLabel: 'termworld-terminal-input');
      _hasBeenFocused = _focusNode.hasFocus;
      _focusNode.addListener(_handleFocusChange);
      _syncCursorBlink();
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.terminal != widget.terminal) {
      oldWidget.terminal
        ..attachFocusHandlers()
        ..attachViewElements();
      _clearLinkCache();
      _renderListener?.dispose();
      _cursorMoveListener?.dispose();
      _scrollListener?.dispose();
      _selectionListener?.dispose();
      _disposeAccessibilityListeners();
      _controller.detach();
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? TerminalViewController();
      _attach();
    }
  }

  void _attach() {
    _controller.attach(widget.terminal, _requestKeyboard);
    final documentOverride = widget.terminal.options.documentOverride;
    widget.terminal.attachViewElements(
      element: documentOverride?.resolveElement(context) ?? context,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentOverride = widget.terminal.options.documentOverride;
      final screen = context.findRenderObject();
      final textarea = _inputKey.currentState;
      widget.terminal.attachViewElements(
        element: currentOverride?.resolveElement(context) ?? context,
        screen: currentOverride?.resolveScreenElement(screen) ?? screen,
        textarea: currentOverride?.resolveTextarea(textarea) ?? textarea,
      );
    });
    _renderListener = widget.terminal.onRender.listen((_) {
      if (mounted) {
        _syncCursorBlink();
        setState(() {});
      }
    });
    _cursorMoveListener = widget.terminal.onCursorMove.listen((_) {
      _restartCursorBlinkAnimation();
    });
    _scrollListener = widget.terminal.onScroll.listen((_) {
      if (mounted) setState(() {});
    });
    _selectionListener = widget.terminal.onSelectionChange.listen((_) {
      if (mounted) setState(() {});
    });
    _syncImageAddon();
    _a11yCharListener = widget.terminal.onA11yChar.listen(_handleA11yChar);
    _a11yTabListener = widget.terminal.onA11yTab.listen((spaceCount) {
      for (var index = 0; index < spaceCount; index++) {
        _handleA11yChar(' ');
      }
    });
    _a11yLineFeedListener = widget.terminal.onLineFeed.listen((_) {
      _handleA11yChar('\n');
    });
    _a11yKeyListener = widget.terminal.onKey.listen((event) {
      _clearA11yAnnouncement();
      if (!_containsControlCharacter(event.key)) {
        _a11yCharsToConsume.add(event.key);
      }
    });
    widget.terminal.attachFocusHandlers(
      focus: _requestKeyboard,
      blur: _focusNode.unfocus,
    );
  }

  void _syncImageAddon() {
    final addon = ImageAddon.activeFor(widget.terminal);
    if (identical(addon, _imageAddon)) return;
    _imageListener?.dispose();
    _imageListener = null;
    _imageAddon = addon;
    _clearDecodedImages();
    if (addon == null) return;
    _imageListener = addon.onImagesChanged.listen((_) => _decodeImages());
    _decodeImages();
  }

  void _decodeImages() {
    final addon = _imageAddon;
    if (addon == null) return;
    final generation = ++_imageDecodeGeneration;
    final live = addon.images.map((image) => image.storageId).toSet();
    for (final id in _decodedImages.keys.toList(growable: false)) {
      if (live.contains(id)) continue;
      _decodedImages.remove(id)?.raster.dispose();
    }
    for (final source in addon.images) {
      if (_decodedImages.containsKey(source.storageId)) continue;
      unawaited(
        _decodeTerminalImage(source)
            .then((raster) {
              if (!mounted ||
                  generation != _imageDecodeGeneration ||
                  !addon.images.any(
                    (image) => image.storageId == source.storageId,
                  )) {
                raster.dispose();
                return;
              }
              _decodedImages[source.storageId] = (
                raster: raster,
                source: source,
              );
              setState(() {});
            })
            .onError((_, _) {
              // Browser decoders also ignore malformed protocol payloads.
            }),
      );
    }
  }

  Future<ui.Image> _decodeTerminalImage(TerminalImage source) {
    if (source.data.length >= 4 &&
        source.data[0] == 0x71 &&
        source.data[1] == 0x6f &&
        source.data[2] == 0x69 &&
        source.data[3] == 0x66) {
      final decoded = decodeQoi(source.data);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        decoded.pixels,
        decoded.width,
        decoded.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    }
    return decodeImageFromList(source.data);
  }

  void _clearDecodedImages() {
    _imageDecodeGeneration++;
    for (final decoded in _decodedImages.values) {
      decoded.raster.dispose();
    }
    _decodedImages.clear();
  }

  void _requestKeyboard() {
    _focusNode.requestFocus();
    _inputKey.currentState?.requestKeyboard();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _hasBeenFocused = true;
      _restartCursorBlinkAnimation();
    } else {
      _syncCursorBlink();
      _clearA11yAnnouncement();
    }
    if (mounted) setState(() {});
  }

  static bool _containsControlCharacter(String value) => value.runes.any(
    (codePoint) =>
        codePoint < 0x20 ||
        codePoint == 0x7f ||
        codePoint >= 0x80 && codePoint <= 0x9f,
  );

  void _handleA11yChar(String character) {
    if (!widget.terminal.options.screenReaderMode || _a11yLineCount > 20) {
      return;
    }
    if (_a11yCharsToConsume.isNotEmpty) {
      final consumed = _a11yCharsToConsume.removeAt(0);
      if (consumed != character) _a11yCharsToAnnounce.write(character);
    } else {
      _a11yCharsToAnnounce.write(character);
    }
    if (character == '\n') {
      _a11yLineCount++;
      if (_a11yLineCount == 21) {
        _a11yAnnouncement = Terminal.strings.tooMuchOutput;
      }
    }
    _scheduleA11yFlush();
  }

  void _scheduleA11yFlush() {
    if (_a11yFlushScheduled) return;
    _a11yFlushScheduled = true;
    scheduleMicrotask(() {
      _a11yFlushScheduled = false;
      if (!mounted || _a11yCharsToAnnounce.isEmpty) return;
      if (_a11yAnnouncement == Terminal.strings.tooMuchOutput) {
        _a11yAnnouncement = '';
        _a11yLineCount = 0;
      }
      _a11yAnnouncement += _a11yCharsToAnnounce.toString();
      _a11yCharsToAnnounce.clear();
      setState(() {});
    });
  }

  void _clearA11yAnnouncement() {
    _a11yAnnouncement = '';
    _a11yLineCount = 0;
    if (mounted) setState(() {});
  }

  void _disposeAccessibilityListeners() {
    _a11yCharListener?.dispose();
    _a11yTabListener?.dispose();
    _a11yLineFeedListener?.dispose();
    _a11yKeyListener?.dispose();
    _a11yCharListener = null;
    _a11yTabListener = null;
    _a11yLineFeedListener = null;
    _a11yKeyListener = null;
    _a11yCharsToConsume.clear();
    _a11yCharsToAnnounce.clear();
    _a11yAnnouncement = '';
    _a11yLineCount = 0;
  }

  void _syncCursorBlink() {
    final shouldBlink = _focusNode.hasFocus && _effectiveStyle.cursorBlink;
    if (!shouldBlink) {
      _cursorBlinkTimer?.cancel();
      _cursorBlinkTimer = null;
      _cursorBlinkIdleTimer?.cancel();
      _cursorBlinkIdleTimer = null;
      _cursorBlinkIdle = false;
      _cursorVisible = true;
      return;
    }
    if (_cursorBlinkIdle) {
      _cursorBlinkTimer?.cancel();
      _cursorBlinkTimer = null;
      _cursorVisible = true;
      return;
    }
    if (_cursorBlinkTimer != null) return;
    _cursorVisible = true;
    _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      _cursorVisible = !_cursorVisible;
      setState(() {});
    });
    _resetCursorBlinkIdleTimer();
  }

  void _restartCursorBlinkAnimation() {
    _cursorBlinkIdle = false;
    _cursorBlinkTimer?.cancel();
    _cursorBlinkTimer = null;
    _cursorVisible = true;
    _syncCursorBlink();
    if (mounted) setState(() {});
  }

  void _resetCursorBlinkIdleTimer() {
    _cursorBlinkIdleTimer?.cancel();
    _cursorBlinkIdleTimer = Timer(const Duration(minutes: 5), () {
      if (!mounted) return;
      _cursorBlinkIdle = true;
      _cursorBlinkTimer?.cancel();
      _cursorBlinkTimer = null;
      _cursorVisible = true;
      setState(() {});
    });
  }

  Future<Object?> _handleTestingCall(MethodCall call) async {
    if (call.method != 'injectEditingValue') {
      throw MissingPluginException('Unknown termworld testing method');
    }
    final arguments = Map<String, dynamic>.from(call.arguments as Map);
    _inputKey.currentState?.updateEditingValue(
      TextEditingValue.fromJSON(arguments),
    );
    return null;
  }

  @override
  void dispose() {
    _clearLinkCache();
    _cursorBlinkTimer?.cancel();
    _cursorBlinkIdleTimer?.cancel();
    _clickResetTimer?.cancel();
    _dragScrollTimer?.cancel();
    _focusNode.removeListener(_handleFocusChange);
    _renderListener?.dispose();
    _cursorMoveListener?.dispose();
    _scrollListener?.dispose();
    _selectionListener?.dispose();
    _imageListener?.dispose();
    _clearDecodedImages();
    _disposeAccessibilityListeners();
    _testingChannel?.setMethodCallHandler(null);
    _testingChannel = null;
    _controller.detach();
    widget.terminal.attachFocusHandlers();
    widget.terminal.attachViewElements();
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _syncImageAddon();
      _reportDimensions(context, constraints.biggest);
      final theme =
          widget.theme ??
          TerminalThemes.resolve(
            widget.terminal.options.theme,
            overrides: widget.terminal.colorOverrides,
          );
      final style = _effectiveStyle;
      final renderer = CustomPaint(
        painter: _TerminalPainter(
          terminal: widget.terminal,
          theme: theme,
          style: style,
          padding: widget.padding ?? EdgeInsets.zero,
          backgroundOpacity: widget.backgroundOpacity,
          focused: _focusNode.hasFocus,
          cursorInitialized: _hasBeenFocused,
          cursorVisible: _cursorVisible,
          hoveredLink: _hoveredLink,
          decodedImages: _decodedImages,
        ),
        size: constraints.biggest,
      );
      final composingText = _inputKey.currentState?.composingText ?? '';
      final padding = widget.padding ?? EdgeInsets.zero;
      final dimensions = widget.terminal.dimensions;
      final view = Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        onPointerHover: _onPointerHover,
        onPointerSignal: _onPointerSignal,
        child: MouseRegion(
          cursor: _linkUsesPointer(_hoveredLink)
              ? SystemMouseCursors.click
              : _mouseReportingCapturesPointer
              ? SystemMouseCursors.basic
              : SystemMouseCursors.text,
          onHover: (event) {
            if (widget.terminal.modes.mouseTrackingMode == 'none') {
              unawaited(
                _updateHoveredLink(event, _cellAt(event.localPosition)),
              );
            }
          },
          onExit: _leaveLink,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _requestKeyboard,
            onTapDown: (details) {
              if (widget.terminal.modes.mouseTrackingMode != 'none') return;
              unawaited(
                _recordPointerDownLink(
                  details,
                  _cellAt(details.localPosition),
                ),
              );
            },
            onTapUp: (details) {
              final cell = _cellAt(details.localPosition);
              widget.onTapUp?.call(details, cell);
              if (widget.terminal.modes.mouseTrackingMode != 'none') return;
              unawaited(_activatePointerDownLink(details, cell));
            },
            onTapCancel: () => _pointerDownLink = null,
            onSecondaryTapDown: (details) {
              widget.onSecondaryTapDown?.call(
                details,
                _cellAt(details.localPosition),
              );
            },
            onSecondaryTapUp: (details) {
              widget.onSecondaryTapUp?.call(
                details,
                _cellAt(details.localPosition),
              );
            },
            child: _TerminalTextInput(
              key: _inputKey,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              readOnly: widget.readOnly,
              terminal: widget.terminal,
              onKeyEvent: _onKeyEvent,
              onComposingChanged: () {
                if (mounted) setState(() {});
              },
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  renderer,
                  if (composingText.isNotEmpty && dimensions != null)
                    Positioned(
                      left:
                          padding.left +
                          widget.terminal.buffer.active.cursorX *
                              dimensions.cellWidth,
                      top:
                          padding.top +
                          widget.terminal.buffer.active.cursorY *
                              dimensions.cellHeight,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.background,
                            border: Border(
                              bottom: BorderSide(color: theme.foreground),
                            ),
                          ),
                          child: Text(
                            composingText,
                            key: const ValueKey<String>('termworld-preedit'),
                            style: style.toTextStyle(
                              color: theme.foreground,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.semanticLabel,
        value: widget.terminal.options.screenReaderMode
            ? _semanticValue()
            : null,
        textField: !widget.readOnly,
        child: widget.terminal.options.screenReaderMode
            ? Stack(
                children: <Widget>[
                  view,
                  Semantics(
                    container: true,
                    liveRegion: true,
                    label: _a11yAnnouncement,
                    child: const SizedBox.shrink(),
                  ),
                ],
              )
            : view,
      );
    },
  );

  String _semanticValue() {
    final terminal = widget.terminal;
    final output = <String>[];
    for (var row = 0; row < terminal.rows; row++) {
      final line = terminal.buffer.active.getLine(terminal.viewportY + row);
      if (line == null) continue;
      output.add(line.translateToString(trimRight: true));
    }
    return output.join('\n');
  }

  TerminalCellOffset _cellAt(Offset localPosition) {
    final dimensions = widget.terminal.dimensions;
    final padding = widget.padding ?? EdgeInsets.zero;
    if (dimensions == null) return const TerminalCellOffset(0, 0);
    return TerminalCellOffset(
      ((localPosition.dx - padding.left) / dimensions.cellWidth).floor().clamp(
        0,
        widget.terminal.cols - 1,
      ),
      ((localPosition.dy - padding.top) / dimensions.cellHeight).floor().clamp(
        0,
        widget.terminal.rows - 1,
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _restartCursorBlinkAnimation();
    final button = _mouseButton(event.buttons);
    _pressedMouseButton = button;
    final cell = _cellAt(event.localPosition);
    if (_reportPointer(event, cell, button, TerminalMouseAction.down)) return;
    final bufferCell = TerminalCellOffset(
      cell.x,
      widget.terminal.viewportY + cell.y,
    );
    if (button == TerminalMouseButton.right) {
      if (widget.terminal.options.rightClickSelectsWord &&
          !widget.terminal.hasSelection()) {
        final range = _wordRange(bufferCell, allowWhitespaceOnly: false);
        if (range != null) _selectRange(range);
      }
      return;
    }
    if (button != TerminalMouseButton.left) return;
    if (HardwareKeyboard.instance.isShiftPressed) {
      final existing = widget.terminal.getSelectionPosition();
      if (existing != null) {
        _selectionAnchor = TerminalCellOffset(
          existing.start.x,
          existing.start.y,
        );
        _selectionAnchorEnd = TerminalCellOffset(
          existing.end.x,
          existing.end.y,
        );
        _pointerSelectionMode = widget.terminal.selectionColumnMode
            ? _PointerSelectionMode.column
            : _PointerSelectionMode.normal;
        _extendSelection(bufferCell);
        _startDragScroll();
        return;
      }
    }
    _updateClickCount(bufferCell);
    if (_clickCount > 3) return;
    final range = switch (_clickCount) {
      2 => _wordRange(bufferCell, allowWhitespaceOnly: true),
      >= 3 => _wrappedLineRange(bufferCell.y),
      _ => null,
    };
    if (range == null) {
      final columnSelection =
          HardwareKeyboard.instance.isAltPressed &&
          !(defaultTargetPlatform == TargetPlatform.macOS &&
              widget.terminal.options.macOptionClickForcesSelection);
      _pointerSelectionMode = columnSelection
          ? _PointerSelectionMode.column
          : _PointerSelectionMode.normal;
      _selectionAnchor = bufferCell;
      _selectionAnchorEnd = TerminalCellOffset(bufferCell.x + 1, bufferCell.y);
      if (columnSelection) {
        widget.terminal.selectColumns(
          bufferCell.x,
          bufferCell.y,
          bufferCell.x,
          bufferCell.y,
        );
      } else {
        widget.terminal.select(bufferCell.x, bufferCell.y, 0);
      }
      _startDragScroll();
      return;
    }
    _pointerSelectionMode = _clickCount == 2
        ? _PointerSelectionMode.word
        : _PointerSelectionMode.line;
    _selectionAnchor = TerminalCellOffset(range.start.x, range.start.y);
    _selectionAnchorEnd = TerminalCellOffset(range.end.x, range.end.y);
    _selectRange(range);
    _startDragScroll();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final cell = _cellAt(event.localPosition);
    if (_reportPointer(
      event,
      cell,
      _pressedMouseButton,
      TerminalMouseAction.move,
    )) {
      return;
    }
    final anchor = _selectionAnchor;
    if (anchor == null || _pressedMouseButton != TerminalMouseButton.left) {
      return;
    }
    _dragScrollAmount = _mouseDragScrollAmount(event.localPosition);
    _dragSelectionColumn = cell.x;
    final selectionColumn = switch (_dragScrollAmount) {
      > 0 => widget.terminal.cols - 1,
      < 0 => 0,
      _ => cell.x,
    };
    _extendSelection(
      TerminalCellOffset(
        _pointerSelectionMode == _PointerSelectionMode.column
            ? cell.x
            : selectionColumn,
        widget.terminal.viewportY + cell.y,
      ),
    );
  }

  void _extendSelection(TerminalCellOffset current) {
    final anchor = _selectionAnchor;
    final anchorEnd = _selectionAnchorEnd;
    if (anchor == null || anchorEnd == null) return;
    final currentRange = switch (_pointerSelectionMode) {
      _PointerSelectionMode.normal => TerminalBufferRange(
        start: TerminalBufferPosition(current.x, current.y),
        end: TerminalBufferPosition(current.x + 1, current.y),
      ),
      _PointerSelectionMode.word => _wordRange(
        current,
        allowWhitespaceOnly: true,
      ),
      _PointerSelectionMode.line => _wrappedLineRange(current.y),
      _PointerSelectionMode.column => TerminalBufferRange(
        start: TerminalBufferPosition(current.x, current.y),
        end: TerminalBufferPosition(current.x + 1, current.y),
      ),
    };
    if (currentRange == null) return;
    if (_pointerSelectionMode == _PointerSelectionMode.column) {
      _selectRange(
        TerminalBufferRange(
          start: TerminalBufferPosition(
            math.min(anchor.x, current.x),
            anchor.y,
          ),
          end: TerminalBufferPosition(
            math.max(anchor.x, current.x) + 1,
            current.y,
          ),
        ),
        columnMode: true,
      );
      return;
    }
    final columns = widget.terminal.cols;
    final anchorOffset = anchor.y * columns + anchor.x;
    final currentOffset = currentRange.start.y * columns + currentRange.start.x;
    final range = anchorOffset <= currentOffset
        ? TerminalBufferRange(
            start: TerminalBufferPosition(anchor.x, anchor.y),
            end: currentRange.end,
          )
        : TerminalBufferRange(
            start: currentRange.start,
            end: TerminalBufferPosition(anchorEnd.x, anchorEnd.y),
          );
    _selectRange(range);
  }

  void _updateClickCount(TerminalCellOffset cell) {
    if (_lastClickCell == cell && _clickResetTimer?.isActive == true) {
      _clickCount++;
    } else {
      _clickCount = 1;
    }
    _lastClickCell = cell;
    _clickResetTimer?.cancel();
    _clickResetTimer = Timer(const Duration(milliseconds: 500), () {
      _clickCount = 0;
      _lastClickCell = null;
      _clickResetTimer = null;
    });
  }

  TerminalBufferRange? _wordRange(
    TerminalCellOffset position, {
    required bool allowWhitespaceOnly,
  }) => TerminalSelectionService(widget.terminal).wordRange(
    TerminalBufferPosition(position.x, position.y),
    allowWhitespaceOnly: allowWhitespaceOnly,
  );

  TerminalBufferRange? _wrappedLineRange(int row) =>
      TerminalSelectionService(widget.terminal).wrappedLineRange(row);

  void _selectRange(
    TerminalBufferRange range, {
    bool columnMode = false,
  }) {
    if (columnMode) {
      widget.terminal.selectColumns(
        range.start.x,
        range.start.y,
        range.end.x,
        range.end.y,
      );
      return;
    }
    final columns = widget.terminal.cols;
    final start = range.start.y * columns + range.start.x;
    final end = range.end.y * columns + range.end.x;
    widget.terminal.select(
      range.start.x,
      range.start.y,
      (end - start).clamp(0, 0x7fffffff),
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    final cell = _cellAt(event.localPosition);
    _reportPointer(
      event,
      cell,
      _pressedMouseButton,
      TerminalMouseAction.up,
    );
    _pressedMouseButton = TerminalMouseButton.none;
    _stopDragScroll();
    _selectionAnchor = null;
    _selectionAnchorEnd = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pressedMouseButton = TerminalMouseButton.none;
    _stopDragScroll();
    _selectionAnchor = null;
    _selectionAnchorEnd = null;
  }

  void _startDragScroll() {
    _dragScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _dragScroll(),
    );
  }

  void _stopDragScroll() {
    _dragScrollTimer?.cancel();
    _dragScrollTimer = null;
    _dragScrollAmount = 0;
  }

  int _mouseDragScrollAmount(Offset position) {
    final dimensions = widget.terminal.dimensions;
    if (dimensions == null) return 0;
    final top = (widget.padding ?? EdgeInsets.zero).top;
    final height = dimensions.cellHeight * widget.terminal.rows;
    var offset = position.dy - top;
    if (offset >= 0 && offset <= height) return 0;
    if (offset > height) offset -= height;
    final normalized = offset.clamp(-50.0, 50.0) / 50;
    return normalized.sign.toInt() + (normalized * 14).round();
  }

  void _dragScroll() {
    if (_dragScrollAmount == 0 ||
        _selectionAnchor == null ||
        _pressedMouseButton != TerminalMouseButton.left) {
      return;
    }
    widget.terminal.scrollLines(_dragScrollAmount);
    final row = _dragScrollAmount > 0
        ? widget.terminal.viewportY + widget.terminal.rows - 1
        : widget.terminal.viewportY;
    final column = _pointerSelectionMode == _PointerSelectionMode.column
        ? _dragSelectionColumn
        : _dragScrollAmount > 0
        ? widget.terminal.cols - 1
        : 0;
    _extendSelection(TerminalCellOffset(column, row));
  }

  void _onPointerHover(PointerHoverEvent event) {
    final cell = _cellAt(event.localPosition);
    _reportPointer(
      event,
      cell,
      TerminalMouseButton.none,
      TerminalMouseAction.move,
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    final wheel = TerminalWheelEvent(
      deltaX: event.scrollDelta.dx,
      deltaY: event.scrollDelta.dy,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      control: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
    );
    if (!widget.terminal.handleWheelEvent(wheel)) return;
    final lines = _consumeWheel(event.scrollDelta.dy, wheel);
    if (lines == 0) return;
    final cell = _cellAt(event.localPosition);
    final action = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx < 0
              ? TerminalMouseAction.wheelLeft
              : TerminalMouseAction.wheelRight
        : event.scrollDelta.dy < 0
        ? TerminalMouseAction.up
        : TerminalMouseAction.down;
    if (_reportPointer(event, cell, TerminalMouseButton.wheel, action)) return;
    if (widget.terminal.buffer.active.baseY > 0) {
      widget.terminal.scrollLines(lines);
      return;
    }
    final sequence =
        '\u001b${widget.terminal.modes.applicationCursorKeysMode ? 'O' : '['}'
        '${event.scrollDelta.dy < 0 ? 'A' : 'B'}';
    widget.terminal.input(sequence);
  }

  int _consumeWheel(double deltaY, TerminalWheelEvent event) {
    if (deltaY == 0 || event.shift) return 0;
    final dimensions = widget.terminal.dimensions;
    if (dimensions == null || dimensions.cellHeight <= 0) return 0;
    var amount = deltaY * widget.terminal.options.scrollSensitivity;
    if (event.alt || event.control || event.shift) {
      amount *= widget.terminal.options.fastScrollSensitivity;
    }
    amount /= dimensions.cellHeight;
    if (deltaY.abs() < 50) amount *= 0.3;
    _wheelPartialScroll += amount;
    final whole = _wheelPartialScroll.abs().floor();
    if (whole == 0) return 0;
    final lines = _wheelPartialScroll > 0 ? whole : -whole;
    _wheelPartialScroll %= 1;
    return lines;
  }

  bool _reportPointer(
    PointerEvent event,
    TerminalCellOffset cell,
    TerminalMouseButton button,
    TerminalMouseAction action,
  ) {
    final padding = widget.padding ?? EdgeInsets.zero;
    return widget.terminal.reportMouseEvent(
      TerminalMouseEvent(
        column: cell.x,
        row: cell.y,
        pixelX: ((event.localPosition.dx - padding.left).floor() + 1).clamp(
          1,
          0x7fffffff,
        ),
        pixelY: ((event.localPosition.dy - padding.top).floor() + 1).clamp(
          1,
          0x7fffffff,
        ),
        button: button,
        action: action,
        shift: HardwareKeyboard.instance.isShiftPressed,
        alt: HardwareKeyboard.instance.isAltPressed,
        control: HardwareKeyboard.instance.isControlPressed,
      ),
    );
  }

  TerminalMouseButton _mouseButton(int buttons) {
    if (buttons & kPrimaryMouseButton != 0) return TerminalMouseButton.left;
    if (buttons & kMiddleMouseButton != 0) return TerminalMouseButton.middle;
    if (buttons & kSecondaryMouseButton != 0) return TerminalMouseButton.right;
    return TerminalMouseButton.none;
  }

  TerminalStyle get _effectiveStyle {
    final override = widget.style;
    if (override != null) return override;
    final options = widget.terminal.options;
    return TerminalStyle(
      fontFamily: options.fontFamily,
      fontSize: options.fontSize,
      height: options.lineHeight,
      fontWeight: _fontWeight(options.fontWeight, FontWeight.normal),
      fontWeightBold: _fontWeight(options.fontWeightBold, FontWeight.bold),
      letterSpacing: options.letterSpacing,
      cursorType: switch (options.cursorStyle) {
        TerminalCursorStyle.block => TerminalCursorType.block,
        TerminalCursorStyle.underline => TerminalCursorType.underline,
        TerminalCursorStyle.bar => TerminalCursorType.bar,
      },
      cursorBlink: options.cursorBlink,
      cursorWidth: options.cursorWidth.toDouble(),
    );
  }

  FontWeight _fontWeight(Object value, FontWeight fallback) {
    if (value is int) {
      return switch (value.clamp(100, 900)) {
        <= 100 => FontWeight.w100,
        <= 200 => FontWeight.w200,
        <= 300 => FontWeight.w300,
        <= 400 => FontWeight.w400,
        <= 500 => FontWeight.w500,
        <= 600 => FontWeight.w600,
        <= 700 => FontWeight.w700,
        <= 800 => FontWeight.w800,
        _ => FontWeight.w900,
      };
    }
    final text = value.toString();
    if (text == 'bold') return FontWeight.bold;
    if (text == 'normal') return FontWeight.normal;
    final parsed = int.tryParse(text);
    return parsed == null ? fallback : _fontWeight(parsed, fallback);
  }

  Future<void> _updateHoveredLink(
    PointerHoverEvent event,
    TerminalCellOffset cell,
  ) async {
    final link = await _linkAt(cell);
    if (!mounted) return;
    if (identical(link, _hoveredLink)) return;
    final previous = _hoveredLink;
    _linkDecorationListener?.dispose();
    _linkDecorationListener = null;
    _hoveredLink = link;
    previous?.leave?.call(event, previous.text);
    link?.hover?.call(event, link.text);
    final decorations = link?.decorations;
    if (decorations != null) {
      _linkDecorationListener = decorations.onChange(() {
        if (mounted && identical(_hoveredLink, link)) setState(() {});
      });
    }
    setState(() {});
  }

  Future<void> _recordPointerDownLink(
    TapDownDetails event,
    TerminalCellOffset cell,
  ) async {
    final link = await _linkAt(cell);
    if (!mounted) return;
    _pointerDownLink = link;
  }

  Future<void> _activatePointerDownLink(
    TapUpDetails event,
    TerminalCellOffset cell,
  ) async {
    final link = await _linkAt(cell);
    if (!mounted) return;
    final pointerDownLink = _pointerDownLink;
    _pointerDownLink = null;
    if (link != null && identical(link, pointerDownLink)) {
      link.activate(event, link.text);
    }
  }

  Future<TerminalLink?> _linkAt(TerminalCellOffset cell) async {
    final x = cell.x + 1;
    final y = widget.terminal.viewportY + cell.y + 1;
    if (_activeLinkLine != y) {
      final generation = ++_linkRequestGeneration;
      _disposeLinkReplies();
      _activeLinkLine = y;
      final replies = <List<TerminalLink>>[];
      for (final provider in widget.terminal.linkProviders) {
        replies.add(await provider.provideLinks(y));
        if (!mounted || generation != _linkRequestGeneration) {
          for (final links in replies) {
            for (final link in links) {
              link.dispose?.call();
            }
          }
          return null;
        }
      }
      _activeLinkReplies = replies;
    }
    for (final links in _activeLinkReplies ?? const <List<TerminalLink>>[]) {
      for (final link in links) {
        if (_linkContains(link, x, y)) return link;
      }
    }
    return null;
  }

  bool _linkContains(TerminalLink link, int x, int y) {
    final columns = widget.terminal.cols;
    final lower = link.range.start.y * columns + link.range.start.x;
    final upper = link.range.end.y * columns + link.range.end.x;
    final current = y * columns + x;
    return lower <= current && current <= upper;
  }

  bool _linkUsesPointer(TerminalLink? link) =>
      link != null && (link.decorations?.pointerCursor ?? true);

  bool get _mouseReportingCapturesPointer {
    if (widget.terminal.modes.mouseTrackingMode == 'none') return false;
    return !widget.terminal.options.mouseEventsRequireAlt ||
        HardwareKeyboard.instance.isAltPressed;
  }

  void _leaveLink(PointerExitEvent event) {
    final previous = _hoveredLink;
    if (previous == null) return;
    _linkDecorationListener?.dispose();
    _linkDecorationListener = null;
    _hoveredLink = null;
    previous.leave?.call(event, previous.text);
    if (mounted) setState(() {});
  }

  void _disposeLinkReplies() {
    for (final links in _activeLinkReplies ?? const <List<TerminalLink>>[]) {
      for (final link in links) {
        link.dispose?.call();
      }
    }
    _activeLinkReplies = null;
  }

  void _clearLinkCache() {
    _linkRequestGeneration++;
    final previous = _hoveredLink;
    _linkDecorationListener?.dispose();
    _linkDecorationListener = null;
    _hoveredLink = null;
    _pointerDownLink = null;
    _activeLinkLine = -1;
    previous?.leave?.call(null, previous.text);
    _disposeLinkReplies();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final character = event.character;
    final eventKey = character != null && character.isNotEmpty
        ? character
        : event.logicalKey.keyLabel;
    if ((event.logicalKey == LogicalKeyboardKey.altLeft ||
            event.logicalKey == LogicalKeyboardKey.altRight) &&
        mounted) {
      setState(() {});
    }
    final kittyFlags = widget.terminal.kittyKeyboardFlags;
    final useWin32 = widget.terminal.modes.win32InputMode;
    if (event is KeyUpEvent &&
        !useWin32 &&
        !KittyKeyboard.shouldUseProtocol(kittyFlags)) {
      return KeyEventResult.ignored;
    }
    final allowed = widget.terminal.handleKeyEvent(
      TerminalKeyEvent(
        key: eventKey,
        shift: keyboard.isShiftPressed,
        alt: keyboard.isAltPressed,
        control: keyboard.isControlPressed,
        meta: keyboard.isMetaPressed,
      ),
    );
    if (!allowed) return KeyEventResult.handled;
    if (event is! KeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        !keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !(_inputKey.currentState?._isComposing ?? false)) {
      // Browsers deliver an unmodified space through xterm's hidden textarea.
      // Linux IBus can omit that TextInput delta while still sending the key
      // event, so bridge it here and absorb a delayed platform echo elsewhere.
      _inputKey.currentState?._suppressPhysicalCommitEcho(' ');
      widget.terminal.input(' ');
      return KeyEventResult.handled;
    }
    final protocolEvent = KittyKeyboardEvent(
      key: character != null && character.isNotEmpty
          ? character
          : _kittyKey(event.logicalKey),
      code: _kittyCode(event.physicalKey),
      keyCode: _legacyKeyCode(event.logicalKey, event.physicalKey),
      type: event is KeyUpEvent ? 'keyup' : 'keydown',
      shiftKey: keyboard.isShiftPressed,
      altKey: keyboard.isAltPressed,
      ctrlKey: keyboard.isControlPressed,
      metaKey: keyboard.isMetaPressed,
    );
    if (useWin32) {
      final result = widget.terminal.evaluateWin32Keyboard(
        protocolEvent,
        isKeyDown: event is! KeyUpEvent,
      );
      final sequence = result.key;
      if (sequence != null) widget.terminal.input(sequence);
      return result.cancel || sequence != null
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (KittyKeyboard.shouldUseProtocol(kittyFlags)) {
      final result = widget.terminal.evaluateKittyKeyboard(
        protocolEvent,
        eventType: event is KeyUpEvent
            ? KittyKeyboardEventType.release
            : event is KeyRepeatEvent
            ? KittyKeyboardEventType.repeat
            : KittyKeyboardEventType.press,
      );
      final sequence = result.key;
      if (sequence != null) widget.terminal.input(sequence);
      if (result.cancel || sequence != null) return KeyEventResult.handled;
      if (event is KeyUpEvent) return KeyEventResult.ignored;
    }
    final legacy = evaluateKeyboardEvent(
      protocolEvent,
      applicationCursorMode: widget.terminal.modes.applicationCursorKeysMode,
      isMac: defaultTargetPlatform == TargetPlatform.macOS,
      macOptionIsMeta: widget.terminal.options.macOptionIsMeta,
    );
    switch (legacy.type) {
      case KittyKeyboardResultType.selectAll:
        widget.terminal.selectAll();
        return KeyEventResult.handled;
      case KittyKeyboardResultType.pageUp:
        widget.terminal.scrollPages(-1);
        return KeyEventResult.handled;
      case KittyKeyboardResultType.pageDown:
        widget.terminal.scrollPages(1);
        return KeyEventResult.handled;
      case KittyKeyboardResultType.sendKey:
        final sequence = legacy.key;
        if (sequence == null) return KeyEventResult.ignored;
        widget.terminal.input(sequence);
        return KeyEventResult.handled;
    }
  }

  int _legacyKeyCode(
    LogicalKeyboardKey logical,
    PhysicalKeyboardKey physical,
  ) {
    final usage = physical.usbHidUsage & 0xffff;
    if (usage >= 0x04 && usage <= 0x1d) return 65 + usage - 0x04;
    if (usage >= 0x1e && usage <= 0x26) return 49 + usage - 0x1e;
    if (usage == 0x27) return 48;
    final physicalCodes = <int, int>{
      0x28: 13,
      0x29: 27,
      0x2a: 8,
      0x2b: 9,
      0x2c: 32,
      0x2d: 189,
      0x2e: 187,
      0x2f: 219,
      0x30: 221,
      0x31: 220,
      0x33: 186,
      0x34: 222,
      0x35: 192,
      0x36: 188,
      0x37: 190,
      0x38: 191,
    };
    final physicalCode = physicalCodes[usage];
    if (physicalCode != null) return physicalCode;
    final named = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.pageUp: 33,
      LogicalKeyboardKey.pageDown: 34,
      LogicalKeyboardKey.end: 35,
      LogicalKeyboardKey.home: 36,
      LogicalKeyboardKey.arrowLeft: 37,
      LogicalKeyboardKey.arrowUp: 38,
      LogicalKeyboardKey.arrowRight: 39,
      LogicalKeyboardKey.arrowDown: 40,
      LogicalKeyboardKey.insert: 45,
      LogicalKeyboardKey.delete: 46,
    };
    final namedCode = named[logical];
    if (namedCode != null) return namedCode;
    for (var number = 1; number <= 12; number++) {
      if (logical == _logicalFunctionKey(number)) return 111 + number;
    }
    return 0;
  }

  String _kittyKey(LogicalKeyboardKey key) {
    final named = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.escape: 'Escape',
      LogicalKeyboardKey.enter: 'Enter',
      LogicalKeyboardKey.numpadEnter: 'Enter',
      LogicalKeyboardKey.tab: 'Tab',
      LogicalKeyboardKey.backspace: 'Backspace',
      LogicalKeyboardKey.capsLock: 'CapsLock',
      LogicalKeyboardKey.scrollLock: 'ScrollLock',
      LogicalKeyboardKey.numLock: 'NumLock',
      LogicalKeyboardKey.printScreen: 'PrintScreen',
      LogicalKeyboardKey.pause: 'Pause',
      LogicalKeyboardKey.contextMenu: 'ContextMenu',
      LogicalKeyboardKey.arrowUp: 'ArrowUp',
      LogicalKeyboardKey.arrowDown: 'ArrowDown',
      LogicalKeyboardKey.arrowRight: 'ArrowRight',
      LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
      LogicalKeyboardKey.home: 'Home',
      LogicalKeyboardKey.end: 'End',
      LogicalKeyboardKey.insert: 'Insert',
      LogicalKeyboardKey.delete: 'Delete',
      LogicalKeyboardKey.pageUp: 'PageUp',
      LogicalKeyboardKey.pageDown: 'PageDown',
      LogicalKeyboardKey.shift: 'Shift',
      LogicalKeyboardKey.control: 'Control',
      LogicalKeyboardKey.alt: 'Alt',
      LogicalKeyboardKey.meta: 'Meta',
    };
    for (var number = 1; number <= 24; number++) {
      if (key == _logicalFunctionKey(number)) return 'F$number';
    }
    return named[key] ?? key.keyLabel;
  }

  LogicalKeyboardKey _logicalFunctionKey(int number) => switch (number) {
    1 => LogicalKeyboardKey.f1,
    2 => LogicalKeyboardKey.f2,
    3 => LogicalKeyboardKey.f3,
    4 => LogicalKeyboardKey.f4,
    5 => LogicalKeyboardKey.f5,
    6 => LogicalKeyboardKey.f6,
    7 => LogicalKeyboardKey.f7,
    8 => LogicalKeyboardKey.f8,
    9 => LogicalKeyboardKey.f9,
    10 => LogicalKeyboardKey.f10,
    11 => LogicalKeyboardKey.f11,
    12 => LogicalKeyboardKey.f12,
    13 => LogicalKeyboardKey.f13,
    14 => LogicalKeyboardKey.f14,
    15 => LogicalKeyboardKey.f15,
    16 => LogicalKeyboardKey.f16,
    17 => LogicalKeyboardKey.f17,
    18 => LogicalKeyboardKey.f18,
    19 => LogicalKeyboardKey.f19,
    20 => LogicalKeyboardKey.f20,
    21 => LogicalKeyboardKey.f21,
    22 => LogicalKeyboardKey.f22,
    23 => LogicalKeyboardKey.f23,
    _ => LogicalKeyboardKey.f24,
  };

  String _kittyCode(PhysicalKeyboardKey key) {
    final usage = key.usbHidUsage & 0xffff;
    if (usage >= 0x04 && usage <= 0x1d) {
      return 'Key${String.fromCharCode(0x41 + usage - 0x04)}';
    }
    if (usage >= 0x1e && usage <= 0x26) return 'Digit${usage - 0x1d}';
    if (usage == 0x27) return 'Digit0';
    return <PhysicalKeyboardKey, String>{
          PhysicalKeyboardKey.shiftLeft: 'ShiftLeft',
          PhysicalKeyboardKey.shiftRight: 'ShiftRight',
          PhysicalKeyboardKey.controlLeft: 'ControlLeft',
          PhysicalKeyboardKey.controlRight: 'ControlRight',
          PhysicalKeyboardKey.altLeft: 'AltLeft',
          PhysicalKeyboardKey.altRight: 'AltRight',
          PhysicalKeyboardKey.metaLeft: 'MetaLeft',
          PhysicalKeyboardKey.metaRight: 'MetaRight',
          PhysicalKeyboardKey.numpad0: 'Numpad0',
          PhysicalKeyboardKey.numpad1: 'Numpad1',
          PhysicalKeyboardKey.numpad2: 'Numpad2',
          PhysicalKeyboardKey.numpad3: 'Numpad3',
          PhysicalKeyboardKey.numpad4: 'Numpad4',
          PhysicalKeyboardKey.numpad5: 'Numpad5',
          PhysicalKeyboardKey.numpad6: 'Numpad6',
          PhysicalKeyboardKey.numpad7: 'Numpad7',
          PhysicalKeyboardKey.numpad8: 'Numpad8',
          PhysicalKeyboardKey.numpad9: 'Numpad9',
          PhysicalKeyboardKey.numpadDecimal: 'NumpadDecimal',
          PhysicalKeyboardKey.numpadDivide: 'NumpadDivide',
          PhysicalKeyboardKey.numpadMultiply: 'NumpadMultiply',
          PhysicalKeyboardKey.numpadSubtract: 'NumpadSubtract',
          PhysicalKeyboardKey.numpadAdd: 'NumpadAdd',
          PhysicalKeyboardKey.numpadEnter: 'NumpadEnter',
          PhysicalKeyboardKey.numpadEqual: 'NumpadEqual',
        }[key] ??
        '';
  }

  void _reportDimensions(BuildContext context, Size size) {
    if (!size.isFinite || size.isEmpty) return;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final style = _effectiveStyle;
    final cellHeight = style.fontSize * style.height;
    final cellWidth = style.fontSize * 0.6 + style.letterSpacing;
    final padding = widget.padding ?? EdgeInsets.zero;
    final columns = ((size.width - padding.horizontal) / cellWidth).floor();
    final rows = ((size.height - padding.vertical) / cellHeight).floor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.terminal.updateDimensions(
        TerminalRenderDimensions(
          width: size.width,
          height: size.height,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
          devicePixelRatio: pixelRatio,
        ),
      );
      if (widget.autoResize && columns > 0 && rows > 0) {
        widget.terminal.resize(columns, rows);
      }
    });
  }
}

final class _TerminalPainter extends CustomPainter {
  const _TerminalPainter({
    required this.terminal,
    required this.theme,
    required this.style,
    required this.padding,
    required this.backgroundOpacity,
    required this.focused,
    required this.cursorInitialized,
    required this.cursorVisible,
    required this.hoveredLink,
    required this.decodedImages,
  });

  final Terminal terminal;
  final TerminalTheme theme;
  final TerminalStyle style;
  final EdgeInsets padding;
  final double backgroundOpacity;
  final bool focused;
  final bool cursorInitialized;
  final bool cursorVisible;
  final TerminalLink? hoveredLink;
  final Map<int, ({ui.Image raster, TerminalImage source})> decodedImages;

  @override
  void paint(Canvas canvas, Size size) {
    final dimensions = terminal.dimensions;
    if (dimensions == null) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = theme.background.withValues(alpha: backgroundOpacity),
    );
    final buffer = terminal.buffer.active;
    final selection = terminal.getSelectionPosition();
    final colorResolver = TerminalCellColorResolver(
      theme: theme,
      focused: focused,
      drawBoldTextInBrightColors: terminal.options.drawBoldTextInBrightColors,
      minimumContrastRatio: terminal.options.minimumContrastRatio,
    );
    _paintDecorations(canvas, dimensions, TerminalDecorationLayer.bottom);
    for (var row = 0; row < terminal.rows; row++) {
      final bufferRow = terminal.viewportY + row;
      final line = buffer.getLine(bufferRow);
      if (line == null) continue;
      for (var column = 0; column < terminal.cols; column++) {
        final cell = line.getCell(column);
        if (cell == null || cell.width == 0) continue;
        final rect = Rect.fromLTWH(
          padding.left + column * dimensions.cellWidth,
          padding.top + row * dimensions.cellHeight,
          dimensions.cellWidth * cell.width,
          dimensions.cellHeight,
        );
        final selected = _selected(selection, column, bufferRow);
        final colors = colorResolver.resolve(
          cell,
          selected: selected,
          bottomDecorations: _cellDecorations(
            column,
            bufferRow,
            TerminalDecorationLayer.bottom,
          ),
          topDecorations: _cellDecorations(
            column,
            bufferRow,
            TerminalDecorationLayer.top,
          ),
        );
        final foreground = colors.foreground;
        if (colors.paintBackground) {
          canvas.drawRect(rect, Paint()..color = colors.cellBackground);
        }
        _paintImageCell(canvas, rect, cell);
        for (final overlay in colors.backgroundOverlays) {
          canvas.drawRect(rect, Paint()..color = overlay);
        }
        if (!cell.isInvisible &&
            (!cell.isBlink || cursorVisible) &&
            cell.chars.isNotEmpty) {
          final underlineColor = _color(
            cell.underlineColorMode,
            cell.underlineColorValue,
            foreground,
          );
          TextPainter(
              text: TextSpan(
                text: cell.chars,
                style: style
                    .toTextStyle(
                      color: foreground,
                    )
                    .copyWith(
                      fontWeight: cell.isBold
                          ? style.fontWeightBold
                          : style.fontWeight,
                      fontStyle: cell.isItalic
                          ? FontStyle.italic
                          : FontStyle.normal,
                      decoration: TextDecoration.combine(<TextDecoration>[
                        if (cell.isUnderline) TextDecoration.underline,
                        if (cell.isStrikethrough) TextDecoration.lineThrough,
                        if (cell.isOverline) TextDecoration.overline,
                      ]),
                      decorationColor: cell.isUnderline
                          ? underlineColor
                          : foreground,
                      decorationStyle: switch (cell.underlineStyle) {
                        TerminalUnderlineStyle.double =>
                          TextDecorationStyle.double,
                        TerminalUnderlineStyle.curly =>
                          TextDecorationStyle.wavy,
                        TerminalUnderlineStyle.dotted =>
                          TextDecorationStyle.dotted,
                        TerminalUnderlineStyle.dashed =>
                          TextDecorationStyle.dashed,
                        _ => TextDecorationStyle.solid,
                      },
                    ),
              ),
              textDirection: TextDirection.ltr,
              textWidthBasis: TextWidthBasis.longestLine,
            )
            ..layout(maxWidth: rect.width)
            ..paint(canvas, rect.topLeft);
        }
      }
    }
    _paintDecorations(canvas, dimensions, TerminalDecorationLayer.top);
    _paintHoveredLink(canvas, dimensions);
    final cursorRow = buffer.baseY + buffer.cursorY - terminal.viewportY;
    if (terminal.modes.showCursor &&
        cursorInitialized &&
        cursorRow >= 0 &&
        cursorRow < terminal.rows &&
        (!focused || cursorVisible)) {
      _paintCursor(canvas, dimensions, buffer.cursorX, cursorRow);
    }
  }

  void _paintImageCell(Canvas canvas, Rect destination, TerminalCell cell) {
    final decoded = decodedImages[cell.imageId];
    if (decoded == null || cell.imageTileId < 0) return;
    final columns = decoded.source.columns ?? 1;
    final rows = decoded.source.rows ?? 1;
    final tileColumn = cell.imageTileId % columns;
    final tileRow = cell.imageTileId ~/ columns;
    if (tileRow >= rows) return;
    final tileWidth = decoded.raster.width / columns;
    final tileHeight = decoded.raster.height / rows;
    final source = Rect.fromLTRB(
      tileColumn * tileWidth,
      tileRow * tileHeight,
      math.min((tileColumn + 1) * tileWidth, decoded.raster.width.toDouble()),
      math.min((tileRow + 1) * tileHeight, decoded.raster.height.toDouble()),
    );
    canvas.drawImageRect(decoded.raster, source, destination, Paint());
  }

  void _paintHoveredLink(
    Canvas canvas,
    TerminalRenderDimensions dimensions,
  ) {
    final link = hoveredLink;
    if (link == null || !(link.decorations?.underline ?? true)) return;
    final underline = TerminalLinkUnderlineEvent.fromLink(
      link,
      columns: terminal.cols,
      viewportY: terminal.viewportY,
    );
    final startRow = underline.y1.clamp(0, terminal.rows - 1);
    final endRow = underline.y2.clamp(0, terminal.rows - 1);
    if (startRow > endRow ||
        underline.y2 < 0 ||
        underline.y1 >= terminal.rows) {
      return;
    }
    final paint = Paint()
      ..color = theme.foreground
      ..strokeWidth = 1;
    for (var row = startRow; row <= endRow; row++) {
      final startColumn = row == underline.y1 ? underline.x1 : 0;
      final endColumn = row == underline.y2 ? underline.x2 : underline.columns;
      final y = padding.top + (row + 1) * dimensions.cellHeight - 1;
      canvas.drawLine(
        Offset(padding.left + startColumn * dimensions.cellWidth, y),
        Offset(padding.left + endColumn * dimensions.cellWidth, y),
        paint,
      );
    }
  }

  Iterable<TerminalCellDecorationColors> _cellDecorations(
    int column,
    int row,
    TerminalDecorationLayer layer,
  ) sync* {
    for (final decoration in terminal.decorations) {
      final x = _decorationColumn(decoration);
      if (decoration.layer == layer &&
          !decoration.isDisposed &&
          decoration.marker.line <= row &&
          decoration.marker.line + decoration.height > row &&
          column >= x &&
          column < x + decoration.width) {
        yield TerminalCellDecorationColors(
          foreground: TerminalThemes.parseColor(decoration.foregroundColor),
          background: TerminalThemes.parseColor(decoration.backgroundColor),
        );
      }
    }
  }

  void _paintDecorations(
    Canvas canvas,
    TerminalRenderDimensions dimensions,
    TerminalDecorationLayer layer,
  ) {
    for (final decoration in terminal.decorations) {
      if (decoration.layer != layer || decoration.isDisposed) continue;
      final viewportRow = decoration.marker.line - terminal.viewportY;
      if (viewportRow + decoration.height <= 0 ||
          viewportRow >= terminal.rows) {
        continue;
      }
      final rect = Rect.fromLTWH(
        padding.left + _decorationColumn(decoration) * dimensions.cellWidth,
        padding.top + viewportRow * dimensions.cellHeight,
        decoration.width * dimensions.cellWidth,
        decoration.height * dimensions.cellHeight,
      );
      final border = _cssColor(decoration.borderColor);
      if (border != null) {
        canvas.drawRect(
          rect.deflate(0.5),
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      decoration.rendered();
    }
  }

  int _decorationColumn(TerminalDecoration decoration) =>
      decoration.anchor == TerminalDecorationAnchor.left
      ? decoration.x
      : terminal.cols - decoration.x - decoration.width;

  Color? _cssColor(String? source) => TerminalThemes.parseColor(source);

  Color _color(TerminalColorMode mode, int value, Color fallback) =>
      switch (mode) {
        TerminalColorMode.defaultColor => fallback,
        TerminalColorMode.palette =>
          value >= 0 && value < theme.palette.length
              ? theme.palette[value]
              : fallback,
        TerminalColorMode.rgb => Color(0xff000000 | value),
      };

  bool _selected(TerminalBufferRange? range, int column, int row) {
    if (range == null || row < range.start.y || row > range.end.y) return false;
    if (terminal.selectionColumnMode) {
      final startColumn = math.min(range.start.x, range.end.x);
      final endColumn = math.max(range.start.x, range.end.x);
      return column >= startColumn && column < endColumn;
    }
    if (range.start.y == range.end.y) {
      return column >= range.start.x && column < range.end.x;
    }
    if (row == range.start.y) return column >= range.start.x;
    if (row == range.end.y) return column < range.end.x;
    return true;
  }

  void _paintCursor(
    Canvas canvas,
    TerminalRenderDimensions dimensions,
    int column,
    int row,
  ) {
    final left = padding.left + column * dimensions.cellWidth;
    final top = padding.top + row * dimensions.cellHeight;
    final inactiveStyle = terminal.options.cursorInactiveStyle;
    if (!focused && inactiveStyle == TerminalInactiveCursorStyle.none) return;
    final cursorType = focused
        ? style.cursorType
        : switch (inactiveStyle) {
            TerminalInactiveCursorStyle.outline => TerminalCursorType.block,
            TerminalInactiveCursorStyle.block => TerminalCursorType.block,
            TerminalInactiveCursorStyle.bar => TerminalCursorType.bar,
            TerminalInactiveCursorStyle.underline =>
              TerminalCursorType.underline,
            TerminalInactiveCursorStyle.none => TerminalCursorType.block,
          };
    final rect = switch (cursorType) {
      TerminalCursorType.block => Rect.fromLTWH(
        left,
        top,
        dimensions.cellWidth,
        dimensions.cellHeight,
      ),
      TerminalCursorType.underline => Rect.fromLTWH(
        left,
        top + dimensions.cellHeight - 2,
        dimensions.cellWidth,
        2,
      ),
      TerminalCursorType.bar => Rect.fromLTWH(
        left,
        top,
        style.cursorWidth,
        dimensions.cellHeight,
      ),
    };
    final paint = Paint()
      ..color = theme.cursor
      ..isAntiAlias = false
      ..style = !focused && inactiveStyle == TerminalInactiveCursorStyle.outline
          ? PaintingStyle.stroke
          : PaintingStyle.fill;
    canvas.drawRect(
      paint.style == PaintingStyle.stroke ? rect.deflate(0.5) : rect,
      paint,
    );
    if (cursorType == TerminalCursorType.block &&
        paint.style == PaintingStyle.fill) {
      final line = terminal.buffer.active.getLine(
        terminal.viewportY + row,
      );
      final cell = line?.getCell(column);
      if (cell != null &&
          cell.width > 0 &&
          !cell.isInvisible &&
          cell.chars.isNotEmpty) {
        TextPainter(
            text: TextSpan(
              text: cell.chars,
              style: style
                  .toTextStyle(color: theme.cursorAccent)
                  .copyWith(
                    fontWeight: cell.isBold
                        ? style.fontWeightBold
                        : style.fontWeight,
                    fontStyle: cell.isItalic
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
            ),
            textDirection: TextDirection.ltr,
            textWidthBasis: TextWidthBasis.longestLine,
          )
          ..layout(maxWidth: rect.width)
          ..paint(canvas, rect.topLeft);
      }
    }
  }

  @override
  bool shouldRepaint(_TerminalPainter oldDelegate) => true;
}

final class _TerminalTextInput extends StatefulWidget {
  const _TerminalTextInput({
    required this.focusNode,
    required this.autofocus,
    required this.readOnly,
    required this.terminal,
    required this.onKeyEvent,
    required this.onComposingChanged,
    required this.child,
    super.key,
  });

  final FocusNode focusNode;
  final bool autofocus;
  final bool readOnly;
  final Terminal terminal;
  final FocusOnKeyEventCallback onKeyEvent;
  final VoidCallback onComposingChanged;
  final Widget child;

  @override
  State<_TerminalTextInput> createState() => _TerminalTextInputState();
}

final class _TerminalTextInputState extends State<_TerminalTextInput>
    with DeltaTextInputClient {
  TextInputConnection? _connection;
  TextEditingValue _editingValue = TextEditingValue.empty;
  TextEditingValue _platformEditingValue = TextEditingValue.empty;
  String _committedPrefix = '';
  String _resetEchoPrefix = '';
  String _compositionSuffix = '';

  bool get _isComposing =>
      _editingValue.composing.isValid && !_editingValue.composing.isCollapsed;

  String get composingText {
    if (!_isComposing) return '';
    return _editingValue.composing.textInside(_editingValue.text);
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(_TerminalTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
    }
    if (oldWidget.terminal != widget.terminal) _resetEditingState();
    if (widget.readOnly && !oldWidget.readOnly) _closeConnection();
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    _closeConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: widget.focusNode,
    autofocus: widget.autofocus,
    canRequestFocus: !widget.readOnly,
    onKeyEvent: widget.onKeyEvent,
    child: widget.child,
  );

  void requestKeyboard() {
    if (!widget.focusNode.hasFocus) widget.focusNode.requestFocus();
    _openConnection();
  }

  void _focusChanged() {
    widget.terminal.reportFocus(focused: widget.focusNode.hasFocus);
    if (widget.focusNode.hasFocus) {
      _openConnection();
    } else {
      _commitComposition();
      _closeConnection();
    }
  }

  void _commitComposition() {
    if (!_isComposing) return;
    _reconcileCommitted(_textWithoutCompositionSuffix(_editingValue.text));
    _resetEditingState();
    widget.onComposingChanged();
  }

  void _resetEditingState() {
    _editingValue = TextEditingValue.empty;
    _platformEditingValue = TextEditingValue.empty;
    _committedPrefix = '';
    _resetEchoPrefix = '';
    _compositionSuffix = '';
    _connection?.setEditingState(_editingValue);
  }

  void _openConnection() {
    if (widget.readOnly) return;
    if (_connection case final connection? when connection.attached) {
      connection.show();
      return;
    }
    _connection = TextInput.attach(
      this,
      TextInputConfiguration(
        viewId: View.of(context).viewId,
        inputAction: TextInputAction.newline,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        enableDeltaModel: true,
      ),
    )..setEditingState(_editingValue);
    _connection?.show();
  }

  void _closeConnection() {
    _connection?.close();
    _connection = null;
  }

  @override
  TextEditingValue? get currentTextEditingValue => _platformEditingValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    _platformEditingValue = value;
    _accept(value);
    _finishCommittedInput();
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    for (final delta in deltas) {
      _platformEditingValue = delta.apply(_platformEditingValue);
      _accept(_platformEditingValue);
    }
    _finishCommittedInput();
  }

  void _accept(TextEditingValue value) {
    final wasComposing = _isComposing;
    final previousComposing = _editingValue.composing;
    final normalized = _withoutResetEcho(value);
    _editingValue = normalized;
    final composing = normalized.composing;
    final isComposing = composing.isValid && !composing.isCollapsed;
    if (isComposing &&
        (!wasComposing || composing.start > previousComposing.start)) {
      // Flutter exposes the post-edit value rather than a separate DOM
      // compositionstart event. Text outside the composing range therefore
      // existed before this composition and must not be sent again. Keeping
      // the suffix also mirrors xterm's screen-reader textarea behavior when
      // composition happens in the middle of existing text.
      final prefix = normalized.text.substring(0, composing.start);
      if (wasComposing) {
        // A new composition can begin before the platform reports the prior
        // composition end (notably Korean final-consonant redistribution).
        // Commit the text preceding the new range before tracking that range.
        _reconcileCommitted(prefix);
      } else {
        _committedPrefix = prefix;
      }
      _compositionSuffix = normalized.text.substring(composing.end);
    }
    final committedText = isComposing
        ? normalized.text.substring(0, composing.start)
        : wasComposing
        ? _textWithoutCompositionSuffix(normalized.text)
        : normalized.text;
    _reconcileCommitted(committedText);
    if (!isComposing) _compositionSuffix = '';
    widget.onComposingChanged();
  }

  String _textWithoutCompositionSuffix(String value) {
    final suffix = _compositionSuffix;
    if (suffix.isEmpty || !value.endsWith(suffix)) return value;
    return value.substring(0, value.length - suffix.length);
  }

  void _finishCommittedInput() {
    if (_isComposing || _editingValue.text.isEmpty) return;
    // xterm clears its hidden textarea after committed input. Keeping the
    // committed value makes a later platform synchronization to an empty
    // editing value look like a user deletion and emits duplicate DEL bytes.
    _resetEchoPrefix = _platformEditingValue.text;
    _editingValue = TextEditingValue.empty;
    _platformEditingValue = TextEditingValue.empty;
    _committedPrefix = '';
    _connection?.setEditingState(_editingValue);
    widget.onComposingChanged();
  }

  void _suppressPhysicalCommitEcho(String text) {
    if (_isComposing || text.isEmpty) return;
    _resetEchoPrefix = text;
  }

  TextEditingValue _withoutResetEcho(TextEditingValue value) {
    final prefix = _resetEchoPrefix;
    if (prefix.isEmpty) return value;
    if (value.text.isEmpty) {
      _resetEchoPrefix = '';
      _committedPrefix = '';
      return value;
    }
    if (!value.text.startsWith(prefix)) {
      _resetEchoPrefix = '';
      _committedPrefix = '';
      return value;
    }
    final offset = prefix.length;
    int adjusted(int position) => position < 0
        ? position
        : (position - offset).clamp(0, value.text.length - offset);
    final selection = value.selection;
    final composing = value.composing;
    return TextEditingValue(
      text: value.text.substring(offset),
      selection: TextSelection(
        baseOffset: adjusted(selection.baseOffset),
        extentOffset: adjusted(selection.extentOffset),
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      ),
      composing: composing.isValid
          ? TextRange(
              start: adjusted(composing.start),
              end: adjusted(composing.end),
            )
          : TextRange.empty,
    );
  }

  void _reconcileCommitted(String next) {
    final previousClusters = _committedPrefix.characters.toList();
    final nextClusters = next.characters.toList();
    var common = 0;
    while (common < previousClusters.length &&
        common < nextClusters.length &&
        previousClusters[common] == nextClusters[common]) {
      common++;
    }
    final removed = previousClusters.length - common;
    if (removed > 0) widget.terminal.input('\u007f' * removed);
    if (common < nextClusters.length) {
      widget.terminal.input(nextClusters.skip(common).join());
    }
    _committedPrefix = next;
  }

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline || action == TextInputAction.done) {
      widget.terminal.input('\r');
    }
  }

  @override
  void connectionClosed() {
    _connection?.connectionClosedReceived();
    _connection = null;
    if (!mounted || widget.readOnly || !widget.focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.readOnly && widget.focusNode.hasFocus) {
        _openConnection();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void showToolbar() {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  bool onFocusReceived() => false;

  @override
  void performSelector(String selectorName) {}
}
