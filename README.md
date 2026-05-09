# Bussruta

Bussruta is a Flutter version of the card game with two play modes:

- Local mode: everyone plays on one device.
- Hosted mode: one device hosts, players join from other devices on the same Wi-Fi using LAN discovery, PIN, direct host address, or the WebSocket relay for browser/mobile/PC play.

The current product direction is to keep LAN play as the baseline, with relay rooms available for browser/mobile/PC play on the same trusted network. Bluetooth is deferred unless offline no-Wi-Fi play becomes a hard requirement.

## Current Status

- Local game flow is implemented: setup, four warmup rounds, pyramid, tie-break, bus route, finish, game log, language toggle, persistence, onboarding, and auto play.
- Hosted LAN flow is implemented with host-authoritative commands, per-player projected views, drink assignment prompts, reconnect seat reclaim, host shutdown handling, and emulator join guidance.
- Hosted relay flow is implemented for browsers, phones, and PCs that can reach the same WebSocket relay on the network.
- Automated checks currently cover the domain engine, hosted session runtime/projection/models, LAN transport, relay transport, join target parsing, and onboarding persistence.
- Manual device QA is still required before release.

## Run Locally

```bash
flutter pub get
flutter run
```

Common verification commands:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Browser Play On The Same Network

Run the relay on the PC that should coordinate the room:

```bash
dart run tool/internet_relay.dart --port 8080
```

Run the Flutter web app so other devices on the same Wi-Fi can open it:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081
```

Open `http://<pc-lan-ip>:8081` from the PC browser, another PC, or a phone on
the same network. In Hosted mode, use `ws://<pc-lan-ip>:8080/ws` as the Relay
URL. The host creates a room and shares the shown room key; other players join
with the same Relay URL and room key.

## Hosted LAN Testing

For real devices, put the host and clients on the same Wi-Fi. Start a hosted session on one device, then join from the other devices through LAN discovery or by entering the host address and PIN.

Android emulators need an ADB port-forwarding workaround because each emulator has its own virtual network. See [docs/emulator_hosted_join_workflow.md](docs/emulator_hosted_join_workflow.md).

Manual release checks live in [docs/manual_qa_checklist.md](docs/manual_qa_checklist.md).

## Project Layout

- `lib/domain/` contains the game state, rule engine, hosted models, and hosted projection logic.
- `lib/application/` contains local and hosted controllers, persistence, hosted runtime, LAN discovery, and TCP transport.
- `lib/presentation/` contains the Flutter UI for mode selection, local gameplay, hosted gameplay, rules, and onboarding.
- `test/` contains unit and application-level regression tests.
- `BusRoute_web_app/` is the earlier static web version/reference implementation.
- `docs/` contains product, QA, multiplayer, and release readiness notes.
- `graphify-out/` contains the generated knowledge graph used to navigate this codebase.

## Graphify

This repository has a Graphify knowledge graph. Before investigating code relationships, read `graphify-out/GRAPH_REPORT.md`. After code changes, run:

```bash
graphify update .
```

## Release Readiness

The app is not release-ready until manual device QA, app identity, signing, and store metadata are completed. See [docs/release_readiness.md](docs/release_readiness.md).
