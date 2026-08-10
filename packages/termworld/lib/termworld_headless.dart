/// Headless xterm-compatible terminal APIs.
///
/// The parser, the cell grid, and ANSI serialization live in `vtworld`, a
/// plain Dart package, so a server with no Flutter SDK can hold the same
/// screen model this package renders. They are re-exported here so a consumer
/// of `termworld` never has to name the split.
library;

export 'package:vtworld/vtworld.dart';
