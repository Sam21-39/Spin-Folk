# Spinfolk — Claude implementation handoff

Build Spinfolk from scratch as a polished, offline, single-phone Truth-or-Dare party game, primarily for iPhone. This document is the product specification and phased implementation brief. The owner is Sumit Pal, GitHub account Sam21-39. The intended public repository is Sam21-39/Spin-Folk; verify whether it exists before configuring a remote. Display name: Spinfolk. Dart package name: spinfolk. Do not invent an Apple team ID, bundle identifier owned by the user, signing credentials, or App Store Connect record.

## Objective and delivery expectations

Aim for a playable beta and TestFlight delivery within one to two hours if the installed tooling, signing and account access permit it. This is a target, not permission to skip correctness, native integration or verification. Report blockers early. Native glass is a core requirement. Live Activities are also requested, implemented after the playable core. A beta without Live Activities must be explicitly described as incomplete against the full scope; do not silently drop them to meet the time target.

The user approved a Flutter/native hybrid: Flutter draws the animated bottle, dial and player markers; actual native iOS controls provide the picker and glass action surfaces. GetX owns state, routing and dependency injection. GetStorage persists the active session and settings. No backend, accounts, cloud sync, advertising, analytics, online multiplayer, score system, challenge generator or challenge library is requested.

## Phase 0 — Inspect and establish a runnable baseline

Read applicable repository instructions. Inspect installed Flutter/FVM, Dart, Xcode, available simulators, signing capabilities and existing files before changing them. Flutter 3.50 is a released stable line according to the official November 11, 2026 release announcement; verify the latest compatible stable patch and pin it with FVM. Do not upgrade global tooling unnecessarily. Check compatibility of GetX/GetStorage with the selected SDK and current standalone Cupertino/Material package structure. Use stable package versions and commit the app lockfile.

Use a valid reverse-domain bundle identifier chosen from the user's existing configuration when authorized; otherwise use an explicitly temporary development identifier and report that TestFlight requires the final one. Add only dependencies needed for the agreed behavior. Prefer Flutter/Apple APIs and existing compatible packages over new infrastructure. Do not build an elaborate generic architecture.

Gate: a baseline Flutter app builds for an available iOS simulator. Report SDK versions and any missing signing/account prerequisites.

## Product flow and rules

### Launch and setup

With no active session, show a minimal New Game screen with an actual native iOS wheel picker for 2–60 players and a Start Session button. Default to numbered players. Optional names live behind Add Names and must not slow the numbered-player flow. Seat order is clockwise; show a short explanation to sit in numbered order around the phone.

The user briefly requested a range beginning at one, but the reviewed plan recommends two because giver and taker must be distinct. Implement 2–60 for playable sessions and state this choice explicitly. Do not add a solo preview unless requested.

With a persisted active session, offer Resume Session or End Session. Never silently replace it. Player count/order changes are only available between rounds through an explicit setup action that clears incompatible current-round selection while retaining a valid active session. Keep that flow simple.

### Game screen

Show a clock-like circular dial, a centered bottle, a large Spin action, a compact session/settings action and a clear role/action panel. At low counts, show names when they fit. At high counts, use compact numbered ticks/markers and large selected-player labels below. Support all counts without overflow. The interface supports 60 players; it cannot make one phone readable to 60 people at once, so do not claim otherwise.

The neck selects the taker; the base indicates the giver. Both roles must be explicit in text, not conveyed only through color. Use teal for the taker and coral for the giver.

### Selection mathematics and invariants

Use zero-based seat indices internally with clockwise seat angles theta(i) = 2*pi*i/N, measured from twelve o'clock. Display indices plus one. Choose taker uniformly in [0,N). For even N, giver = (taker + N/2) mod N. For odd N, choose with equal probability between (taker + floor(N/2)) mod N and (taker + ceil(N/2)) mod N. For N=2 the other player is always giver. Roles must always be distinct and in bounds. Allow repeated results across rounds; do not introduce anti-repeat bias.

For odd N, a straight bottle cannot align exactly with both selected seats. Keep the neck exactly aligned with the taker. Draw a small base arc/connector toward the selected nearest-opposite giver and highlight that giver's marker. Do not bend the bottle or imply an exact geometric opposite exists.

Choose the outcome before animating. Choose five or six full clockwise revolutions, then add the nonnegative clockwise offset to the target orientation. Account for the artwork's initial neck direction. Maintain continuous positive angular travel from the current orientation and normalize only when safe so repeated spins do not reverse or jump. A full-turn result must still animate five/six turns. Use Dart's standard random generator; inject deterministic randomness or expose a pure selection function for tests, without a speculative framework.

### Round lifecycle

States: setup, ready, spinning, revealed, challenge. Keep the selected outcome independent from animation progress. During spin, disable repeat taps and player edits. Animate approximately 4–6 seconds with smooth acceleration/deceleration. Finish exactly on the chosen taker; then pulse selected seats and use a restrained haptic.

After reveal, announce the roles once. The taker chooses Truth or Dare. The giver supplies the question/challenge aloud. Show the selected mode and both roles. Next Round prepares another spin. Pass skips without a penalty. Include a concise reminder that anyone can pass. End Session explicitly ends the game and its Live Activity, clearing session data but retaining preferences.

## Phase 1 — Prove native glass before building the full UI

Verify native iOS view embedding with a real wheel picker and a real native glass button/control area over or alongside the Flutter scene. Cupertino styling alone is not native UI. Use UIKit or hosted SwiftUI as appropriate, Apple public glass APIs on supported OS versions and standard native materials/controls below that availability threshold. Do not substitute a Flutter shader/blur and label it native glass.

Flutter 3.50 direct interop is an available integration option, not a requirement to generate a huge binding surface. Use the simplest supported bridge or existing maintained integration that preserves actual native rendering. Keep native control islands few and stable; do not embed one native view per player marker. Native actions report into GetX, with Flutter game state as the authoritative source. Manage hosting-controller lifetimes, callbacks, accessibility, hit testing, safe areas and disposal correctly.

Gate: picker selection reaches Flutter; Flutter state updates native control enabled state; native glass renders acceptably against the real Flutter background; no blocked touches or obvious animation stutter. Check Reduce Transparency/Reduce Motion behavior. Do not assume embedding automatically guarantees correct glass backdrop sampling. If composition fails, investigate and propose a real native layout adjustment rather than silently faking glass.

## Phase 2 — Build setup, selection and animation

Use a small feature-oriented structure and GetX bindings/routes/controllers. A small app-level session owner can survive route changes; screen-specific controllers should dispose normally. Keep pure selection/angle logic testable outside UI. Flutter's AnimationController owns frame updates; do not rebuild the entire screen through global reactive updates every frame.

Draw the bottle and dial sharply at different sizes using Flutter drawing primitives. Design direction: minimal party atmosphere, deep navy, teal and warm coral, generous spacing, readable typography and real glass controls. Avoid flashing lights and constant confetti. Support small iPhones, long names, text scaling and accessible labels. Reduce Motion should offer a brief/simple reveal without changing the random outcome.

Gate: a complete numbered-player game loop works for 2, 3, 5, 7, 59 and 60 players, including Truth, Dare, Pass, Next Round and End Session.

## Phase 3 — Persistence, speech and lifecycle

Initialize GetStorage before reading. Persist a small versioned, JSON-compatible session record: session ID, start time, player list/order, round number, current phase, selected giver/taker and chosen mode. Persist voice settings separately. Validate restored records, counts and indices; handle missing/corrupt/unsupported data gracefully rather than crashing or exposing nonsense. Await critical writes before treating a session/round as durably saved. Surface meaningful failures. Never put credentials or signing data in GetStorage.

Save a selected spin result before animation so backgrounding/termination does not reroll it. If backgrounded during a spin, retain the outcome and show its completed reveal on resume. Do not depend on Flutter continuing to animate in the background. Do not automatically replay speech on restore; provide Replay. On process restart, restore a valid reveal rather than a half-running animation. Session state must not depend on a live GetX controller continuing to exist.

Use native iOS speech synthesis or a compatible wrapper using it. Announce after the stop: 'Player 1, give a challenge to Player 7.' Use names when present while keeping ambiguous/duplicate names identifiable by player number. Include announcements on/off, available device voices, speed, preview and replay. Handle interrupted speech and voice unavailability with a visual fallback. Do not download cloud voices, add microphone permissions or enable continuous background audio merely to speak results. Verify which selected voices work offline; don't promise that every voice is preinstalled.

Gate: voice and preferences work; session resumes after backgrounding and process restart; ending removes the session and preserves settings. Test interruption during spin and announcement.

## Phase 4 — Local Live Activity and Dynamic Island

Implement ActivityKit with a SwiftUI Widget extension. Start an authorized Live Activity when a session starts while the app is foregrounded, not only after backgrounding. Use static attributes for session identity and compact dynamic content for player count, round, last giver/taker and relevant status. Show a useful Lock Screen layout and compact/minimal/expanded Dynamic Island layouts on supported devices. Tapping returns to the appropriate saved session; validate incoming session references. Keep extension display state derived from app session state; it is not a second database.

Update on completed rounds and session changes. No server/APNs is required for these foreground-driven local updates. Handle disabled authorization, unsupported OS/device and extension errors without preventing gameplay. Reconcile stale or duplicate activities on launch. End the matching activity when the session ends and clean up stale activities after interrupted cleanup. If storage deletion or activity cleanup fails, make the state retryable and report appropriately rather than claiming complete success.

Apple limits a Live Activity to eight active hours, with possible Lock Screen retention afterward. Users/system may dismiss it. The saved game can remain active until End Session, but do not promise an indefinitely visible Dynamic Island or a continuously running background process. If expired, starting a replacement may occur when the user resumes in foreground, subject to authorization. No automatic infinite background restart mechanism.

Gate: verify start, round updates, background/lock visibility, tap-to-resume and end on a supported simulator/device where available. Explicitly report any device-only verification not performed.

## Phase 5 — Proof and TestFlight

Run formatter, static analysis and focused tests. Cover selection for every N from 2 to 60 with deterministic inputs: valid distinct roles, even opposite and both odd alternatives. Test clockwise angle alignment, wrap boundaries, repeated spins and no double-spin. Test serialization/restoration and invalid records. Use meaningful focused tests, not a large boilerplate framework. Smoke-test the complete flow on iOS, including high player count, long names, accessibility settings and background/resume.

Audit permission strings and dependencies against actual behavior. No microphone permission for text-to-speech. No unnecessary background modes. Verify release configuration, extension bundle IDs, signing, version/build number and icons. Keep public repository free of certificates, provisioning profiles, private keys, tokens, team secrets and personal device identifiers.

The user wants a TestFlight beta. If authorized signing and App Store Connect access exist, prepare an archive, validate and upload using approved tooling. Do not claim TestFlight availability merely because upload succeeded: Apple processing and beta access are separate steps. External testing may require beta review. Do not promise Apple processing within the one-to-two-hour target. If account access, final bundle ID, distribution permission, paid membership or signing is missing, finish all local build/validation work and ask only for the specific missing prerequisite. Never request passwords or tokens pasted into chat.

## Working and reporting expectations

Implement in the phase order above and preserve each runnable milestone. After each phase report what works, checks passed, actual blockers and next step. Do not stop at a scaffold or silently leave a requested feature as a stub. Do not invent test results or device verification. Avoid speculative extensibility, generic services and duplicated state. Maintain a short README with setup, pinned tooling, run/test commands, iOS/signing prerequisites, gameplay, odd-player rule and known limitations.

The final handoff must distinguish: implemented, simulator-tested, physical-device-tested, archived, uploaded, and available in TestFlight. Include exact remaining actions only where necessary.

## Primary references to recheck during implementation

- Flutter 3.50: https://flutter.dev/blog/whats-new-in-flutter-3-50
- Native iOS view embedding: https://docs.flutter.dev/platform-integration/ios/platform-views
- Apple native glass: https://developer.apple.com/documentation/UIKit/UIGlassEffect
- ActivityKit: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- GetX: https://pub.dev/packages/get
- GetStorage: https://github.com/jonataslaw/get_storage
