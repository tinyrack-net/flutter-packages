import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/core/addon.dart';
import 'package:termworld/src/core/addon_manager.dart';

void main() {
  group('AddonManager', () {
    group('loadAddon', () {
      test('should call addon constructor', () {
        final manager = AddonManager();
        final addon = _Addon();
        manager.loadAddon('foo', addon);
        expect(addon.terminal, 'foo');
      });
    });

    group('dispose', () {
      test('should dispose all loaded addons', () {
        final manager = AddonManager();
        final addons = <_Addon>[_Addon(), _Addon(), _Addon()];
        for (final addon in addons) {
          manager.loadAddon(Object(), addon);
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
  Object? terminal;
  int disposeCalls = 0;

  @override
  void activate(covariant Object terminal) => this.terminal = terminal;

  @override
  void dispose() {
    if (isDisposed) return;
    disposeCalls++;
    super.dispose();
  }
}
