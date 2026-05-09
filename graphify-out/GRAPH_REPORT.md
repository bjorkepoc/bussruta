# Graph Report - bussruta  (2026-05-09)

## Corpus Check
- 46 files · ~51,700 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 657 nodes · 878 edges · 39 communities (31 shown, 8 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7b213af2`
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

## God Nodes (most connected - your core abstractions)
1. `tr()` - 30 edges
2. `renderAll()` - 19 edges
3. `package:bussruta_app/domain/game_models.dart` - 19 edges
4. `revealPyramidSlot()` - 16 edges
5. `addLog()` - 14 edges
6. `runAutoPlayStep()` - 12 edges
7. `playBusGuess()` - 12 edges
8. `revealWarmupCardFromDeck()` - 11 edges
9. `renderControls()` - 10 edges
10. `startGame()` - 9 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (39 total, 8 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (90): addLog(), advanceWarmupTurn(), animateCardFlight(), animationScale(), applyVisualPreferences(), AUTO_PLAY_PRESETS, autoPlayControlsHtml(), beginBusRoute() (+82 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (78): Align, _animateBusGuess, _animateBusRouteDeal, _animateBusZoneDelta, AnimatedContainer, AnimatedScale, _animatePyramidReveal, _animateTieBreak (+70 more)

### Community 2 - "Community 2"
Cohesion: 0.04
Nodes (54): AnimatedBuilder, _bannerCard, build, _buildEntry, _buildGame, _buildLobby, _busRouteBoard, _busRouteView (+46 more)

### Community 3 - "Community 3"
Cohesion: 0.05
Nodes (46): AnimatedBuilder, _BannerCard, build, _buildHome, BussrutaApp, _BussrutaAppState, Container, DecoratedBox (+38 more)

### Community 4 - "Community 4"
Cohesion: 0.05
Nodes (36): applyLocalCommand, _broadcastSnapshots, closeForInvalidFrame, copyWith, Duration, _emit, _emitIssue, _emitProjection (+28 more)

### Community 5 - "Community 5"
Cohesion: 0.05
Nodes (36): _advanceWarmupTurn, ArgumentError, beginBusRoute, _busGuessPlacement, chooseBusGuessByStats, chooseWarmupGuessByStats, _compareCardRanks, _DeckDraw (+28 more)

### Community 6 - "Community 6"
Cohesion: 0.06
Nodes (35): acknowledgeDrinks, assignDrinks, _attemptReconnect, beginBusRoute, _bindClient, _bindHostServer, _dispatch, dispose (+27 more)

### Community 7 - "Community 7"
Cohesion: 0.06
Nodes (32): AutoPlayState, BusHistoryEntry, BusRouteState, BusZoneStack, BusZoneTone, copyWith, fromEncodedJson, fromJson (+24 more)

### Community 8 - "Community 8"
Cohesion: 0.07
Nodes (27): addParticipant, _appendDrinkDistributionLog, applyCommand, _autoExpirePromptCommand, _compare, _expireStaleDrinkPrompts, _handleAcknowledgeDrinks, _handleAssignDrinks (+19 more)

### Community 9 - "Community 9"
Cohesion: 0.08
Nodes (25): addPlayer, beginBusRoute, didChangeAppLifecycleState, dispose, _emit, GameController, hardResetSetup, markOnboardingSeen (+17 more)

### Community 10 - "Community 10"
Cohesion: 0.32
Nodes (15): bussruta(), farge(), intro(), kort_stokk(), krhs(), mellom_eller_utenfor(), over_under(), print_hånd() (+7 more)

### Community 11 - "Community 11"
Cohesion: 0.12
Nodes (15): Bus route + finish, Drink distribution + bus control, Gameplay authority + privacy, Host + join, Hosted LAN mode, Known manual-only checks, Local mode, Manual QA Checklist (+7 more)

### Community 12 - "Community 12"
Cohesion: 0.14
Nodes (13): AnimatedContainer, build, Card, dispose, _HelpCard, _IntroSlide, OnboardingIntroScreen, _OnboardingIntroScreenState (+5 more)

### Community 13 - "Community 13"
Cohesion: 0.15
Nodes (12): Bussruta, bussruta_app, code:bash (flutter pub get), code:bash (dart format --output=none --set-exit-if-changed .), code:bash (graphify update .), Current Status, Getting Started, Graphify (+4 more)

### Community 14 - "Community 14"
Cohesion: 0.15
Nodes (12): Bluetooth support, Current product decision, Current state in repo, Decisions needed from product owner, Feasibility, Internet room-key support, Multiplayer Options Evaluation, Recommendation (+4 more)

### Community 15 - "Community 15"
Cohesion: 0.18
Nodes (10): Duration, expectLater, Function, HostedProjectedView, main, _waitFor, dart:async, dart:io (+2 more)

### Community 16 - "Community 16"
Cohesion: 0.2
Nodes (9): _busSetupState, card, HostedSessionCommand, HostedSessionState, main, PlayerState, PlayingCard, _pyramidState (+1 more)

### Community 17 - "Community 17"
Cohesion: 0.22
Nodes (8): _busRoute, BusRouteState, card, HostedSessionState, main, PlayingCard, _sessionState, package:bussruta_app/domain/hosted_projection.dart

### Community 18 - "Community 18"
Cohesion: 0.38
Nodes (4): rødt_svart(), spill(), start(), trekk_kort()

### Community 19 - "Community 19"
Cohesion: 0.29
Nodes (6): _busRoute, BusRouteState, _card, HostedProjectedView, main, PlayingCard

### Community 20 - "Community 20"
Cohesion: 0.29
Nodes (6): code:powershell (adb -s emulator-5554 forward tcp:45879 tcp:45879), code:powershell (adb -s emulator-5554 forward --remove tcp:45879), Hosted LAN Testing On Android Emulators, Real-device expectation, Recommended emulator workflow, Why join fails by default

### Community 21 - "Community 21"
Cohesion: 0.29
Nodes (6): code:bash (dart format --output=none --set-exit-if-changed .), Current Baseline, Next Product Track, Recommended Release Gate, Release Readiness, Required Before Release

### Community 22 - "Community 22"
Cohesion: 0.33
Nodes (5): busGuessLabel, languageName, phaseLabel, tr, warmupGuessLabel

### Community 23 - "Community 23"
Cohesion: 0.4
Nodes (4): GameStorage, SharedPrefsGameStorage, package:bussruta_app/domain/game_models.dart, package:shared_preferences/shared_preferences.dart

### Community 24 - "Community 24"
Cohesion: 0.4
Nodes (4): code:bash (python -m http.server 8000), Game flow implemented, Run locally, UI tweaks included

### Community 28 - "Community 28"
Cohesion: 0.5
Nodes (3): HostedProjectedView, projectHostedView, package:bussruta_app/domain/hosted_models.dart

## Knowledge Gaps
- **470 isolated node(s):** `MainActivity`, `SUITS`, `RANK_LABELS`, `PYRAMID_ROWS`, `state` (+465 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:bussruta_app/domain/game_models.dart` connect `Community 23` to `Community 1`, `Community 2`, `Community 3`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 12`, `Community 15`, `Community 16`, `Community 17`, `Community 19`, `Community 22`, `Community 28`?**
  _High betweenness centrality (0.205) - this node is a cross-community bridge._
- **Why does `dart:async` connect `Community 15` to `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 6`, `Community 9`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **Why does `dart:math` connect `Community 5` to `Community 1`, `Community 2`, `Community 4`, `Community 6`?**
  _High betweenness centrality (0.048) - this node is a cross-community bridge._
- **What connects `MainActivity`, `SUITS`, `RANK_LABELS` to the rest of the system?**
  _470 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._