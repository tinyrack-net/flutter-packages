# Changelog

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
