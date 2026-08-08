# xterm.js fixtures

The files in `escape_sequence_files` are copied from xterm.js revision
`904ae935269eef5ec6a1415b64463c3d02eff1eb`. Their SHA-256 hashes are recorded
in `packages/termworld/tool/xterm_reference.json`. They remain available under
the adjacent xterm.js MIT license.

`kitty_keyboard_cases.json` captures every evaluation performed by
`src/common/input/KittyKeyboard.test.ts` at the same revision. It was produced
by instrumenting the pinned implementation in memory while running all 165
upstream tests. Its Git blob hash is verified by the parity gate.
