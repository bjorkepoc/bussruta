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

## Relay Messages

Host creates a room:

```json
{"type":"host.create","roomKey":"ROOM42"}
```

Client joins a room:

```json
{"type":"player.join","roomKey":"ROOM42","payload":{"type":"join","name":"Client"}}
```

Client sends an existing hosted payload to the host:

```json
{"type":"client.message","payload":{"type":"command","command":{"type":"warmupGuess"}}}
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

- Flutter UI for internet rooms.
- A WebSocket transport adapter inside `HostedSessionController`.
- TLS termination, authentication, room rate limiting, idle expiry, or deployment config.
- Host migration.

Those should be built as a separate transport integration after the relay protocol is accepted.
