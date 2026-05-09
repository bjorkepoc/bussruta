# Manual QA Results

## 2026-05-09 Release Smoke

Environment:

- Host: Windows, Flutter `3.41.4`.
- Device: Android emulator `emulator-5554`, Android 16 / API 36, `sdk_gphone64_x86_64`, `1080x2400`.
- Physical devices: blocked. `adb devices -l` only listed `emulator-5554`; no real phones were connected.
- Release package: `com.bjork.bussruta`, version `1.0.0+1`.
- Signing: release APK verified with `apksigner verify --print-certs`.

Verified:

- Installed release APK and launched `com.bjork.bussruta/.MainActivity`.
- Skipped onboarding, opened `Local`, started a local game, and reached `Warmup 1 / 4` with `Turn: Player 1`.
- Opened `Hosted`, hosted a LAN session, and reached `Hosted lobby` with status `Connected`, a session PIN, host address `10.0.2.16:45879`, and `1 / 1 connected`.
- Confirmed old development package ID `com.bjork.bussruta_app` was still installed on the emulator and could hold TCP port `45879`; uninstalled it before the final hosted smoke.

Not completed:

- Physical two-phone LAN QA.
- LAN discovery join from another real device.
- Direct host-address join from another real device.
- Reconnect after Wi-Fi interruption.
- Multi-device private-hand verification.
- Real-device drink distribution and loser-only bus-route authority.

Release implication:

- Emulator smoke is good enough for package/signing/startup confidence.
- Real release readiness still requires the physical-device hosted LAN checklist in `docs/manual_qa_checklist.md`.

## 2026-05-09 QA Findings Fix Pass

Environment:

- Host: Windows, Flutter debug APK built from `codex/ui-refresh-premium-card-table`.
- Device: Android emulator `emulator-5554`, package `com.bjork.bussruta`, `1080x2400`.
- Physical devices: blocked. This pass intentionally documents the release gate instead of closing it.

Verified:

- Installed `build/app/outputs/flutter-apk/app-debug.apk`, cleared app data, and launched `com.bjork.bussruta/.MainActivity`.
- First-run intro opened; skipped intro to mode chooser.
- Switched language from EN to NO and verified Norwegian mode labels.
- Opened `Hvordan spille`, captured the help screen, and returned to mode chooser.
- Opened local setup, verified `Tilbake til valg` and `Fjern spiller N` accessible labels in the UI tree, then used Android Back to return to mode chooser.
- Started a local game, reached warmup, used autoplay through warmup and pyramid, selected bus route start, resumed autoplay, reached finished state, and used `Nytt spill` to return to setup.
- Opened hosted mode, hosted a LAN session, verified lobby/PIN/status, started hosted game, made a warmup choice, verified pending drink assignment blocks choices, verified plus/minus drink buttons have explicit Norwegian labels, sent drink distribution, acknowledged the drink, and used Android Back to leave the hosted game back to mode chooser.
- Checked app PID logcat and Android crash buffer for Flutter exceptions, RenderFlex overflow, and app crashes; no matching entries were present.

Still blocked:

- Physical two-phone LAN discovery.
- Direct host-address join from another real device.
- Reconnect after Wi-Fi interruption.
- Host shutdown behavior on real clients.
- Cross-device private-hand verification.
- Real-device drink distribution and loser-only bus-route authority.

Release implication:

- Local mode and single-emulator hosted host flow passed this QA fix smoke.
- Hosted LAN remains release-blocked until the physical-device checklist is run on at least two Android phones on the same Wi-Fi.
