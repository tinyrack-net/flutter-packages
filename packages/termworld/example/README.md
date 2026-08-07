# termworld example

Runs the terminal on every supported Flutter platform for manual IME checks and
the shared platform conformance suite.

`tool/run_linux_ibus_e2e.sh` starts the Linux-only real IBus Hangul suite. It
expects an X11 display, D-Bus session, `ibus-hangul`, `xdotool`, `xclip`, and
`scrot`; CI provisions these in the required `Linux IBus Hangul E2E` job.
