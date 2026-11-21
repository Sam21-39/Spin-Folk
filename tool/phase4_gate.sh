#!/usr/bin/env bash
# DEFERRED: run in the post-Phase-5 device pass. Not executed in Phase 4.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIM:?set SIM to a booted simulator UDID (a Dynamic Island model)}"
APP=in.appamania.spinfolk
EVID=docs/plans/phase-4/evidence; mkdir -p "$EVID"      # git-ignored
fvm flutter build ios --simulator --debug
xcrun simctl uninstall "$SIM" "$APP" || true
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
~/.maestro/bin/maestro --device "$SIM" test tool/maestro/phase4.yaml
DB=$(find "$(xcrun simctl get_app_container "$SIM" "$APP" data)" -name spinfolk.db | head -1)
ID=$(sqlite3 "$DB" 'SELECT id FROM session;')            # re-check the table name against schema v2
# P4-D4 warm: app is in the background after the flow.
xcrun simctl openurl "$SIM" "spinfolk://session/$ID"; sleep 2
xcrun simctl io "$SIM" screenshot "$EVID/p4-link-warm.png"        # game screen, same round
# P4-D4 cold.
xcrun simctl terminate "$SIM" "$APP"
xcrun simctl openurl "$SIM" "spinfolk://session/$ID"; sleep 4
xcrun simctl io "$SIM" screenshot "$EVID/p4-link-cold.png"        # game screen, not Home
# Foreign id must be ignored.
xcrun simctl openurl "$SIM" "spinfolk://session/00000000000000000000000000000000"; sleep 2
xcrun simctl io "$SIM" screenshot "$EVID/p4-link-foreign.png"     # unchanged
