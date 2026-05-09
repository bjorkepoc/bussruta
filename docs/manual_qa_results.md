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
