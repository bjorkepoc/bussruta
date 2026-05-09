# Manual QA Checklist

This checklist is for manual validation on real devices before release.

## Test setup

- Use at least one Android emulator and two physical phones on the same Wi-Fi.
- Verify both `EN` and `NO` language toggles at least once per flow.
- Start with a clean app state (`New game` / leave hosted session).

## Local mode

### Setup

- [ ] Open app -> choose `Local`.
- [ ] Change player count (2, 4, 7) and names.
- [ ] Toggle reverse pyramid.
- [ ] Start game is visible without confusing scroll jumps.

Expected:
- Setup updates are immediate and stable.
- Start action remains obvious.

### Warmup (Rounds 1-4)

- [ ] Verify first deal starts from top-left seat and proceeds clockwise.
- [ ] Verify option panel supports 2, 3, and 4 options without clipping.
- [ ] Verify bottom player hands remain visible (panel does not cover cards).

Expected:
- Visual seating/deal order matches turn progression.
- All options are visible and tappable.

### Pyramid

- [ ] Enter pyramid and reveal by tapping deck.
- [ ] Confirm hidden slots remain hidden until revealed.
- [ ] Confirm center remains focused on deck+pyramid, player docks stay perimeter.

Expected:
- Reveal order and drink prompts follow rules.
- No overlap between instruction text, pyramid cards, and player docks.

### Tie-break

- [ ] Force a tie on highest remaining cards (at least 2 contenders).
- [ ] Verify contenders all get facedown cards.
- [ ] Verify reveal happens together after suspense delay.
- [ ] Verify winner/loser message is clear and flow continues to bus setup.

Expected:
- No stuck tie-break state.
- Contender cards are visible and progression is deterministic.

### Bus route + finish

- [ ] Verify only active column/card is highlighted.
- [ ] Verify `Same` action sits near active card without covering card center.
- [ ] Verify route cards are not clipped on small width.
- [ ] Finish route and press `New game`.

Expected:
- Above/below/same interactions are clear.
- Finish overlay is centered and readable.
- New game returns to setup cleanly.

## Hosted LAN mode

### Host + join

- [ ] Device A: choose `Hosted`, host a session, note PIN.
- [ ] Device B: join via LAN discovery.
- [ ] Device C: join via PIN + host address.
- [ ] Confirm lobby shows connected slots and host marker.

Expected:
- Session status transitions are clear (`joining`, `connected`).
- Host can start only from lobby.

### Reconnect + disconnect handling

- [ ] During game, disable Wi-Fi on Device B briefly, then re-enable.
- [ ] Verify reconnect attempts and same-seat reclaim.
- [ ] Stop host app/session and observe client behavior.

Expected:
- Client shows reconnecting/disconnected/host unavailable/session closed states clearly.
- Reconnect returns to same seat when host is alive.
- Host shutdown ends session with clear message for clients.

### Gameplay authority + privacy

- [ ] Verify each client only sees own hand + public table state.
- [ ] Verify host can use host tools (auto play, game log) and still play normally.
- [ ] Verify non-host clients cannot run host-only actions (pyramid reveal, tie-break round).

Expected:
- Host-authoritative enforcement is consistent.
- No private hand leakage.

### Drink distribution + bus control

- [ ] Trigger give-out drink events in warmup and pyramid.
- [ ] Split drinks across multiple targets from source player device.
- [ ] Trigger loser-only bus route phase.

Expected:
- Pending distribution blocks unrelated actions until resolved.
- Source player can split allocation across targets.
- Only loser can control bus route actions; others see public/spectator state.

## Quick regression smoke

- [ ] Leave hosted session and return to local mode.
- [ ] Start a local game again.

Expected:
- No stale hosted connection state leaks into local flow.
- App remains stable after repeated mode switching.

## Known manual-only checks

- Multi-device LAN discovery reliability under noisy networks.
- Reconnect behavior across real router/AP changes.
- Touch ergonomics and readability across different phone aspect ratios.
