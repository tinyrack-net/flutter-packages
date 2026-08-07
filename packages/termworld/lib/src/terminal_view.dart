import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:termworld/src/terminal_emulator.dart';
import 'package:termworld/src/terminal_models.dart';
import 'package:termworld/src/terminal_view_controller.dart';

/// A style-neutral, interactive Flutter terminal viewport.
class TerminalView extends StatefulWidget {
  /// Creates a terminal view.
  const TerminalView({
    required this.emulator,
    this.controller,
    this.theme = const TerminalTheme(
      background: Color(0xFF000000),
      foreground: Color(0xFFE5E5E5),
      cursor: Color(0xFFFFFFFF),
      selection: Color(0x663B8EEA),
    ),
    this.style = const TerminalStyle(
      textStyle: TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.2),
      padding: EdgeInsets.all(8),
    ),
    this.autofocus = false,
    this.readOnly = false,
    this.onSecondaryTapDown,
    this.onPointerEvent,
    this.onKeyEvent,
    this.semanticLabel,
    super.key,
  });

  /// Emulator rendered by this view.
  final TerminalEmulator emulator;

  /// Optional externally-owned view controller.
  final TerminalViewController? controller;

  /// Terminal colors.
  final TerminalTheme theme;

  /// Terminal typography and geometry.
  final TerminalStyle style;

  /// Whether the view requests focus when mounted.
  final bool autofocus;

  /// Whether text and keyboard input are disabled.
  final bool readOnly;

  /// Receives a secondary pointer press not consumed by mouse tracking.
  final GestureTapDownCallback? onSecondaryTapDown;

  /// Observes pointer events after terminal mouse reporting is applied.
  final ValueChanged<PointerEvent>? onPointerEvent;

  /// Gives a consumer first refusal for non-text key events.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Optional accessibility name.
  final String? semanticLabel;

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

final class _TerminalViewState extends State<TerminalView> {
  late TerminalViewController _controller;
  late bool _ownsController;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<_TerminalTextInputState> _inputKey =
      GlobalKey<_TerminalTextInputState>();
  Offset? _dragStart;

  @override
  void initState() {
    super.initState();
    _adoptController();
    widget.emulator.addListener(_changed);
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emulator != widget.emulator) {
      oldWidget.emulator.removeListener(_changed);
      widget.emulator.addListener(_changed);
      _controller.emulator = widget.emulator;
    }
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_changed);
      if (_ownsController) _controller.dispose();
      _adoptController();
      _controller.addListener(_changed);
    }
  }

  void _adoptController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TerminalViewController();
    _controller.emulator = widget.emulator;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.emulator.removeListener(_changed);
    _controller.removeListener(_changed);
    if (_ownsController) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _requestInput() {
    _controller.clearSelection();
    _inputKey.currentState?.requestKeyboard();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final override = widget.onKeyEvent?.call(node, event);
    if (override != null && override != KeyEventResult.ignored) return override;
    if (widget.readOnly || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (_inputKey.currentState?.isComposing ?? false) {
      return KeyEventResult.skipRemainingHandlers;
    }
    final logicalKey = event.logicalKey;
    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter) {
      // The text-input action owns Enter while a connection is active.
      return KeyEventResult.ignored;
    }
    if (logicalKey == LogicalKeyboardKey.backspace &&
        (_inputKey.currentState?.hasCommittedText ?? false)) {
      // A deletion delta owns Backspace once the platform editing buffer has
      // committed text. Handling both paths would delete twice.
      return KeyEventResult.ignored;
    }
    final hardware = HardwareKeyboard.instance;
    final character = event.character;
    if (hardware.isControlPressed &&
        character != null &&
        character.isNotEmpty) {
      final rune = character.toLowerCase().runes.first;
      if (rune >= 0x61 && rune <= 0x7a) {
        widget.emulator.input(String.fromCharCode(rune - 0x60));
        return KeyEventResult.handled;
      }
    }
    final sequence = widget.emulator.keySequence(logicalKey);
    if (sequence != null) {
      widget.emulator.input(sequence);
      return KeyEventResult.handled;
    }
    if ((hardware.isAltPressed || hardware.isMetaPressed) &&
        character != null &&
        character.isNotEmpty) {
      widget.emulator.input('\u001b$character');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final baseStyle = widget.style.textStyle;
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: baseStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final cellWidth = math.max<double>(1, painter.width);
    final cellHeight = math.max<double>(1, painter.height);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = widget.style.padding.horizontal;
        final vertical = widget.style.padding.vertical;
        final columns = math.max(
          1,
          ((constraints.maxWidth - horizontal) / cellWidth).floor(),
        );
        final rows = math.max(
          1,
          ((constraints.maxHeight - vertical) / cellHeight).floor(),
        );
        if (columns != widget.emulator.columns ||
            rows != widget.emulator.rows) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.emulator.resize(columns, rows);
          });
        }
        final viewport = Listener(
          onPointerDown: (event) => _reportPointer(
            event,
            pressed: true,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
          ),
          onPointerUp: (event) => _reportPointer(
            event,
            pressed: false,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
          ),
          onPointerHover: (event) => _reportPointer(
            event,
            pressed: event.buttons != 0,
            motion: true,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _requestInput,
            onSecondaryTapDown: widget.onSecondaryTapDown,
            onDoubleTapDown: (details) => _controller.selectWordAt(
              _positionAt(details.localPosition, cellWidth, cellHeight),
            ),
            onLongPressStart: (details) => _controller.selectLineAt(
              _positionAt(details.localPosition, cellWidth, cellHeight).row,
            ),
            onPanStart:
                widget.emulator.mouseTrackingMode ==
                    TerminalMouseTrackingMode.none
                ? (details) {
                    _dragStart = details.localPosition;
                    _updateSelection(
                      details.localPosition,
                      details.localPosition,
                      cellWidth,
                      cellHeight,
                    );
                  }
                : null,
            onPanUpdate:
                widget.emulator.mouseTrackingMode ==
                    TerminalMouseTrackingMode.none
                ? (details) {
                    final start = _dragStart;
                    if (start == null) return;
                    _updateSelection(
                      start,
                      details.localPosition,
                      cellWidth,
                      cellHeight,
                    );
                  }
                : null,
            child: CustomPaint(
              painter: _TerminalPainter(
                emulator: widget.emulator,
                controller: _controller,
                terminalTheme: widget.theme,
                terminalStyle: widget.style,
                textScaler: scaler,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                composingText: _inputKey.currentState?.composingText,
              ),
              size: Size.infinite,
            ),
          ),
        );
        return Semantics(
          label: widget.semanticLabel,
          textField: !widget.readOnly,
          readOnly: widget.readOnly,
          child: ColoredBox(
            color: widget.theme.background,
            child: _TerminalTextInput(
              key: _inputKey,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              readOnly: widget.readOnly,
              emulator: widget.emulator,
              onKeyEvent: _handleKey,
              onComposingChanged: _changed,
              child: viewport,
            ),
          ),
        );
      },
    );
  }

  void _updateSelection(
    Offset first,
    Offset second,
    double cellWidth,
    double cellHeight,
  ) {
    final a = _positionAt(first, cellWidth, cellHeight);
    final b = _positionAt(second, cellWidth, cellHeight);
    final aBefore = a.row < b.row || (a.row == b.row && a.column <= b.column);
    _controller.setSelection(
      TerminalSelection(aBefore ? a : b, aBefore ? b : a),
    );
  }

  TerminalPosition _positionAt(
    Offset offset,
    double cellWidth,
    double cellHeight,
  ) {
    final local = offset - widget.style.padding.topLeft;
    final visibleStart = math.max(
      0,
      widget.emulator.lines.length - widget.emulator.rows,
    );
    return TerminalPosition(
      (local.dx / cellWidth).floor().clamp(0, widget.emulator.columns),
      visibleStart +
          (local.dy / cellHeight).floor().clamp(0, widget.emulator.rows - 1),
    );
  }

  void _reportPointer(
    PointerEvent event, {
    required bool pressed,
    required double cellWidth,
    required double cellHeight,
    bool motion = false,
  }) {
    widget.onPointerEvent?.call(event);
    final local = event.localPosition - widget.style.padding.topLeft;
    final buttons = event.buttons;
    final button = buttons & kPrimaryButton != 0
        ? 0
        : buttons & kMiddleMouseButton != 0
        ? 1
        : buttons & kSecondaryButton != 0
        ? 2
        : 3;
    final hardware = HardwareKeyboard.instance;
    final report = widget.emulator.mouseReport(
      button: button,
      column: (local.dx / cellWidth).floor(),
      row: (local.dy / cellHeight).floor(),
      pressed: pressed,
      motion: motion,
      shift: hardware.isShiftPressed,
      meta: hardware.isMetaPressed || hardware.isAltPressed,
      control: hardware.isControlPressed,
    );
    if (report != null) widget.emulator.input(report);
  }
}

final class _TerminalTextInput extends StatefulWidget {
  const _TerminalTextInput({
    required this.focusNode,
    required this.autofocus,
    required this.readOnly,
    required this.emulator,
    required this.onKeyEvent,
    required this.onComposingChanged,
    required this.child,
    super.key,
  });

  final FocusNode focusNode;
  final bool autofocus;
  final bool readOnly;
  final TerminalEmulator emulator;
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

  bool get isComposing =>
      _editingValue.composing.isValid && !_editingValue.composing.isCollapsed;

  bool get hasCommittedText => _committedPrefix.isNotEmpty;

  String? get composingText {
    if (!isComposing) return null;
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
    if (oldWidget.emulator != widget.emulator) {
      _editingValue = TextEditingValue.empty;
      _committedPrefix = '';
      _connection?.setEditingState(_editingValue);
    }
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
    onKeyEvent: widget.onKeyEvent,
    child: widget.child,
  );

  void requestKeyboard() {
    if (!widget.focusNode.hasFocus) widget.focusNode.requestFocus();
    _openConnection();
  }

  void _focusChanged() {
    if (widget.focusNode.hasFocus) {
      _openConnection();
    } else {
      _closeConnection();
    }
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
  void updateEditingValue(TextEditingValue value) => _accept(value);

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    for (final delta in textEditingDeltas) {
      _accept(delta.apply(_editingValue));
    }
  }

  void _accept(TextEditingValue value) {
    _editingValue = value;
    final composing = value.composing;
    final committedEnd = composing.isValid && !composing.isCollapsed
        ? composing.start
        : value.text.length;
    final nextPrefix = value.text.substring(0, committedEnd);
    _reconcileCommitted(nextPrefix);
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
    if (removed > 0) widget.emulator.input('\u007f' * removed);
    if (common < nextClusters.length) {
      widget.emulator.input(nextClusters.skip(common).join());
    }
    _committedPrefix = next;
  }

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline || action == TextInputAction.done) {
      widget.emulator.input('\r');
    }
  }

  @override
  void connectionClosed() => _connection = null;

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

final class _TerminalPainter extends CustomPainter {
  _TerminalPainter({
    required this.emulator,
    required this.controller,
    required this.terminalTheme,
    required this.terminalStyle,
    required this.textScaler,
    required this.cellWidth,
    required this.cellHeight,
    required this.composingText,
  });

  final TerminalEmulator emulator;
  final TerminalViewController controller;
  final TerminalTheme terminalTheme;
  final TerminalStyle terminalStyle;
  final TextScaler textScaler;
  final double cellWidth;
  final double cellHeight;
  final String? composingText;

  @override
  void paint(Canvas canvas, Size size) {
    final lines = emulator.lines;
    final firstRow = math.max(
      0,
      lines.length - emulator.rows - controller.scrollOffset.round(),
    );
    final lastRow = math.min(lines.length, firstRow + emulator.rows);
    canvas.clipRect(Offset.zero & size);
    for (var row = firstRow; row < lastRow; row++) {
      final y = terminalStyle.padding.top + (row - firstRow) * cellHeight;
      final line = lines[row];
      for (var column = 0; column < line.length; column++) {
        final cell = line[column];
        if (cell.width == 0) continue;
        final x = terminalStyle.padding.left + column * cellWidth;
        final selected = _isSelected(column, row);
        final foreground = cell.style.inverse
            ? cell.style.background ?? terminalTheme.background
            : cell.style.foreground ?? terminalTheme.foreground;
        final background = selected
            ? terminalTheme.selection
            : cell.style.inverse
            ? cell.style.foreground ?? terminalTheme.foreground
            : cell.style.background;
        if (background != null) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, cellWidth * cell.width, cellHeight),
            Paint()..color = background,
          );
        }
        if (cell.text.isEmpty) continue;
        final decorations = cell.style.underline
            ? TextDecoration.underline
            : TextDecoration.none;
        TextPainter(
            text: TextSpan(
              text: cell.text,
              style: terminalStyle.textStyle.copyWith(
                color: foreground,
                fontWeight: cell.style.bold ? FontWeight.bold : null,
                fontStyle: cell.style.italic ? FontStyle.italic : null,
                decoration: decorations,
              ),
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )
          ..layout()
          ..paint(canvas, Offset(x, y));
      }
    }
    final cursorVisibleRow = emulator.cursorRow - firstRow;
    if (emulator.cursorVisible &&
        cursorVisibleRow >= 0 &&
        cursorVisibleRow < emulator.rows) {
      final cursorOffset = Offset(
        terminalStyle.padding.left + emulator.cursorColumn * cellWidth,
        terminalStyle.padding.top + cursorVisibleRow * cellHeight,
      );
      canvas.drawRect(
        cursorOffset & Size(cellWidth, cellHeight),
        Paint()
          ..color = terminalTheme.cursor
          ..style = PaintingStyle.stroke,
      );
      final composing = composingText;
      if (composing != null && composing.isNotEmpty) {
        TextPainter(
            text: TextSpan(
              text: composing,
              style: terminalStyle.textStyle.copyWith(
                color: terminalTheme.foreground,
                decoration: TextDecoration.underline,
                decorationColor: terminalTheme.cursor,
              ),
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )
          ..layout()
          ..paint(canvas, cursorOffset);
      }
    }
  }

  bool _isSelected(int column, int row) {
    final selection = controller.selection;
    if (selection == null ||
        row < selection.start.row ||
        row > selection.end.row) {
      return false;
    }
    if (selection.start.row == selection.end.row) {
      return row == selection.start.row &&
          column >= selection.start.column &&
          column < selection.end.column;
    }
    if (row == selection.start.row) return column >= selection.start.column;
    if (row == selection.end.row) return column < selection.end.column;
    return true;
  }

  @override
  bool shouldRepaint(_TerminalPainter oldDelegate) => true;
}
