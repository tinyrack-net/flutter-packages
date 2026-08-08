# ADR 0001: Own the desktop webview engines

- Status: Accepted
- Date: 2026-08-08
- Decision owners: `browsewell` maintainers
- Evidence: draft PR 9, CI runs `31255602185` and `31256102277`

## Context

`browsewell` tested whether the public `webview_all` controller, widget, and
JavaScript-channel APIs could support the complete desktop automation contract
without depending on private Dart libraries, generated private Pigeon channels,
or pub-cache changes. The experiment allowed one correction iteration after the
first Windows 2022, macOS 15 arm64, and Ubuntu 24.04 run.

The conformance suite was split so native input, capture, frames, resizing, and
profile behavior report independently. Every DOM input listener checks
`event.isTrusted`.

## Results

The first run established that Ubuntu could deliver trusted click, text,
keyboard, select, upload, and scroll input, and could host two views sharing the
same logical profile. Linux hover, viewport resize, and cross-origin snapshots
failed. Windows rendered and snapshotted the main document, but the live Flutter
test binding consumed the injected pointer stream as diagnostics. macOS could
build and run its native tests, but its sandbox lacked loopback client access.

The single correction iteration enabled device-pointer propagation in the live
test binding, added the macOS network-client entitlement, added a Linux crossing
event before hover, and made resize readiness bounded. The second fast run then
showed:

| Platform | Passed | Failed |
| --- | --- | --- |
| macOS 15 arm64 | main-frame snapshot, trusted text, keypress, select | trusted click, hover/drag, upload chooser, cross-origin frame, click-dependent multi-view automation |
| Ubuntu 24.04 | native correction did not compile because `GdkEventCrossing` has no public `device` field; the local correction uses `gdk_event_set_device` but was not rerun after the stop condition was met | fast L3 gate |
| Windows 2022 | L3, main-frame snapshot, and trusted click passed after real pointer propagation was enabled | trusted text/keyboard timed out; drag did not complete within ten minutes, so the run was cancelled before upload, scroll, capture, frame, profile, or Release could be decided |

The macOS trusted-click and cross-origin failures alone satisfy the agreed stop
condition. The full distribution matrix and Release gates therefore did not
run.

## Public API boundaries found

`addJavaScriptChannel` installs each backend's generated channel wrapper at
document start and in all frames. It does not expose a common public API for an
arbitrary document-start script. Consequently `browsewell` cannot install its
frame nonce, generation, relay, and `postMessage` bootstrap in cross-origin
children. Main-frame JavaScript evaluation cannot cross the same-origin
boundary. A channel alone is insufficient because child documents have no
package-owned code that can receive snapshot requests.

The wrapper widgets also do not expose stable public handles for their native
WebView2 Composition Controller, WKWebView, or WebKitWebView. Native code can
search the application window hierarchy, but that does not provide a reliable
view identity for simultaneous instances, input focus, file choosers, lifecycle
races, or capture. The macOS result demonstrates that target-local text input
can work while target-local pointer and chooser behavior still fails.

Finally, `webview_all` selects its default platform data store. A Dart-only
logical profile binding can reject a second ID, but it cannot configure or prove
the physical store associated with the first ID, nor can it provide a reliable
two-process persistence test contract.

## Decision

Stop the public-wrapper experiment. Keep PR 9 in draft form as evidence and do
not merge or integrate it into Coder.

Implement `browsewell` with package-owned native engines:

- Windows owns the WebView2 environment, user-data folder, Composition
  Controller, DevTools Protocol input/capture, and document-created scripts.
- macOS owns WKWebView configuration and data store, WKUserScripts for every
  frame, exact NSView event delivery, capture, dialogs, and file-panel delegate.
- Linux owns WebKitWebsiteDataManager, WebKitWebView and user-content manager,
  exact widget-local GDK delivery, snapshots, and chooser callbacks.

The Dart controller continues to own policies, generations, ref validation,
frame-tree merging, result limits, and the process-wide logical profile ID.
Native adapters return typed `busy`, `stale_ref`, `timeout`, `denied`, and
`internal` errors rather than exposing engine objects.

## Consequences

The native implementation is larger, but every critical capability now has an
owned API boundary and an exact native view identity. Coder integration remains
blocked until the replacement passes the fast three-OS matrix, the full desktop
matrix, restart persistence, capture, multiple instances, and Release builds.
