import 'dart:convert';

import 'package:bussruta_app/domain/game_models.dart';

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
    required this.busRunnerPlayerId,
    required this.busRoute,
    required this.banner,
    required this.bannerTone,
    required this.pendingDrinkDistribution,
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
  final int? busRunnerPlayerId;
  final BusRouteState? busRoute;
  final String banner;
  final BannerTone bannerTone;
  final HostedPendingDrinkDistribution? pendingDrinkDistribution;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionPin': sessionPin,
      'stage': stage.name,
      'phase': phase.name,
      'language': language.name,
      'players': players.map((HostedPublicPlayer player) => player.toJson()),
      'currentTurnPlayerId': currentTurnPlayerId,
      'warmupRound': warmupRound,
      'pyramidCards': pyramidCards
          .map((PlayingCard? card) => card?.toJson())
          .toList(),
      'pyramidRevealIndex': pyramidRevealIndex,
      'busRunnerPlayerId': busRunnerPlayerId,
      'busRoute': busRoute?.toJson(),
      'banner': banner,
      'bannerTone': bannerTone.name,
      'pendingDrinkDistribution': pendingDrinkDistribution?.toJson(),
    };
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'viewerPlayerId': viewerPlayerId,
      'viewerName': viewerName,
      'isHost': isHost,
      'publicView': publicView.toJson(),
      'ownHand': ownHand.map((PlayingCard card) => card.toJson()).toList(),
      'giveOutPromptDrinks': giveOutPromptDrinks,
      'drinkPromptDrinks': drinkPromptDrinks,
      'canControlBusRoute': canControlBusRoute,
      'canUseHostTools': canUseHostTools,
    };
  }
}
