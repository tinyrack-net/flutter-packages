import 'package:vtworld/vtworld.dart';

/// Renderer-layer lifecycle contract ported from xterm's WebGL renderer.
abstract interface class TerminalWebglRenderLayer implements Disposable {
  /// Handles terminal focus loss.
  void handleBlur(Terminal terminal);

  /// Handles terminal focus acquisition.
  void handleFocus(Terminal terminal);

  /// Handles cursor movement.
  void handleCursorMove(Terminal terminal);

  /// Handles a changed inclusive viewport row range.
  void handleGridChanged(Terminal terminal, int startRow, int endRow);

  /// Handles selection geometry changes.
  void handleSelectionChanged(
    Terminal terminal,
    (int, int)? start,
    (int, int)? end, {
    bool columnSelectMode = false,
  });

  /// Updates renderer dimensions.
  void resize(Terminal terminal, TerminalRenderDimensions dimensions);

  /// Clears all layer state for [terminal].
  void reset(Terminal terminal);
}

/// Optional character-joiner operations implemented by text render layers.
abstract interface class TerminalWebglCharacterJoinerLayer {
  /// Registers a character joining callback and returns its identity.
  int registerCharacterJoiner(
    List<(int, int)> Function(String text) handler,
  );

  /// Removes a registered character joiner.
  bool deregisterCharacterJoiner(int joinerId);
}
