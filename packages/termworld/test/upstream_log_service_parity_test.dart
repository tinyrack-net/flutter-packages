import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/core/log_service.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('LogService', () {
    test('filters levels and follows live logLevel changes', () {
      final options = TerminalOptions(logLevel: TerminalLogLevel.warning);
      final records = <(TerminalLogLevel, String, List<Object?>)>[];
      final service = TerminalLogService(
        options,
        sink: (level, message, parameters) {
          records.add((level, message, parameters));
        },
      );
      addTearDown(service.dispose);
      service
        ..info('hidden')
        ..warning('shown')
        ..error('error');
      options.logLevel = TerminalLogLevel.trace;
      service.trace('trace');
      expect(
        records.map((record) => (record.$1, record.$2)),
        <(TerminalLogLevel, String)>[
          (TerminalLogLevel.warning, 'xterm.js: shown'),
          (TerminalLogLevel.error, 'xterm.js: error'),
          (TerminalLogLevel.trace, 'xterm.js: trace'),
        ],
      );
    });

    test('evaluates lazy parameters only for emitted messages', () {
      final options = TerminalOptions();
      final values = <Object?>[];
      var evaluations = 0;
      final service = TerminalLogService(
        options,
        sink: (_, _, parameters) => values.addAll(parameters),
      );
      addTearDown(service.dispose);
      Object? lazy() {
        evaluations++;
        return 'value';
      }

      service
        ..debug('hidden', <Object?>[lazy])
        ..info('shown', <Object?>[lazy]);
      expect(evaluations, 1);
      expect(values, <Object?>['value']);
    });

    test('routes unprefixed records through a configured logger', () {
      final logger = _Logger();
      final service = TerminalLogService(
        TerminalOptions(logger: logger, logLevel: TerminalLogLevel.trace),
      );
      addTearDown(service.dispose);
      service.debug('message', <Object?>[1, 2]);
      expect(logger.records.single.$2, 'message');
      expect(logger.records.single.$3, <Object?>[1, 2]);
    });
  });
}

final class _Logger implements TerminalLogger {
  final records = <(TerminalLogLevel, String, Object?)>[];

  @override
  void log(TerminalLogLevel level, String message, [Object? data]) {
    records.add((level, message, data));
  }
}
