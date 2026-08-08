import 'package:flutter/widgets.dart';

/// Supplies Flutter widgets that render additional terminal-buffer elements.
// A named interface mirrors xterm's provider lifecycle contract.
// ignore: one_member_abstracts
abstract interface class TerminalBufferElementProvider {
  /// Creates the widget subtree inserted over the terminal buffer.
  Widget provideBufferElements();
}
