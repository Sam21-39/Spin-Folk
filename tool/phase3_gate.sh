#!/usr/bin/env bash
# DEFERRED: run in the post-Phase-5 device pass. Not executed in Phase 3.
# Kill / restore / corrupt-row checks on a booted simulator.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIM:?set SIM to a booted simulator UDID}"
APP=in.appamania.spinfolk
mkdir -p docs/plans/phase-3/evidence # git-ignored
fvm flutter build ios --simulator --debug
xcrun simctl uninstall "$SIM" "$APP" || true
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
~/.maestro/bin/maestro --device "$SIM" test tool/maestro/phase3.yaml
# P3-D5: SQL-legal corruption of the active session (player table, schema v2).
xcrun simctl terminate "$SIM" "$APP" || true
DB=$(find "$(xcrun simctl get_app_container "$SIM" "$APP" data)" -name spinfolk.db | head -1)
sqlite3 "$DB" 'DELETE FROM player WHERE seat = 1;'
xcrun simctl launch "$SIM" "$APP"
sleep 3
xcrun simctl io "$SIM" screenshot docs/plans/phase-3/evidence/p3-corrupt.png # expect the "Couldn't restore the last game" notice
