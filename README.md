# Bussruta

Bussruta is a Flutter version of the card game with two play modes:

- Local mode: everyone plays on one device.
- Hosted LAN mode: one device hosts, players join from other devices on the same Wi-Fi using LAN discovery, PIN, or direct host address.

The current product direction is to polish LAN play first. Internet room-key play is documented as a future backend/relay project, and Bluetooth is deferred unless offline no-Wi-Fi play becomes a hard requirement.

## Current Status

- Local game flow is implemented: setup, four warmup rounds, pyramid, tie-break, bus route, finish, game log, language toggle, persistence, onboarding, and auto play.
- Hosted LAN flow is implemented with host-authoritative commands, per-player projected views, drink assignment prompts, reconnect seat reclaim, host shutdown handling, and emulator join guidance.
- Automated checks currently cover the domain engine, hosted session runtime/projection/models, LAN transport, join target parsing, and onboarding persistence.
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
