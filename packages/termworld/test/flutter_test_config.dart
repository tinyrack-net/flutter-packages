import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Applies a bounded timeout to widget tests as well as plain Dart tests.
///
/// `testWidgets` explicitly uses the binding's ten-minute default, bypassing
/// the command-line timeout. Keeping both at 30 seconds makes a stalled
/// platform-parity test fail with its exact name instead of hiding for ten
/// minutes in every runner.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AutomatedTestWidgetsFlutterBinding.ensureInitialized().defaultTestTimeout =
      const Timeout(Duration(seconds: 30));
  await testMain();
}
