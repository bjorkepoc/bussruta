# Release Readiness

This project is in a LAN-first hardening phase. The automated Dart/Flutter checks are healthy, but release still depends on product, device QA, signing, and store setup.

## Current Baseline

- Local mode and hosted LAN mode are implemented.
- Hosted LAN uses UDP discovery on port `45878` and TCP session traffic on port `45879`.
- Hosted sessions are host-authoritative and send per-player projections so clients only receive their own private hand.
- A minimal internet relay backend exists at `tool/internet_relay.dart`, but Flutter-side internet room UI/transport is not wired yet.
- Bluetooth is deferred unless offline play without Wi-Fi becomes a required product goal.

## Required Before Release

- Complete the manual QA checklist in `docs/manual_qa_checklist.md` on two physical phones on the same Wi-Fi.
- Record manual QA evidence in `docs/manual_qa_results.md`.
- Confirm hosted LAN discovery, direct address join, reconnect, host shutdown, drink assignment, and bus-route authority on real devices.
- Android application ID is `com.bjork.bussruta`.
- iOS bundle identifier is `com.bjork.bussruta`.
- Keep `android/key.properties` and `android/app/upload-keystore.jks` backed up outside git. They are intentionally ignored.
- Confirm the iOS signing team before App Store/TestFlight distribution.
- Decide the user-facing app name, icon, screenshots, privacy text, and store description.
- Decide whether version `1.0.0+1` in `pubspec.yaml` is the first release version or should be reset before publishing.

## Local Signing Setup

Android release signing reads ignored local secrets from:

```text
android/key.properties
android/app/upload-keystore.jks
```

Use `android/key.properties.example` as the committed template. Release builds fail if `android/key.properties` is absent; debug/profile developer builds do not need the keystore.

## Recommended Release Gate

Run these commands locally and in CI before tagging a release:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Then run the manual checklist and record device models, OS versions, network type, and any failed/retried steps.

## Next Product Track

Keep LAN + PIN as the baseline until real-device QA passes. After that, the next major feature can be internet room-key play through a small WebSocket relay that reuses the existing hosted command/projection protocol.
