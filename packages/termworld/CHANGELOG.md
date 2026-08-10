# Changelog

## 0.4.0

- Keeps a terminal resize from abandoning output. `Terminal.resize` flushes the
  write buffer synchronously first, and that flush re-entered the parser when a
  chunk was still awaiting an asynchronous handler. This parser refuses
  re-entry, unlike xterm.js' resumable synchronous one, so the flush threw
  `improper continuation due to previous async handler` out of the frame
  callback and dropped the chunk it was holding. A resize landing mid-handler
  now leaves the queue to the pending write, which parses it in order once the
  handler resolves. `writeSync` is guarded the same way.
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
