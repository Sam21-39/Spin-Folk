# Spinfolk

Offline, single-phone Truth-or-Dare for iPhone. One bottle, 2–60 players, no accounts, no network.

Status: version 0.1.0 (1). Simulator gate run 2026-11-22; see Known limits. Not yet run on a real device or uploaded to TestFlight; both need an Apple team ID.

## Gameplay

- Pick 2–60 players on the wheel; names are optional.
- Spin. The bottle's **neck** points at the **taker** (teal). The **base** points at the **giver** (coral), who sets the challenge.
- The taker chooses Truth or Dare, or anyone passes. Then Next Round.
- The result is announced aloud (voice and speed in the session sheet) and shown on the Lock Screen and Dynamic Island.
- A game survives closing the app. Ended games are kept in History on the phone.

**Odd player counts.** Nobody sits exactly opposite the taker, so the giver is picked at random from the two nearest-opposite seats. The bottle stays straight; a dotted arc shows which seat was chosen.

## Setup

Requires macOS with Xcode 27.2, and [FVM](https://fvm.app).

```sh
fvm install                                   # Flutter 3.50.1 / Dart 3.14, from .fvmrc
fvm flutter config --enable-swift-package-manager
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # regenerates lib/core/di/injection.config.dart
```

Package versions are pinned exactly in `pubspec.yaml`; `pubspec.lock` is committed. iOS dependencies come through Swift Package Manager only (no CocoaPods).

## Run and test

```sh
fvm flutter run                               # on a booted iOS simulator
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
tool/check_rules.sh                           # architecture rules
tool/final_gate.sh                            # full simulator pass (Maestro); see the script header
# needs Maestro at ~/.maestro/bin (or set MAESTRO); set SIM, SE, SIM18 to your simulator UDIDs (iOS 26 Dynamic Island iPhone, SE-size iOS 26, iOS 18)
swift tool/make_icon.swift ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

## Architecture

Lean Clean Architecture, feature-first. Full detail: [docs/spec-v2.md](docs/spec-v2.md).

```
lib/app/         router (go_router, redirect-driven), navigator, tokens, shared UI
lib/core/        dependency injection (get_it + injectable), failures
lib/features/    session · setup · game · settings · history · home
                 each: domain (pure Dart) / data (sqflite, shared_preferences) / presentation (bloc, cubit, pages)
lib/platform/    MethodChannel bridge, speech announcer, Live Activity sync, native glass views
ios/Runner/Native/     SwiftUI glass picker and action bar, AVSpeechSynthesizer, ActivityKit bridge
ios/SpinfolkWidget/    Live Activity and Dynamic Island
```

State is flutter_bloc only: no `setState`, no `BuildContext` below the widgets. The outcome of a spin is saved before the animation starts, so it can never be re-rolled.

## iOS and signing

- iOS 17.0 or later. Liquid Glass on iOS 26+, system material on 17–25.
- Bundle IDs: `in.appamania.spinfolk` and `in.appamania.spinfolk.SpinfolkWidget`.
- iPhone only (`TARGETED_DEVICE_FAMILY = 1`); export compliance declared (`ITSAppUsesNonExemptEncryption = false`).
- The repo contains no team ID, certificate or profile, and must not. Simulator builds need none. For a device build pass your team on the command line: `FLUTTER_XCODE_DEVELOPMENT_TEAM=<team id> fvm flutter build ios --release`.
- No microphone permission, no background modes, no App Group.

## Known limits

- iPhone, portrait, dark appearance, English only.
- The Live Activity updates only while the app is running and lasts at most 8 hours.
- Announcements use the voices installed on the phone; without one the roles are shown but not spoken.
- Not yet checked on hardware: audio ducking and the mute switch, haptics, frame pacing, VoiceOver.
- History Undo restore is verified only by widget tests and manually (Maestro cannot tap it within the 5 s window).
- VoiceOver, sheet detents, Dynamic Island expanded and the Live Activities-off text are manual checks.
- Real-device audio, haptics and Live Activity need a team ID.
- The app does not write challenges. The group does.
