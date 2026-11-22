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

Flutter 3.50.1 via FVM, flutter_bloc, get_it + injectable, go_router, sqflite, shared_preferences, native SwiftUI glass islands, ActivityKit.

## Implementation brief

Read [the implementation spec](docs/spec-v2.md) (the phased handoff in [CLAUDE_HANDOFF.md](CLAUDE_HANDOFF.md) is partly superseded) for requirements, native integration, animation rules, tests, milestones, and TestFlight prerequisites.

Native glass is a core requirement. Live Activities follow the playable core. The one-to-two-hour target depends on tooling and signing; Apple processing time is separate.
