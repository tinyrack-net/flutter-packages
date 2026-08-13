#!/usr/bin/env bash

set -uo pipefail

if [[ "$#" -ne 1 || -z "${1:-}" ]]; then
  echo "usage: $0 <adb-serial>" >&2
  exit 64
fi

device="$1"
script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
example_directory="$repository_root/packages/termworld/example"
diagnostic_parent="${RUNNER_TEMP:-$repository_root/build}"
diagnostics="$diagnostic_parent/termworld-android-input"
test_log="$diagnostics/test-output.log"

mkdir -p "$diagnostics" || exit 1
: > "$test_log" || exit 1

(
  cd "$example_directory" &&
    flutter test integration_test/conformance_test.dart -d "$device"
) 2>&1 | tee -a "$test_log"
status=${PIPESTATUS[0]}

if [[ "$status" -eq 0 ]]; then
  (
    cd "$repository_root" &&
      dart run tool/run_android_input_connection_e2e.dart --device "$device"
  ) 2>&1 | tee -a "$test_log"
  status=${PIPESTATUS[0]}
fi

if [[ "$status" -ne 0 ]]; then
  adb -s "$device" logcat -d -v threadtime \
    > "$diagnostics/logcat.txt" 2>&1 || true
  adb -s "$device" shell dumpsys input_method \
    > "$diagnostics/input-method.txt" 2>&1 || true
  grep 'TERMWORLD_ANDROID_FIXTURE=' "$test_log" \
    | tail -1 > "$diagnostics/fixture-name.txt" || true
  if [[ ! -s "$diagnostics/fixture-name.txt" ]]; then
    echo 'TERMWORLD_ANDROID_FIXTURE=shared-conformance-or-startup' \
      > "$diagnostics/fixture-name.txt"
  fi
fi

exit "$status"
