# termworld example

Runs the terminal on every supported Flutter platform for manual IME checks and
the shared platform conformance suite.

`tool/run_linux_ibus_e2e.sh` starts the Linux-only real IBus Hangul suite. It
expects an X11 display, D-Bus session, `ibus-hangul`, `xdotool`, `xclip`, and
`scrot`; CI provisions these in the required `Linux IBus Hangul E2E` job.

`tool/run_linux_ibus_wayland_e2e.sh` starts the native Wayland sibling under a
headless Sway compositor. It compiles the repository's `wlkey` helper to send
physical-layout-compatible keycodes through `virtual-keyboard-v1`; CI provisions
the Wayland, IBus, and compiler dependencies in the required
`Linux IBus Wayland E2E` job.

For Android, `tool/run_android_input_connection_e2e.dart` builds the example's
Debug APK and the separate `:ime_harness` APK. The runner temporarily selects
`com.example.termworld_ime_harness/.TermworldTestInputMethodService`, while the
Debug activity relays fixture commands through `sendAppPrivateCommand`. The IME
then applies those commands to its system-owned `currentInputConnection` and
returns status through a platform `Messenger`/`Message` reply, which remains
parcelable across the two APK processes. The runner restores and verifies the
emulator's original enabled and selected IME state after the suite.
`tool/run_android_termworld_input_ci.sh` runs the shared closed-loop conformance
test and this native boundary on API 24 and 35.
