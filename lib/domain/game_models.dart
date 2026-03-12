import 'dart:convert';

enum GamePhase { setup, warmup, pyramid, tiebreak, bussetup, bus, finished }

enum AppLanguage { en, no }

enum BannerTone { info, success, fail }

enum BusStartSide { left, right }

enum BusGuess { above, below, same }

enum WarmupGuess {
  black,
  red,
  above,
  below,
  between,
  outside,
  same,
  clubs,
  diamonds,
  hearts,
  spades,
}

enum Suit { clubs, diamonds, hearts, spades }

extension SuitProps on Suit {
  bool get isBlack {
    return this == Suit.clubs || this == Suit.spades;
  }

  String get symbol {
    switch (this) {
      case Suit.clubs:
        return 'C';
      case Suit.diamonds:
        return 'D';
      case Suit.hearts:
        return 'H';
      case Suit.spades:
        return 'S';
    }
  }

  WarmupGuess get warmupGuess {
    switch (this) {
      case Suit.clubs:
        return WarmupGuess.clubs;
      case Suit.diamonds:
        return WarmupGuess.diamonds;
      case Suit.hearts:
        return WarmupGuess.hearts;
      case Suit.spades:
        return WarmupGuess.spades;
    }
  }
}

class PlayingCard {
  const PlayingCard({required this.suit, required this.rank});

  final Suit suit;
  final int rank;

  String get rankLabel {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return rank.toString();
    }
  }

  String shortLabel() {
    return '$rankLabel${suit.symbol}';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'suit': suit.name,
      'rank': rank,
    };
  }

  static PlayingCard fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      suit: Suit.values.byName(json['suit'] as String),
      rank: json['rank'] as int,
    );
  }
}

class PlayerState {
  const PlayerState({required this.name, required this.hand});

  final String name;
  final List<PlayingCard> hand;

  PlayerState copyWith({
    String? name,
    List<PlayingCard>? hand,
  }) {
    return PlayerState(
      name: name ?? this.name,
      hand: hand ?? this.hand,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'hand': hand.map((PlayingCard card) => card.toJson()).toList(),
    };
  }

  static PlayerState fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawHand = json['hand'] as List<dynamic>;
    return PlayerState(
      name: json['name'] as String,
      hand: rawHand
          .map((dynamic item) =>
              PlayingCard.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SetupDraft {
  const SetupDraft({
    required this.playerCount,
    required this.names,
    required this.reversePyramid,
  });

  final int playerCount;
  final List<String> names;
  final bool reversePyramid;

  SetupDraft copyWith({
    int? playerCount,
    List<String>? names,
    bool? reversePyramid,
  }) {
    return SetupDraft(
      playerCount: playerCount ?? this.playerCount,
      names: names ?? this.names,
      reversePyramid: reversePyramid ?? this.reversePyramid,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'playerCount': playerCount,
      'names': names,
      'reversePyramid': reversePyramid,
    };
  }

  static SetupDraft fromJson(Map<String, dynamic> json) {
    return SetupDraft(
      playerCount: json['playerCount'] as int,
      names: (json['names'] as List<dynamic>).cast<String>(),
      reversePyramid: json['reversePyramid'] as bool,
    );
  }
}

class AutoPlayState {
  const AutoPlayState({
    required this.enabled,
    required this.delayMs,
  });

  final bool enabled;
  final int delayMs;

  AutoPlayState copyWith({
    bool? enabled,
    int? delayMs,
  }) {
    return AutoPlayState(
      enabled: enabled ?? this.enabled,
      delayMs: delayMs ?? this.delayMs,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'delayMs': delayMs,
    };
  }

  static AutoPlayState fromJson(Map<String, dynamic> json) {
    return AutoPlayState(
      enabled: json['enabled'] as bool,
      delayMs: json['delayMs'] as int,
    );
  }
}

class TieBreakDraw {
  const TieBreakDraw({
    required this.playerIndex,
    required this.card,
  });

  final int playerIndex;
  final PlayingCard card;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'playerIndex': playerIndex,
      'card': card.toJson(),
    };
  }

  static TieBreakDraw fromJson(Map<String, dynamic> json) {
    return TieBreakDraw(
      playerIndex: json['playerIndex'] as int,
      card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
    );
  }
}

class TieBreakState {
  const TieBreakState({
    required this.contenders,
    required this.deck,
    required this.round,
    required this.lastDraws,
  });

  final List<int> contenders;
  final List<PlayingCard> deck;
  final int round;
  final List<TieBreakDraw> lastDraws;

  TieBreakState copyWith({
    List<int>? contenders,
    List<PlayingCard>? deck,
    int? round,
    List<TieBreakDraw>? lastDraws,
  }) {
    return TieBreakState(
      contenders: contenders ?? this.contenders,
      deck: deck ?? this.deck,
      round: round ?? this.round,
      lastDraws: lastDraws ?? this.lastDraws,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'contenders': contenders,
      'deck': deck.map((PlayingCard card) => card.toJson()).toList(),
      'round': round,
      'lastDraws': lastDraws.map((TieBreakDraw draw) => draw.toJson()).toList(),
    };
  }

  static TieBreakState fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawDeck = json['deck'] as List<dynamic>;
    final List<dynamic> rawLastDraws = json['lastDraws'] as List<dynamic>;
    return TieBreakState(
      contenders: (json['contenders'] as List<dynamic>).cast<int>(),
      deck: rawDeck
          .map((dynamic item) =>
              PlayingCard.fromJson(item as Map<String, dynamic>))
          .toList(),
      round: json['round'] as int,
      lastDraws: rawLastDraws
          .map((dynamic item) =>
              TieBreakDraw.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BusZoneStack {
  const BusZoneStack({
    required this.high,
    required this.low,
    required this.same,
  });

  final List<PlayingCard> high;
  final List<PlayingCard> low;
  final List<PlayingCard> same;

  BusZoneStack copyWith({
    List<PlayingCard>? high,
    List<PlayingCard>? low,
    List<PlayingCard>? same,
  }) {
    return BusZoneStack(
      high: high ?? this.high,
      low: low ?? this.low,
      same: same ?? this.same,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'high': high.map((PlayingCard card) => card.toJson()).toList(),
      'low': low.map((PlayingCard card) => card.toJson()).toList(),
      'same': same.map((PlayingCard card) => card.toJson()).toList(),
    };
  }

  static BusZoneStack fromJson(Map<String, dynamic> json) {
    List<PlayingCard> parse(String key) {
      final List<dynamic> raw = json[key] as List<dynamic>;
      return raw
          .map((dynamic item) =>
              PlayingCard.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return BusZoneStack(
      high: parse('high'),
      low: parse('low'),
      same: parse('same'),
    );
  }
}

class BusZoneTone {
  const BusZoneTone({
    required this.high,
    required this.low,
    required this.same,
  });

  final BannerTone? high;
  final BannerTone? low;
  final BannerTone? same;

  BusZoneTone copyWith({
    BannerTone? high,
    BannerTone? low,
    BannerTone? same,
  }) {
    return BusZoneTone(
      high: high,
      low: low,
      same: same,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'high': high?.name,
      'low': low?.name,
      'same': same?.name,
    };
  }

  static BusZoneTone fromJson(Map<String, dynamic> json) {
    BannerTone? parse(dynamic value) {
      if (value == null) {
        return null;
      }
      return BannerTone.values.byName(value as String);
    }

    return BusZoneTone(
      high: parse(json['high']),
      low: parse(json['low']),
      same: parse(json['same']),
    );
  }
}

class BusHistoryEntry {
  const BusHistoryEntry({
    required this.step,
    required this.guess,
    required this.target,
    required this.draw,
    required this.message,
    required this.correct,
  });

  final int step;
  final BusGuess guess;
  final PlayingCard target;
  final PlayingCard draw;
  final String message;
  final bool correct;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'step': step,
      'guess': guess.name,
      'target': target.toJson(),
      'draw': draw.toJson(),
      'message': message,
      'correct': correct,
    };
  }

  static BusHistoryEntry fromJson(Map<String, dynamic> json) {
    return BusHistoryEntry(
      step: json['step'] as int,
      guess: BusGuess.values.byName(json['guess'] as String),
      target: PlayingCard.fromJson(json['target'] as Map<String, dynamic>),
      draw: PlayingCard.fromJson(json['draw'] as Map<String, dynamic>),
      message: json['message'] as String,
      correct: json['correct'] as bool,
    );
  }
}

class BusRouteState {
  const BusRouteState({
    required this.routeCards,
    required this.deck,
    required this.overlays,
    required this.zoneTone,
    required this.startSide,
    required this.order,
    required this.progress,
    required this.firstTry,
    required this.history,
  });

  final List<PlayingCard> routeCards;
  final List<PlayingCard> deck;
  final List<BusZoneStack> overlays;
  final List<BusZoneTone> zoneTone;
  final BusStartSide? startSide;
  final List<int> order;
  final int progress;
  final bool firstTry;
  final List<BusHistoryEntry> history;

  BusRouteState copyWith({
    List<PlayingCard>? routeCards,
    List<PlayingCard>? deck,
    List<BusZoneStack>? overlays,
    List<BusZoneTone>? zoneTone,
    BusStartSide? startSide,
    List<int>? order,
    int? progress,
    bool? firstTry,
    List<BusHistoryEntry>? history,
  }) {
    return BusRouteState(
      routeCards: routeCards ?? this.routeCards,
      deck: deck ?? this.deck,
      overlays: overlays ?? this.overlays,
      zoneTone: zoneTone ?? this.zoneTone,
      startSide: startSide ?? this.startSide,
      order: order ?? this.order,
      progress: progress ?? this.progress,
      firstTry: firstTry ?? this.firstTry,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'routeCards': routeCards.map((PlayingCard card) => card.toJson()).toList(),
      'deck': deck.map((PlayingCard card) => card.toJson()).toList(),
      'overlays': overlays.map((BusZoneStack stack) => stack.toJson()).toList(),
      'zoneTone': zoneTone.map((BusZoneTone tone) => tone.toJson()).toList(),
      'startSide': startSide?.name,
      'order': order,
      'progress': progress,
      'firstTry': firstTry,
      'history': history.map((BusHistoryEntry entry) => entry.toJson()).toList(),
    };
  }

  static BusRouteState fromJson(Map<String, dynamic> json) {
    List<PlayingCard> parseCardList(String key) {
      final List<dynamic> raw = json[key] as List<dynamic>;
      return raw
          .map((dynamic item) =>
              PlayingCard.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final List<dynamic> rawOverlays = json['overlays'] as List<dynamic>;
    final List<dynamic> rawZoneTone = json['zoneTone'] as List<dynamic>;
    final List<dynamic> rawHistory = json['history'] as List<dynamic>;

    return BusRouteState(
      routeCards: parseCardList('routeCards'),
      deck: parseCardList('deck'),
      overlays: rawOverlays
          .map((dynamic item) =>
              BusZoneStack.fromJson(item as Map<String, dynamic>))
          .toList(),
      zoneTone: rawZoneTone
          .map((dynamic item) =>
              BusZoneTone.fromJson(item as Map<String, dynamic>))
          .toList(),
      startSide: json['startSide'] == null
          ? null
          : BusStartSide.values.byName(json['startSide'] as String),
      order: (json['order'] as List<dynamic>).cast<int>(),
      progress: json['progress'] as int,
      firstTry: json['firstTry'] as bool,
      history: rawHistory
          .map((dynamic item) =>
              BusHistoryEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GameState {
  const GameState({
    required this.phase,
    required this.language,
    required this.setupDraft,
    required this.players,
    required this.deck,
    required this.reversePyramid,
    required this.busStartSide,
    required this.warmupRound,
    required this.currentPlayerIndex,
    required this.pyramidCards,
    required this.pyramidRevealIndex,
    required this.busRunnerIndex,
    required this.tieBreak,
    required this.busRoute,
    required this.pendingWarmupGuess,
    required this.bannerTone,
    required this.pyramidHighlightPlayers,
    required this.autoPlay,
    required this.banner,
    required this.log,
    required this.interactionLocked,
  });

  factory GameState.initial() {
    return const GameState(
      phase: GamePhase.setup,
      language: AppLanguage.en,
      setupDraft: SetupDraft(
        playerCount: 4,
        names: <String>['', '', '', ''],
        reversePyramid: false,
      ),
      players: <PlayerState>[],
      deck: <PlayingCard>[],
      reversePyramid: false,
      busStartSide: BusStartSide.left,
      warmupRound: 1,
      currentPlayerIndex: 0,
      pyramidCards: <PlayingCard?>[
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ],
      pyramidRevealIndex: 0,
      busRunnerIndex: null,
      tieBreak: null,
      busRoute: null,
      pendingWarmupGuess: null,
      bannerTone: BannerTone.info,
      pyramidHighlightPlayers: <int>[],
      autoPlay: AutoPlayState(enabled: false, delayMs: 1500),
      banner: '',
      log: <String>[],
      interactionLocked: false,
    );
  }

  final GamePhase phase;
  final AppLanguage language;
  final SetupDraft setupDraft;
  final List<PlayerState> players;
  final List<PlayingCard> deck;
  final bool reversePyramid;
  final BusStartSide busStartSide;
  final int warmupRound;
  final int currentPlayerIndex;
  final List<PlayingCard?> pyramidCards;
  final int pyramidRevealIndex;
  final int? busRunnerIndex;
  final TieBreakState? tieBreak;
  final BusRouteState? busRoute;
  final WarmupGuess? pendingWarmupGuess;
  final BannerTone bannerTone;
  final List<int> pyramidHighlightPlayers;
  final AutoPlayState autoPlay;
  final String banner;
  final List<String> log;
  final bool interactionLocked;

  GameState copyWith({
    GamePhase? phase,
    AppLanguage? language,
    SetupDraft? setupDraft,
    List<PlayerState>? players,
    List<PlayingCard>? deck,
    bool? reversePyramid,
    BusStartSide? busStartSide,
    int? warmupRound,
    int? currentPlayerIndex,
    List<PlayingCard?>? pyramidCards,
    int? pyramidRevealIndex,
    int? busRunnerIndex,
    bool clearBusRunnerIndex = false,
    TieBreakState? tieBreak,
    bool clearTieBreak = false,
    BusRouteState? busRoute,
    bool clearBusRoute = false,
    WarmupGuess? pendingWarmupGuess,
    bool clearPendingWarmupGuess = false,
    BannerTone? bannerTone,
    List<int>? pyramidHighlightPlayers,
    AutoPlayState? autoPlay,
    String? banner,
    List<String>? log,
    bool? interactionLocked,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      language: language ?? this.language,
      setupDraft: setupDraft ?? this.setupDraft,
      players: players ?? this.players,
      deck: deck ?? this.deck,
      reversePyramid: reversePyramid ?? this.reversePyramid,
      busStartSide: busStartSide ?? this.busStartSide,
      warmupRound: warmupRound ?? this.warmupRound,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      pyramidCards: pyramidCards ?? this.pyramidCards,
      pyramidRevealIndex: pyramidRevealIndex ?? this.pyramidRevealIndex,
      busRunnerIndex:
          clearBusRunnerIndex ? null : (busRunnerIndex ?? this.busRunnerIndex),
      tieBreak: clearTieBreak ? null : (tieBreak ?? this.tieBreak),
      busRoute: clearBusRoute ? null : (busRoute ?? this.busRoute),
      pendingWarmupGuess: clearPendingWarmupGuess
          ? null
          : (pendingWarmupGuess ?? this.pendingWarmupGuess),
      bannerTone: bannerTone ?? this.bannerTone,
      pyramidHighlightPlayers:
          pyramidHighlightPlayers ?? this.pyramidHighlightPlayers,
      autoPlay: autoPlay ?? this.autoPlay,
      banner: banner ?? this.banner,
      log: log ?? this.log,
      interactionLocked: interactionLocked ?? this.interactionLocked,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'phase': phase.name,
      'language': language.name,
      'setupDraft': setupDraft.toJson(),
      'players': players.map((PlayerState player) => player.toJson()).toList(),
      'deck': deck.map((PlayingCard card) => card.toJson()).toList(),
      'reversePyramid': reversePyramid,
      'busStartSide': busStartSide.name,
      'warmupRound': warmupRound,
      'currentPlayerIndex': currentPlayerIndex,
      'pyramidCards': pyramidCards
          .map((PlayingCard? card) => card == null ? null : card.toJson())
          .toList(),
      'pyramidRevealIndex': pyramidRevealIndex,
      'busRunnerIndex': busRunnerIndex,
      'tieBreak': tieBreak?.toJson(),
      'busRoute': busRoute?.toJson(),
      'pendingWarmupGuess': pendingWarmupGuess?.name,
      'bannerTone': bannerTone.name,
      'pyramidHighlightPlayers': pyramidHighlightPlayers,
      'autoPlay': autoPlay.toJson(),
      'banner': banner,
      'log': log,
      'interactionLocked': interactionLocked,
    };
  }

  static GameState fromJson(Map<String, dynamic> json) {
    List<PlayingCard> parseCards(String key) {
      final List<dynamic> raw = json[key] as List<dynamic>;
      return raw
          .map((dynamic item) =>
              PlayingCard.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final List<dynamic> rawPlayers = json['players'] as List<dynamic>;
    final List<dynamic> rawPyramidCards = json['pyramidCards'] as List<dynamic>;

    return GameState(
      phase: GamePhase.values.byName(json['phase'] as String),
      language: AppLanguage.values.byName(json['language'] as String),
      setupDraft: SetupDraft.fromJson(json['setupDraft'] as Map<String, dynamic>),
      players: rawPlayers
          .map(
              (dynamic item) => PlayerState.fromJson(item as Map<String, dynamic>))
          .toList(),
      deck: parseCards('deck'),
      reversePyramid: json['reversePyramid'] as bool,
      busStartSide: BusStartSide.values.byName(json['busStartSide'] as String),
      warmupRound: json['warmupRound'] as int,
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      pyramidCards: rawPyramidCards.map((dynamic item) {
        if (item == null) {
          return null;
        }
        return PlayingCard.fromJson(item as Map<String, dynamic>);
      }).toList(),
      pyramidRevealIndex: json['pyramidRevealIndex'] as int,
      busRunnerIndex: json['busRunnerIndex'] as int?,
      tieBreak: json['tieBreak'] == null
          ? null
          : TieBreakState.fromJson(json['tieBreak'] as Map<String, dynamic>),
      busRoute: json['busRoute'] == null
          ? null
          : BusRouteState.fromJson(json['busRoute'] as Map<String, dynamic>),
      pendingWarmupGuess: json['pendingWarmupGuess'] == null
          ? null
          : WarmupGuess.values.byName(json['pendingWarmupGuess'] as String),
      bannerTone: BannerTone.values.byName(json['bannerTone'] as String),
      pyramidHighlightPlayers:
          (json['pyramidHighlightPlayers'] as List<dynamic>).cast<int>(),
      autoPlay: AutoPlayState.fromJson(json['autoPlay'] as Map<String, dynamic>),
      banner: json['banner'] as String,
      log: (json['log'] as List<dynamic>).cast<String>(),
      interactionLocked: json['interactionLocked'] as bool,
    );
  }

  String toEncodedJson() {
    return jsonEncode(toJson());
  }

  static GameState fromEncodedJson(String payload) {
    final Map<String, dynamic> decoded =
        jsonDecode(payload) as Map<String, dynamic>;
    return fromJson(decoded);
  }
}

