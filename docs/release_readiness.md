# Release Readiness

This project is in a LAN-first hardening phase. The automated Dart/Flutter checks are healthy, but release still depends on product, device QA, signing, and store setup.

## Current Baseline

- Local mode and hosted LAN mode are implemented.
- Hosted LAN uses UDP discovery on port `45878` and TCP session traffic on port `45879`.
- Hosted sessions are host-authoritative and send per-player projections so clients only receive their own private hand.
- Internet room-key play is not implemented yet. It requires a backend relay/signaling service.
- Bluetooth is deferred unless offline play without Wi-Fi becomes a required product goal.

## Required Before Release

- Complete the manual QA checklist in `docs/manual_qa_checklist.md` on at least one Android emulator and two physical phones on the same Wi-Fi.
- Confirm hosted LAN discovery, direct address join, reconnect, host shutdown, drink assignment, and bus-route authority on real devices.
- Replace any placeholder app identity and decide the final Android package/application ID.
- Configure Android release signing with a real keystore. The current Gradle release block still uses debug signing so release-mode local runs work.
- Confirm the iOS bundle identifier, signing team, and local-network permission copy before App Store/TestFlight distribution.
- Decide the user-facing app name, icon, screenshots, privacy text, and store description.
- Decide whether version `1.0.0+1` in `pubspec.yaml` is the first release version or should be reset before publishing.

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
