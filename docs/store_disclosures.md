# Store Disclosures And Release Metadata

This file is a working checklist for Google Play, App Store Connect, and future monetization changes. It is not legal advice; final store answers must match the exact build submitted.

## Current Build

- App name: Bussruta
- Version: `1.0.0+1`
- Android application ID: `com.bjork.bussruta`
- iOS bundle identifier: `com.bjork.bussruta`
- Current monetization: none
- Current accounts: none
- Current ads: none
- Current analytics/crash reporting: none
- Current payment processing: none
- Current network features: hosted LAN and optional WebSocket relay rooms
- Privacy policy: `docs/privacy_policy.md` must be hosted at a public non-PDF URL before store submission

## Suggested Descriptions

Short description:

> Bussruta is a local and hosted multiplayer card game for playing on one device, over LAN, or through a same-network relay.

Full description draft:

> Bussruta brings the classic card-game flow into a Flutter app with local play and hosted multiplayer. Play on one device, host a same-Wi-Fi room, or use the relay room flow for browsers, phones, and PCs that can reach the same relay on your network.
>
> Features:
>
> - Local game mode for one shared device.
> - Hosted mode with host-authoritative gameplay.
> - LAN discovery, direct host-address join, and relay room-key join.
> - Per-player private hand projections in hosted sessions.
> - Warmup rounds, pyramid, drink assignment prompts, tie-break, bus route, finish state, and game log.
> - English and Norwegian UI.
>
> The app is drinking-game themed and intended for adults. It does not include real-money gambling, accounts, ads, analytics, or in-app purchases in the current build.

Keywords:

```text
bussruta, card game, party game, multiplayer, LAN, drinking game, bus route, cards
```

## Google Play Data Safety

Answer this section from the exact deployed architecture.

Current local/LAN-only build with no developer-operated backend:

- Data collection by developer: likely `No`, if no developer server, analytics, crash reporting, ads, or payments are present.
- Data shared by the app: disclose conservatively if Play Console asks about user-to-user or relay transfer. Hosted mode can transmit player display names, gameplay content, room keys, reconnect tokens, and network metadata to the host, joined players, and any relay server selected for the session.
- Data processed only on device: local game state, preferences, and onboarding flag.
- Security practices: do not claim all data is encrypted in transit for the bundled relay helper unless TLS is added. Current helper uses `ws://` for trusted local-network testing.
- Account deletion: not applicable while the app has no accounts.
- Privacy policy: required in Play Console and in-app/public URL.

If a developer-operated public relay is shipped:

- Re-evaluate data collection as `Yes`.
- Consider categories such as App activity / Gameplay content, User provided display names, identifiers or network metadata, and diagnostics if logged.
- Declare purpose as app functionality, security, fraud/abuse prevention if applicable.
- Document retention and deletion request flow.
- Use modern cryptography in transit, preferably `wss://` over TLS.

If ads are shipped:

- Declare ad identifiers and any app activity, device identifiers, or usage data used by the ad SDK.
- Add a consent flow where required.
- Keep the privacy policy, in-app disclosures, and Data safety answers consistent.

If paid digital features are shipped:

- Use Google Play billing where required.
- Declare any purchase history, account, fraud-prevention, or payment-related data the app receives or shares.

## Apple App Privacy

Answer this section from the exact deployed architecture.

Current local/LAN-only build with no developer-operated backend:

- Data collected by developer: likely none, if data is only processed on device or user-initiated between peers and no developer server receives it.
- On-device data: Apple guidance says data processed only on device is not collected for App Store Connect answers.
- Multiplayer/gameplay: if a developer-operated relay or backend receives gameplay data, declare Gameplay Content and any identifiers/network metadata according to Apple guidance.
- Privacy policy URL: required.

If ads are shipped:

- Update App Privacy details for tracking, identifiers, purchases, usage data, or diagnostics used by ad partners.
- Use App Tracking Transparency where tracking applies.
- Ensure ads match the app age rating and include required ad reporting/visibility features.

If paid digital features are shipped:

- Use Apple's in-app purchase system where required.
- Disclose purchases and related account/identifier data if collected by the developer or third-party partners.

## Age Rating And Content

- The app is drinking-game themed and should not be marketed as a children's app.
- It does not include real-money gambling in the current build.
- Complete store age-rating questionnaires honestly for alcohol/drinking references, simulated card gameplay, multiplayer/user interaction, and any future ads.

## Screenshots Needed

Capture final release screenshots after physical-device QA:

- Mode chooser.
- Local setup.
- Warmup gameplay.
- Pyramid/drink assignment.
- Hosted lobby with PIN/relay controls.
- Hosted player view showing private hand and public table.
- Finished/bus-route result.

## Official Source Links

- Google Play User Data policy: https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play Data safety help: https://support.google.com/googleplay/android-developer/answer/10787469
- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Google AdMob EU consent guidance: https://support.google.com/admob/answer/7666519
- Google Play Payments policy: https://support.google.com/googleplay/android-developer/answer/9858738
- FTC COPPA guidance: https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-six-step-compliance-plan-your-business
