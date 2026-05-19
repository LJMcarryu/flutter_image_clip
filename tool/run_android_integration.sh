#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root/example"

flutter pub get
flutter create --platforms=android --project-name flutter_image_clip_example .
flutter pub get

run_integration_test() {
  timeout 12m flutter test integration_test -d emulator-5554
}

if ! run_integration_test; then
  echo "Android integration test did not start cleanly; restarting ADB and retrying once."
  adb kill-server || true
  adb start-server
  adb wait-for-device
  sleep 5
  run_integration_test
fi
