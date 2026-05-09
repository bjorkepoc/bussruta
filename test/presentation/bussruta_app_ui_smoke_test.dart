import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/application/game_storage.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/presentation/bussruta_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
