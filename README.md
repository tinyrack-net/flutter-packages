# Tinyrack Flutter packages

Reusable Flutter packages maintained by Tinyrack.

| Package | Description |
| --- | --- |
| [`dropwell`](packages/dropwell) | Native file drag-and-drop and clipboard file reading for Flutter on Windows, macOS, Linux, Web, Android, and iOS. |

These packages are **not published to pub.dev**. Consumers depend on them from
this public repository pinned to an exact 40-character commit SHA:

```yaml
dependencies:
  dropwell:
    git:
      url: https://github.com/tinyrack-net/flutter-packages.git
      ref: <40-character commit SHA>
      path: packages/dropwell
```

## Development

Install the workspace dependencies from the repository root:

```console
flutter pub get
```

Then validate the package you changed:

```console
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test packages/dropwell
dart run tool/verify_coverage.dart dropwell
dart run tool/verify_platform_matrix.dart
```

Every package must keep behavior identical on every platform it declares. See
[`AGENTS.md`](AGENTS.md) for the full five-layer verification contract and the
CI matrix that enforces it.
