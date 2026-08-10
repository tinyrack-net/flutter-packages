#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "usage: $0 <reset|diagnose> <simulator-udid>" >&2
  exit 64
}

if [[ $# -ne 2 ]]; then
  usage
fi

operation=$1
simulator_udid=$2

case "$operation" in
  reset | diagnose) ;;
  *) usage ;;
esac

available_devices=$(xcrun simctl list devices available)
if ! grep -Fq "$simulator_udid" <<<"$available_devices"; then
  echo "iOS simulator is not available: $simulator_udid" >&2
  exit 1
fi

reset_simulator() {
  # XCTest can leave the base simulator booted but unable to launch a Flutter
  # app. Erasing it also removes stale permissions and installed test runners.
  #
  # The erase alone cannot reach a wedged host-side simulator stack: Flutter
  # discovers the app's VM service by reading the simulator's unified log,
  # and once that log reader dies ("Error waiting for a debug connection:
  # The log reader failed unexpectedly") every attempt fails no matter how
  # clean the device is. Restart the whole CoreSimulator stack first; simctl
  # respawns the service on the next invocation.
  xcrun simctl shutdown "$simulator_udid" || true
  killall Simulator 2>/dev/null || true
  sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
  xcrun simctl erase "$simulator_udid"
  xcrun simctl boot "$simulator_udid"
  xcrun simctl bootstatus "$simulator_udid" -b
  open -a Simulator
}

diagnose_simulator() {
  # Diagnostics must be best-effort so one unavailable data source does not
  # hide the remaining evidence before the retry resets the simulator.
  set +e

  echo "::group::iOS simulator devices"
  xcrun simctl list devices
  echo "::endgroup::"

  echo "::group::Installed simulator applications"
  xcrun simctl listapps "$simulator_udid"
  echo "::endgroup::"

  echo "::group::Recent Runner and CoreSimulator logs"
  xcrun simctl spawn "$simulator_udid" log show \
    --last 15m \
    --style compact \
    --predicate \
    'process == "Runner" OR process == "launchd_sim" OR subsystem BEGINSWITH "com.apple.CoreSimulator"'
  echo "::endgroup::"

  echo "::group::Related host processes"
  ps -axo pid,ppid,state,etime,command | awk \
    'NR == 1 || /[Ff]lutter|[Xx]codebuild|CoreSimulator|Simulator\.app|\/Runner( |$)/'
  echo "::endgroup::"

  return 0
}

case "$operation" in
  reset)
    reset_simulator
    ;;
  diagnose)
    diagnose_simulator
    ;;
esac
