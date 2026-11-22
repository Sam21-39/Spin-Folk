#!/usr/bin/env bash
# Phase 2 simulator gate: fresh install + full Maestro loop per player count.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIM:?set SIM to a booted simulator UDID}"
APP=in.appamania.spinfolk
mkdir -p docs/plans/phase-2/evidence
for n in ${COUNTS:-2 3 5 7 59 60}; do
  fvm flutter build ios --simulator --debug --dart-define=SPINFOLK_INITIAL_COUNT="$n"
  xcrun simctl uninstall "$SIM" "$APP" || true
  xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
  ~/.maestro/bin/maestro --device "$SIM" test -e N="$n" tool/maestro/loop.yaml
done
