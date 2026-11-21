# Spinfolk

An offline, single-phone Truth-or-Dare party game for iPhone, planned with Flutter and native iOS glass controls.

## Status

Planning and implementation handoff are complete. The app has not been implemented or uploaded to TestFlight yet.

## Gameplay

- 2–60 numbered players, with optional names.
- A clockwise bottle spin selects the taker.
- The opposite player gives the challenge; for odd counts, choose randomly between the two nearest opposite seats.
- Spoken results, Truth/Dare selection, Pass, and Next Round.
- Local session resume and voice preferences.

## Planned stack

Flutter, GetX for state/routing/dependency injection, GetStorage, native iOS controls and speech, and ActivityKit with a SwiftUI Live Activity extension.

## Implementation brief

Read [the complete phased Claude handoff](CLAUDE_HANDOFF.md) for requirements, native integration, animation rules, tests, milestones, and TestFlight prerequisites.

Native glass is a core requirement. Live Activities follow the playable core. The one-to-two-hour target depends on tooling and signing; Apple processing time is separate.
