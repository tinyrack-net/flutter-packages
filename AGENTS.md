# Tinyrack Flutter packages

This repository is a Flutter/Dart pub workspace containing reusable packages
consumed by Tinyrack products from pinned commit SHAs.

## Boundaries

- `packages/dropwell` is a general-purpose native file drag-and-drop and
  clipboard-file plugin. It knows nothing about any product's models, upload
  policy, size limits, or presentation.
- Keep product-specific types and behavior out of every package. A consumer that
  needs a 50 MB cap or a MIME allow-list implements that in its own adapter.
- Treat each package's public API, README, and package metadata as user-facing.
- Import only public `package:<name>/<library>.dart` entrypoints across package
  boundaries. Never reach into another package's `lib/src/`.

## Platform-behavior contract

A package that declares a platform in `flutter.plugin.platforms` promises the
**same observable Dart behavior** on that platform. A Dart mock passing is not
evidence that a platform works. Every declared platform must have all five
verification layers, and `dart run tool/verify_platform_matrix.dart` fails the
build when one is missing.

| Layer | What it covers | Where it runs |
| --- | --- | --- |
| L1 Dart unit | Pure functions: channel codec, hit testing, coordinate conversion, MIME inference | Every runner |
| L2 Dart widget | Widget contracts driven through a mock binary messenger | Every runner |
| L3 native unit | Platform source in its own language: format parsing, type priority, marshalling | That OS, no Flutter |
| L4 conformance | **One** Dart test body executed on every platform against real OS APIs | That OS, real app process |
| L5 build | The example app builds for release | That platform |

### L4 is one file, not one file per platform

`packages/dropwell/example/integration_test/conformance_test.dart` runs
unchanged on all six surfaces. Branching is allowed only on a **declared
capability** such as `DropwellPlatform.instance.supportsDrop` — never on
`Platform.isX` or `kIsWeb`. Per-platform test bodies let platforms drift apart
while every job stays green, which is exactly the failure this contract exists
to prevent.

### Test hooks are Debug-only

L4 injects state through a `dropwell/testing` channel that is registered only in
Debug builds (`#ifndef NDEBUG`, `#if DEBUG`, `BuildConfig.DEBUG`, `kDebugMode`).
Release binaries must not contain the hook; CI asserts this.

Drag sessions are synthesized by calling each OS's drop entry point directly
(`IDropTarget::Drop`, `performDragOperation`, `drag-data-received`, a dispatched
`DragEvent`). Do not automate a real mouse: it is slow, needs a session, and
flakes on headless runners.

## Validation

From the repository root:

```console
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test packages/dropwell
dart run tool/verify_coverage.dart dropwell
dart run tool/verify_platform_matrix.dart
```

For the platform you can run locally, also:

```console
cd packages/dropwell/example
flutter test integration_test -d <device>
flutter build <platform>
```

## Gates

- Each package independently reaches **90% line and 80% branch** Dart coverage.
  Missing production files count as 0%; only generated sources and `_web.dart`
  entry points are excluded. A web entry point transitively imports
  `dart:ui_web` and can only load in a browser, where `flutter test --coverage`
  measures nothing; it is covered instead by its mandatory browser-only L3
  suite, whose existence `tool/verify_platform_matrix.dart` enforces.
- The example app is **not** a pub workspace member. Flutter writes a workspace
  member's `native_assets/` under the workspace root while the generated CMake
  install rule looks for it under the app's own `build/`, so a member example
  cannot build on Windows. Run `flutter pub get` inside the example separately.
- `flutter analyze --fatal-infos` reports zero diagnostics under
  `very_good_analysis` with strict casts, inference, and raw types.
- No broad lint ignores, coverage ignores, or skipped tests to make a gate pass.
  A necessary line-level ignore carries a comment with its reason and safety
  argument.
- Test order is randomized. Preserve the printed seed when reproducing a
  failure.
- No CI job uses a real API key, a paid request, a user home directory, or an
  internet-dependent call. Fixtures are files committed to this repository.
- Every CI job is a required status check. `continue-on-error` is not used.
