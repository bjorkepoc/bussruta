import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameEngine warmup', () {
    test('round 2 equal with non-same guess gives drink 4 path', () {
      final GameEngine engine = GameEngine();
      final GameState state = GameState.initial().copyWith(
        phase: GamePhase.warmup,
        warmupRound: 2,
        players: <PlayerState>[
          PlayerState(name: 'Alex', hand: <PlayingCard>[card(Suit.clubs, 7)]),
        ],
        currentPlayerIndex: 0,
        deck: <PlayingCard>[card(Suit.hearts, 7)],
      );

      final GameState next = engine.playWarmupGuess(state, WarmupGuess.above);

      expect(next.banner.toLowerCase(), contains('drink 4'));
      expect(next.warmupRound, 3);
    });

    test('round 3 edge match with non-same guess gives drink 6', () {
      final GameEngine engine = GameEngine();
      final GameState state = GameState.initial().copyWith(
        phase: GamePhase.warmup,
        warmupRound: 3,
        players: <PlayerState>[
          PlayerState(
            name: 'Alex',
            hand: <PlayingCard>[card(Suit.clubs, 3), card(Suit.diamonds, 9)],
          ),
        ],
        currentPlayerIndex: 0,
        deck: <PlayingCard>[card(Suit.hearts, 3)],
      );

      final GameState next = engine.playWarmupGuess(state, WarmupGuess.between);

      expect(next.banner.toLowerCase(), contains('drink 6'));
    });
  });

  group('GameEngine pyramid', () {
    test('reverse mapping keeps web parity for reveal order and drinks', () {
      final GameEngine engine = GameEngine();

      expect(engine.pyramidSlotForStep(step: 0, reversePyramid: false), 0);
      expect(engine.pyramidSlotForStep(step: 0, reversePyramid: true), 14);
      expect(engine.pyramidDrinksForIndex(index: 0, reversePyramid: false), 1);
      expect(engine.pyramidDrinksForIndex(index: 0, reversePyramid: true), 5);
    });

    test('matching rank removes all matching cards from player hand', () {
      final GameEngine engine = GameEngine();
      final GameState state = GameState.initial().copyWith(
        phase: GamePhase.pyramid,
        players: <PlayerState>[
          PlayerState(
            name: 'Alex',
            hand: <PlayingCard>[
              card(Suit.clubs, 7),
              card(Suit.hearts, 7),
              card(Suit.spades, 9),
            ],
          ),
          PlayerState(
            name: 'Bryn',
            hand: <PlayingCard>[card(Suit.diamonds, 2)],
          ),
        ],
        deck: <PlayingCard>[card(Suit.spades, 7)],
      );

      final GameState next = engine.revealNextPyramidSlot(state);

      expect(next.players[0].hand.map((PlayingCard c) => c.rank), <int>[9]);
      expect(next.pyramidHighlightPlayers, <int>[0]);
    });
  });

  group('GameEngine tie-break', () {
    test('tie-break repeats until one winner is found', () {
      final GameEngine engine = GameEngine();
      final GameState state = GameState.initial().copyWith(
        phase: GamePhase.tiebreak,
        players: <PlayerState>[
          const PlayerState(name: 'A', hand: <PlayingCard>[]),
          const PlayerState(name: 'B', hand: <PlayingCard>[]),
        ],
        tieBreak: TieBreakState(
          contenders: <int>[0, 1],
          deck: <PlayingCard>[
            card(Suit.clubs, 9),
            card(Suit.hearts, 12),
            card(Suit.spades, 10),
            card(Suit.diamonds, 10),
          ],
          round: 1,
          lastDraws: const <TieBreakDraw>[],
        ),
      );

      final GameState afterRound1 = engine.runTieBreakRound(state);
      expect(afterRound1.phase, GamePhase.tiebreak);
      expect(afterRound1.tieBreak!.contenders.length, 2);
      expect(afterRound1.tieBreak!.round, 2);

      final GameState afterRound2 = engine.runTieBreakRound(afterRound1);
      expect(afterRound2.phase, GamePhase.bussetup);
      expect(afterRound2.busRunnerIndex, 0);
    });
  });

  group('GameEngine bus route', () {
    test('equal-card non-same after progress > 0 does not reset', () {
      final GameEngine engine = GameEngine();
      final GameState state = busState(
        progress: 1,
        firstTry: true,
        draw: card(Suit.hearts, 5),
      );

      final GameState next = engine.playBusGuess(state, BusGuess.above);

      expect(next.busRoute!.progress, 1);
      expect(next.busRoute!.firstTry, true);
      expect(next.banner.toLowerCase(), contains('retry this step'));
    });

    test('equal-card non-same at progress 0 triggers restart path', () {
      final GameEngine engine = GameEngine();
      final GameState state = busState(
        progress: 0,
        firstTry: true,
        draw: card(Suit.hearts, 4),
      );

      final GameState next = engine.playBusGuess(state, BusGuess.above);

      expect(next.busRoute!.progress, 0);
      expect(next.busRoute!.firstTry, false);
      expect(next.banner.toLowerCase(), contains('restart route'));
    });

    test('finishing bus route on first try uses first-try finish text', () {
      final GameEngine engine = GameEngine();
      final GameState state = busState(
        progress: 4,
        firstTry: true,
        draw: card(Suit.hearts, 6),
      );

      final GameState next = engine.playBusGuess(state, BusGuess.above);

      expect(next.phase, GamePhase.finished);
      expect(next.banner.toLowerCase(), contains('first try'));
    });
  });
}

PlayingCard card(Suit suit, int rank) {
  return PlayingCard(suit: suit, rank: rank);
}

GameState busState({
  required int progress,
  required bool firstTry,
  required PlayingCard draw,
}) {
  return GameState.initial().copyWith(
    phase: GamePhase.bus,
    players: const <PlayerState>[PlayerState(name: 'A', hand: <PlayingCard>[])],
    busRunnerIndex: 0,
    busRoute: BusRouteState(
      routeCards: <PlayingCard>[
        card(Suit.clubs, 4),
        card(Suit.diamonds, 5),
        card(Suit.hearts, 6),
        card(Suit.spades, 7),
        card(Suit.clubs, 5),
      ],
      deck: <PlayingCard>[draw],
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
      progress: progress,
      firstTry: firstTry,
      history: const <BusHistoryEntry>[],
    ),
  );
}
