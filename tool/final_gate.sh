#!/usr/bin/env bash
# Final device pass: every simulator check deferred from Phases 1-4, in one run.
#   tool/final_gate.sh [stage ...]        no arguments = all stages, in order
# Stages: static release loop edit history lifecycle activity se motion ios18
# Logs and screenshots: docs/plans/phase-5/evidence/ (git-ignored).
# A failing stage does not stop the run; the exit code is 1 if any stage failed.
set -uo pipefail
cd "$(dirname "$0")/.."

SIM="${SIM:-2938F81B-D7F8-4DFD-81D8-968C25C04F1F}"     # iPhone 17 Pro, iOS 26.5 (Dynamic Island)
SE="${SE:-584BBD07-5D8E-4995-A740-1155986A238E}"       # "Spinfolk SE3", iOS 26.5
SIM18="${SIM18:-66C64697-4A19-4C8F-85FE-3FEE1469323D}" # iPhone 16e, iOS 18.6 (glass fallback)
APP=in.appamania.spinfolk
EVID=docs/plans/phase-5/evidence
BUILT=build/ios/iphonesimulator/Runner.app
MAESTRO="${MAESTRO:-$HOME/.maestro/bin/maestro}"
mkdir -p "$EVID"

boot()    { xcrun simctl boot "$1" 2>/dev/null || true; xcrun simctl bootstatus "$1" -b >/dev/null; }
build()   { fvm flutter build ios --simulator --debug "$@"; }
install() { xcrun simctl uninstall "$1" "$APP" 2>/dev/null || true; xcrun simctl install "$1" "$BUILT"; }
# Maestro 2.11 only writes screenshots under its own output dir; copy them into $EVID.
flow()    { local dev=$1 d rc=0; d=$(mktemp -d); shift; "$MAESTRO" --device "$dev" test --test-output-dir "$d" "$@" || rc=$?
            find "$d" -path '*/takeScreenshot/*' -name '*.png' -exec cp {} "$EVID/" \; ; rm -rf "$d"; return $rc; }
shot()    { xcrun simctl io "$1" screenshot "$EVID/$2.png" >/dev/null; }
data()    { xcrun simctl get_app_container "$1" "$APP" data; }
db()      { find "$(data "$1")" -name spinfolk.db | head -1; }
a11y()    { xcrun simctl spawn "$1" defaults write com.apple.Accessibility "$2" -bool "$3"; }
eq()      { [ "$2" = "$3" ] || { echo "FAIL $1: got '$2', want '$3'"; exit 1; }; echo "ok   $1 = $2"; }

stage_static() {                                   # P1-9, P5-1
  fvm dart run build_runner build --delete-conflicting-outputs
  git diff --exit-code lib/core/di/injection.config.dart
  fvm dart format --set-exit-if-changed .
  fvm flutter analyze
  fvm flutter test
  tool/check_rules.sh
}

stage_release() {                                  # P5-2
  fvm flutter build ios --release --no-codesign
  local a=build/ios/iphoneos/Runner.app x=build/ios/iphoneos/Runner.app/PlugIns/SpinfolkWidget.appex b
  pb() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Info.plist"; }
  eq 'app id' "$(pb $a CFBundleIdentifier)" "$APP"
  eq 'widget id' "$(pb $x CFBundleIdentifier)" "$APP.SpinfolkWidget"
  for b in $a $x; do
    eq "version $b" "$(pb $b CFBundleShortVersionString)" 0.1.0
    eq "build $b" "$(pb $b CFBundleVersion)" 1
    eq "min os $b" "$(pb $b MinimumOSVersion)" 17.0
  done
  eq 'live activities' "$(pb $a NSSupportsLiveActivities)" true
  eq 'url scheme' "$(pb $a CFBundleURLTypes:0:CFBundleURLSchemes:0)" spinfolk
  eq 'deep linking' "$(pb $a FlutterDeepLinkingEnabled)" false
  eq 'extension point' "$(pb $x NSExtension:NSExtensionPointIdentifier)" com.apple.widgetkit-extension
  eq 'icon name' "$(pb $a CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName)" AppIcon
  eq 'forbidden keys' "$(plutil -p $a/Info.plist | grep -cE 'UIBackgroundModes|UsageDescription')" 0
  eq 'encryption key' "$(pb $a ITSAppUsesNonExemptEncryption)" false
  eq 'device family' "$(plutil -extract UIDeviceFamily json -o - $a/Info.plist)" '[1]'
  [ -f $a/Assets.car ] || { echo 'FAIL Assets.car missing'; exit 1; }
  eq 'team ids' "$(codesign -dv $a 2>&1 | grep 'TeamIdentifier=' | grep -vc 'not set')" 0
}

stage_loop() {                                     # P2-12 P2-13 P2-17 P1-2 P1-3 P1-8 P2b-S1 P2b-S5
  boot "$SIM"
  local n
  for n in ${COUNTS:-2 3 5 7 59 60}; do
    build --dart-define=SPINFOLK_INITIAL_COUNT="$n"
    install "$SIM"
    flow "$SIM" -e N="$n" -e TAG=loop tool/maestro/loop.yaml
  done
}

stage_edit() {                                     # P2-16 P1-1
  boot "$SIM"; build; install "$SIM"
  flow "$SIM" tool/maestro/edit.yaml
}

stage_history() {                                  # P2b-S5 P2b-S1 (Undo toast look)
  boot "$SIM"; build; install "$SIM"
  flow "$SIM" tool/maestro/history.yaml
}

stage_lifecycle() {                                # P3-D1 D2 D3 D4 D5 D7
  boot "$SIM"; build; install "$SIM"
  flow "$SIM" tool/maestro/phase3.yaml             # ends with an active session, Announcements off
  xcrun simctl terminate "$SIM" "$APP" || true
  sqlite3 "$(db "$SIM")" 'DELETE FROM player WHERE seat = 1;'      # P3-D5: SQL-legal corruption
  xcrun simctl launch "$SIM" "$APP"; sleep 4
  shot "$SIM" p3-corrupt                           # expect "Couldn't restore the last game" on Home
  flow "$SIM" -e N=8 -e TAG=d4 tool/maestro/loop.yaml              # plays and ends one session
  xcrun simctl terminate "$SIM" "$APP" || true
  eq 'active session rows' "$(sqlite3 "$(db "$SIM")" 'SELECT count(*) FROM session;')" 0      # P3-D4
  eq 'archived games' "$(sqlite3 "$(db "$SIM")" 'SELECT count(*) FROM game;')" 1
  plutil -p "$(data "$SIM")/Library/Preferences/$APP.plist" \
    | grep -E '"(flutter\.)?announce" => (0|false)' \
    || { echo 'FAIL announce pref not kept as off'; exit 1; }                                 # P3-D1 + D4
}

stage_activity() {                                 # P4-D1 ... D6
  boot "$SIM"; build; install "$SIM"
  flow "$SIM" tool/maestro/phase4.yaml             # leaves the app in the background, round 2
  local id; id=$(sqlite3 "$(db "$SIM")" 'SELECT id FROM session;')
  [ -n "$id" ] || { echo 'FAIL no active session id'; exit 1; }
  xcrun simctl openurl "$SIM" "spinfolk://session/$id"; sleep 2; flow "$SIM" tool/maestro/open_confirm.yaml; sleep 2; shot "$SIM" p4-link-warm      # game, round 2
  xcrun simctl terminate "$SIM" "$APP" || true
  xcrun simctl openurl "$SIM" "spinfolk://session/$id"; sleep 3; flow "$SIM" tool/maestro/open_confirm.yaml; sleep 3; shot "$SIM" p4-link-cold      # game, not Home
  xcrun simctl openurl "$SIM" "spinfolk://session/00000000000000000000000000000000"; sleep 2; flow "$SIM" tool/maestro/open_confirm.yaml; sleep 2
  shot "$SIM" p4-link-foreign                      # unchanged
  flow "$SIM" tool/maestro/phase4_end.yaml
}

stage_se() {                                       # P2-14 P2-17
  boot "$SE"
  trap 'xcrun simctl ui "$SE" content_size large' EXIT
  build --dart-define=SPINFOLK_INITIAL_COUNT=2
  local size
  for size in large extra-extra-extra-large accessibility-extra-extra-extra-large; do
    xcrun simctl ui "$SE" content_size "$size"
    install "$SE"
    flow "$SE" -e TAG="$size" -e TYPE=yes tool/maestro/screens.yaml
  done
}

stage_motion() {                                   # P1-6 P2-15
  boot "$SIM"; build; install "$SIM"
  trap 'a11y "$SIM" ReduceMotionEnabled NO; a11y "$SIM" EnhancedBackgroundContrastEnabled NO' EXIT
  a11y "$SIM" ReduceMotionEnabled YES
  a11y "$SIM" EnhancedBackgroundContrastEnabled YES          # Reduce Transparency
  flow "$SIM" tool/maestro/reduced.yaml
}

stage_ios18() {                                    # P1-7 P2b-S1 (fallback material)
  boot "$SIM18"; build; install "$SIM18"
  flow "$SIM18" -e N=8 -e TAG=ios18 tool/maestro/loop.yaml
  xcrun simctl shutdown "$SIM18"
}

[ $# -eq 0 ] && set -- static release loop edit history lifecycle activity se motion ios18
failed=0; table=''
for s in "$@"; do
  declare -f "stage_$s" >/dev/null || { echo "unknown stage: $s"; exit 2; }
  echo "=== $s"
  ( set -e; "stage_$s" ) 2>&1 | tee "$EVID/$s.log"
  if [ "${PIPESTATUS[0]}" -eq 0 ]; then table="$table\nPASS  $s"; else table="$table\nFAIL  $s"; failed=1; fi
done
printf "$table\n" | tee "$EVID/summary.txt"
exit "$failed"
