# termworld

`termworld` is a style-neutral Flutter terminal emulator. It owns VT/ANSI
parsing, a Unicode character-cell buffer, selection, keyboard and pointer input,
and a delta-model text-input client that keeps IME preedit text out of the PTY
until it is committed.

```dart
final emulator = TerminalEmulator(
  onOutput: process.write,
  onResize: (size) => process.resize(size.columns, size.rows),
);

TerminalView(
  emulator: emulator,
  controller: TerminalViewController(),
  autofocus: true,
  theme: TerminalTheme(
    background: colors.surface,
    foreground: colors.text,
    cursor: colors.focus,
    selection: colors.surfaceSelected,
  ),
  style: TerminalStyle(
    textStyle: productMonospaceStyle,
    padding: productTerminalPadding,
  ),
);
```

Feed decoded process output to `TerminalEmulator.write`. `onOutput` receives
user input, control sequences and bracketed paste data exactly as they should be
written to a PTY. The package does not spawn processes or choose product colors.

## Input methods

The view opts into Flutter's `DeltaTextInputClient`. Text inside the composing
range is painted as preedit text and is not emitted. When text leaves that
range, the committed grapheme delta is emitted once. This covers Hangul, Kana,
Chinese candidate replacement, dead keys, combining marks and emoji sequences
without guessing from UTF-16 string lengths. While preedit is active, its
underline replaces the regular terminal cursor; after commit the cursor
returns at the emitted grapheme's terminal-cell boundary.

## Keyboard input

`TerminalView` translates editing, navigation, function, and application-keypad
keys to standard VT/xterm byte sequences. Shift, Alt/Option, Control, and Meta
modifiers are encoded consistently on every supported platform. In particular,
Backspace emits DEL and Alt/Option+Backspace emits ESC DEL so the program in the
PTY remains responsible for character and word deletion.

An externally owned `TerminalViewController` can call `requestKeyboard()` after
a native menu or another platform interaction ends. The view restores focus and
its platform text connection without changing terminal selection.

The emulator also retains automatic-wrap boundaries separately from explicit
line feeds. Backspace output can therefore move into the previous visual row
of one editable shell line without crossing a command boundary.

## Platforms

The same Dart implementation runs on Android, iOS, Linux, macOS, Windows and
web. Platform conformance tests exercise one input contract on every target.
Linux CI additionally runs a real IBus Hangul two-set session under X11. It
injects physical key positions, language toggles and clipboard paste rather
than calling Flutter's synthetic text-entry helpers.
