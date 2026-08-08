import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/core/addon.dart';
import 'package:termworld/src/core/addon_manager.dart';
import 'package:termworld/src/core/terminal.dart';

void main() {
  group('AddonManager', () {
    group('loadAddon', () {
      test('should call addon constructor', () {
        final manager = AddonManager();
        final addon = _Addon();
        final terminal = Terminal();
        manager.loadAddon(terminal, addon);
        expect(addon.terminal, same(terminal));
      });
    });

    group('dispose', () {
      test('should dispose all loaded addons', () {
        final manager = AddonManager();
        final addons = <_Addon>[_Addon(), _Addon(), _Addon()];
        for (final addon in addons) {
          manager.loadAddon(Terminal(), addon);
        }
        expect(manager.loadedAddonCount, 3);
        manager.dispose();
        expect(addons.map((addon) => addon.disposeCalls), <int>[1, 1, 1]);
        expect(manager.loadedAddonCount, 0);
      });
    });
  });
}

final class _Addon extends TerminalAddon {
  Terminal? terminal;
  int disposeCalls = 0;

  @override
  void activate(Terminal terminal) => this.terminal = terminal;

  @override
  void dispose() {
    if (isDisposed) return;
    disposeCalls++;
    super.dispose();
  }
}
