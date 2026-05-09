# Graph Report - bussruta  (2026-05-09)

## Corpus Check
- 59 files · ~63,188 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 824 nodes · 1089 edges · 46 communities (36 shown, 10 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e46e78dc`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]

## God Nodes (most connected - your core abstractions)
1. `tr()` - 30 edges
2. `package:bussruta_app/domain/game_models.dart` - 23 edges
3. `renderAll()` - 19 edges
4. `revealPyramidSlot()` - 16 edges
5. `addLog()` - 14 edges
6. `package:flutter_test/flutter_test.dart` - 13 edges
7. `runAutoPlayStep()` - 12 edges
8. `playBusGuess()` - 12 edges
9. `package:bussruta_app/domain/game_engine.dart` - 12 edges
10. `dart:async` - 12 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (46 total, 10 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (90): addLog(), advanceWarmupTurn(), animateCardFlight(), animationScale(), applyVisualPreferences(), AUTO_PLAY_PRESETS, autoPlayControlsHtml(), beginBusRoute() (+82 more)

### Community 1 - "Community 1"
Cohesion: 0.02
Nodes (83): _addFlight, Align, _animateBusGuess, _animateBusRouteDeal, _animateBusZoneDelta, AnimatedContainer, AnimatedScale, _animatePyramidReveal (+75 more)

### Community 2 - "Community 2"
Cohesion: 0.03
Nodes (61): AnimatedBuilder, _bannerCard, build, _buildEntry, _buildGame, _buildLobby, _busRouteBoard, _busRouteView (+53 more)

### Community 3 - "Community 3"
Cohesion: 0.05
Nodes (45): GameStorage, SharedPrefsGameStorage, busGuessLabel, languageName, phaseLabel, tr, warmupGuessLabel, _FakeStorage (+37 more)

### Community 4 - "Community 4"
Cohesion: 0.05
Nodes (40): Duration, expectLater, Function, HostedProjectedView, main, StateError, _waitFor, Duration (+32 more)

### Community 5 - "Community 5"
Cohesion: 0.05
Nodes (42): acknowledgeDrinks, _applyHostAuthorityCommand, _applyHostStateToController, assignDrinks, _attemptReconnect, beginBusRoute, _bindClient, _bindHostServer (+34 more)

### Community 6 - "Community 6"
Cohesion: 0.05
Nodes (36): applyLocalCommand, _broadcastSnapshots, closeForInvalidFrame, copyWith, Duration, _emit, _emitIssue, _emitProjection (+28 more)

### Community 7 - "Community 7"
Cohesion: 0.06
Nodes (35): _advanceWarmupTurn, ArgumentError, beginBusRoute, _busGuessPlacement, chooseBusGuessByStats, chooseWarmupGuessByStats, _compareCardRanks, _DeckDraw (+27 more)

### Community 8 - "Community 8"
Cohesion: 0.06
Nodes (33): AnimatedBuilder, AppBanner, AppSurfaceCard, _BannerCard, build, _buildHome, BussrutaApp, _BussrutaAppState (+25 more)

### Community 9 - "Community 9"
Cohesion: 0.07
Nodes (28): applyLocalCommand, _broadcastSnapshots, _emitError, _emitIssue, _emitProjection, _emitState, _ensureTokenForPlayer, _handleClientDisconnect (+20 more)

### Community 10 - "Community 10"
Cohesion: 0.07
Nodes (27): addPlayer, beginBusRoute, _cancelPendingSetupPersist, didChangeAppLifecycleState, dispose, _emit, GameController, hardResetSetup (+19 more)

### Community 11 - "Community 11"
Cohesion: 0.07
Nodes (27): addParticipant, _appendDrinkDistributionLog, applyCommand, _autoExpirePromptCommand, _compare, _expireStaleDrinkPrompts, _handleAcknowledgeDrinks, _handleAssignDrinks (+19 more)

### Community 12 - "Community 12"
Cohesion: 0.11
Nodes (17): AutoPlayState, BusHistoryEntry, BusRouteState, BusZoneStack, BusZoneTone, copyWith, fromEncodedJson, fromJson (+9 more)

### Community 13 - "Community 13"
Cohesion: 0.12
Nodes (16): ArgumentError, copyWith, decode, encode, fromJson, HostedParticipant, HostedPendingDrinkDistribution, HostedProjectedView (+8 more)

### Community 14 - "Community 14"
Cohesion: 0.32
Nodes (15): bussruta(), farge(), intro(), kort_stokk(), krhs(), mellom_eller_utenfor(), over_under(), print_hånd() (+7 more)

### Community 15 - "Community 15"
Cohesion: 0.12
Nodes (15): AppBanner, AppStatusChip, AppSurfaceCard, AppTheme, bannerColor, bannerIcon, BoxDecoration, build (+7 more)

### Community 16 - "Community 16"
Cohesion: 0.12
Nodes (15): AnimatedContainer, AppSurfaceCard, build, Card, dispose, _HelpCard, _IntroSlide, OnboardingIntroScreen (+7 more)

### Community 17 - "Community 17"
Cohesion: 0.13
Nodes (15): Browser Play On The Same Network, Bussruta, bussruta_app, code:bash (flutter pub get), code:bash (dart format --output=none --set-exit-if-changed .), code:bash (dart run tool/internet_relay.dart --port 8080), code:bash (flutter run -d web-server --web-hostname 0.0.0.0 --web-port ), code:bash (graphify update .) (+7 more)

### Community 18 - "Community 18"
Cohesion: 0.12
Nodes (15): Bus route + finish, Drink distribution + bus control, Gameplay authority + privacy, Host + join, Hosted LAN mode, Known manual-only checks, Local mode, Manual QA Checklist (+7 more)

### Community 19 - "Community 19"
Cohesion: 0.13
Nodes (14): Bluetooth support, Current product decision, Current state in repo, Decisions needed from product owner, Feasibility, Internet room-key support, Multiplayer Options Evaluation, Recommendation (+6 more)

### Community 20 - "Community 20"
Cohesion: 0.16
Nodes (13): code:bash (dart run tool/internet_relay.dart --port 8080), code:text (ws://127.0.0.1:8080/ws), code:text (ws://<pc-lan-ip>:8080/ws), code:bash (flutter run -d web-server --web-hostname 0.0.0.0 --web-port ), code:json ({"type":"host.create","roomKey":"ROOM42"}), code:json ({"type":"player.join","roomKey":"ROOM42","payload":{"type":"), code:json ({"type":"client.message","payload":{"type":"command","comman), code:json ({"type":"host.message","clientId":"client-1","payload":{"typ) (+5 more)

### Community 21 - "Community 21"
Cohesion: 0.18
Nodes (10): applyLocalCommand, HostedLanClientConnection, HostedLanDiscovery, HostedLanHostServer, projectHostedView, projectionForHost, projectionForPlayer, sendCommand (+2 more)

### Community 22 - "Community 22"
Cohesion: 0.18
Nodes (10): _busSetupState, card, HostedSessionCommand, HostedSessionState, main, PlayerState, PlayingCard, _pyramidState (+2 more)

### Community 23 - "Community 23"
Cohesion: 0.22
Nodes (8): _busRoute, BusRouteState, card, HostedSessionState, main, PlayingCard, _sessionState, package:bussruta_app/domain/hosted_projection.dart

### Community 24 - "Community 24"
Cohesion: 0.25
Nodes (8): code:text (android/key.properties), code:bash (dart format --output=none --set-exit-if-changed .), Current Baseline, Local Signing Setup, Next Product Track, Recommended Release Gate, Release Readiness, Required Before Release

### Community 25 - "Community 25"
Cohesion: 0.38
Nodes (4): rødt_svart(), spill(), start(), trekk_kort()

### Community 26 - "Community 26"
Cohesion: 0.29
Nodes (6): code:powershell (adb -s emulator-5554 forward tcp:45879 tcp:45879), code:powershell (adb -s emulator-5554 forward --remove tcp:45879), Hosted LAN Testing On Android Emulators, Real-device expectation, Recommended emulator workflow, Why join fails by default

### Community 27 - "Community 27"
Cohesion: 0.33
Nodes (5): HostedProjectedView, HostedPublicView, projectHostedPublicView, projectHostedView, package:bussruta_app/domain/hosted_models.dart

### Community 28 - "Community 28"
Cohesion: 0.4
Nodes (4): code:bash (python -m http.server 8000), Game flow implemented, Run locally, UI tweaks included

### Community 32 - "Community 32"
Cohesion: 0.5
Nodes (3): copyWith, HostedClientIssue, HostedDiscoveryEntry

## Knowledge Gaps
- **608 isolated node(s):** `MainActivity`, `SUITS`, `RANK_LABELS`, `PYRAMID_ROWS`, `state` (+603 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:bussruta_app/domain/game_models.dart` connect `Community 3` to `Community 1`, `Community 2`, `Community 4`, `Community 5`, `Community 7`, `Community 8`, `Community 10`, `Community 11`, `Community 13`, `Community 16`, `Community 22`, `Community 23`, `Community 27`?**
  _High betweenness centrality (0.178) - this node is a cross-community bridge._
- **Why does `dart:async` connect `Community 4` to `Community 1`, `Community 2`, `Community 5`, `Community 6`, `Community 8`, `Community 9`, `Community 10`, `Community 21`?**
  _High betweenness centrality (0.088) - this node is a cross-community bridge._
- **Why does `dart:math` connect `Community 9` to `Community 1`, `Community 2`, `Community 4`, `Community 5`, `Community 6`, `Community 7`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **What connects `MainActivity`, `SUITS`, `RANK_LABELS` to the rest of the system?**
  _608 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._