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

## 2026-06-03 Browser Relay Fix And In-App Browser QA

Environment:

- Host machine: Windows, repo build served from `build/web`.
- Helper: `tool/start_lan_web.ps1`, relay `ws://192.168.10.104:8090/ws`, app `http://192.168.10.104:8091/`.
- Browser QA surface: Codex in-app browser at `1280x720`.
- Physical second PC/browser: blocked. This run used in-app browser tabs/agents on the host machine, not a separate PC on the LAN.
- Physical phones: blocked. No two real phones were connected for this run.

Verified:

- `Copy join details` on a relay host room copied app URL, Relay URL, and room key.
- A stale Flutter web/service-worker origin on the earlier default port showed the old assignment layout; a fresh origin on ports `8090/8091` showed the updated build.
- Host-side drink assignment status showed `Assign drinks`, not a misleading waiting message.
- Host-side drink assignment layout kept `Send assignment` visible in the first `1280x720` viewport and above `Public table`.
- Generic/default names no longer produced two identical raw `Player` labels in the tested hosted projections.
- Automated regression coverage was added for generic fallback names, pending drink source status, first-viewport drink assignment layout, relay clipboard success/failure, and relay URL prefill from the app link.
- `tool/start_lan_web.ps1` now prints an app URL with `relayUrl` query parameter so custom relay ports prefill Hosted mode instead of defaulting to `8080`.

Observed issues and fixes:

- PASS: Host relay invite clipboard contained the expected join details.
- PASS: Host pending assignment status and first-viewport layout passed on a fresh origin.
- PASS: Console warnings/errors were clean in the in-app browser host checks.
- FIXED: Custom-port helper URLs no longer require manual relay-port correction when users open the printed app URL.
- PARTIAL: A synchronized two-agent browser replay was interrupted by the active goal update before the host wrote the new room key; the earlier joined-browser run did verify `2 / 2 connected`, but it used the stale-origin build for the assignment-layout screenshot.
- BLOCKED: The release checklist item for a separate second PC browser on the same Wi-Fi/LAN is still manual and must be rerun outside the in-app browser.

Still blocked:

- Physical two-phone Hosted LAN QA.
- Local full game-flow QA on a physical phone.
- Separate second-PC same-network browser relay QA.
- Real-device reconnect, host shutdown, private-hand verification, drink distribution, and bus-route authority.

Release implication:

- Browser relay implementation and host-side assignment regressions are now covered by automated tests and in-app browser evidence.
- The app is still not release-ready until physical device QA and separate-PC relay QA are logged as PASS, or explicitly removed from first-release scope.

## 2026-06-03 Technical Release Gate

Environment:

- Host: Windows.
- Flutter project version: `1.0.0+1`.
- Android package: `com.bjork.bussruta`.
- iOS bundle identifier: `com.bjork.bussruta`.

Commands:

- PASS: `dart format --output=none --set-exit-if-changed .`.
- PASS: `flutter analyze`.
- PASS: `flutter test` (`79` tests passed).
- PASS: `flutter build apk --release`.
- PASS: `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`.
- PASS: `flutter build web --no-wasm-dry-run`.
- PASS: `git diff --check` reported no whitespace errors; Git emitted CRLF conversion warnings only.

Artifacts:

- Android release APK: `build/app/outputs/flutter-apk/app-release.apk`, `49.3MB`.
- APK certificate DN: `CN=Bussruta, OU=Bussruta, O=Bjork, L=Oslo, ST=Oslo, C=NO`.
- APK certificate SHA-256 digest: `f01a49e64e4df2dcb66dff9715d4f7f6ad13eee57230cd6301fd52dbc3ff4f75`.
- Web build: `build/web`.

Signing and store blockers:

- PASS: `android/key.properties` exists locally.
- PASS: `android/app/upload-keystore.jks` exists locally.
- PASS: both Android signing secret paths are ignored by git.
- BLOCKED: external backup of the keystore/key properties was not independently verified.
- BLOCKED: iOS signing team is not set in `ios/Runner.xcodeproj/project.pbxproj` and must be confirmed before TestFlight/App Store distribution.

Warnings:

- `flutter build web` printed a Cupertino icon font warning, but no `CupertinoIcons` / `cupertino_icons` references were found in `lib`, `test`, or `pubspec.yaml`. The build completed successfully.

Release implication:

- Automated technical gates and Android release signing passed on this machine.
- Release remains blocked by physical QA, separate-PC browser relay QA, public privacy-policy URL, final store metadata, iOS signing team, and explicit first-release decisions for public relay, ads, payments, and Bluetooth.

## 2026-06-03 Physical Local Gameplay QA Availability Check

Environment:

- Host: Windows.
- Android release APK: `build/app/outputs/flutter-apk/app-release.apk`, `49.3MB`.
- ADB check: `adb devices -l`.

Result:

- BLOCKED: no Android devices were attached. `adb devices -l` returned only the header `List of devices attached`.
- NOT RUN: physical local gameplay QA for EN/NO language, 2/4/7 player setup, warmup rounds, pyramid, tie-break, bus route, finish, and `New game` return to setup.

Release implication:

- The release APK is available for installation, but this checklist item cannot be closed until at least one physical Android device is connected and visible in `adb devices -l`.
