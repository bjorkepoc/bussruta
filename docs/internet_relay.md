# Internet Relay

The first internet-room building block is a small Dart WebSocket relay in `tool/internet_relay.dart`.

It is intentionally host-authoritative:

- The host creates a room and remains the game authority.
- Clients join the room through the relay.
- Client messages are wrapped with a relay `clientId` and forwarded to the host.
- Host messages are forwarded to individual clients or broadcast to all clients.
- The relay does not inspect private card state and does not run game rules.

## Run Locally

On Windows, this repo includes a helper that builds the web app, then starts
both the relay and a static web server for same-network browser play:

```powershell
powershell -ExecutionPolicy Bypass -File tool\start_lan_web.ps1
```

Use `-OpenFirewall` from an administrator PowerShell when other PCs on the same
private network cannot reach the app or relay. Use `-Stop` to stop the local
listeners.

Manual relay startup:

```bash
dart run tool/internet_relay.dart --port 8080
```

The server listens on `/ws`, for example:

```text
ws://127.0.0.1:8080/ws
```

For same-network browser/mobile play, run the relay on the PC and use that PC's
LAN IP from every device:

```text
ws://<pc-lan-ip>:8080/ws
```

Then build and serve the Flutter web app on the network:

```bash
flutter build web
python -m http.server 8081 --bind 0.0.0.0 --directory build/web
```

Open the app URL printed by the helper. It includes the relay URL as a query
parameter so Hosted mode is prefilled, including when custom ports are used.
The host creates a room and shares the room key with other PCs on the same
network. The lobby can copy the app URL, Relay URL, and room key together from
`Copy join details` when the web app is served from a LAN address.

## Relay Messages

Host creates a room:

```json
{"type":"host.create","roomKey":"ROOM42"}
```

Client joins a room:

```json
{"type":"player.join","roomKey":"ROOM42","payload":{"type":"join","pin":"ROOM42","name":"Client"}}
```

Client sends an existing hosted payload to the host:

```json
{"type":"client.message","payload":{"type":"command","command":{"type":"warmupGuess","playerId":2}}}
```

Host sends an existing hosted payload to one client:

```json
{"type":"host.message","clientId":"client-1","payload":{"type":"snapshot","projection":{}}}
```

Host broadcasts an existing hosted payload:

```json
{"type":"host.broadcast","payload":{"type":"session_closed","message":"Host ended the session."}}
```

## Not Included Yet

- TLS termination, authentication, room rate limiting, idle expiry, or deployment config.
- Host migration.

Those hardening items should be added before exposing the relay on the public
internet. The current relay flow is intended for trusted local networks or
development use.
