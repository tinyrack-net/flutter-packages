#!/usr/bin/env bash
set -euo pipefail

artifact_dir="${GITHUB_WORKSPACE:-$(pwd)}/ibus-artifacts"
mkdir -p "$artifact_dir"

capture_failure() {
  local status=$?
  if [[ $status -ne 0 ]]; then
    ibus engine >"$artifact_dir/engine.txt" 2>&1 || true
    gsettings list-recursively org.freedesktop.ibus.engine.hangul \
      >"$artifact_dir/config.txt" 2>&1 || true
    xwininfo -root -tree >"$artifact_dir/windows.txt" 2>&1 || true
    scrot "$artifact_dir/failure.png" || true
  fi
  exit "$status"
}
trap capture_failure EXIT

gsettings set org.freedesktop.ibus.engine.hangul hangul-keyboard '2'
gsettings set org.freedesktop.ibus.engine.hangul initial-input-mode 'hangul'
gsettings set org.freedesktop.ibus.engine.hangul preedit-mode 'syllable'
gsettings set org.freedesktop.ibus.engine.hangul word-commit false
gsettings set org.freedesktop.ibus.engine.hangul switch-keys 'Shift+space'

ibus-daemon --daemonize --xim
for _ in 1 2 3 4 5; do
  if ibus list-engine | grep -q 'hangul - Hangul'; then
    break
  fi
  sleep 1
done
ibus engine hangul
[[ $(ibus engine) == hangul ]]

cd packages/termworld/example
mise exec -- flutter pub get
mise exec -- flutter test integration_test/linux_ibus_e2e_test.dart -d linux
