import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/marker.dart';
import 'package:termworld/src/core/terminal.dart';
import 'package:termworld/src/flutter/terminal_theme.dart';
import 'package:termworld/src/flutter/terminal_view_controller.dart';

/// Flutter renderer and input surface for a headless [Terminal].
class TerminalView extends StatefulWidget {
  /// Creates a terminal view. The caller retains ownership of [terminal].
  const TerminalView({
    required this.terminal,
    super.key,
    this.controller,
    this.theme,
    this.style = const TerminalStyle(),
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
  final TerminalStyle style;

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
  Disposable? _scrollListener;
  Disposable? _selectionListener;

  @override
  void initState() {
    super.initState();
    _attach();
    if (kDebugMode) {
      _testingChannel = const MethodChannel('termworld/testing')
        ..setMethodCallHandler(_handleTestingCall);
    }
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode =
          widget.focusNode ?? FocusNode(debugLabel: 'termworld-terminal-input');
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.terminal != widget.terminal) {
      _renderListener?.dispose();
      _scrollListener?.dispose();
      _selectionListener?.dispose();
      _controller.detach();
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? TerminalViewController();
      _attach();
    }
  }

  void _attach() {
    _controller.attach(widget.terminal, _requestKeyboard);
    _renderListener = widget.terminal.onRender.listen((_) {
      if (mounted) setState(() {});
    });
    _scrollListener = widget.terminal.onScroll.listen((_) {
      if (mounted) setState(() {});
    });
    _selectionListener = widget.terminal.onSelectionChange.listen((_) {
      if (mounted) setState(() {});
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
    _renderListener?.dispose();
    _scrollListener?.dispose();
    _selectionListener?.dispose();
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
      final theme = widget.theme ?? TerminalThemes.defaultTheme;
      final renderer = CustomPaint(
        painter: _TerminalPainter(
          terminal: widget.terminal,
          theme: theme,
          style: widget.style,
          padding: widget.padding ?? EdgeInsets.zero,
          backgroundOpacity: widget.backgroundOpacity,
          focused: _focusNode.hasFocus,
        ),
        size: constraints.biggest,
      );
      final composingText = _inputKey.currentState?.composingText ?? '';
      final padding = widget.padding ?? EdgeInsets.zero;
      final dimensions = widget.terminal.dimensions;
      final view = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _requestKeyboard,
        onTapUp: (details) {
          widget.onTapUp?.call(details, _cellAt(details.localPosition));
        },
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
                        style: widget.style.toTextStyle(
                          color: theme.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      return Semantics(
        label: widget.semanticLabel,
        textField: !widget.readOnly,
        child: view,
      );
    },
  );

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
    final cellHeight = widget.style.fontSize * widget.style.height;
    final cellWidth = widget.style.fontSize * 0.6;
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
  });

  final Terminal terminal;
  final TerminalTheme theme;
  final TerminalStyle style;
  final EdgeInsets padding;
  final double backgroundOpacity;
  final bool focused;

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
        if (_selected(selection, column, bufferRow)) {
          canvas.drawRect(rect, Paint()..color = theme.selection);
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
                          ? FontWeight.bold
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
    if (terminal.modes.showCursor && focused) {
      _paintCursor(canvas, dimensions, buffer.cursorX, buffer.cursorY);
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
    final rect = switch (style.cursorType) {
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
        2,
        dimensions.cellHeight,
      ),
    };
    canvas.drawRect(rect, Paint()..color = theme.cursor.withValues(alpha: 0.7));
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
  String _committedPrefix = '';

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
    _committedPrefix = '';
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
  TextEditingValue? get currentTextEditingValue => _editingValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    _accept(value);
    _finishCommittedInput();
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    for (final delta in deltas) {
      _accept(delta.apply(_editingValue));
    }
    _finishCommittedInput();
  }

  void _accept(TextEditingValue value) {
    _editingValue = value;
    final composing = value.composing;
    final committedEnd = composing.isValid && !composing.isCollapsed
        ? composing.start
        : value.text.length;
    _reconcileCommitted(value.text.substring(0, committedEnd));
    widget.onComposingChanged();
  }

  void _finishCommittedInput() {
    if (_isComposing || _editingValue.text.isEmpty) return;
    // xterm clears its hidden textarea after committed input. Keeping the
    // committed value makes a later platform synchronization to an empty
    // editing value look like a user deletion and emits duplicate DEL bytes.
    _resetEditingState();
    widget.onComposingChanged();
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
