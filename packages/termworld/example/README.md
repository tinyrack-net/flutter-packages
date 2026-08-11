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
