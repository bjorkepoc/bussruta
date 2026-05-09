import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hosted models', () {
    test('round-trips a valid hosted projection', () {
      final HostedProjectedView parsed = HostedProjectedView.fromJson(
        _validProjectionJson(),
      );

      expect(parsed.publicView.pyramidCards.length, 15);
      expect(parsed.publicView.busRoute?.progress, 0);
      expect(parsed.publicView.busRoute?.deckCount, 1);
    });

    test('rejects hosted projections with short pyramid card lists', () {
      final Map<String, dynamic> json = _validProjectionJson();
      (json['publicView'] as Map<String, dynamic>)['pyramidCards'] = <dynamic>[
        null,
      ];

      expect(
        () => HostedProjectedView.fromJson(json),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.message,
            'message',
            contains('pyramidCards'),
          ),
        ),
      );
    });

    test('rejects hosted projections with negative bus progress', () {
      final Map<String, dynamic> json = _validProjectionJson();
      final Map<String, dynamic> publicView =
          json['publicView'] as Map<String, dynamic>;
      (publicView['busRoute'] as Map<String, dynamic>)['progress'] = -1;

      expect(
        () => HostedProjectedView.fromJson(json),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.message,
            'message',
            contains('progress'),
          ),
        ),
      );
    });
  });
}

Map<String, dynamic> _validProjectionJson() {
  return HostedProjectedView(
    viewerPlayerId: 1,
    viewerName: 'Host',
    isHost: true,
    publicView: HostedPublicView(
      sessionPin: '1234',
      stage: HostedSessionStage.inGame,
      phase: GamePhase.bus,
      language: AppLanguage.en,
      players: const <HostedPublicPlayer>[
        HostedPublicPlayer(
          playerId: 1,
          name: 'Host',
          isHost: true,
          connected: true,
          handCount: 0,
        ),
      ],
      currentTurnPlayerId: null,
      warmupRound: 1,
      pyramidCards: List<PlayingCard?>.filled(15, null),
      pyramidRevealIndex: 0,
      tieBreak: null,
      busRunnerPlayerId: 1,
      busRoute: _busRoute(progress: 0),
      banner: '',
      bannerTone: BannerTone.info,
      pendingDrinkDistribution: null,
      autoPlayEnabled: false,
      autoPlayDelayMs: 1500,
    ),
    ownHand: const <PlayingCard>[],
    giveOutPromptDrinks: 0,
    drinkPromptDrinks: 0,
    canControlBusRoute: true,
    canUseHostTools: true,
  ).toJson();
}

HostedPublicBusRouteState _busRoute({required int progress}) {
  return HostedPublicBusRouteState.fromBusRoute(
    BusRouteState(
      routeCards: <PlayingCard>[
        _card(Suit.clubs, 4),
        _card(Suit.hearts, 6),
        _card(Suit.spades, 8),
        _card(Suit.diamonds, 10),
        _card(Suit.clubs, 12),
      ],
      deck: <PlayingCard>[_card(Suit.hearts, 2)],
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
      firstTry: true,
      history: const <BusHistoryEntry>[],
    ),
  );
}

PlayingCard _card(Suit suit, int rank) {
  return PlayingCard(suit: suit, rank: rank);
}
