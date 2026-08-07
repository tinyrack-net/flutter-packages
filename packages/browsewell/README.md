# browsewell

`browsewell` embeds the operating system webview on Flutter desktop and exposes
one automation contract on Windows, macOS, and Linux. It uses WebView2,
WKWebView, and WebKitGTK 4.1 respectively.

Consumers provide an explicit profile directory and URL policy. The package
does not discover product settings, workspace paths, or user home directories.

```dart
final browser = await BrowsewellController.create(
  profile: BrowsewellProfile(directory: profileDirectory),
  initialUrl: Uri.parse('https://example.com'),
);

BrowsewellView(controller: browser);

final snapshot = await browser.snapshot();
await browser.click(snapshot.document.children.first.ref!);
```

The controller supports navigation, snapshots with generation-scoped refs,
PNG capture, console logs, waits, trusted pointer and keyboard input, selection,
dragging, uploads, scrolling, and bounded JavaScript evaluation. A consumer is
responsible for validating profile and upload paths before passing them in.

## Verification

The example's single `integration_test/conformance_test.dart` runs unchanged on
all three desktop operating systems against a loopback-only HTML fixture. CI
also builds every example in Release mode and runs native-language tests.

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
