# Release Readiness

This project is in a LAN-first hardening phase. The automated Dart/Flutter checks are healthy, but release still depends on product, device QA, signing, and store setup.

## Current Baseline

- Local mode and hosted LAN mode are implemented.
- Hosted LAN uses UDP discovery on port `45878` and TCP session traffic on port `45879`.
- Hosted sessions are host-authoritative and send per-player projections so clients only receive their own private hand.
- Same-network browser rooms are implemented through the WebSocket relay in `tool/internet_relay.dart`, Flutter relay transport, and the Hosted mode Relay URL / room key UI.
- `tool/start_lan_web.ps1` builds the web app, then starts the relay and static web server for PC browser testing on the same network.
- Public internet relay deployment is not hardened yet; keep it to trusted local networks until TLS, auth, rate limits, and deployment controls exist.
- Bluetooth is deferred unless offline play without Wi-Fi becomes a required product goal.

## First Release Scope Decisions

- Public internet relay: not in the first release. Keep relay rooms scoped to trusted LAN/development/same-network browser play until a hardened `wss://` deployment exists.
- Ads: not in the first release.
- Paid features/subscriptions: not in the first release.
- Bluetooth: not in the first release.

If any of these decisions change, update `docs/privacy_policy.md`, `docs/store_disclosures.md`, `docs/manual_qa_checklist.md`, and this release gate before publishing.

## Required Before Release

- Complete the manual QA checklist in `docs/manual_qa_checklist.md` on two physical phones on the same Wi-Fi.
- Record manual QA evidence in `docs/manual_qa_results.md`.
- Confirm hosted LAN discovery, direct address join, reconnect, host shutdown, drink assignment, and bus-route authority on real devices.
- Confirm same-network browser play from at least two PCs using the relay helper or equivalent manual commands.
- Android application ID is `com.bjork.bussruta`.
- iOS bundle identifier is `com.bjork.bussruta`.
- Keep `android/key.properties` and `android/app/upload-keystore.jks` backed up outside git. They are intentionally ignored.
- Confirm the iOS signing team before App Store/TestFlight distribution.
- Decide the final user-facing app icon and screenshot set.
- Host `docs/privacy_policy.md` at a public non-PDF URL, fill in the developer/controller and contact placeholders, and add the link in-app/store metadata.
- Complete the store disclosure checklist in `docs/store_disclosures.md` for the exact release architecture.
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

Keep LAN + same-network browser relay play as the baseline until real-device QA passes. After that, the next major feature can be public internet room-key play through a hardened WebSocket relay that reuses the existing hosted command/projection protocol.
