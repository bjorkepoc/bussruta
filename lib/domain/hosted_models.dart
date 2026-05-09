import 'dart:convert';

import 'package:bussruta_app/domain/game_models.dart';

const int _hostedPyramidCardCount = 15;

enum HostedSessionStage { lobby, inGame, finished }

enum HostedCommandType {
  startGame,
  resetToSetup,
  warmupGuess,
  revealPyramid,
  runTieBreakRound,
  beginBusRoute,
  playBusGuess,
  assignDrinks,
  acknowledgeDrinks,
  toggleAutoPlay,
  setAutoPlayDelayMs,
}

class HostedSessionCommand {
  const HostedSessionCommand({
    required this.type,
    required this.playerId,
    this.payload = const <String, dynamic>{},
  });

  final HostedCommandType type;
  final int playerId;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'playerId': playerId,
      'payload': payload,
    };
  }

  static HostedSessionCommand fromJson(Map<String, dynamic> json) {
    return HostedSessionCommand(
      type: HostedCommandType.values.byName(json['type'] as String),
      playerId: json['playerId'] as int,
      payload: Map<String, dynamic>.from(
        json['payload'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{},
      ),
    );
  }

  String encode() {
    return jsonEncode(toJson());
  }

  static HostedSessionCommand decode(String source) {
    final Map<String, dynamic> parsed =
        jsonDecode(source) as Map<String, dynamic>;
    return HostedSessionCommand.fromJson(parsed);
  }
}

class HostedParticipant {
  const HostedParticipant({
    required this.playerId,
    required this.name,
    required this.isHost,
    required this.connected,
  });

  final int playerId;
  final String name;
  final bool isHost;
  final bool connected;

  HostedParticipant copyWith({
    int? playerId,
    String? name,
    bool? isHost,
    bool? connected,
  }) {
    return HostedParticipant(
      playerId: playerId ?? this.playerId,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      connected: connected ?? this.connected,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'playerId': playerId,
      'name': name,
      'isHost': isHost,
      'connected': connected,
    };
  }

  static HostedParticipant fromJson(Map<String, dynamic> json) {
    return HostedParticipant(
      playerId: json['playerId'] as int,
      name: json['name'] as String,
      isHost: json['isHost'] as bool,
      connected: json['connected'] as bool,
    );
  }
}

class HostedPendingDrinkDistribution {
  const HostedPendingDrinkDistribution({
    required this.sourcePlayerId,
    required this.totalDrinks,
    required this.assignedDrinksByTarget,
    required this.reason,
  });

  final int sourcePlayerId;
  final int totalDrinks;
  final Map<int, int> assignedDrinksByTarget;
  final String reason;

  int get assignedTotal {
    int sum = 0;
    for (final int value in assignedDrinksByTarget.values) {
      sum += value;
    }
    return sum;
  }

  int get remainingDrinks => totalDrinks - assignedTotal;

  bool get isComplete => remainingDrinks == 0;

  HostedPendingDrinkDistribution copyWith({
    int? sourcePlayerId,
    int? totalDrinks,
    Map<int, int>? assignedDrinksByTarget,
    String? reason,
  }) {
    return HostedPendingDrinkDistribution(
      sourcePlayerId: sourcePlayerId ?? this.sourcePlayerId,
      totalDrinks: totalDrinks ?? this.totalDrinks,
      assignedDrinksByTarget:
          assignedDrinksByTarget ?? this.assignedDrinksByTarget,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourcePlayerId': sourcePlayerId,
      'totalDrinks': totalDrinks,
      'assignedDrinksByTarget': assignedDrinksByTarget.map(
        (int key, int value) => MapEntry<String, int>(key.toString(), value),
      ),
      'reason': reason,
    };
  }

  static HostedPendingDrinkDistribution fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawMap =
        json['assignedDrinksByTarget'] as Map<String, dynamic>;
    return HostedPendingDrinkDistribution(
      sourcePlayerId: json['sourcePlayerId'] as int,
      totalDrinks: json['totalDrinks'] as int,
      assignedDrinksByTarget: rawMap.map(
        (String key, dynamic value) =>
            MapEntry<int, int>(int.parse(key), value as int),
      ),
      reason: json['reason'] as String,
    );
  }
}

class HostedSessionState {
  const HostedSessionState({
    required this.sessionPin,
    required this.hostPlayerId,
    required this.stage,
    required this.participants,
    required this.playerOrder,
    required this.gameState,
    required this.pendingDrinkDistribution,
    required this.queuedDrinkDistributions,
    required this.pendingDrinkPenaltyByPlayer,
    required this.lastError,
  });

  factory HostedSessionState.lobby({
    required String sessionPin,
    required HostedParticipant host,
    AppLanguage language = AppLanguage.en,
  }) {
    final GameState base = GameState.initial().copyWith(language: language);
    return HostedSessionState(
      sessionPin: sessionPin,
      hostPlayerId: host.playerId,
      stage: HostedSessionStage.lobby,
      participants: <HostedParticipant>[host],
      playerOrder: <int>[host.playerId],
      gameState: base,
      pendingDrinkDistribution: null,
      queuedDrinkDistributions: const <HostedPendingDrinkDistribution>[],
      pendingDrinkPenaltyByPlayer: const <int, int>{},
      lastError: null,
    );
  }

  final String sessionPin;
  final int hostPlayerId;
  final HostedSessionStage stage;
  final List<HostedParticipant> participants;
  final List<int> playerOrder;
  final GameState gameState;
  final HostedPendingDrinkDistribution? pendingDrinkDistribution;
  final List<HostedPendingDrinkDistribution> queuedDrinkDistributions;
  final Map<int, int> pendingDrinkPenaltyByPlayer;
  final String? lastError;

  HostedSessionState copyWith({
    String? sessionPin,
    int? hostPlayerId,
    HostedSessionStage? stage,
    List<HostedParticipant>? participants,
    List<int>? playerOrder,
    GameState? gameState,
    HostedPendingDrinkDistribution? pendingDrinkDistribution,
    bool clearPendingDrinkDistribution = false,
    List<HostedPendingDrinkDistribution>? queuedDrinkDistributions,
    Map<int, int>? pendingDrinkPenaltyByPlayer,
    String? lastError,
    bool clearLastError = false,
  }) {
    return HostedSessionState(
      sessionPin: sessionPin ?? this.sessionPin,
      hostPlayerId: hostPlayerId ?? this.hostPlayerId,
      stage: stage ?? this.stage,
      participants: participants ?? this.participants,
      playerOrder: playerOrder ?? this.playerOrder,
      gameState: gameState ?? this.gameState,
      pendingDrinkDistribution: clearPendingDrinkDistribution
          ? null
          : (pendingDrinkDistribution ?? this.pendingDrinkDistribution),
      queuedDrinkDistributions:
          queuedDrinkDistributions ?? this.queuedDrinkDistributions,
      pendingDrinkPenaltyByPlayer:
          pendingDrinkPenaltyByPlayer ?? this.pendingDrinkPenaltyByPlayer,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  bool get hasStarted => gameState.phase != GamePhase.setup;

  int? playerIndexForId(int playerId) {
    final int index = playerOrder.indexOf(playerId);
    if (index < 0 || index >= gameState.players.length) {
      return null;
    }
    return index;
  }

  int? playerIdForIndex(int index) {
    if (index < 0 || index >= playerOrder.length) {
      return null;
    }
    return playerOrder[index];
  }

  HostedParticipant? participantById(int playerId) {
    for (final HostedParticipant participant in participants) {
      if (participant.playerId == playerId) {
        return participant;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionPin': sessionPin,
      'hostPlayerId': hostPlayerId,
      'stage': stage.name,
      'participants': participants
          .map((HostedParticipant p) => p.toJson())
          .toList(),
      'playerOrder': playerOrder,
      'gameState': gameState.toJson(),
      'pendingDrinkDistribution': pendingDrinkDistribution?.toJson(),
      'queuedDrinkDistributions': queuedDrinkDistributions
          .map((HostedPendingDrinkDistribution value) => value.toJson())
          .toList(),
      'pendingDrinkPenaltyByPlayer': pendingDrinkPenaltyByPlayer.map(
        (int key, int value) => MapEntry<String, int>(key.toString(), value),
      ),
      'lastError': lastError,
    };
  }

  static HostedSessionState fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawParticipants = json['participants'] as List<dynamic>;
    final List<dynamic> rawQueued =
        json['queuedDrinkDistributions'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic> rawPenalty =
        json['pendingDrinkPenaltyByPlayer'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return HostedSessionState(
      sessionPin: json['sessionPin'] as String,
      hostPlayerId: json['hostPlayerId'] as int,
      stage: HostedSessionStage.values.byName(json['stage'] as String),
      participants: rawParticipants
          .map(
            (dynamic item) =>
                HostedParticipant.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      playerOrder: (json['playerOrder'] as List<dynamic>).cast<int>(),
      gameState: GameState.fromJson(json['gameState'] as Map<String, dynamic>),
      pendingDrinkDistribution: json['pendingDrinkDistribution'] == null
          ? null
          : HostedPendingDrinkDistribution.fromJson(
              json['pendingDrinkDistribution'] as Map<String, dynamic>,
            ),
      queuedDrinkDistributions: rawQueued
          .map(
            (dynamic item) => HostedPendingDrinkDistribution.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      pendingDrinkPenaltyByPlayer: rawPenalty.map(
        (String key, dynamic value) =>
            MapEntry<int, int>(int.parse(key), value as int),
      ),
      lastError: json['lastError'] as String?,
    );
  }
}

class HostedPublicPlayer {
  const HostedPublicPlayer({
    required this.playerId,
    required this.name,
    required this.isHost,
    required this.connected,
    required this.handCount,
  });

  final int playerId;
  final String name;
  final bool isHost;
  final bool connected;
  final int handCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'playerId': playerId,
      'name': name,
      'isHost': isHost,
      'connected': connected,
      'handCount': handCount,
    };
  }

  static HostedPublicPlayer fromJson(Map<String, dynamic> json) {
    return HostedPublicPlayer(
      playerId: json['playerId'] as int,
      name: json['name'] as String,
      isHost: json['isHost'] as bool,
      connected: json['connected'] as bool,
      handCount: json['handCount'] as int,
    );
  }
}

class HostedPublicTieBreakState {
  const HostedPublicTieBreakState({
    required this.contenders,
    required this.deckCount,
    required this.round,
    required this.lastDraws,
  });

  factory HostedPublicTieBreakState.fromTieBreak(TieBreakState tieBreak) {
    return HostedPublicTieBreakState(
      contenders: List<int>.from(tieBreak.contenders),
      deckCount: tieBreak.deck.length,
      round: tieBreak.round,
      lastDraws: List<TieBreakDraw>.from(tieBreak.lastDraws),
    );
  }

  final List<int> contenders;
  final int deckCount;
  final int round;
  final List<TieBreakDraw> lastDraws;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'contenders': contenders,
      'deckCount': deckCount,
      'round': round,
      'lastDraws': lastDraws.map((TieBreakDraw draw) => draw.toJson()).toList(),
    };
  }

  static HostedPublicTieBreakState fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawLastDraws = json['lastDraws'] as List<dynamic>;
    final int deckCount =
        json['deckCount'] as int? ??
        (json['deck'] as List<dynamic>? ?? const <dynamic>[]).length;
    if (deckCount < 0) {
      throw ArgumentError('tieBreak deckCount must be non-negative.');
    }
    return HostedPublicTieBreakState(
      contenders: (json['contenders'] as List<dynamic>).cast<int>(),
      deckCount: deckCount,
      round: json['round'] as int,
      lastDraws: rawLastDraws
          .map(
            (dynamic item) =>
                TieBreakDraw.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class HostedPublicBusRouteState {
  const HostedPublicBusRouteState({
    required this.routeCards,
    required this.deckCount,
    required this.overlays,
    required this.zoneTone,
    required this.startSide,
    required this.order,
    required this.progress,
    required this.firstTry,
    required this.history,
  });

  factory HostedPublicBusRouteState.fromBusRoute(BusRouteState busRoute) {
    return HostedPublicBusRouteState(
      routeCards: List<PlayingCard>.from(busRoute.routeCards),
      deckCount: busRoute.deck.length,
      overlays: List<BusZoneStack>.from(busRoute.overlays),
      zoneTone: List<BusZoneTone>.from(busRoute.zoneTone),
      startSide: busRoute.startSide,
      order: List<int>.from(busRoute.order),
      progress: busRoute.progress,
      firstTry: busRoute.firstTry,
      history: List<BusHistoryEntry>.from(busRoute.history),
    );
  }

  final List<PlayingCard> routeCards;
  final int deckCount;
  final List<BusZoneStack> overlays;
  final List<BusZoneTone> zoneTone;
  final BusStartSide? startSide;
  final List<int> order;
  final int progress;
  final bool firstTry;
  final List<BusHistoryEntry> history;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'routeCards': routeCards
          .map((PlayingCard card) => card.toJson())
          .toList(),
      'deckCount': deckCount,
      'overlays': overlays.map((BusZoneStack stack) => stack.toJson()).toList(),
      'zoneTone': zoneTone.map((BusZoneTone tone) => tone.toJson()).toList(),
      'startSide': startSide?.name,
      'order': order,
      'progress': progress,
      'firstTry': firstTry,
      'history': history
          .map((BusHistoryEntry entry) => entry.toJson())
          .toList(),
    };
  }

  static HostedPublicBusRouteState fromJson(Map<String, dynamic> json) {
    List<PlayingCard> parseCardList(String key) {
      final List<dynamic> raw = json[key] as List<dynamic>;
      return raw
          .map(
            (dynamic item) =>
                PlayingCard.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    final List<dynamic> rawOverlays = json['overlays'] as List<dynamic>;
    final List<dynamic> rawZoneTone = json['zoneTone'] as List<dynamic>;
    final List<dynamic> rawHistory = json['history'] as List<dynamic>;
    final int deckCount =
        json['deckCount'] as int? ??
        (json['deck'] as List<dynamic>? ?? const <dynamic>[]).length;
    if (deckCount < 0) {
      throw ArgumentError('busRoute deckCount must be non-negative.');
    }

    return HostedPublicBusRouteState(
      routeCards: parseCardList('routeCards'),
      deckCount: deckCount,
      overlays: rawOverlays
          .map(
            (dynamic item) =>
                BusZoneStack.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      zoneTone: rawZoneTone
          .map(
            (dynamic item) =>
                BusZoneTone.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      startSide: json['startSide'] == null
          ? null
          : BusStartSide.values.byName(json['startSide'] as String),
      order: (json['order'] as List<dynamic>).cast<int>(),
      progress: json['progress'] as int,
      firstTry: json['firstTry'] as bool,
      history: rawHistory
          .map(
            (dynamic item) =>
                BusHistoryEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class HostedPublicView {
  const HostedPublicView({
    required this.sessionPin,
    required this.stage,
    required this.phase,
    required this.language,
    required this.players,
    required this.currentTurnPlayerId,
    required this.warmupRound,
    required this.pyramidCards,
    required this.pyramidRevealIndex,
    required this.tieBreak,
    required this.busRunnerPlayerId,
    required this.busRoute,
    required this.banner,
    required this.bannerTone,
    required this.pendingDrinkDistribution,
    required this.autoPlayEnabled,
    required this.autoPlayDelayMs,
  });

  final String sessionPin;
  final HostedSessionStage stage;
  final GamePhase phase;
  final AppLanguage language;
  final List<HostedPublicPlayer> players;
  final int? currentTurnPlayerId;
  final int warmupRound;
  final List<PlayingCard?> pyramidCards;
  final int pyramidRevealIndex;
  final HostedPublicTieBreakState? tieBreak;
  final int? busRunnerPlayerId;
  final HostedPublicBusRouteState? busRoute;
  final String banner;
  final BannerTone bannerTone;
  final HostedPendingDrinkDistribution? pendingDrinkDistribution;
  final bool autoPlayEnabled;
  final int autoPlayDelayMs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionPin': sessionPin,
      'stage': stage.name,
      'phase': phase.name,
      'language': language.name,
      'players': players
          .map((HostedPublicPlayer player) => player.toJson())
          .toList(),
      'currentTurnPlayerId': currentTurnPlayerId,
      'warmupRound': warmupRound,
      'pyramidCards': pyramidCards
          .map((PlayingCard? card) => card?.toJson())
          .toList(),
      'pyramidRevealIndex': pyramidRevealIndex,
      'tieBreak': tieBreak?.toJson(),
      'busRunnerPlayerId': busRunnerPlayerId,
      'busRoute': busRoute?.toJson(),
      'banner': banner,
      'bannerTone': bannerTone.name,
      'pendingDrinkDistribution': pendingDrinkDistribution?.toJson(),
      'autoPlayEnabled': autoPlayEnabled,
      'autoPlayDelayMs': autoPlayDelayMs,
    };
  }

  static HostedPublicView fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawPlayers = json['players'] as List<dynamic>;
    final List<dynamic> rawPyramidCards = json['pyramidCards'] as List<dynamic>;
    final List<PlayingCard?> pyramidCards = rawPyramidCards.map((dynamic item) {
      if (item == null) {
        return null;
      }
      return PlayingCard.fromJson(item as Map<String, dynamic>);
    }).toList();
    if (pyramidCards.length != _hostedPyramidCardCount) {
      throw ArgumentError(
        'pyramidCards must contain $_hostedPyramidCardCount entries.',
      );
    }
    final HostedPublicBusRouteState? busRoute = json['busRoute'] == null
        ? null
        : HostedPublicBusRouteState.fromJson(
            json['busRoute'] as Map<String, dynamic>,
          );
    if (busRoute != null) {
      _validateHostedBusRoute(busRoute);
    }
    return HostedPublicView(
      sessionPin: json['sessionPin'] as String,
      stage: HostedSessionStage.values.byName(json['stage'] as String),
      phase: GamePhase.values.byName(json['phase'] as String),
      language: AppLanguage.values.byName(json['language'] as String),
      players: rawPlayers
          .map(
            (dynamic item) =>
                HostedPublicPlayer.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      currentTurnPlayerId: json['currentTurnPlayerId'] as int?,
      warmupRound: json['warmupRound'] as int,
      pyramidCards: pyramidCards,
      pyramidRevealIndex: json['pyramidRevealIndex'] as int,
      tieBreak: json['tieBreak'] == null
          ? null
          : HostedPublicTieBreakState.fromJson(
              json['tieBreak'] as Map<String, dynamic>,
            ),
      busRunnerPlayerId: json['busRunnerPlayerId'] as int?,
      busRoute: busRoute,
      banner: json['banner'] as String,
      bannerTone: BannerTone.values.byName(json['bannerTone'] as String),
      pendingDrinkDistribution: json['pendingDrinkDistribution'] == null
          ? null
          : HostedPendingDrinkDistribution.fromJson(
              json['pendingDrinkDistribution'] as Map<String, dynamic>,
            ),
      autoPlayEnabled: json['autoPlayEnabled'] as bool? ?? false,
      autoPlayDelayMs: json['autoPlayDelayMs'] as int? ?? 1500,
    );
  }
}

void _validateHostedBusRoute(HostedPublicBusRouteState route) {
  if (route.progress < 0) {
    throw ArgumentError('busRoute progress must be non-negative.');
  }
  if (route.progress > route.order.length) {
    throw ArgumentError('busRoute progress cannot exceed route order length.');
  }
}

class HostedProjectedView {
  const HostedProjectedView({
    required this.viewerPlayerId,
    required this.viewerName,
    required this.isHost,
    required this.publicView,
    required this.ownHand,
    required this.giveOutPromptDrinks,
    required this.drinkPromptDrinks,
    required this.canControlBusRoute,
    required this.canUseHostTools,
  });

  final int viewerPlayerId;
  final String viewerName;
  final bool isHost;
  final HostedPublicView publicView;
  final List<PlayingCard> ownHand;
  final int giveOutPromptDrinks;
  final int drinkPromptDrinks;
  final bool canControlBusRoute;
  final bool canUseHostTools;

  Map<String, dynamic> toJson({Map<String, dynamic>? publicViewJson}) {
    return <String, dynamic>{
      'viewerPlayerId': viewerPlayerId,
      'viewerName': viewerName,
      'isHost': isHost,
      'publicView': publicViewJson ?? publicView.toJson(),
      'ownHand': ownHand.map((PlayingCard card) => card.toJson()).toList(),
      'giveOutPromptDrinks': giveOutPromptDrinks,
      'drinkPromptDrinks': drinkPromptDrinks,
      'canControlBusRoute': canControlBusRoute,
      'canUseHostTools': canUseHostTools,
    };
  }

  static HostedProjectedView fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawOwnHand = json['ownHand'] as List<dynamic>;
    return HostedProjectedView(
      viewerPlayerId: json['viewerPlayerId'] as int,
      viewerName: json['viewerName'] as String,
      isHost: json['isHost'] as bool,
      publicView: HostedPublicView.fromJson(
        json['publicView'] as Map<String, dynamic>,
      ),
      ownHand: rawOwnHand
          .map(
            (dynamic item) =>
                PlayingCard.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      giveOutPromptDrinks: json['giveOutPromptDrinks'] as int,
      drinkPromptDrinks: json['drinkPromptDrinks'] as int,
      canControlBusRoute: json['canControlBusRoute'] as bool,
      canUseHostTools: json['canUseHostTools'] as bool,
    );
  }
}
