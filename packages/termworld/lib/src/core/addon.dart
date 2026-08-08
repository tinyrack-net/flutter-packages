import 'package:termworld/src/core/disposable.dart';

/// Extension loaded into a terminal instance.
abstract interface class TerminalAddon implements Disposable {
  /// Activates this addon. It is called at most once.
  void activate(covariant Object terminal);
}
