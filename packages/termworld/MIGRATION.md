# Migrating to termworld 0.4.0

The 0.2 API and the delegated 0.3 implementation are removed. There is no
compatibility wrapper and no xterm.dart type is exposed. Construct `Terminal`
instead of `TerminalEmulator`,
listen to `terminal.onData` for PTY-bound data, listen to `terminal.onResize`
for geometry changes, and provide it to `TerminalView` with the `terminal`
named parameter.

```dart
final terminal = Terminal();
terminal.onData.listen(pty.write);
terminal.onResize.listen((event) => pty.resize(event.cols, event.rows));

final view = TerminalView(terminal: terminal);
```

Cell, buffer, mode, parser, marker, decoration, and addon APIs are exported by
`termworld_headless.dart`. Renderer theme and style types remain available from
`termworld.dart`. Product-specific process, upload, color, and policy types do
not belong in this package.
