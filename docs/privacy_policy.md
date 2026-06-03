# Privacy Policy

Effective date: 2026-06-03

This privacy policy describes how Bussruta handles information when you use the app. Replace the placeholders below before publishing this policy publicly:

- Developer/controller: [developer name or company]
- Contact: [privacy contact email]
- Public policy URL: [public non-PDF URL]

## Summary

Bussruta is a local and hosted multiplayer card game. The current app has no accounts, no analytics SDK, no advertising SDK, and no in-app payment integration. It stores game data on your device so you can continue a game, and it can transmit multiplayer data to the host device, joined players, or a relay server that you choose or operate.

If ads, paid features, subscriptions, analytics, crash reporting, or a developer-operated public relay are added later, this policy and the store privacy disclosures must be updated before those features are released.

## Information Handled By The App

### Local app data

The app stores these items locally on your device:

- Player display names entered in setup.
- Game state, including cards, turns, drinks assigned in the game, bus-route state, log messages, language, and autoplay/setup preferences.
- Whether the onboarding intro has been seen.

This local data is used only to run the game and restore the last game. You can delete it by clearing the app's storage or uninstalling the app.

### Hosted LAN and relay play

When you use Hosted mode, the app sends multiplayer data needed to run the game:

- Player display names.
- Room or PIN details, relay room key, and connection status.
- Game commands, public game state, private hand state for the relevant player, drink assignment prompts, reconnect tokens, and similar session messages.
- Network metadata needed to connect, such as IP addresses and ports.

Hosted sessions are host-authoritative. The host device has the full game state. Joined players receive the public game state and their own private hand projection.

If you use the bundled same-network relay helper, it forwards WebSocket messages between room participants and keeps room data in memory only while the relay process is running. It is intended for trusted local-network testing and play. A different relay server, especially one operated on the public internet, may be able to see network metadata and relay traffic and may have its own logging or retention practices.

## Information We Do Not Currently Collect

The current app does not include:

- User accounts or login.
- Email address collection.
- Payment or purchase processing.
- Advertising identifiers or ad tracking.
- Analytics or crash-reporting services.
- Camera, microphone, contacts, photos, SMS, or precise location access.

## How Information Is Used

The app uses information to:

- Run local and hosted games.
- Show player names, hands, turns, prompts, and logs.
- Let players join, reconnect, and receive the correct private/public game projection.
- Persist a local game on your own device.
- Maintain the security and functionality of hosted sessions.

## Sharing

In Hosted mode, multiplayer information is shared with the host device, joined players, and any relay server used for the session. We do not sell personal information.

If a developer-operated relay, analytics provider, ad network, payment processor, or crash-reporting provider is added later, this policy will identify the provider, the data categories involved, the purposes, retention, and any required choices or consent.

## Ads And Payments Planned For The Future

Bussruta does not currently serve ads or process payments. Before ads are enabled, the app must add any legally required consent flow, disclose ad technology providers, and update Google Play Data safety and Apple App Privacy details. If Google AdMob is used for users in the EEA, UK, or Switzerland, Google's current guidance requires a Google-certified consent management platform integrated with the IAB TCF when serving ads.

Before paid digital features or subscriptions are enabled, the app must use the applicable app-store billing system where required and disclose any purchase, account, fraud-prevention, or payment-related data handled by the app or payment processor.

## Legal Bases For EEA/UK Users

Where the GDPR or UK GDPR applies, the legal bases may include:

- Contract or pre-contract steps: to provide the game and hosted-session features you request.
- Legitimate interests: to maintain app functionality, connection security, and abuse prevention for hosted sessions.
- Consent: where required for optional features such as personalized ads, tracking, or certain local storage.
- Legal obligation: where processing is necessary to comply with applicable law.

## Retention

Local game data remains on your device until you clear app storage, start/reset a game, or uninstall the app. The bundled relay helper does not intentionally persist room data; it keeps room state in memory only while the process and room are active. A future developer-operated relay must define and publish a retention period before release.

## Security

The app limits hosted players to per-player projections so clients should not receive other players' private hands. The bundled relay helper is intended for trusted local networks and is not hardened for public internet use. Public relay deployment should add TLS, authentication or abuse controls, rate limiting, monitoring, and clear retention limits before production use.

## Children

Bussruta is a drinking-game themed card game and is not directed to children. The app does not knowingly collect personal information from children under 13. If the app is used by someone under the age where parental consent is required, it should be used only with a parent or guardian.

## Your Choices And Rights

You can:

- Clear local app data from your device settings.
- Avoid Hosted mode if you do not want multiplayer data sent to a host, other players, or a relay server.
- Contact us at the privacy contact above to request access, correction, deletion, restriction, portability, or objection where those rights apply.

EEA/UK users may also complain to their local data protection authority if they believe their rights have not been respected.

## International Transfers

Local mode keeps data on your device. Hosted mode sends data to the devices and relay server participating in the session. If you choose or operate a relay outside your country, data may be transmitted to that location. A future developer-operated public relay must document transfer safeguards before release.

## Changes

We may update this policy when the app changes. Material changes, especially ads, payments, accounts, analytics, crash reporting, or a developer-operated relay, should be reflected in this policy and in app-store privacy disclosures before release.

## Store Compliance Notes

Before publication, host this policy at a public, non-PDF URL and fill in the developer/controller and contact details. Google Play requires a privacy policy link in Play Console and in the app even for apps that do not access personal and sensitive user data.
