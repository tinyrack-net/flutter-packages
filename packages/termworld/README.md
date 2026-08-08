# termworld

`termworld` is a Flutter and pure-Dart port of xterm.js 6.0.0, pinned to
revision `904ae935269eef5ec6a1415b64463c3d02eff1eb`. The headless terminal owns
VT parsing, normal and alternate buffers, Unicode width, selection, modes,
markers, decorations, links, write ordering, and addon lifecycles. Flutter is
an adapter over that engine and uses the delta text-input protocol for IME.

```dart
final terminal = Terminal();
terminal.onData.listen(process.write);
terminal.onResize.listen(
  (event) => process.resize(event.cols, event.rows),
);

TerminalView(
  terminal: terminal,
  controller: TerminalViewController(),
  autofocus: true,
);

terminal.write(processOutput);
```

Import `package:termworld/termworld_headless.dart` in command-line and server
programs. It does not import Flutter UI. Flutter applications normally import
`package:termworld/termworld.dart`.

## Input methods

`TerminalView` is a `DeltaTextInputClient`. Preedit text stays local until the
platform marks a grapheme committed. Candidate replacement, cancellation,
reconversion, focus loss, Hangul, Kana, CJK input, dead keys, combining marks,
and emoji are reconciled by grapheme rather than UTF-16 offset. A committed
grapheme is emitted to `onData` exactly once.

## Addons

Each official addon has an independent entrypoint:

- `addon_attach.dart`, `addon_clipboard.dart`, `addon_fit.dart`
- `addon_image.dart`, `addon_ligatures.dart`, `addon_progress.dart`
- `addon_search.dart`, `addon_serialize.dart`
- `addon_unicode_graphemes.dart`, `addon_unicode11.dart`
- `addon_web_fonts.dart`, `addon_web_links.dart`, `addon_webgl.dart`

Load an addon with `terminal.loadAddon(addon)`. Browser font and WebGL addons
report their capability and throw `UnsupportedError` when activated outside
web. Other addons have the same Dart contract on Android, iOS, Linux, macOS,
Windows, and web.

## Reference and verification

`xterm_parity.yaml` maps the public API, implementation, tests, platform
adaptations, and all addons. `tool/xterm_reference.json` records the pinned
upstream declarations, test names, fixture hashes, and source blob hashes.
The vendored VT fixtures are MIT-licensed xterm.js test data from that revision;
CI never needs a local xterm checkout or network access.

Run the package checks from the repository root:

```console
flutter test packages/termworld
dart run tool/verify_xterm_parity.dart
dart run tool/verify_platform_matrix.dart
```

The example contains the shared six-platform conformance test. Linux CI also
runs an actual IBus Hangul session under X11.

## Migration from 0.2.x

0.3.0 is intentionally breaking. Replace `TerminalEmulator` with `Terminal`,
subscribe to `onData`/`onResize`, and pass the engine using
`TerminalView(terminal: terminal)`. The old model and widget wrappers were
removed; there is no compatibility layer.
