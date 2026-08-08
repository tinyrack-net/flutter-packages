# Changelog

## 0.3.0

- Replaces the 0.2 engine and widget API with an xterm.js 6.0.0-compatible
  headless `Terminal` and a Flutter `TerminalView` adapter.
- Adds ordered string and UTF-8 writes, parser handlers, buffer namespaces,
  modes, Unicode providers, selection, markers, decorations, and links.
- Adds all 13 official addon entrypoints and explicit web capability errors.
- Moves IME handling to a grapheme-aware delta input client and adds one shared
  conformance suite for Android, iOS, Linux, macOS, Windows, and web.
- Vendors the pinned upstream VT fixtures and a reproducible parity manifest.

## 0.2.1

- Lets terminal output move the cursor backward across automatically wrapped
  rows while keeping explicit line boundaries intact, including double-width
  graphemes and resized scrollback.
- Hides the regular cursor while an input method is composing and renders only
  the preedit underline until the text is committed.

## 0.2.0

- Adds standard VT sequences for modified navigation, editing, function, and
  keypad keys, including Alt/Option+Backspace word deletion.
- Keeps hardware deletion and platform text deltas from emitting duplicate
  input, and supports held-key repeats.
- Restores a focused terminal's platform text connection after native menus
  and other platform-owned interactions close it.

## 0.1.0

- Adds a VT/ANSI terminal engine, Unicode cell renderer, selection controller,
  keyboard and pointer surface, bracketed paste, and delta-model IME input.
- Supports Android, iOS, Linux, macOS, Windows and web from one Dart contract.
