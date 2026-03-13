import 'package:bussruta_app/application/hosted_session_runtime.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostedSessionRuntime', () {
    test(
      'blocks gameplay commands until pending drink assignment is resolved',
      () {
        final HostedSessionRuntime runtime = HostedSessionRuntime(
          engine: GameEngine(),
          initialState: _warmupState(
            round: 1,
            players: <PlayerState>[
              const PlayerState(name: 'Host', hand: <PlayingCard>[]),
              const PlayerState(name: 'Guest', hand: <PlayingCard>[]),
            ],
            deck: <PlayingCard>[card(Suit.spades, 8)],
          ),
        );

        runtime.applyCommand(
          const HostedSessionCommand(
            type: HostedCommandType.warmupGuess,
            playerId: 1,
            payload: <String, dynamic>{'guess': 'black'},
          ),
        );
        expect(runtime.state.pendingDrinkDistribution?.totalDrinks, 1);
        expect(runtime.state.pendingDrinkDistribution?.sourcePlayerId, 1);

        runtime.applyCommand(
          const HostedSessionCommand(
            type: HostedCommandType.warmupGuess,
            playerId: 2,
            payload: <String, dynamic>{'guess': 'red'},
          ),
        );
        expect(runtime.state.lastError, contains('Finish drink assignment'));

        runtime.applyCommand(
          const HostedSessionCommand(
            type: HostedCommandType.assignDrinks,
            playerId: 1,
            payload: <String, dynamic>{
              'targets': <String, int>{'2': 1},
            },
          ),
        );

        expect(runtime.state.pendingDrinkDistribution, isNull);
        expect(runtime.state.pendingDrinkPenaltyByPlayer[2], 1);
      },
    );

    test('supports split drink distribution across several players', () {
      final HostedSessionRuntime runtime = HostedSessionRuntime(
        engine: GameEngine(),
        initialState: _warmupState(
          round: 2,
          players: <PlayerState>[
            PlayerState(name: 'Host', hand: <PlayingCard>[card(Suit.clubs, 5)]),
            const PlayerState(name: 'A', hand: <PlayingCard>[]),
            const PlayerState(name: 'B', hand: <PlayingCard>[]),
          ],
          deck: <PlayingCard>[card(Suit.hearts, 12)],
        ),
      );

      runtime.applyCommand(
        const HostedSessionCommand(
          type: HostedCommandType.warmupGuess,
          playerId: 1,
          payload: <String, dynamic>{'guess': 'above'},
        ),
      );
      expect(runtime.state.pendingDrinkDistribution?.totalDrinks, 2);

      runtime.applyCommand(
        const HostedSessionCommand(
          type: HostedCommandType.assignDrinks,
          playerId: 1,
          payload: <String, dynamic>{
            'targets': <String, int>{'2': 1},
          },
        ),
      );
      expect(runtime.state.pendingDrinkDistribution?.remainingDrinks, 1);

      runtime.applyCommand(
        const HostedSessionCommand(
          type: HostedCommandType.assignDrinks,
          playerId: 1,
          payload: <String, dynamic>{
            'targets': <String, int>{'3': 1},
          },
        ),
      );

      expect(runtime.state.pendingDrinkDistribution, isNull);
      expect(runtime.state.pendingDrinkPenaltyByPlayer[2], 1);
      expect(runtime.state.pendingDrinkPenaltyByPlayer[3], 1);
    });

    test('queues pyramid givers and resolves them one-by-one', () {
      final HostedSessionRuntime runtime = HostedSessionRuntime(
        engine: GameEngine(),
        initialState: _pyramidState(),
      );

      runtime.applyCommand(
        const HostedSessionCommand(
          type: HostedCommandType.revealPyramid,
          playerId: 1,
        ),
      );

      expect(runtime.state.pendingDrinkDistribution?.sourcePlayerId, 1);
      expect(runtime.state.pendingDrinkDistribution?.totalDrinks, 1);
      expect(runtime.state.queuedDrinkDistributions.length, 1);
      expect(runtime.state.queuedDrinkDistributions.first.sourcePlayerId, 2);

      runtime.applyCommand(
        const HostedSessionCommand(
          type: HostedCommandType.assignDrinks,
          playerId: 1,
          payload: <String, dynamic>{
            'targets': <String, int>{'3': 1},
          },
        ),
      );
      expect(runtime.state.pendingDrinkDistribution?.sourcePlayerId, 2);

      runtime.applyCommand(
        const HostedSessionCommand(
          type: HostedCommandType.assignDrinks,
          playerId: 2,
          payload: <String, dynamic>{
            'targets': <String, int>{'3': 1},
          },
        ),
      );

      expect(runtime.state.pendingDrinkDistribution, isNull);
      expect(runtime.state.pendingDrinkPenaltyByPlayer[3], 2);
    });

    test('only bus loser can control bus route actions', () {
      final HostedSessionRuntime runtime = HostedSessionRuntime(
        engine: GameEngine(),
        initialState: _busSetupState(),
      );

      runtime.applyCommand(
        const HostedSessionCommand(
          type: HostedCommandType.beginBusRoute,
          playerId: 1,
          payload: <String, dynamic>{'side': 'left'},
        ),
      );
      expect(runtime.state.lastError, contains('Only the bus loser'));
      expect(runtime.state.gameState.phase, GamePhase.bussetup);

      runtime.applyCommand(
        const HostedSessionCommand(
          type: HostedCommandType.beginBusRoute,
          playerId: 2,
          payload: <String, dynamic>{'side': 'left'},
        ),
      );
      expect(runtime.state.gameState.phase, GamePhase.bus);

      runtime.applyCommand(
        const HostedSessionCommand(
          type: HostedCommandType.playBusGuess,
          playerId: 1,
          payload: <String, dynamic>{'guess': 'above'},
        ),
      );
      expect(runtime.state.lastError, contains('Only the bus loser'));
    });
  });
}

HostedSessionState _warmupState({
  required int round,
  required List<PlayerState> players,
  required List<PlayingCard> deck,
}) {
  return HostedSessionState(
    sessionPin: '9991',
    hostPlayerId: 1,
    stage: HostedSessionStage.inGame,
    participants: List<HostedParticipant>.generate(
      players.length,
      (int index) => HostedParticipant(
        playerId: index + 1,
        name: players[index].name,
        isHost: index == 0,
        connected: true,
      ),
    ),
    playerOrder: List<int>.generate(players.length, (int index) => index + 1),
    gameState: GameState.initial().copyWith(
      phase: GamePhase.warmup,
      warmupRound: round,
      currentPlayerIndex: 0,
      players: players,
      deck: deck,
    ),
    pendingDrinkDistribution: null,
    queuedDrinkDistributions: const <HostedPendingDrinkDistribution>[],
    pendingDrinkPenaltyByPlayer: const <int, int>{},
    lastError: null,
  );
}

HostedSessionState _pyramidState() {
  return HostedSessionState(
    sessionPin: '9992',
    hostPlayerId: 1,
    stage: HostedSessionStage.inGame,
    participants: const <HostedParticipant>[
      HostedParticipant(
        playerId: 1,
        name: 'Host',
        isHost: true,
        connected: true,
      ),
      HostedParticipant(playerId: 2, name: 'A', isHost: false, connected: true),
      HostedParticipant(playerId: 3, name: 'B', isHost: false, connected: true),
    ],
    playerOrder: const <int>[1, 2, 3],
    gameState: GameState.initial().copyWith(
      phase: GamePhase.pyramid,
      players: <PlayerState>[
        PlayerState(
          name: 'Host',
          hand: <PlayingCard>[card(Suit.clubs, 7), card(Suit.hearts, 4)],
        ),
        PlayerState(name: 'A', hand: <PlayingCard>[card(Suit.diamonds, 7)]),
        PlayerState(name: 'B', hand: <PlayingCard>[card(Suit.spades, 9)]),
      ],
      deck: <PlayingCard>[card(Suit.hearts, 7)],
      pyramidCards: List<PlayingCard?>.filled(15, null),
      pyramidRevealIndex: 0,
    ),
    pendingDrinkDistribution: null,
    queuedDrinkDistributions: const <HostedPendingDrinkDistribution>[],
    pendingDrinkPenaltyByPlayer: const <int, int>{},
    lastError: null,
  );
}

HostedSessionState _busSetupState() {
  return HostedSessionState(
    sessionPin: '9993',
    hostPlayerId: 1,
    stage: HostedSessionStage.inGame,
    participants: const <HostedParticipant>[
      HostedParticipant(
        playerId: 1,
        name: 'Host',
        isHost: true,
        connected: true,
      ),
      HostedParticipant(
        playerId: 2,
        name: 'Loser',
        isHost: false,
        connected: true,
      ),
    ],
    playerOrder: const <int>[1, 2],
    gameState: GameState.initial().copyWith(
      phase: GamePhase.bussetup,
      players: const <PlayerState>[
        PlayerState(name: 'Host', hand: <PlayingCard>[]),
        PlayerState(name: 'Loser', hand: <PlayingCard>[]),
      ],
      busRunnerIndex: 1,
      busRoute: BusRouteState(
        routeCards: <PlayingCard>[
          card(Suit.clubs, 4),
          card(Suit.hearts, 5),
          card(Suit.spades, 6),
          card(Suit.diamonds, 7),
          card(Suit.clubs, 8),
        ],
        deck: <PlayingCard>[card(Suit.spades, 10)],
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
        startSide: null,
        order: const <int>[0, 1, 2, 3, 4],
        progress: 0,
        firstTry: true,
        history: const <BusHistoryEntry>[],
      ),
    ),
    pendingDrinkDistribution: null,
    queuedDrinkDistributions: const <HostedPendingDrinkDistribution>[],
    pendingDrinkPenaltyByPlayer: const <int, int>{},
    lastError: null,
  );
}

PlayingCard card(Suit suit, int rank) {
  return PlayingCard(suit: suit, rank: rank);
}
