# termworld

`termworld` 0.5.0 is an independent Flutter and pure-Dart port of xterm.js
6.0.0, pinned to revision `904ae935269eef5ec6a1415b64463c3d02eff1eb`.
It does not depend on, export, wrap, or delegate to `xterm.dart`. The headless terminal owns
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

Version 0.5.0 requires Flutter 3.47 or newer and Dart 3.13 or newer. Its public
renderer types continue to come from Flutter's core widget and painting APIs;
applications can choose the standalone `material_ui` or another design system.

## Migration to 0.5.0

Upgrade the consuming application to Flutter 3.47 and Dart 3.13. No termworld
Dart API changes are required. Applications adopting Flutter's standalone
Material library should import `package:material_ui/material_ui.dart` instead
of the legacy `package:flutter/material.dart` entrypoint.

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

On web, `WebglAddon` replaces the Flutter cell painter with a WebGL2 canvas,
uploads terminal frames through a GPU texture, maintains the xterm-compatible
multi-page glyph-atlas model, and rebuilds GPU resources after context restore.
While the context is lost, `TerminalView` immediately falls back to its default
renderer. CI exercises this lifecycle in Chromium, Firefox, and WebKit.

## Reference and verification

`xterm_parity.yaml` maps the public API, implementation, tests, platform
adaptations, and all addons. `tool/xterm_reference.json` records the pinned
upstream declarations, test names, fixture hashes, and source blob hashes.
The vendored VT fixtures are MIT-licensed xterm.js test data from that revision.
Parity verification and behavior tests never access a local xterm checkout or
fetch upstream fixtures at runtime.

Run the package checks from the repository root:

```console
flutter analyze --fatal-infos
dart run tool/verify_xterm_parity.dart
dart run tool/verify_termworld_dependencies.dart
dart run tool/verify_platform_matrix.dart
cd packages/termworld/example && flutter build web --release
```

Local verification is compile-only. The example contains the shared
six-platform conformance test, which runs only in CI. Linux CI also runs an
actual IBus Hangul session under X11, and the browser matrix executes the real
WebGL2 renderer in Chromium, Firefox, and WebKit.

## Migration to 0.4.0

0.4.0 removes the former xterm.dart-backed 0.3 implementation and is
intentionally breaking. Replace `TerminalEmulator` with `Terminal`,
subscribe to `onData`/`onResize`, and pass the engine using
`TerminalView(terminal: terminal)`. The old model, delegated terminal, and
widget wrappers were removed; there is no compatibility layer.
