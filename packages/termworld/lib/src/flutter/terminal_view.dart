import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/marker.dart';
import 'package:termworld/src/core/options.dart';
import 'package:termworld/src/core/terminal.dart';
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
      _focusNode.addListener(_handleFocusChange);
      _syncCursorBlink();
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.terminal != widget.terminal) {
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

  void _requestKeyboard() {
    _focusNode.requestFocus();
    _inputKey.currentState?.requestKeyboard();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
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
    _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
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
    _disposeAccessibilityListeners();
    _testingChannel?.setMethodCallHandler(null);
    _testingChannel = null;
    _controller.detach();
    widget.terminal.attachFocusHandlers();
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
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
          cursorVisible: _cursorVisible,
          hoveredLink: _hoveredLink,
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
              : MouseCursor.defer,
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
  }) {
    final terminal = widget.terminal;
    final buffer = terminal.buffer.active;
    final line = buffer.getLine(position.y);
    if (line == null || position.x >= terminal.cols) return null;
    var column = position.x;
    while (column > 0 && line.getCell(column)?.width == 0) {
      column--;
    }
    final initial = line.getCell(column);
    if (initial == null) return null;
    final spaces = initial.chars == ' ';
    bool matches(TerminalCell? cell) {
      if (cell == null) return false;
      if (spaces) return cell.chars == ' ';
      if (cell.width == 0) return true;
      return !terminal.options.wordSeparator.contains(cell.chars);
    }

    if (!spaces && !matches(initial)) {
      if (!allowWhitespaceOnly) return null;
    }
    var startRow = position.y;
    var startColumn = column;
    while (true) {
      if (startColumn > 0) {
        final previous = buffer.getLine(startRow)?.getCell(startColumn - 1);
        if (!matches(previous)) break;
        startColumn--;
        continue;
      }
      final currentLine = buffer.getLine(startRow);
      if (spaces || startRow == 0 || !(currentLine?.isWrapped ?? false)) {
        break;
      }
      final previous = buffer.getLine(startRow - 1)?.getCell(terminal.cols - 1);
      if (!matches(previous)) break;
      startRow--;
      startColumn = terminal.cols - 1;
    }
    var endRow = position.y;
    var endColumn = column;
    while (true) {
      if (endColumn + 1 < terminal.cols) {
        final next = buffer.getLine(endRow)?.getCell(endColumn + 1);
        if (!matches(next)) break;
        endColumn++;
        continue;
      }
      final nextLine = buffer.getLine(endRow + 1);
      if (spaces ||
          nextLine == null ||
          !nextLine.isWrapped ||
          !matches(nextLine.getCell(0))) {
        break;
      }
      endRow++;
      endColumn = 0;
    }
    final onlyWhitespace = spaces || initial.chars.trim().isEmpty;
    if (!allowWhitespaceOnly && onlyWhitespace) return null;
    return TerminalBufferRange(
      start: TerminalBufferPosition(startColumn, startRow),
      end: TerminalBufferPosition(endColumn + 1, endRow),
    );
  }

  TerminalBufferRange? _wrappedLineRange(int row) {
    final buffer = widget.terminal.buffer.active;
    if (buffer.getLine(row) == null) return null;
    var first = row;
    while (first > 0 && (buffer.getLine(first)?.isWrapped ?? false)) {
      first--;
    }
    var last = row;
    while (last + 1 < buffer.length &&
        (buffer.getLine(last + 1)?.isWrapped ?? false)) {
      last++;
    }
    return TerminalBufferRange(
      start: TerminalBufferPosition(0, first),
      end: TerminalBufferPosition(widget.terminal.cols, last),
    );
  }

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
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final allowed = widget.terminal.handleKeyEvent(
      TerminalKeyEvent(
        key: event.logicalKey.keyLabel,
        shift: keyboard.isShiftPressed,
        alt: keyboard.isAltPressed,
        control: keyboard.isControlPressed,
        meta: keyboard.isMetaPressed,
      ),
    );
    if (!allowed) return KeyEventResult.handled;
    if (keyboard.isShiftPressed &&
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      widget.terminal.scrollPages(-1);
      return KeyEventResult.handled;
    }
    if (keyboard.isShiftPressed &&
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      widget.terminal.scrollPages(1);
      return KeyEventResult.handled;
    }
    final sequence = _keySequence(event.logicalKey, keyboard);
    if (sequence == null) return KeyEventResult.ignored;
    widget.terminal.input(sequence);
    return KeyEventResult.handled;
  }

  String? _keySequence(
    LogicalKeyboardKey key,
    HardwareKeyboard keyboard,
  ) {
    final shift = keyboard.isShiftPressed;
    final alt = keyboard.isAltPressed;
    final control = keyboard.isControlPressed;
    final meta = keyboard.isMetaPressed;
    final modifier =
        1 +
        (shift ? 1 : 0) +
        (alt ? 2 : 0) +
        (control ? 4 : 0) +
        (meta ? 8 : 0);
    final applicationCursorMode =
        widget.terminal.modes.applicationCursorKeysMode;
    String? cursor(String finalByte) {
      if (meta) return null;
      if (modifier != 1) return '\u001b[1;$modifier$finalByte';
      return applicationCursorMode ? '\u001bO$finalByte' : '\u001b[$finalByte';
    }

    String tilde(int code) =>
        modifier == 1 ? '\u001b[$code~' : '\u001b[$code;$modifier~';
    if (key == LogicalKeyboardKey.backspace) {
      final deletion = control ? '\b' : '\u007f';
      return alt ? '\u001b$deletion' : deletion;
    }
    if (key == LogicalKeyboardKey.tab) {
      if (shift) return '\u001b[Z';
      return '\t';
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return alt ? '\u001b\r' : '\r';
    }
    if (key == LogicalKeyboardKey.escape) {
      return alt ? '\u001b\u001b' : '\u001b';
    }
    if (key == LogicalKeyboardKey.arrowUp) return cursor('A');
    if (key == LogicalKeyboardKey.arrowDown) return cursor('B');
    if (key == LogicalKeyboardKey.arrowRight) return cursor('C');
    if (key == LogicalKeyboardKey.arrowLeft) return cursor('D');
    if (key == LogicalKeyboardKey.home) return cursor('H');
    if (key == LogicalKeyboardKey.end) return cursor('F');
    if (key == LogicalKeyboardKey.insert) {
      return shift || control ? null : '\u001b[2~';
    }
    if (key == LogicalKeyboardKey.delete) return tilde(3);
    if (key == LogicalKeyboardKey.pageUp) {
      return control ? tilde(5) : '\u001b[5~';
    }
    if (key == LogicalKeyboardKey.pageDown) {
      return control ? tilde(6) : '\u001b[6~';
    }
    final function = _functionKey(key);
    if (function != null) {
      final (code, finalByte) = function;
      if (code == 1) {
        return modifier == 1
            ? '\u001bO$finalByte'
            : '\u001b[1;$modifier$finalByte';
      }
      return modifier == 1 ? '\u001b[$code~' : '\u001b[$code;$modifier~';
    }
    final controlSequence = _controlSequence(key, shift, control, alt, meta);
    if (controlSequence != null) return controlSequence;
    final altSequence = _altSequence(key, shift, control, alt, meta);
    if (altSequence != null) return altSequence;
    return null;
  }

  (int, String)? _functionKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.f1) return (1, 'P');
    if (key == LogicalKeyboardKey.f2) return (1, 'Q');
    if (key == LogicalKeyboardKey.f3) return (1, 'R');
    if (key == LogicalKeyboardKey.f4) return (1, 'S');
    if (key == LogicalKeyboardKey.f5) return (15, '');
    if (key == LogicalKeyboardKey.f6) return (17, '');
    if (key == LogicalKeyboardKey.f7) return (18, '');
    if (key == LogicalKeyboardKey.f8) return (19, '');
    if (key == LogicalKeyboardKey.f9) return (20, '');
    if (key == LogicalKeyboardKey.f10) return (21, '');
    if (key == LogicalKeyboardKey.f11) return (23, '');
    if (key == LogicalKeyboardKey.f12) return (24, '');
    return null;
  }

  String? _controlSequence(
    LogicalKeyboardKey key,
    bool shift,
    bool control,
    bool alt,
    bool meta,
  ) {
    if (!control || alt || meta) return null;
    final label = key.keyLabel;
    if (!shift && key == LogicalKeyboardKey.space) return '\u0000';
    if (!shift && label.length == 1) {
      final code = label.toUpperCase().codeUnitAt(0);
      if (code >= 0x41 && code <= 0x5a) return String.fromCharCode(code - 0x40);
      if ('34567'.contains(label)) {
        return String.fromCharCode(label.codeUnitAt(0) - 0x33 + 0x1b);
      }
      if (label == '8') return '\u007f';
      if (label == '[') return '\u001b';
      if (label == r'\') return '\u001c';
      if (label == ']') return '\u001d';
      if (label == '/') return '\u001f';
    }
    if (shift) {
      if (key == LogicalKeyboardKey.minus) return '\u001f';
      if (key == LogicalKeyboardKey.digit2) return '\u0000';
      if (key == LogicalKeyboardKey.digit6) return '\u001e';
    }
    return null;
  }

  String? _altSequence(
    LogicalKeyboardKey key,
    bool shift,
    bool control,
    bool alt,
    bool meta,
  ) {
    if (!alt || meta) return null;
    if (defaultTargetPlatform == TargetPlatform.macOS &&
        !widget.terminal.options.macOptionIsMeta) {
      return null;
    }
    var label = key == LogicalKeyboardKey.space ? ' ' : key.keyLabel;
    if (label.length != 1) return null;
    if (control) {
      final code = label.toUpperCase().codeUnitAt(0);
      if (code >= 0x41 && code <= 0x5a) {
        label = String.fromCharCode(code - 0x40);
      } else if (label == ' ') {
        label = '\u0000';
      }
    } else if (!shift) {
      label = label.toLowerCase();
    }
    return '\u001b$label';
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
    required this.cursorVisible,
    required this.hoveredLink,
  });

  final Terminal terminal;
  final TerminalTheme theme;
  final TerminalStyle style;
  final EdgeInsets padding;
  final double backgroundOpacity;
  final bool focused;
  final bool cursorVisible;
  final TerminalLink? hoveredLink;

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
        var foreground = _color(
          cell.foregroundMode,
          cell.foreground,
          theme.foreground,
        );
        var background = _color(
          cell.backgroundMode,
          cell.background,
          theme.background,
        );
        final decorationForeground = _decorationForeground(column, bufferRow);
        if (decorationForeground != null) foreground = decorationForeground;
        if (cell.isInverse) {
          final swapped = foreground;
          foreground = background;
          background = swapped;
        }
        if (cell.backgroundMode != TerminalColorMode.defaultColor ||
            cell.isInverse) {
          canvas.drawRect(rect, Paint()..color = background);
        }
        final selected = _selected(selection, column, bufferRow);
        if (selected) {
          final selectionColor = focused
              ? theme.selection
              : theme.selectionInactive;
          canvas.drawRect(
            rect,
            Paint()..color = selectionColor,
          );
          foreground = theme.selectionForeground ?? foreground;
          background = TerminalThemes.blend(background, selectionColor);
        }
        final codePoint = cell.chars.isEmpty ? null : cell.chars.runes.first;
        if (codePoint != null &&
            !_treatGlyphAsBackgroundColor(codePoint) &&
            terminal.options.minimumContrastRatio != 1) {
          foreground = TerminalThemes.ensureContrast(
            background,
            foreground,
            terminal.options.minimumContrastRatio / (cell.isDim ? 2 : 1),
          );
        }
        if (!cell.isInvisible && cell.chars.isNotEmpty) {
          TextPainter(
              text: TextSpan(
                text: cell.chars,
                style: style
                    .toTextStyle(
                      color: cell.isDim
                          ? foreground.withValues(alpha: 0.5)
                          : foreground,
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
    if (terminal.modes.showCursor && (!focused || cursorVisible)) {
      _paintCursor(canvas, dimensions, buffer.cursorX, buffer.cursorY);
    }
  }

  void _paintHoveredLink(
    Canvas canvas,
    TerminalRenderDimensions dimensions,
  ) {
    final link = hoveredLink;
    if (link == null || !(link.decorations?.underline ?? true)) return;
    final firstVisibleLine = terminal.viewportY + 1;
    final lastVisibleLine = firstVisibleLine + terminal.rows - 1;
    final startLine = link.range.start.y.clamp(
      firstVisibleLine,
      lastVisibleLine,
    );
    final endLine = link.range.end.y.clamp(firstVisibleLine, lastVisibleLine);
    if (startLine > endLine) return;
    final paint = Paint()
      ..color = theme.foreground
      ..strokeWidth = 1;
    for (var line = startLine; line <= endLine; line++) {
      final startColumn = line == link.range.start.y
          ? link.range.start.x - 1
          : 0;
      final endColumn = line == link.range.end.y
          ? link.range.end.x
          : terminal.cols;
      final y =
          padding.top +
          (line - firstVisibleLine + 1) * dimensions.cellHeight -
          1;
      canvas.drawLine(
        Offset(padding.left + startColumn * dimensions.cellWidth, y),
        Offset(padding.left + endColumn * dimensions.cellWidth, y),
        paint,
      );
    }
  }

  Color? _decorationForeground(int column, int row) {
    Color? result;
    for (final decoration in terminal.decorations) {
      final x = _decorationColumn(decoration);
      if (decoration.marker.line <= row &&
          decoration.marker.line + decoration.height > row &&
          column >= x &&
          column < x + decoration.width) {
        result = _cssColor(decoration.foregroundColor) ?? result;
      }
    }
    return result;
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
      final background = _cssColor(decoration.backgroundColor);
      if (background != null) {
        canvas.drawRect(rect, Paint()..color = background);
      }
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

  Color? _cssColor(String? source) {
    if (source == null) return null;
    final value = source.trim();
    if (!value.startsWith('#')) return null;
    final hex = value.substring(1);
    if (hex.length == 3 || hex.length == 4) {
      final expanded = hex.split('').map((part) => '$part$part').join();
      final parsed = int.tryParse(expanded, radix: 16);
      if (parsed == null) return null;
      return hex.length == 3
          ? Color(0xff000000 | parsed)
          : Color((parsed & 0xff) << 24 | parsed >> 8);
    }
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    if (hex.length == 6) return Color(0xff000000 | parsed);
    if (hex.length == 8) {
      return Color((parsed & 0xff) << 24 | parsed >> 8);
    }
    return null;
  }

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

  bool _treatGlyphAsBackgroundColor(int codePoint) =>
      codePoint >= 0xe0a4 && codePoint <= 0xe0d6 ||
      codePoint >= 0x2500 && codePoint <= 0x259f;

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
      ..style = !focused && inactiveStyle == TerminalInactiveCursorStyle.outline
          ? PaintingStyle.stroke
          : PaintingStyle.fill;
    canvas.drawRect(rect, paint);
    if (cursorType == TerminalCursorType.block &&
        paint.style == PaintingStyle.fill) {
      final line = terminal.buffer.active.getLine(
        terminal.buffer.active.baseY + row,
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
    _reconcileCommitted(_editingValue.text);
    _resetEditingState();
    widget.onComposingChanged();
  }

  void _resetEditingState() {
    _editingValue = TextEditingValue.empty;
    _platformEditingValue = TextEditingValue.empty;
    _committedPrefix = '';
    _resetEchoPrefix = '';
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
    final normalized = _withoutResetEcho(value);
    _editingValue = normalized;
    final composing = normalized.composing;
    final committedEnd = composing.isValid && !composing.isCollapsed
        ? composing.start
        : normalized.text.length;
    _reconcileCommitted(normalized.text.substring(0, committedEnd));
    widget.onComposingChanged();
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
