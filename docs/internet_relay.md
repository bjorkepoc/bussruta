# Internet Relay

The first internet-room building block is a small Dart WebSocket relay in `tool/internet_relay.dart`.

It is intentionally host-authoritative:

- The host creates a room and remains the game authority.
- Clients join the room through the relay.
- Client messages are wrapped with a relay `clientId` and forwarded to the host.
- Host messages are forwarded to individual clients or broadcast to all clients.
- The relay does not inspect private card state and does not run game rules.

## Run Locally

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

Then run the Flutter web app on the network:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081
```

Open `http://<pc-lan-ip>:8081`, choose Hosted mode, and use the relay URL above.
The host creates a room and shares the room key with phones or other PCs on the
same network.

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
