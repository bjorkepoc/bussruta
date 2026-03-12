import 'dart:math';

import 'package:bussruta_app/domain/game_models.dart';

class GameEngine {
  GameEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const int minPlayers = 1;
  static const int maxPlayers = 9;
  static const int maxLogItems = 140;
  static const int busRouteLength = 5;
  static const int maxBusZoneStackSize = 6;

  static const List<String> _randomStarts = <String>[
    'River',
    'Echo',
    'Nova',
    'Mango',
    'Polar',
    'Velvet',
    'Sunny',
    'Pixel',
    'Frost',
    'Clover',
    'Lemon',
    'Rogue',
  ];

  static const List<String> _randomEnds = <String>[
    'Fox',
    'Raven',
    'Tiger',
    'Otter',
    'Falcon',
    'Comet',
    'Wolf',
    'Panda',
    'Hawk',
    'Lynx',
    'Moose',
    'Shark',
  ];

  SetupDraft defaultSetupDraft() {
    return const SetupDraft(
      playerCount: 4,
      names: <String>['', '', '', ''],
      reversePyramid: false,
    );
  }

  SetupDraft resizeSetupDraft(SetupDraft draft, int nextCount) {
    final int count = nextCount.clamp(minPlayers, maxPlayers);
    final List<String> names = List<String>.from(draft.names);
    while (names.length < count) {
      names.add('');
    }
    if (names.length > count) {
      names.removeRange(count, names.length);
    }
    return draft.copyWith(playerCount: count, names: names);
  }

  List<String> randomSetupNames({
    required int count,
    required AppLanguage language,
  }) {
    final int total = count.clamp(minPlayers, maxPlayers);
    final String fallbackPrefix =
        language == AppLanguage.no ? 'Spiller' : 'Player';
    final Set<String> used = <String>{};
    final List<String> generated = <String>[];

    for (int i = 0; i < total; i += 1) {
      int tries = 0;
      String candidate = '';
      while (tries < 40) {
        final String start = _randomStarts[_random.nextInt(_randomStarts.length)];
        final String end = _randomEnds[_random.nextInt(_randomEnds.length)];
        candidate = '$start $end';
        if (!used.contains(candidate.toLowerCase())) {
          break;
        }
        tries += 1;
      }
      if (candidate.isEmpty || used.contains(candidate.toLowerCase())) {
        candidate = '$fallbackPrefix ${i + 1}';
      }
      used.add(candidate.toLowerCase());
      generated.add(candidate);
    }

    return generated;
  }

  GameState resetToSetup(GameState state, {required bool hardReset}) {
    final SetupDraft nextDraft;
    final AppLanguage nextLanguage;
    final int nextAutoPlayDelay;

    if (hardReset) {
      nextDraft = defaultSetupDraft();
      nextLanguage = AppLanguage.en;
      nextAutoPlayDelay = 1500;
    } else if (state.players.isNotEmpty) {
      nextDraft = SetupDraft(
        playerCount: state.players.length,
        names: state.players.map((PlayerState player) => player.name).toList(),
        reversePyramid: state.reversePyramid,
      );
      nextLanguage = state.language;
      nextAutoPlayDelay = state.autoPlay.delayMs;
    } else {
      nextDraft = state.setupDraft;
      nextLanguage = state.language;
      nextAutoPlayDelay = state.autoPlay.delayMs;
    }

    return GameState.initial().copyWith(
      phase: GamePhase.setup,
      language: nextLanguage,
      setupDraft: nextDraft,
      reversePyramid: nextDraft.reversePyramid,
      autoPlay: AutoPlayState(enabled: false, delayMs: nextAutoPlayDelay),
      banner: '',
      log: <String>[],
      interactionLocked: false,
    );
  }

  GameState startGame({
    required GameState state,
    required List<String> rawNames,
    required bool reversePyramid,
    required AppLanguage language,
  }) {
    final List<String> normalizedNames = normalizePlayerNames(rawNames);
    if (normalizedNames.length < minPlayers ||
        normalizedNames.length > maxPlayers) {
      throw ArgumentError(
        'Player count must be between $minPlayers and $maxPlayers.',
      );
    }

    final List<String> dedupedNames = dedupePlayerNames(normalizedNames, language);
    final List<PlayerState> players = dedupedNames
        .map(
          (String name) =>
              const PlayerState(name: '', hand: <PlayingCard>[])
                  .copyWith(name: name),
        )
        .toList();
    final List<PlayingCard> deck = createDeck();

    final SetupDraft remembered = SetupDraft(
      playerCount: dedupedNames.length,
      names: List<String>.from(dedupedNames),
      reversePyramid: reversePyramid,
    );

    final List<String> logs = <String>[];
    _pushLog(
      logs,
      _tr(
        language,
        'Game started with ${players.length} player(s).',
        'Spillet startet med ${players.length} spillere.',
      ),
    );
    _pushLog(
      logs,
      reversePyramid
          ? _tr(
              language,
              'Pyramid drinks are reversed: bottom = 5, top = 1.',
              'Pyramide er reversert: nederst = 5, overst = 1.',
            )
          : _tr(
              language,
              'Pyramid drinks are normal: bottom = 1, top = 5.',
              'Pyramide er normal: nederst = 1, overst = 5.',
            ),
    );
    _pushLog(
      logs,
      _tr(
        language,
        'Warmup tip: choose a guess and draw immediately.',
        'Oppvarmingstips: velg gjetning og trekk med en gang.',
      ),
    );

    return GameState.initial().copyWith(
      phase: GamePhase.warmup,
      language: language,
      setupDraft: remembered,
      players: players,
      deck: deck,
      reversePyramid: reversePyramid,
      busStartSide: BusStartSide.left,
      warmupRound: 1,
      currentPlayerIndex: 0,
      pyramidCards: List<PlayingCard?>.filled(15, null),
      pyramidRevealIndex: 0,
      clearBusRunnerIndex: true,
      clearTieBreak: true,
      clearBusRoute: true,
      clearPendingWarmupGuess: true,
      bannerTone: BannerTone.info,
      pyramidHighlightPlayers: <int>[],
      autoPlay: AutoPlayState(
        enabled: false,
        delayMs: state.autoPlay.delayMs,
      ),
      banner: '',
      log: logs,
      interactionLocked: false,
    );
  }

  List<String> normalizePlayerNames(List<String> names) {
    return names.map((String name) => name.trim()).toList();
  }

  List<String> dedupePlayerNames(List<String> names, AppLanguage language) {
    final String prefix = language == AppLanguage.no ? 'Spiller' : 'Player';
    final Set<String> used = <String>{};
    final Map<String, int> countByBase = <String, int>{};
    final List<String> normalized = <String>[];

    for (int index = 0; index < names.length; index += 1) {
      final String raw = names[index].trim();
      final String baseRaw = raw.isEmpty ? '$prefix ${index + 1}' : raw;
      final String baseKey = baseRaw.toLowerCase();
      int baseCount = (countByBase[baseKey] ?? 0) + 1;
      countByBase[baseKey] = baseCount;

      String candidate = baseCount == 1 ? baseRaw : '$baseRaw $baseCount';
      while (used.contains(candidate.toLowerCase())) {
        baseCount += 1;
        countByBase[baseKey] = baseCount;
        candidate = '$baseRaw $baseCount';
      }

      used.add(candidate.toLowerCase());
      normalized.add(candidate);
    }

    return normalized;
  }

  GameState playWarmupGuess(GameState state, WarmupGuess guess) {
    if (state.phase != GamePhase.warmup) {
      return state;
    }
    final PlayerState currentPlayer = state.players[state.currentPlayerIndex];
    final _DeckDraw mainDeckDraw = _drawFromMainDeck(state.deck, state.language);
    final WarmupEvaluation evaluation = _evaluateWarmupRound(
      round: state.warmupRound,
      guess: guess,
      player: currentPlayer,
      drawnCard: mainDeckDraw.card,
      language: state.language,
    );

    final List<PlayerState> players = state.players
        .map(
          (PlayerState player) =>
              player.copyWith(hand: List<PlayingCard>.from(player.hand)),
        )
        .toList();
    players[state.currentPlayerIndex].hand.add(mainDeckDraw.card);

    final List<String> logs = List<String>.from(state.log);
    logs.insertAll(0, mainDeckDraw.logs.reversed);
    _pushLog(logs, evaluation.message);

    GameState next = state.copyWith(
      players: players,
      deck: mainDeckDraw.deck,
      bannerTone: evaluation.correct ? BannerTone.success : BannerTone.fail,
      banner: evaluation.message,
      clearPendingWarmupGuess: true,
      log: logs,
    );

    next = _advanceWarmupTurn(next);
    return next;
  }

  GameState _advanceWarmupTurn(GameState state) {
    final List<String> logs = List<String>.from(state.log);

    if (state.currentPlayerIndex < state.players.length - 1) {
      return state.copyWith(currentPlayerIndex: state.currentPlayerIndex + 1);
    }

    if (state.warmupRound < 4) {
      final int nextRound = state.warmupRound + 1;
      _pushLog(
        logs,
        _tr(
          state.language,
          'Warmup round $nextRound begins.',
          'Oppvarmingsrunde $nextRound starter.',
        ),
      );
      return state.copyWith(
        warmupRound: nextRound,
        currentPlayerIndex: 0,
        log: logs,
      );
    }

    _pushLog(
      logs,
      _tr(
        state.language,
        'Warmup is complete. Pyramid phase begins.',
        'Oppvarmingen er ferdig. Pyramiden starter.',
      ),
    );
    return state.copyWith(
      phase: GamePhase.pyramid,
      currentPlayerIndex: 0,
      pyramidHighlightPlayers: <int>[],
      bannerTone: BannerTone.info,
      banner: _tr(
        state.language,
        'Tap the next highlighted pyramid card.',
        'Trykk neste markerte kort i pyramiden.',
      ),
      log: logs,
    );
  }

  GameState revealNextPyramidSlot(GameState state) {
    if (state.phase != GamePhase.pyramid) {
      return state;
    }

    final int targetIndex = pyramidSlotForStep(
      step: state.pyramidRevealIndex,
      reversePyramid: state.reversePyramid,
    );
    final _DeckDraw draw = _drawFromMainDeck(state.deck, state.language);
    final int drinksBase = pyramidDrinksForIndex(
      index: targetIndex,
      reversePyramid: state.reversePyramid,
    );

    final List<PlayingCard?> pyramidCards =
        List<PlayingCard?>.from(state.pyramidCards);
    pyramidCards[targetIndex] = draw.card;

    final List<PlayerState> players = state.players
        .map(
          (PlayerState player) =>
              player.copyWith(hand: List<PlayingCard>.from(player.hand)),
        )
        .toList();

    final List<PyramidMatch> matches = _collectPyramidMatches(
      players: players,
      card: draw.card,
      drinksBase: drinksBase,
    );

    if (matches.isNotEmpty) {
      for (final PyramidMatch match in matches) {
        players[match.playerIndex] = players[match.playerIndex].copyWith(
          hand: players[match.playerIndex]
              .hand
              .where((PlayingCard handCard) => handCard.rank != draw.card.rank)
              .toList(),
        );
      }
    }

    final List<String> logs = List<String>.from(state.log);
    logs.insertAll(0, draw.logs.reversed);
    _pushLog(
      logs,
      _tr(
        state.language,
        'Pyramid revealed ${draw.card.shortLabel()} (row value $drinksBase).',
        'Pyramiden viste ${draw.card.shortLabel()} (radverdi $drinksBase).',
      ),
    );

    String banner;
    BannerTone bannerTone;
    if (matches.isEmpty) {
      _pushLog(
        logs,
        _tr(
          state.language,
          'No player had rank ${draw.card.rankLabel}.',
          'Ingen hadde rank ${draw.card.rankLabel}.',
        ),
      );
      banner = _tr(
        state.language,
        '${draw.card.shortLabel()} gave no matches. No drinks handed out.',
        '${draw.card.shortLabel()} ga ingen treff. Ingen kan dele ut.',
      );
      bannerTone = BannerTone.fail;
    } else {
      for (final PyramidMatch match in matches) {
        _pushLog(
          logs,
          _tr(
            state.language,
            '${match.playerName} matched ${match.count} card(s) and can give out ${match.drinks} drink(s).',
            '${match.playerName} hadde ${match.count} treff og kan dele ut ${match.drinks}.',
          ),
        );
      }
      final String details = matches
          .map((PyramidMatch match) => '${match.playerName}: ${match.drinks}')
          .join(' | ');
      banner = _tr(
        state.language,
        '${draw.card.shortLabel()} matched. $details',
        '${draw.card.shortLabel()} ga treff. $details',
      );
      bannerTone = BannerTone.success;
    }

    GameState next = state.copyWith(
      players: players,
      deck: draw.deck,
      pyramidCards: pyramidCards,
      pyramidRevealIndex: state.pyramidRevealIndex + 1,
      pyramidHighlightPlayers:
          matches.map((PyramidMatch match) => match.playerIndex).toList(),
      banner: banner,
      bannerTone: bannerTone,
      log: logs,
    );

    if (next.pyramidRevealIndex == 15) {
      next = _finalizePyramid(next);
    }

    return next;
  }

  GameState _finalizePyramid(GameState state) {
    final List<int> counts =
        state.players.map((PlayerState player) => player.hand.length).toList();
    int maxCount = 0;
    for (final int count in counts) {
      if (count > maxCount) {
        maxCount = count;
      }
    }

    final List<int> contenders = <int>[];
    for (int i = 0; i < counts.length; i += 1) {
      if (counts[i] == maxCount) {
        contenders.add(i);
      }
    }

    if (contenders.length == 1) {
      final int winner = contenders.first;
      final List<String> logs = List<String>.from(state.log);
      _pushLog(
        logs,
        _tr(
          state.language,
          '${state.players[winner].name} has most cards ($maxCount) and takes bus route.',
          '${state.players[winner].name} har flest kort ($maxCount) og ma ta bussruta.',
        ),
      );
      return _startBusRoute(
        state.copyWith(
          busRunnerIndex: winner,
          log: logs,
        ),
      );
    }

    return _startTieBreak(state, contenders: contenders, maxCount: maxCount);
  }

  GameState _startTieBreak(
    GameState state, {
    required List<int> contenders,
    required int maxCount,
  }) {
    final List<String> logs = List<String>.from(state.log);
    _pushLog(
      logs,
      _tr(
        state.language,
        'Tie on most cards ($maxCount). Starting tie-break.',
        'Likestilling med flest kort ($maxCount). Starter tie-break.',
      ),
    );
    return state.copyWith(
      phase: GamePhase.tiebreak,
      tieBreak: TieBreakState(
        contenders: List<int>.from(contenders),
        deck: createDeck(),
        round: 1,
        lastDraws: <TieBreakDraw>[],
      ),
      bannerTone: BannerTone.info,
      banner: _tr(
        state.language,
        'Tie-break: highest card wins. Tap deck to draw.',
        'Tie-break: hoyeste kort vinner. Trykk stokken for trekk.',
      ),
      log: logs,
    );
  }

  GameState runTieBreakRound(GameState state) {
    if (state.phase != GamePhase.tiebreak || state.tieBreak == null) {
      return state;
    }

    final TieBreakState tie = state.tieBreak!;
    if (tie.contenders.length < 2) {
      return state;
    }

    List<PlayingCard> deck = List<PlayingCard>.from(tie.deck);
    final List<String> logs = List<String>.from(state.log);
    if (deck.length < tie.contenders.length) {
      deck = createDeck();
      _pushLog(
        logs,
        _tr(
          state.language,
          'Tie-break deck reshuffled.',
          'Tie-break-stokk stokket pa nytt.',
        ),
      );
    }

    final List<TieBreakDraw> draws = <TieBreakDraw>[];
    for (final int idx in tie.contenders) {
      final PlayingCard draw = deck.removeLast();
      draws.add(TieBreakDraw(playerIndex: idx, card: draw));
    }

    int highest = 0;
    for (final TieBreakDraw entry in draws) {
      if (entry.card.rank > highest) {
        highest = entry.card.rank;
      }
    }

    final List<int> nextContenders = draws
        .where((TieBreakDraw entry) => entry.card.rank == highest)
        .map((TieBreakDraw entry) => entry.playerIndex)
        .toList();

    final String summary = draws
        .map(
          (TieBreakDraw entry) =>
              '${state.players[entry.playerIndex].name}: ${entry.card.shortLabel()}',
        )
        .join(' | ');
    _pushLog(
      logs,
      _tr(
        state.language,
        'Tie-break round ${tie.round}: $summary.',
        'Tie-break runde ${tie.round}: $summary.',
      ),
    );

    if (nextContenders.length == 1) {
      final int winner = nextContenders.first;
      _pushLog(
        logs,
        _tr(
          state.language,
          '${state.players[winner].name} won tie-break and takes bus route.',
          '${state.players[winner].name} vant tie-break og tar bussruta.',
        ),
      );
      return _startBusRoute(
        state.copyWith(
          busRunnerIndex: winner,
          clearTieBreak: true,
          log: logs,
        ),
      );
    }

    return state.copyWith(
      tieBreak: tie.copyWith(
        contenders: nextContenders,
        deck: deck,
        round: tie.round + 1,
        lastDraws: draws,
      ),
      bannerTone: BannerTone.info,
      banner: _tr(
        state.language,
        '${nextContenders.length} players are still tied. Draw next tie-break round.',
        '${nextContenders.length} spillere er fortsatt likt. Trekk neste tie-break-runde.',
      ),
      log: logs,
    );
  }

  GameState _startBusRoute(GameState state) {
    final bool pausedAutoPlay = state.autoPlay.enabled;
    final List<String> logs = List<String>.from(state.log);
    if (pausedAutoPlay) {
      _pushLog(
        logs,
        _tr(
          state.language,
          'Auto play paused for bus route. Press Auto Play again to continue automatically.',
          'Autospill stoppet ved bussruta. Trykk Autospill igjen for a fortsette automatisk.',
        ),
      );
    }

    final List<PlayingCard> busDeck = createDeck();
    final List<PlayingCard> routeCards = <PlayingCard>[];
    for (int i = 0; i < busRouteLength; i += 1) {
      routeCards.add(busDeck.removeLast());
    }

    final BusRouteState routeState = BusRouteState(
      routeCards: routeCards,
      deck: busDeck,
      overlays: List<BusZoneStack>.generate(
        busRouteLength,
        (_) => const BusZoneStack(
          high: <PlayingCard>[],
          low: <PlayingCard>[],
          same: <PlayingCard>[],
        ),
      ),
      zoneTone: List<BusZoneTone>.generate(
        busRouteLength,
        (_) => const BusZoneTone(high: null, low: null, same: null),
      ),
      startSide: null,
      order: const <int>[0, 1, 2, 3, 4],
      progress: 0,
      firstTry: true,
      history: const <BusHistoryEntry>[],
    );

    final String runnerName = state.busRunnerIndex == null
        ? _tr(state.language, 'Runner', 'Deltaker')
        : state.players[state.busRunnerIndex!].name;
    final String pausedNote = pausedAutoPlay
        ? _tr(
            state.language,
            ' Auto play is paused here; press Auto Play again after choosing side.',
            ' Autospill er pause her; trykk Autospill igjen etter sidevalg.',
          )
        : '';
    final String banner = _tr(
      state.language,
      '$runnerName must choose start side after the route cards are dealt.$pausedNote',
      '$runnerName ma velge startside etter at rutekortene er lagt ut.$pausedNote',
    );
    _pushLog(logs, banner);

    return state.copyWith(
      phase: GamePhase.bussetup,
      busRoute: routeState,
      bannerTone: BannerTone.info,
      banner: banner,
      autoPlay: state.autoPlay.copyWith(enabled: false),
      log: logs,
    );
  }

  GameState beginBusRoute(GameState state, BusStartSide startSide) {
    if (state.phase != GamePhase.bussetup || state.busRoute == null) {
      return state;
    }

    final List<int> order = startSide == BusStartSide.right
        ? const <int>[4, 3, 2, 1, 0]
        : const <int>[0, 1, 2, 3, 4];
    final BusRouteState bus = state.busRoute!;

    final String message = _tr(
      state.language,
      '${state.players[state.busRunnerIndex!].name} starts the bus route from the ${startSide.name}.',
      '${state.players[state.busRunnerIndex!].name} starter bussruta fra ${startSide == BusStartSide.right ? 'hoyre' : 'venstre'}.',
    );
    final List<String> logs = List<String>.from(state.log);
    _pushLog(logs, message);

    return state.copyWith(
      phase: GamePhase.bus,
      busStartSide: startSide,
      busRoute: bus.copyWith(
        startSide: startSide,
        order: order,
        progress: 0,
        firstTry: true,
      ),
      bannerTone: BannerTone.info,
      banner: message,
      log: logs,
    );
  }

  GameState playBusGuess(GameState state, BusGuess guess) {
    if (state.phase != GamePhase.bus || state.busRoute == null) {
      return state;
    }

    final BusRouteState bus = state.busRoute!;
    final int activeStep = bus.order[bus.progress];
    final PlayingCard target = bus.routeCards[activeStep];

    final _DeckDraw busDraw = _drawFromBusDeck(bus.deck, state.language);
    final PlayingCard draw = busDraw.card;
    final int relation = _compareCardRanks(draw.rank, target.rank);

    int progress = bus.progress;
    bool firstTry = bus.firstTry;
    bool correct = false;
    bool restartRoute = false;
    late final String message;

    if (guess == BusGuess.above && relation > 0) {
      correct = true;
      progress += 1;
      message = _tr(
        state.language,
        'Correct: ${draw.shortLabel()} is higher than ${target.shortLabel()}.',
        'Riktig: ${draw.shortLabel()} er hoyere enn ${target.shortLabel()}.',
      );
    } else if (guess == BusGuess.below && relation < 0) {
      correct = true;
      progress += 1;
      message = _tr(
        state.language,
        'Correct: ${draw.shortLabel()} is lower than ${target.shortLabel()}.',
        'Riktig: ${draw.shortLabel()} er lavere enn ${target.shortLabel()}.',
      );
    } else if (guess == BusGuess.same && relation == 0) {
      correct = true;
      progress += 1;
      message = _tr(
        state.language,
        'Correct: ${draw.shortLabel()} equals ${target.shortLabel()}.',
        'Riktig: ${draw.shortLabel()} er lik ${target.shortLabel()}.',
      );
    } else if (relation == 0 && progress > 0 && guess != BusGuess.same) {
      message = _tr(
        state.language,
        'Equal card ${draw.shortLabel()}. Drink ${progress + 1} and retry this step.',
        'Lik verdi ${draw.shortLabel()}. Drikk ${progress + 1} og prov samme steg igjen.',
      );
    } else {
      restartRoute = true;
      firstTry = false;
      message = _tr(
        state.language,
        'Wrong with ${draw.shortLabel()}. Drink ${progress + 1} and restart route.',
        'Feil med ${draw.shortLabel()}. Drikk ${progress + 1} og start ruta pa nytt.',
      );
    }

    final List<BusZoneStack> overlays = bus.overlays
        .map(
          (BusZoneStack zone) => zone.copyWith(
            high: List<PlayingCard>.from(zone.high),
            low: List<PlayingCard>.from(zone.low),
            same: List<PlayingCard>.from(zone.same),
          ),
        )
        .toList();
    final List<BusZoneTone> tones = List<BusZoneTone>.from(bus.zoneTone);
    final String placement = _busGuessPlacement(guess);

    BusZoneStack activeZone = overlays[activeStep];
    if (placement == 'high') {
      final List<PlayingCard> cards = List<PlayingCard>.from(activeZone.high)
        ..add(draw);
      if (cards.length > maxBusZoneStackSize) {
        cards.removeAt(0);
      }
      activeZone = activeZone.copyWith(high: cards);
    } else if (placement == 'low') {
      final List<PlayingCard> cards = List<PlayingCard>.from(activeZone.low)
        ..add(draw);
      if (cards.length > maxBusZoneStackSize) {
        cards.removeAt(0);
      }
      activeZone = activeZone.copyWith(low: cards);
    } else {
      final List<PlayingCard> cards = List<PlayingCard>.from(activeZone.same)
        ..add(draw);
      if (cards.length > maxBusZoneStackSize) {
        cards.removeAt(0);
      }
      activeZone = activeZone.copyWith(same: cards);
    }
    overlays[activeStep] = activeZone;

    BusZoneTone tone = const BusZoneTone(high: null, low: null, same: null);
    if (placement == 'high') {
      tone = tone.copyWith(high: correct ? BannerTone.success : BannerTone.fail);
    } else if (placement == 'low') {
      tone = tone.copyWith(low: correct ? BannerTone.success : BannerTone.fail);
    } else {
      tone = tone.copyWith(same: correct ? BannerTone.success : BannerTone.fail);
    }
    tones[activeStep] = tone;

    if (restartRoute && progress > 0) {
      for (int idx = 0; idx < progress; idx += 1) {
        final int cardIndex = bus.order[idx];
        tones[cardIndex] = const BusZoneTone(high: null, low: null, same: null);
      }
      progress = 0;
    }

    final List<String> logs = List<String>.from(state.log);
    logs.insertAll(0, busDraw.logs.reversed);
    _pushLog(logs, message);

    final List<BusHistoryEntry> history = List<BusHistoryEntry>.from(bus.history)
      ..add(
        BusHistoryEntry(
          step: activeStep,
          guess: guess,
          target: target,
          draw: draw,
          message: message,
          correct: correct,
        ),
      );

    GameState next = state.copyWith(
      busRoute: bus.copyWith(
        deck: busDraw.deck,
        overlays: overlays,
        zoneTone: tones,
        progress: progress,
        firstTry: firstTry,
        history: history,
      ),
      bannerTone: correct ? BannerTone.success : BannerTone.fail,
      banner: message,
      log: logs,
    );

    if (progress >= busRouteLength) {
      final String finishText = firstTry
          ? _tr(
              state.language,
              '${state.players[state.busRunnerIndex!].name} finished on first try. Everyone else finishes drinks.',
              '${state.players[state.busRunnerIndex!].name} klarte det pa forste forsok. Alle andre ma fullfore enheten sin.',
            )
          : _tr(
              state.language,
              '${state.players[state.busRunnerIndex!].name} completed the bus route.',
              '${state.players[state.busRunnerIndex!].name} fullforte bussruta.',
            );
      final List<String> finishedLogs = List<String>.from(next.log);
      _pushLog(finishedLogs, finishText);
      next = next.copyWith(
        phase: GamePhase.finished,
        bannerTone: BannerTone.success,
        banner: finishText,
        log: finishedLogs,
      );
    }

    return next;
  }

  List<PlayingCard> createDeck() {
    final List<PlayingCard> deck = <PlayingCard>[];
    for (final Suit suit in Suit.values) {
      for (int rank = 1; rank <= 13; rank += 1) {
        deck.add(PlayingCard(suit: suit, rank: rank));
      }
    }
    _shuffle(deck);
    return deck;
  }

  void _shuffle(List<PlayingCard> cards) {
    for (int i = cards.length - 1; i > 0; i -= 1) {
      final int j = _random.nextInt(i + 1);
      final PlayingCard tmp = cards[i];
      cards[i] = cards[j];
      cards[j] = tmp;
    }
  }

  int _compareCardRanks(int a, int b) {
    if (a > b) {
      return 1;
    }
    if (a < b) {
      return -1;
    }
    return 0;
  }

  String _tr(AppLanguage language, String english, String norwegian) {
    return language == AppLanguage.no ? norwegian : english;
  }

  void _pushLog(List<String> logs, String message) {
    logs.insert(0, message);
    if (logs.length > maxLogItems) {
      logs.removeRange(maxLogItems, logs.length);
    }
  }
}
