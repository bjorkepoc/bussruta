import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/application/game_storage.dart';
import 'package:bussruta_app/application/hosted_session_controller.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:bussruta_app/domain/hosted_projection.dart';
import 'package:bussruta_app/presentation/bussruta_app.dart';
import 'package:bussruta_app/presentation/hosted_session_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/internet_relay.dart';

void main() {
  testWidgets(
    'start mode screen exposes local hosted help intro and language',
    (WidgetTester tester) async {
      await _pumpApp(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Hosted'), findsOneWidget);
      expect(find.text('Quick intro'), findsOneWidget);
      expect(find.text('How to play'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
    },
  );

  testWidgets(
    'local setup opens under small phone text scale with setup controls',
    (WidgetTester tester) async {
      await _withPhoneViewport(tester, () async {
        await _pumpApp(tester);

        await tester.tap(find.text('Local'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Start game'), findsOneWidget);
        expect(find.text('Players: 4'), findsOneWidget);
        expect(
          find.byType(TextFormField, skipOffstage: false),
          findsNWidgets(4),
        );
      });
    },
  );

  testWidgets('local setup edits names and system back returns to modes', (
    WidgetTester tester,
  ) async {
    final GameController controller = await _pumpApp(tester);

    await tester.tap(find.text('Local'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'TestA');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.state.setupDraft.names.first, 'TestA');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Hosted'), findsOneWidget);
  });

  testWidgets('norwegian setup exposes native tooltip labels', (
    WidgetTester tester,
  ) async {
    final GameController controller = await _pumpApp(tester);

    controller.setLanguage(AppLanguage.no);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lokal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Tilbake til valg'), findsOneWidget);
    expect(find.byTooltip('Språk'), findsOneWidget);
    expect(find.byTooltip('Fjern spiller 1'), findsOneWidget);
  });

  testWidgets('starting a local game renders warmup black and red choices', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Local'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Warmup 1/4'), findsOneWidget);
    expect(find.text('Black'), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
  });

  testWidgets('norwegian localization keeps native card and setup terms', (
    WidgetTester tester,
  ) async {
    final GameController controller = await _pumpApp(tester);

    controller.setLanguage(AppLanguage.no);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('på en enhet'), findsWidgets);

    await tester.tap(find.text('Lokal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Klar til å dele ut?'), findsOneWidget);
    expect(find.text('Velg bordstørrelse for utdeling.'), findsOneWidget);

    controller.setPlayerCount(1);
    controller.startGameFromSetup();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Rødt'), findsOneWidget);

    controller.playWarmupGuess(WarmupGuess.black);
    controller.playWarmupGuess(WarmupGuess.above);
    controller.playWarmupGuess(WarmupGuess.between);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kløver'), findsOneWidget);
  });

  testWidgets('local game renders warmup choice sets pyramid and bus route', (
    WidgetTester tester,
  ) async {
    final GameController controller = await _pumpApp(tester);

    controller.setPlayerCount(1);
    controller.startGameFromSetup();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Warmup 1/4'), findsOneWidget);
    expect(find.text('Black'), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);

    controller.playWarmupGuess(WarmupGuess.black);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Warmup 2/4'), findsOneWidget);
    expect(find.text('Higher'), findsOneWidget);
    expect(find.text('Lower'), findsOneWidget);
    expect(find.text('Same'), findsOneWidget);

    controller.playWarmupGuess(WarmupGuess.above);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Warmup 3/4'), findsOneWidget);
    expect(find.text('Between'), findsOneWidget);
    expect(find.text('Outside'), findsOneWidget);
    expect(find.text('Same'), findsOneWidget);

    controller.playWarmupGuess(WarmupGuess.between);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Warmup 4/4'), findsOneWidget);
    expect(find.text('Clubs'), findsOneWidget);
    expect(find.text('Diamonds'), findsOneWidget);
    expect(find.text('Hearts'), findsOneWidget);
    expect(find.text('Spades'), findsOneWidget);

    controller.playWarmupGuess(WarmupGuess.clubs);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.state.phase, GamePhase.pyramid);
    expect(find.text('Pyramid'), findsOneWidget);
    expect(find.text('Tap deck to reveal next pyramid card'), findsOneWidget);

    for (int i = 0; i < 15; i += 1) {
      controller.revealPyramidNext();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    expect(controller.state.phase, GamePhase.bussetup);
    expect(find.text('Bus Setup'), findsOneWidget);
    expect(find.text('Start Left'), findsOneWidget);
    expect(find.text('Start Right'), findsOneWidget);

    controller.beginBusRoute(BusStartSide.left);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.state.phase, GamePhase.bus);
    expect(find.text('Bus Route'), findsOneWidget);
    expect(find.text('ABOVE'), findsWidgets);
    expect(find.text('BELOW'), findsWidgets);
    expect(find.text('Same'), findsWidgets);
  });

  testWidgets('hosted entry opens with host and join surfaces', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Hosted'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Browser / same-network room'), findsOneWidget);
    expect(find.text('Relay URL'), findsOneWidget);
    expect(find.text('Room key'), findsOneWidget);
    expect(find.text('Host room'), findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);
    expect(find.text('Host a LAN game'), findsOneWidget);
    expect(find.text('Host game'), findsOneWidget);
    expect(find.text('Join a hosted game'), findsOneWidget);
    expect(find.text('PIN code'), findsOneWidget);
    expect(find.text('Host address (host or host:port)'), findsOneWidget);
    expect(find.text('Join by PIN'), findsOneWidget);
  });

  testWidgets('hosted entry leaves default player name for role fallback', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Hosted'));
    await tester.pumpAndSettle();

    final TextField nameField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Your name'),
    );
    expect(nameField.controller?.text, isEmpty);
    expect(nameField.decoration?.hintText, 'Host or Player 2');
  });

  test('hosted relay default can be prefilled from app link', () {
    expect(
      defaultHostedRelayUrl(
        Uri.parse(
          'http://192.168.10.104:8091/?relayUrl=ws%3A%2F%2F192.168.10.104%3A8090%2Fws',
        ),
      ),
      'ws://192.168.10.104:8090/ws',
    );

    expect(
      defaultHostedRelayUrl(Uri.parse('http://192.168.10.104:8081/')),
      'ws://192.168.10.104:8080/ws',
    );

    expect(
      defaultHostedRelayUrl(Uri.parse('https://play.example.com/')),
      'wss://play.example.com:8080/ws',
    );

    expect(
      defaultHostedRelayUrl(Uri.parse('http://[2001:db8::1]:8081/')),
      'ws://[2001:db8::1]:8080/ws',
    );
  });

  testWidgets('hosted entry system back returns to mode chooser', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Hosted'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Hosted'), findsOneWidget);
  });

  testWidgets('relay lobby exposes copyable join details', (
    WidgetTester tester,
  ) async {
    final InternetRelayServer relay = InternetRelayServer();
    await tester.runAsync(relay.start);

    final HostedSessionController controller = HostedSessionController(
      enableLanDiscovery: false,
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HostedSessionView(
            controller: controller,
            language: AppLanguage.en,
            onBackToModeChooser: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(
        () => controller.startRelayHosting(
          hostName: 'Host',
          relayUrl: relay.uri.toString(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Relay join details'), findsOneWidget);

      await tester.tap(find.text('Relay join details'));
      await tester.pumpAndSettle();

      expect(find.text('Copy join details'), findsOneWidget);
      expect(find.text(relay.uri.toString()), findsOneWidget);
      expect(find.text(controller.relayRoomKey!), findsWidgets);

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final Object? text =
                (methodCall.arguments as Map<dynamic, dynamic>)['text'];
            clipboardText = text as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(find.text('Copy join details'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Copied'), findsOneWidget);
      expect(clipboardText, contains('Relay URL: ${relay.uri}'));
      expect(clipboardText, contains('Room key: ${controller.relayRoomKey}'));
    } finally {
      controller.dispose();
      await tester.runAsync(relay.close);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('relay copy failure keeps error state instead of copied', (
    WidgetTester tester,
  ) async {
    final InternetRelayServer relay = InternetRelayServer();
    await tester.runAsync(relay.start);

    final HostedSessionController controller = HostedSessionController(
      enableLanDiscovery: false,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard-denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HostedSessionView(
            controller: controller,
            language: AppLanguage.en,
            onBackToModeChooser: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(
        () => controller.startRelayHosting(
          hostName: 'Host',
          relayUrl: relay.uri.toString(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Relay join details'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy join details'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Copied'), findsNothing);
      expect(find.text('Copy failed'), findsOneWidget);
    } finally {
      controller.dispose();
      await tester.runAsync(relay.close);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('hosted lobby distinguishes generic fallback player names', (
    WidgetTester tester,
  ) async {
    final _FakeHostedSessionController controller =
        _FakeHostedSessionController(
          _hostedProjection(
            stage: HostedSessionStage.lobby,
            phase: GamePhase.setup,
            players: const <HostedParticipant>[
              HostedParticipant(
                playerId: 1,
                name: 'Player',
                isHost: true,
                connected: true,
              ),
              HostedParticipant(
                playerId: 2,
                name: 'Player',
                isHost: false,
                connected: true,
              ),
            ],
            viewerPlayerId: 1,
            pendingDrinkDistribution: null,
          ),
        );

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HostedSessionView(
            controller: controller,
            language: AppLanguage.en,
            onBackToModeChooser: () {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Host'), findsWidgets);
      expect(find.text('Player 2'), findsWidgets);
      expect(find.text('Player'), findsNothing);
    } finally {
      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('pending drink source sees assignment status', (
    WidgetTester tester,
  ) async {
    final _FakeHostedSessionController controller =
        _FakeHostedSessionController(
          _hostedProjection(
            phase: GamePhase.warmup,
            currentPlayerIndex: 0,
            viewerPlayerId: 2,
            players: const <HostedParticipant>[
              HostedParticipant(
                playerId: 1,
                name: 'Player',
                isHost: true,
                connected: true,
              ),
              HostedParticipant(
                playerId: 2,
                name: 'Player',
                isHost: false,
                connected: true,
              ),
            ],
            pendingDrinkDistribution: const HostedPendingDrinkDistribution(
              sourcePlayerId: 2,
              totalDrinks: 1,
              assignedDrinksByTarget: <int, int>{},
              reason: 'Warmup round 1',
            ),
          ),
        );

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HostedSessionView(
            controller: controller,
            language: AppLanguage.en,
            onBackToModeChooser: () {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Assign drinks'), findsWidgets);
      expect(find.text('Waiting for Player'), findsNothing);
      expect(find.text('You are Player 2.'), findsOneWidget);
    } finally {
      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('pending drink distribution blocks your-turn status', (
    WidgetTester tester,
  ) async {
    final _FakeHostedSessionController controller =
        _FakeHostedSessionController(
          _hostedProjection(
            phase: GamePhase.warmup,
            currentPlayerIndex: 1,
            viewerPlayerId: 2,
            pendingDrinkDistribution: const HostedPendingDrinkDistribution(
              sourcePlayerId: 1,
              totalDrinks: 1,
              assignedDrinksByTarget: <int, int>{},
              reason: 'Warmup round 1',
            ),
          ),
        );

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HostedSessionView(
            controller: controller,
            language: AppLanguage.en,
            onBackToModeChooser: () {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Your turn'), findsNothing);
      expect(
        find.text('Waiting for another player to distribute drinks.'),
        findsOneWidget,
      );
    } finally {
      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('drink assignment action stays in first viewport at 1280x720', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final _FakeHostedSessionController controller =
        _FakeHostedSessionController(
          _hostedProjection(
            phase: GamePhase.warmup,
            currentPlayerIndex: 0,
            viewerPlayerId: 1,
            players: const <HostedParticipant>[
              HostedParticipant(
                playerId: 1,
                name: 'Host',
                isHost: true,
                connected: true,
              ),
              HostedParticipant(
                playerId: 2,
                name: 'Player 2',
                isHost: false,
                connected: true,
              ),
              HostedParticipant(
                playerId: 3,
                name: 'Player 3',
                isHost: false,
                connected: true,
              ),
              HostedParticipant(
                playerId: 4,
                name: 'Player 4',
                isHost: false,
                connected: true,
              ),
            ],
            pendingDrinkDistribution: const HostedPendingDrinkDistribution(
              sourcePlayerId: 1,
              totalDrinks: 4,
              assignedDrinksByTarget: <int, int>{},
              reason: 'Warmup round 1',
            ),
            banner: 'Player drew KS. Correct, give out 4 drinks.',
            bannerTone: BannerTone.success,
          ),
        );

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HostedSessionView(
            controller: controller,
            language: AppLanguage.en,
            onBackToModeChooser: () {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byTooltip('Add one drink to Host', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Send assignment', skipOffstage: false), findsOneWidget);
      final Rect sendButtonRect = tester.getRect(find.text('Send assignment'));
      expect(sendButtonRect.bottom, lessThanOrEqualTo(720));
      final Rect publicTableRect = tester.getRect(find.text('Public table'));
      expect(sendButtonRect.top, lessThan(publicTableRect.top));
    } finally {
      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

HostedProjectedView _hostedProjection({
  HostedSessionStage stage = HostedSessionStage.inGame,
  GamePhase phase = GamePhase.warmup,
  int currentPlayerIndex = 0,
  int viewerPlayerId = 1,
  List<HostedParticipant> players = const <HostedParticipant>[
    HostedParticipant(playerId: 1, name: 'Host', isHost: true, connected: true),
    HostedParticipant(
      playerId: 2,
      name: 'Guest',
      isHost: false,
      connected: true,
    ),
  ],
  HostedPendingDrinkDistribution? pendingDrinkDistribution,
  String banner = '',
  BannerTone bannerTone = BannerTone.info,
}) {
  final GameState gameState = GameState.initial().copyWith(
    phase: phase,
    currentPlayerIndex: currentPlayerIndex,
    banner: banner,
    bannerTone: bannerTone,
    players: players
        .map(
          (HostedParticipant player) =>
              PlayerState(name: player.name, hand: const <PlayingCard>[]),
        )
        .toList(),
  );
  final HostedSessionState session = HostedSessionState(
    sessionPin: '1234',
    hostPlayerId: 1,
    stage: stage,
    participants: players,
    playerOrder: players
        .map((HostedParticipant player) => player.playerId)
        .toList(),
    gameState: gameState,
    pendingDrinkDistribution: pendingDrinkDistribution,
    queuedDrinkDistributions: const <HostedPendingDrinkDistribution>[],
    pendingDrinkPenaltyByPlayer: const <int, int>{},
    lastError: null,
  );
  return projectHostedView(session: session, viewerPlayerId: viewerPlayerId);
}

class _FakeHostedSessionController extends HostedSessionController {
  _FakeHostedSessionController(this._projection)
    : super(enableLanDiscovery: false);

  final HostedProjectedView _projection;
  Map<int, int>? assignedTargets;

  @override
  HostedConnectionStatus get connectionStatus =>
      HostedConnectionStatus.connected;

  @override
  bool get hasActiveSession => true;

  @override
  bool get isHost => _projection.isHost;

  @override
  int? get localPlayerId => _projection.viewerPlayerId;

  @override
  HostedProjectedView? get projection => _projection;

  @override
  Future<void> initialize({required AppLanguage language}) async {}

  @override
  void assignDrinks(Map<int, int> targets) {
    assignedTargets = Map<int, int>.from(targets);
  }
}

Future<GameController> _pumpApp(WidgetTester tester) async {
  final GameController controller = GameController(
    engine: GameEngine(),
    storage: _FakeStorage(onboardingSeen: true),
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(BussrutaApp(controller: controller));
  await controller.initialize();
  await tester.pump();
  await tester.pumpAndSettle();

  return controller;
}

Future<void> _withPhoneViewport(
  WidgetTester tester,
  Future<void> Function() run,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 640);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  await run();
}

class _FakeStorage implements GameStorage {
  _FakeStorage({required this.onboardingSeen});

  final bool onboardingSeen;

  @override
  Future<void> clearGameState() async {}

  @override
  Future<GameState?> loadGameState() async => null;

  @override
  Future<bool> loadOnboardingSeen() async => onboardingSeen;

  @override
  Future<void> saveGameState(GameState state) async {}

  @override
  Future<void> saveOnboardingSeen(bool seen) async {}
}
