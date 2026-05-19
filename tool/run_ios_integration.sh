#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root/example"

timeout_cmd() {
  local seconds="$1"
  shift
  perl -e 'alarm shift @ARGV; exec @ARGV' "$seconds" "$@"
}

flutter pub get
flutter create --platforms=ios --project-name flutter_image_clip_example .

device_id="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')"
if [ -z "$device_id" ]; then
  echo "No available iPhone simulator found."
  exit 1
fi

boot_device() {
  xcrun simctl boot "$device_id" || true
  timeout_cmd 180 xcrun simctl bootstatus "$device_id" -b
}

run_integration_test() {
  timeout_cmd 900 flutter test integration_test -d "$device_id"
}

boot_device

if ! run_integration_test; then
  echo "iOS integration test did not start cleanly; restarting simulator and retrying once."
  xcrun simctl shutdown "$device_id" || true
  boot_device
  run_integration_test
fi
