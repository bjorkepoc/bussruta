import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:bussruta_app/domain/hosted_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hosted projection', () {
    test('only exposes own hand as private cards', () {
      final HostedSessionState session = _sessionState();

      final HostedProjectedView bobView = projectHostedView(
        session: session,
        viewerPlayerId: 102,
      );

      expect(
        bobView.ownHand.map((PlayingCard card) => card.shortLabel()).toList(),
        <String>['8H', 'JS'],
      );
      expect(
        bobView.ownHand.any(
          (PlayingCard value) => value.suit == Suit.clubs && value.rank == 2,
        ),
        isFalse,
      );

      final Map<String, dynamic> publicJson = bobView.publicView.toJson();
      expect(publicJson.containsKey('ownHand'), isFalse);
      expect(
        (publicJson['players'] as Iterable<dynamic>)
            .map((dynamic item) => (item as Map<String, dynamic>)['handCount'])
            .toList(),
        <int>[1, 2, 1],
      );
    });

    test('includes give-out and drink prompts for the right players', () {
      final HostedSessionState session = _sessionState();

      final HostedProjectedView bobView = projectHostedView(
        session: session,
        viewerPlayerId: 102,
      );
      expect(bobView.giveOutPromptDrinks, 3);
      expect(bobView.drinkPromptDrinks, 0);

      final HostedProjectedView charlieView = projectHostedView(
        session: session,
        viewerPlayerId: 103,
      );
      expect(charlieView.giveOutPromptDrinks, 0);
      expect(charlieView.drinkPromptDrinks, 2);
    });

    test('bus controls only active on the loser device', () {
      final HostedSessionState session = _sessionState().copyWith(
        gameState: _sessionState().gameState.copyWith(
          phase: GamePhase.bus,
          busRunnerIndex: 0,
          busRoute: _busRoute(),
        ),
        clearPendingDrinkDistribution: true,
      );

      final HostedProjectedView hostView = projectHostedView(
        session: session,
        viewerPlayerId: 101,
      );
      expect(hostView.canControlBusRoute, isTrue);

      final HostedProjectedView otherView = projectHostedView(
        session: session,
        viewerPlayerId: 102,
      );
      expect(otherView.canControlBusRoute, isFalse);
    });
  });
}

HostedSessionState _sessionState() {
  final GameState gameState = GameState.initial().copyWith(
    phase: GamePhase.warmup,
    warmupRound: 2,
    currentPlayerIndex: 1,
    players: <PlayerState>[
      PlayerState(name: 'Alice', hand: <PlayingCard>[card(Suit.clubs, 2)]),
      PlayerState(
        name: 'Bob',
        hand: <PlayingCard>[card(Suit.hearts, 8), card(Suit.spades, 11)],
      ),
      PlayerState(name: 'Charlie', hand: <PlayingCard>[card(Suit.diamonds, 5)]),
    ],
  );

  return HostedSessionState(
    sessionPin: '4829',
    hostPlayerId: 101,
    stage: HostedSessionStage.inGame,
    participants: const <HostedParticipant>[
      HostedParticipant(
        playerId: 101,
        name: 'Alice',
        isHost: true,
        connected: true,
      ),
      HostedParticipant(
        playerId: 102,
        name: 'Bob',
        isHost: false,
        connected: true,
      ),
      HostedParticipant(
        playerId: 103,
        name: 'Charlie',
        isHost: false,
        connected: true,
      ),
    ],
    playerOrder: const <int>[101, 102, 103],
    gameState: gameState,
    pendingDrinkDistribution: const HostedPendingDrinkDistribution(
      sourcePlayerId: 102,
      totalDrinks: 4,
      assignedDrinksByTarget: <int, int>{101: 1},
      reason: 'Warmup round 2',
    ),
    queuedDrinkDistributions: const <HostedPendingDrinkDistribution>[],
    pendingDrinkPenaltyByPlayer: const <int, int>{103: 2},
    lastError: null,
  );
}

BusRouteState _busRoute() {
  return BusRouteState(
    routeCards: <PlayingCard>[
      card(Suit.clubs, 4),
      card(Suit.hearts, 6),
      card(Suit.spades, 8),
      card(Suit.diamonds, 10),
      card(Suit.clubs, 12),
    ],
    deck: <PlayingCard>[card(Suit.hearts, 2)],
    overlays: List<BusZoneStack>.generate(
      5,
      (_) => const BusZoneStack(
        high: <PlayingCard>[],
        low: <PlayingCard>[],
        same: <PlayingCard>[],
      ),
    ),
    zoneTone: List<BusZoneTone>.generate(
      5,
      (_) => const BusZoneTone(high: null, low: null, same: null),
    ),
    startSide: BusStartSide.left,
    order: const <int>[0, 1, 2, 3, 4],
    progress: 0,
    firstTry: true,
    history: const <BusHistoryEntry>[],
  );
}

PlayingCard card(Suit suit, int rank) {
  return PlayingCard(suit: suit, rank: rank);
}
