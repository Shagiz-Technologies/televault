#!/usr/bin/env bash

set -euo pipefail

app="${1:?Usage: smoke_test_ios_simulator.sh <Runner.app> <bundle-id>}"
bundle_id="${2:?Usage: smoke_test_ios_simulator.sh <Runner.app> <bundle-id>}"

device_id="${IOS_SIMULATOR_UDID:-}"
if [[ -z "$device_id" ]]; then
  device_id="$(
    xcrun simctl list devices available |
      /usr/bin/awk -F '[()]' '/iPhone/ && /(Shutdown|Booted)/ { print $2; exit }'
  )"
fi

if [[ -z "$device_id" ]]; then
  echo 'No available iPhone simulator was found.' >&2
  xcrun simctl list devices available >&2
  exit 1
fi

cleanup() {
  if [[ -n "${console_pid:-}" ]]; then
    /bin/kill "$console_pid" >/dev/null 2>&1 || true
  fi
  xcrun simctl terminate "$device_id" "$bundle_id" >/dev/null 2>&1 || true
  rm -f "${console_log:-}"
}
trap cleanup EXIT

xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl uninstall "$device_id" "$bundle_id" >/dev/null 2>&1 || true
xcrun simctl install "$device_id" "$app"

console_log="$(mktemp)"
xcrun simctl launch --console "$device_id" "$bundle_id" > "$console_log" 2>&1 &
console_pid=$!

sleep 12
if ! /bin/kill -0 "$console_pid" >/dev/null 2>&1; then
  echo 'TeleVault exited during the simulator launch smoke test.' >&2
  /bin/cat "$console_log" >&2
  exit 1
fi

data_container="$(xcrun simctl get_app_container "$device_id" "$bundle_id" data)"
ready_marker="$(
  /usr/bin/find "$data_container" \
    -type f \
    -name televault_tdlib_ready \
    -print \
    -quit
)"

if [[ -z "$ready_marker" ]]; then
  echo 'TeleVault launched, but TDLib did not initialize successfully.' >&2
  /bin/cat "$console_log" >&2
  exit 1
fi

echo "TeleVault remained alive and initialized TDLib on simulator $device_id."
