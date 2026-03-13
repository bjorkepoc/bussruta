# Multiplayer Options Evaluation

## Current state in repo

- Hosted mode now works with a host-authoritative model on local network.
- Join is available with:
  - LAN discovery (same Wi-Fi)
  - PIN-based join
  - direct host address + PIN
- No external backend or Bluetooth plugin is added yet.

## Internet room-key support

### What is required

- A backend signaling/relay service is required for reliable internet play.
- Pure peer-to-peer without backend is not reliable across NAT/mobile networks.

### Smallest sane option

- Add a lightweight relay backend:
  - room creation (`roomKey`)
  - authenticated socket session for host and players
  - host-authoritative command forwarding and snapshot fanout
- Keep existing hosted command/projection protocol, but swap transport from LAN TCP to backend WebSocket.

### Tradeoffs

- Pros:
  - works across networks
  - room-key UX is straightforward
  - same game/session domain can be reused
- Cons:
  - backend cost and operations
  - security hardening needed (rate limits, session auth, abuse controls)
  - reconnect/session persistence logic becomes important

## Bluetooth support

### Feasibility

- Feasible with plugins, but adds platform complexity and UX edge cases.
- Typical plugin paths:
  - BLE-based data channels (limited throughput/message size)
  - nearby/peer-to-peer plugins with Android/iOS differences

### Tradeoffs

- Pros:
  - offline local play option
- Cons:
  - extra permissions and pairing friction
  - iOS/Android behavior mismatch
  - more device-specific bugs than Wi-Fi LAN
  - higher maintenance burden than LAN or internet relay

## Recommendation

1. Keep current LAN + PIN as the baseline.
2. Implement internet room-key next using a small relay backend.
3. Treat Bluetooth as optional/future unless offline no-Wi-Fi play is a hard requirement.

## Decisions needed from product owner

1. Internet backend approved now (`yes/no`)?
2. Preferred deployment style for backend:
   - managed PaaS (small ops)
   - self-hosted server
3. Bluetooth priority:
   - defer
   - include in this phase
4. Reconnect/host-migration policy for internet sessions:
   - no host migration (simpler)
   - host migration supported (more complex)
