# Changelog

## 0.4.1

- Stops duplicating in-progress Hangul syllables on Windows. The Win32
  embedder applies the terminal's post-commit `setEditingState` reset directly
  to its engine-side `TextInputModel`, and Microsoft's Korean IME closes and
  reopens its composition around every settled syllable; a reset landing after
  the reopen corrupted the model and committed preedit states such as 녀, 핫,
  and 셍 into the PTY ("안녕하세요. " arrived as "안녕녀녕핫하하세셍요요. ").
  Windows now accumulates committed text instead of resetting the platform
  buffer, and the grapheme-cluster diff keeps writing only the tail. The
  full-value (non-delta) path keeps the reset, since an embedder reporting
  whole values maintains no cumulative model for a reset to corrupt.

## 0.4.0

- Picks up the vtworld fix that keeps a resize from abandoning terminal output.
  `Terminal.resize` flushes the write buffer before it changes the geometry,
  and that flush re-entered the parser when a chunk was still awaiting an
  asynchronous handler, throwing out of the frame callback that reported the
  new dimensions and dropping the chunk. A terminal resized while it streamed
  output lost that output.
- Removes the xterm.dart dependency, exports, delegates, wrappers, and
  fallbacks. Core, headless, Flutter, and addon behavior is owned by termworld.
- Pins the behavioral contract to xterm.js
  `904ae935269eef5ec6a1415b64463c3d02eff1eb` with committed declarations,
  source hashes, test IDs, and MIT fixtures.
- Ports xterm's Unicode 6 and 11 width tables and Unicode 15 grapheme property
  trie without a runtime data dependency.
- Activates the owned WebGL2 renderer on Flutter web, including GPU frame
  upload, atlas lifecycle, context-loss fallback/restoration, and required
  Chromium, Firefox, and WebKit conformance jobs.
- Uses Flutter's real delta text-input boundary on all six platforms and the
  browser font-loading boundary on web.

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
