# Graph Report - bussruta  (2026-06-03)

## Corpus Check
- 67 files · ~71,653 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2166 nodes · 2877 edges · 94 communities (83 shown, 11 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `18724c81`
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
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 71|Community 71]]
- [[_COMMUNITY_Community 73|Community 73]]
- [[_COMMUNITY_Community 74|Community 74]]
- [[_COMMUNITY_Community 75|Community 75]]
- [[_COMMUNITY_Community 76|Community 76]]
- [[_COMMUNITY_Community 77|Community 77]]
- [[_COMMUNITY_Community 78|Community 78]]
- [[_COMMUNITY_Community 79|Community 79]]
- [[_COMMUNITY_Community 80|Community 80]]
- [[_COMMUNITY_Community 82|Community 82]]
- [[_COMMUNITY_Community 83|Community 83]]
- [[_COMMUNITY_Community 84|Community 84]]
- [[_COMMUNITY_Community 85|Community 85]]
- [[_COMMUNITY_Community 86|Community 86]]
- [[_COMMUNITY_Community 87|Community 87]]
- [[_COMMUNITY_Community 88|Community 88]]
- [[_COMMUNITY_Community 93|Community 93]]
- [[_COMMUNITY_Community 94|Community 94]]
- [[_COMMUNITY_Community 97|Community 97]]

## God Nodes (most connected - your core abstractions)
1. `_` - 37 edges
2. `tr()` - 31 edges
3. `renderAll()` - 20 edges
4. `revealPyramidSlot()` - 17 edges
5. `addLog()` - 15 edges
6. `Privacy Policy` - 15 edges
7. `runAutoPlayStep()` - 13 edges
8. `playBusGuess()` - 13 edges
9. `revealWarmupCardFromDeck()` - 12 edges
10. `renderControls()` - 11 edges

## Surprising Connections (you probably didn't know these)
- `_FakeStorage` --implements--> `GameStorage`  [EXTRACTED]
  test/application/game_controller_onboarding_test.dart → lib/application/game_storage.dart
- `_RecordingStorage` --implements--> `GameStorage`  [EXTRACTED]
  test/application/game_controller_setup_test.dart → lib/application/game_storage.dart
- `_FakeStorage` --implements--> `GameStorage`  [EXTRACTED]
  test/presentation/bussruta_app_onboarding_test.dart → lib/application/game_storage.dart
- `_FakeStorage` --implements--> `GameStorage`  [EXTRACTED]
  test/presentation/bussruta_app_ui_smoke_test.dart → lib/application/game_storage.dart
- `_FakeHostedSessionController` --inherits--> `HostedSessionController`  [EXTRACTED]
  test/presentation/bussruta_app_ui_smoke_test.dart → lib/application/hosted_session_controller.dart

## Import Cycles
- None detected.

## Communities (94 total, 11 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (93): addLog(), advanceWarmupTurn(), animateCardFlight(), animationScale(), applyVisualPreferences(), AUTO_PLAY_PRESETS, autoPlayControlsHtml(), beginBusRoute() (+85 more)

### Community 1 - "Community 1"
Cohesion: 0.02
Nodes (83): _addFlight, Align, _animateBusGuess, _animateBusRouteDeal, _animateBusZoneDelta, AnimatedContainer, AnimatedScale, _animatePyramidReveal (+75 more)

### Community 2 - "Community 2"
Cohesion: 0.03
Nodes (69): AnimatedBuilder, _bannerCard, build, _buildEntry, _buildGame, _buildLobby, _busRouteBoard, _busRouteView (+61 more)

### Community 3 - "Community 3"
Cohesion: 0.04
Nodes (47): acknowledgeDrinks, _applyHostAuthorityCommand, _applyHostStateToController, assignDrinks, _attemptReconnect, beginBusRoute, _bindClient, _bindHostServer (+39 more)

### Community 4 - "Community 4"
Cohesion: 0.08
Nodes (29): Duration, main, _next, StateError, _broadcastHostMessage, _closeHostRoom, _forwardClientMessage, _forwardHostMessage (+21 more)

### Community 5 - "Community 5"
Cohesion: 0.05
Nodes (36): applyLocalCommand, _broadcastSnapshots, closeForInvalidFrame, copyWith, Duration, _emit, _emitIssue, _emitProjection (+28 more)

### Community 6 - "Community 6"
Cohesion: 0.06
Nodes (35): _advanceWarmupTurn, ArgumentError, beginBusRoute, _busGuessPlacement, chooseBusGuessByStats, chooseWarmupGuessByStats, _compareCardRanks, _DeckDraw (+27 more)

### Community 7 - "Community 7"
Cohesion: 0.06
Nodes (31): AnimatedBuilder, AppBanner, AppSurfaceCard, _BannerCard, build, _buildHome, BussrutaApp, _BussrutaAppState (+23 more)

### Community 8 - "Community 8"
Cohesion: 0.07
Nodes (27): addPlayer, beginBusRoute, _cancelPendingSetupPersist, didChangeAppLifecycleState, dispose, _emit, GameController, hardResetSetup (+19 more)

### Community 9 - "Community 9"
Cohesion: 0.07
Nodes (27): addParticipant, _appendDrinkDistributionLog, applyCommand, _autoExpirePromptCommand, _compare, _expireStaleDrinkPrompts, _handleAcknowledgeDrinks, _handleAssignDrinks (+19 more)

### Community 10 - "Community 10"
Cohesion: 0.07
Nodes (27): applyLocalCommand, _broadcastSnapshots, _emitError, _emitIssue, _emitProjection, _emitState, _ensureTokenForPlayer, _handleClientDisconnect (+19 more)

### Community 11 - "Community 11"
Cohesion: 0.12
Nodes (18): Browser Play On The Same Network, Bussruta, bussruta_app, code:bash (flutter pub get), code:bash (dart format --output=none --set-exit-if-changed .), code:powershell (powershell -ExecutionPolicy Bypass -File tool\start_lan_web.), code:powershell (powershell -ExecutionPolicy Bypass -File tool\start_lan_web.), code:powershell (powershell -ExecutionPolicy Bypass -File tool\start_lan_web.) (+10 more)

### Community 12 - "Community 12"
Cohesion: 0.11
Nodes (17): AutoPlayState, BusHistoryEntry, BusRouteState, BusZoneStack, BusZoneTone, copyWith, fromEncodedJson, fromJson (+9 more)

### Community 13 - "Community 13"
Cohesion: 0.11
Nodes (17): Bus route + finish, Drink distribution + bus control, Gameplay authority + privacy, Host + join, Hosted browser relay mode, Hosted LAN mode, Known manual-only checks, Local mode (+9 more)

### Community 14 - "Community 14"
Cohesion: 0.15
Nodes (12): assignDrinks, _FakeHostedSessionController, _FakeStorage, _hostedProjection, main, PlatformException, projectHostedView, _pumpApp (+4 more)

### Community 15 - "Community 15"
Cohesion: 0.40
Nodes (5): GameController, HostedSessionController, ChangeNotifier, _FakeHostedSessionController, WidgetsBindingObserver

### Community 16 - "Community 16"
Cohesion: 0.32
Nodes (15): bussruta(), farge(), intro(), kort_stokk(), krhs(), mellom_eller_utenfor(), over_under(), print_hånd() (+7 more)

### Community 17 - "Community 17"
Cohesion: 0.12
Nodes (15): AnimatedContainer, AppSurfaceCard, build, Card, dispose, _HelpCard, _IntroSlide, OnboardingIntroScreen (+7 more)

### Community 18 - "Community 18"
Cohesion: 0.12
Nodes (15): AppBanner, AppStatusChip, AppSurfaceCard, AppTheme, bannerColor, bannerIcon, BoxDecoration, build (+7 more)

### Community 19 - "Community 19"
Cohesion: 0.15
Nodes (14): code:powershell (powershell -ExecutionPolicy Bypass -File tool\start_lan_web.), code:json ({"type":"host.broadcast","payload":{"type":"session_closed",), code:bash (dart run tool/internet_relay.dart --port 8080), code:text (ws://127.0.0.1:8080/ws), code:text (ws://<pc-lan-ip>:8080/ws), code:bash (flutter build web), code:json ({"type":"host.create","roomKey":"ROOM42"}), code:json ({"type":"player.join","roomKey":"ROOM42","payload":{"type":") (+6 more)

### Community 20 - "Community 20"
Cohesion: 0.12
Nodes (14): Bluetooth support, Current product decision, Current state in repo, Decisions needed from product owner, Feasibility, Internet room-key support, Multiplayer Options Evaluation, Recommendation (+6 more)

### Community 21 - "Community 21"
Cohesion: 0.20
Nodes (9): DateTime, ServerSocket, close, deadline, main, port, socket, _unusedTcpPort (+1 more)

### Community 22 - "Community 22"
Cohesion: 0.20
Nodes (9): _busSetupState, card, HostedSessionCommand, HostedSessionState, main, PlayerState, PlayingCard, _pyramidState (+1 more)

### Community 23 - "Community 23"
Cohesion: 0.18
Nodes (10): applyLocalCommand, HostedLanClientConnection, HostedLanDiscovery, HostedLanHostServer, projectHostedView, projectionForHost, projectionForPlayer, sendCommand (+2 more)

### Community 24 - "Community 24"
Cohesion: 0.12
Nodes (13): GameStorage, SharedPrefsGameStorage, busGuessLabel, languageName, phaseLabel, tr, warmupGuessLabel, busState (+5 more)

### Community 25 - "Community 25"
Cohesion: 0.04
Nodes (45): clearGameState, _gameStateKey, _instance, _lastSavedGameStatePayload, loadGameState, loadOnboardingSeen, _onboardingSeenKey, _prefs (+37 more)

### Community 26 - "Community 26"
Cohesion: 0.11
Nodes (16): _busRoute, BusRouteState, card, HostedSessionState, main, PlayingCard, _sessionState, _busRoute (+8 more)

### Community 27 - "Community 27"
Cohesion: 0.26
Nodes (13): Ensure-FirewallRule(), Get-LanAddress(), Get-PortProcessIds(), Get-ProcessCommandLine(), Get-PythonExecutable(), Invoke-LoggedCommand(), Show-Help(), Start-LoggedProcess() (+5 more)

### Community 28 - "Community 28"
Cohesion: 0.20
Nodes (9): code:text (android/key.properties), code:bash (dart format --output=none --set-exit-if-changed .), Current Baseline, First Release Scope Decisions, Local Signing Setup, Next Product Track, Recommended Release Gate, Release Readiness (+1 more)

### Community 29 - "Community 29"
Cohesion: 0.17
Nodes (23): lag_kortstokk(), rødt_svart(), rødt_svart(), spill(), start(), trekk(), trekk_kort(), bussruta() (+15 more)

### Community 30 - "Community 30"
Cohesion: 0.22
Nodes (8): busState, card, initial, language, main, rank, suit, required PlayingCard draw,
  AppLanguage

### Community 31 - "Community 31"
Cohesion: 0.25
Nodes (6): code:powershell (adb -s emulator-5554 forward tcp:45879 tcp:45879), code:powershell (adb -s emulator-5554 forward --remove tcp:45879), Hosted LAN Testing On Android Emulators, Real-device expectation, Recommended emulator workflow, Why join fails by default

### Community 32 - "Community 32"
Cohesion: 0.13
Nodes (13): ArgumentError, HostedProjectedView, HostedPublicView, projectHostedPublicView, projectHostedView, _busRoute, _card, fromBusRoute (+5 more)

### Community 33 - "Community 33"
Cohesion: 0.02
Nodes (126): AppLanguage get, acknowledgeDrinks, addresses, _applyHostAuthorityCommand, _applyHostStateToController, assignDrinks, _attemptReconnect, _autoPlayRunning (+118 more)

### Community 34 - "Community 34"
Cohesion: 0.47
Nodes (4): code:bash (python -m http.server 8000), Game flow implemented, Run locally, UI tweaks included

### Community 35 - "Community 35"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 36 - "Community 36"
Cohesion: 0.25
Nodes (5): Any, FlutterAppDelegate, Bool, AppDelegate, UIApplication

### Community 38 - "Community 38"
Cohesion: 0.50
Nodes (3): copyWith, HostedClientIssue, HostedDiscoveryEntry

### Community 39 - "Community 39"
Cohesion: 0.25
Nodes (6): 2026-05-09 QA Findings Fix Pass, 2026-05-09 Release Smoke, 2026-06-03 Browser Relay Fix And In-App Browser QA, 2026-06-03 Physical Local Gameplay QA Availability Check, 2026-06-03 Technical Release Gate, Manual QA Results

### Community 46 - "Community 46"
Cohesion: 0.02
Nodes (114): Offset, active, _addFlight, _animateBusGuess, _animateBusRouteDeal, _animateBusZoneDelta, _animatePyramidReveal, _animateTieBreak (+106 more)

### Community 52 - "Community 52"
Cohesion: 0.02
Nodes (81): _announcementType, applyLocalCommand, _beaconSocket, _beaconTimer, _broadcastSnapshots, _carriageReturn, _cleanupTimer, close (+73 more)

### Community 53 - "Community 53"
Cohesion: 0.02
Nodes (81): AnimationController?, AnimationController get, Color, _bannerCard, _browserAppUrl, build, _buildEntry, _buildGame (+73 more)

### Community 54 - "Community 54"
Cohesion: 0.03
Nodes (77): assignedDrinksByTarget, autoPlayDelayMs, autoPlayEnabled, banner, bannerTone, busRoute, busRunnerPlayerId, canControlBusRoute (+69 more)

### Community 55 - "Community 55"
Cohesion: 0.03
Nodes (70): autoPlay, AutoPlayState, banner, BannerTone, BusGuess, BusHistoryEntry, busRoute, BusRouteState (+62 more)

### Community 56 - "Community 56"
Cohesion: 0.03
Nodes (57): applyLocalCommand, _broadcastSnapshots, _channel, _clientIdByPlayerId, close, _closingLocally, connect, _decodeObject (+49 more)

### Community 57 - "Community 57"
Cohesion: 0.03
Nodes (57): _advanceWarmupTurn, beginBusRoute, _busGuessPlacement, busRouteLength, card, chooseBusGuessByStats, chooseWarmupGuessByStats, _collectPyramidMatches (+49 more)

### Community 58 - "Community 58"
Cohesion: 0.04
Nodes (44): addPlayer, _autoPlayRunning, _autoPlayTimer, beginBusRoute, _cancelPendingSetupPersist, consumeErrorMessage, didChangeAppLifecycleState, dispose (+36 more)

### Community 59 - "Community 59"
Cohesion: 0.05
Nodes (43): Completer, HttpServer?, Map, StreamSubscription, _broadcastHostMessage, cancel, client, clientId (+35 more)

### Community 60 - "Community 60"
Cohesion: 0.05
Nodes (40): BannerTone, GamePhase, HostedProjectedView, HostedSessionStage, HostedConnectionStatus get, HostedPendingDrinkDistribution? pendingDrinkDistribution,
  String, assignDrinks, assignedTargets (+32 more)

### Community 61 - "Community 61"
Cohesion: 0.05
Nodes (37): addParticipant, _appendDrinkDistributionLog, applyCommand, _autoExpirePromptCommand, _busRunnerPlayerId, _compare, drinkDrinks, _engine (+29 more)

### Community 62 - "Community 62"
Cohesion: 0.05
Nodes (36): GlobalKey, NavigatorState, _AppMode, build, _buildHome, controller, createState, description (+28 more)

### Community 63 - "Community 63"
Cohesion: 0.06
Nodes (33): EdgeInsetsGeometry, _, AppBanner, AppBannerTone, AppStatusChip, AppSurfaceCard, AppSurfaceTone, AppTheme (+25 more)

### Community 64 - "Community 64"
Cohesion: 0.06
Nodes (31): applyLocalCommand, close, connect, entries, errors, hostAddress, HostedLanClientConnection, HostedLanDiscovery (+23 more)

### Community 65 - "Community 65"
Cohesion: 0.14
Nodes (13): deadline, hasNext, main, _messages, _next, _nextOrNull, runtime, start (+5 more)

### Community 66 - "Community 66"
Cohesion: 0.09
Nodes (23): _BannerCard, _GameScreen, _LanguageMenu, _ModeChoiceCard, _SetupScreen, _StartModeScreen, _StatusStrip, _BusBase (+15 more)

### Community 67 - "Community 67"
Cohesion: 0.22
Nodes (8): Duration, expectLater, Function, HostedProjectedView, main, StateError, _waitFor, package:bussruta_app/application/hosted_lan_transport.dart

### Community 68 - "Community 68"
Cohesion: 0.09
Nodes (21): AppLanguage, IconData, PageController, body, build, bullets, child, _controller (+13 more)

### Community 69 - "Community 69"
Cohesion: 0.09
Nodes (21): HostedParticipant, HostedPublicView, _buildPublicPlayers, busRunnerPlayerId, canControlBusRoute, _currentTurnPlayerId, drinkPromptDrinks, giveOutPromptDrinks (+13 more)

### Community 70 - "Community 70"
Cohesion: 0.11
Nodes (17): Ads And Payments Planned For The Future, Changes, Children, Hosted LAN and relay play, How Information Is Used, Information Handled By The App, Information We Do Not Currently Collect, International Transfers (+9 more)

### Community 71 - "Community 71"
Cohesion: 0.13
Nodes (14): code, copyWith, hostAddress, HostedClientIssue, HostedClientIssueCode, HostedDiscoveryEntry, hostedDiscoveryPort, hostedSessionPort (+6 more)

### Community 73 - "Community 73"
Cohesion: 0.24
Nodes (11): BussrutaApp, _BussrutaAppState, GameTableView, _GameTableViewState, OnboardingIntroScreen, _OnboardingIntroScreenState, HostedSessionView, _HostedSessionViewState (+3 more)

### Community 74 - "Community 74"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 75 - "Community 75"
Cohesion: 0.12
Nodes (15): clearGameState, _FakeStorage, loadGameState, loadOnboardingSeen, main, onboardingSeen, savedGameState, savedOnboardingSeen (+7 more)

### Community 76 - "Community 76"
Cohesion: 0.20
Nodes (9): Duration, expectLater, Function, HostedSessionCommand, main, _next, StateError, _waitFor (+1 more)

### Community 77 - "Community 77"
Cohesion: 0.11
Nodes (20): clearGameState, loadGameState, loadOnboardingSeen, main, savedGameStates, saveGameState, saveOnboardingSeen, _FakeStorage (+12 more)

### Community 78 - "Community 78"
Cohesion: 0.22
Nodes (8): Age Rating And Content, Apple App Privacy, Current Build, Google Play Data Safety, Official Source Links, Screenshots Needed, Store Disclosures And Release Metadata, Suggested Descriptions

### Community 79 - "Community 79"
Cohesion: 0.22
Nodes (8): Browser Play On The Same Network, Bussruta, Current Status, Graphify, Hosted LAN Testing, Project Layout, Release Readiness, Run Locally

### Community 80 - "Community 80"
Cohesion: 0.25
Nodes (7): busGuessLabel, language, languageName, phaseLabel, tr, warmupGuessLabel, return

### Community 82 - "Community 82"
Cohesion: 0.40
Nodes (4): images, info, author, version

### Community 83 - "Community 83"
Cohesion: 0.17
Nodes (11): _FakeStorage, main, package:bussruta_app/presentation/bussruta_app.dart, package:bussruta_app/presentation/help_view.dart, clearGameState, loadGameState, loadOnboardingSeen, main (+3 more)

### Community 84 - "Community 84"
Cohesion: 0.40
Nodes (4): images, info, author, version

### Community 93 - "Community 93"
Cohesion: 0.18
Nodes (10): _completesSoon, deadline, lastError, main, _projectionJson, _startServer, timeout, _waitFor (+2 more)

### Community 94 - "Community 94"
Cohesion: 0.22
Nodes (8): _busSetupState, card, main, _pyramidState, rank, suit, _warmupState, package:bussruta_app/application/hosted_session_runtime.dart

### Community 97 - "Community 97"
Cohesion: 0.17
Nodes (10): main, main, _busRoute, BusRouteState, _card, HostedProjectedView, main, PlayingCard (+2 more)

## Knowledge Gaps
- **1680 isolated node(s):** `String`, `SBFrame`, `SBDebugger`, `flutter_export_environment.sh script`, `UIApplication` (+1675 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `Community 63` to `Community 68`, `Community 77`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **Why does `AppLanguage` connect `Community 68` to `Community 33`, `Community 46`, `Community 53`, `Community 54`, `Community 55`, `Community 62`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **Why does `GameEngine` connect `Community 61` to `Community 33`, `Community 58`, `Community 57`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `String`, `SBFrame`, `SBDebugger` to the rest of the system?**
  _1681 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.07704367301231803 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.023809523809523808 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.02857142857142857 - nodes in this community are weakly interconnected._