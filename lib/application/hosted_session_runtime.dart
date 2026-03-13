import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';

class HostedSessionRuntime {
  HostedSessionRuntime({
    required GameEngine engine,
    required HostedSessionState initialState,
  }) : _engine = engine,
       _state = initialState;

  final GameEngine _engine;
  HostedSessionState _state;

  HostedSessionState get state => _state;

  HostedSessionState addParticipant({
    required int playerId,
    required String name,
    bool connected = true,
  }) {
    if (_state.hasStarted) {
      _state = _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Cannot join after game start.',
          'Kan ikke bli med etter spillstart.',
        ),
      );
      return _state;
    }
    if (_state.participantById(playerId) != null) {
      return _state;
    }
    final List<HostedParticipant> participants =
        List<HostedParticipant>.from(_state.participants)..add(
          HostedParticipant(
            playerId: playerId,
            name: name.trim().isEmpty ? 'Player $playerId' : name.trim(),
            isHost: false,
            connected: connected,
          ),
        );
    final List<int> order = List<int>.from(_state.playerOrder)..add(playerId);
    _state = _state.copyWith(
      participants: participants,
      playerOrder: order,
      clearLastError: true,
    );
    return _state;
  }

  HostedSessionState updateParticipantConnection({
    required int playerId,
    required bool connected,
  }) {
    final List<HostedParticipant> participants = _state.participants.map((
      HostedParticipant participant,
    ) {
      if (participant.playerId != playerId) {
        return participant;
      }
      return participant.copyWith(connected: connected);
    }).toList();
    _state = _state.copyWith(participants: participants);
    return _state;
  }

  HostedSessionState applyCommand(HostedSessionCommand command) {
    if (_state.pendingDrinkDistribution != null &&
        command.type != HostedCommandType.assignDrinks &&
        command.type != HostedCommandType.acknowledgeDrinks &&
        command.type != HostedCommandType.resetToSetup) {
      _state = _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Finish drink assignment first.',
          'Fordel drikker ferdig forst.',
        ),
      );
      return _state;
    }

    switch (command.type) {
      case HostedCommandType.startGame:
        _state = _handleStartGame(command);
        break;
      case HostedCommandType.resetToSetup:
        _state = _handleResetToSetup(command);
        break;
      case HostedCommandType.warmupGuess:
        _state = _handleWarmupGuess(command);
        break;
      case HostedCommandType.revealPyramid:
        _state = _handleRevealPyramid(command);
        break;
      case HostedCommandType.runTieBreakRound:
        _state = _handleRunTieBreak(command);
        break;
      case HostedCommandType.beginBusRoute:
        _state = _handleBeginBusRoute(command);
        break;
      case HostedCommandType.playBusGuess:
        _state = _handlePlayBusGuess(command);
        break;
      case HostedCommandType.assignDrinks:
        _state = _handleAssignDrinks(command);
        break;
      case HostedCommandType.acknowledgeDrinks:
        _state = _handleAcknowledgeDrinks(command);
        break;
      case HostedCommandType.toggleAutoPlay:
        _state = _handleToggleAutoPlay(command);
        break;
      case HostedCommandType.setAutoPlayDelayMs:
        _state = _handleSetAutoPlayDelayMs(command);
        break;
    }
    return _state;
  }

  HostedSessionState _handleStartGame(HostedSessionCommand command) {
    if (!_isHost(command.playerId)) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Only host can start hosted game.',
          'Kun verten kan starte hostet spill.',
        ),
      );
    }
    if (_state.participants.length < GameEngine.minPlayers) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Need at least one player.',
          'Minst en spiller kreves.',
        ),
      );
    }

    final List<HostedParticipant> orderedParticipants = _orderedParticipants();
    final List<String> names = orderedParticipants
        .map((HostedParticipant participant) => participant.name)
        .toList();
    final List<int> playerOrder = orderedParticipants
        .map((HostedParticipant participant) => participant.playerId)
        .toList();

    try {
      final GameState gameState = _engine.startGame(
        state: _state.gameState,
        rawNames: names,
        reversePyramid: _state.gameState.setupDraft.reversePyramid,
        language: _state.gameState.language,
      );
      return _state.copyWith(
        stage: _stageFromPhase(gameState.phase),
        playerOrder: playerOrder,
        gameState: gameState,
        clearPendingDrinkDistribution: true,
        queuedDrinkDistributions: const <HostedPendingDrinkDistribution>[],
        pendingDrinkPenaltyByPlayer: const <int, int>{},
        clearLastError: true,
      );
    } on ArgumentError {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Could not start game with current lobby.',
          'Kunne ikke starte spill med gjeldende lobby.',
        ),
      );
    }
  }

  HostedSessionState _handleResetToSetup(HostedSessionCommand command) {
    if (!_isHost(command.playerId)) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Only host can reset game.',
          'Kun verten kan nullstille spillet.',
        ),
      );
    }
    final GameState reset = _engine.resetToSetup(
      _state.gameState,
      hardReset: false,
    );
    return _state.copyWith(
      stage: HostedSessionStage.lobby,
      gameState: reset,
      clearPendingDrinkDistribution: true,
      queuedDrinkDistributions: const <HostedPendingDrinkDistribution>[],
      pendingDrinkPenaltyByPlayer: const <int, int>{},
      clearLastError: true,
    );
  }

  HostedSessionState _handleWarmupGuess(HostedSessionCommand command) {
    if (_state.gameState.phase != GamePhase.warmup) {
      return _state;
    }
    final int? actorIndex = _state.playerIndexForId(command.playerId);
    if (actorIndex == null ||
        actorIndex != _state.gameState.currentPlayerIndex) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Not your warmup turn.',
          'Det er ikke din oppvarmingstur.',
        ),
      );
    }

    final String? guessRaw = command.payload['guess'] as String?;
    if (guessRaw == null) {
      return _reject(_state, 'Missing warmup guess.');
    }
    final WarmupGuess guess;
    try {
      guess = WarmupGuess.values.byName(guessRaw);
    } on ArgumentError {
      return _reject(_state, 'Invalid warmup guess.');
    }

    final GameState previous = _state.gameState;
    final GameState next = _engine.playWarmupGuess(previous, guess);
    final _WarmupHostedOutcome outcome = _warmupOutcome(
      previous: previous,
      next: next,
      actorIndex: actorIndex,
      guess: guess,
    );

    HostedSessionState updated = _state.copyWith(
      stage: _stageFromPhase(next.phase),
      gameState: next,
      clearLastError: true,
    );

    if (outcome.giveOutDrinks > 0) {
      final int actorId = _state.playerOrder[actorIndex];
      updated =
          _queueDrinkDistributions(updated, <HostedPendingDrinkDistribution>[
            HostedPendingDrinkDistribution(
              sourcePlayerId: actorId,
              totalDrinks: outcome.giveOutDrinks,
              assignedDrinksByTarget: const <int, int>{},
              reason: outcome.reason,
            ),
          ]);
    } else if (outcome.drinkDrinks > 0) {
      final int actorId = _state.playerOrder[actorIndex];
      final Map<int, int> penalties = Map<int, int>.from(
        updated.pendingDrinkPenaltyByPlayer,
      );
      penalties[actorId] = (penalties[actorId] ?? 0) + outcome.drinkDrinks;
      updated = updated.copyWith(pendingDrinkPenaltyByPlayer: penalties);
    }

    return updated;
  }

  HostedSessionState _handleRevealPyramid(HostedSessionCommand command) {
    if (!_isHost(command.playerId)) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Only host can reveal pyramid cards.',
          'Kun verten kan avdekke pyramidekort.',
        ),
      );
    }
    if (_state.gameState.phase != GamePhase.pyramid) {
      return _state;
    }

    final GameState previous = _state.gameState;
    final GameState next = _engine.revealNextPyramidSlot(previous);
    final List<HostedPendingDrinkDistribution> distributions =
        _pyramidDistributions(previous: previous, next: next);

    HostedSessionState updated = _state.copyWith(
      stage: _stageFromPhase(next.phase),
      gameState: next,
      clearLastError: true,
    );
    if (distributions.isNotEmpty) {
      updated = _queueDrinkDistributions(updated, distributions);
    }
    return updated;
  }

  HostedSessionState _handleRunTieBreak(HostedSessionCommand command) {
    if (!_isHost(command.playerId)) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Only host can run tie-break round.',
          'Kun verten kan kjore tie-break-runde.',
        ),
      );
    }
    if (_state.gameState.phase != GamePhase.tiebreak) {
      return _state;
    }
    final GameState next = _engine.runTieBreakRound(_state.gameState);
    return _state.copyWith(
      stage: _stageFromPhase(next.phase),
      gameState: next,
      clearLastError: true,
    );
  }

  HostedSessionState _handleBeginBusRoute(HostedSessionCommand command) {
    if (_state.gameState.phase != GamePhase.bussetup) {
      return _state;
    }
    final int? busRunnerId = _busRunnerPlayerId(_state);
    if (busRunnerId == null || command.playerId != busRunnerId) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Only the bus loser can choose side.',
          'Kun busstaperen kan velge side.',
        ),
      );
    }
    final String? sideRaw = command.payload['side'] as String?;
    if (sideRaw == null) {
      return _reject(_state, 'Missing bus side.');
    }
    final BusStartSide side;
    try {
      side = BusStartSide.values.byName(sideRaw);
    } on ArgumentError {
      return _reject(_state, 'Invalid bus side.');
    }
    final GameState next = _engine.beginBusRoute(_state.gameState, side);
    return _state.copyWith(
      stage: _stageFromPhase(next.phase),
      gameState: next,
      clearLastError: true,
    );
  }

  HostedSessionState _handlePlayBusGuess(HostedSessionCommand command) {
    if (_state.gameState.phase != GamePhase.bus) {
      return _state;
    }
    final int? busRunnerId = _busRunnerPlayerId(_state);
    if (busRunnerId == null || command.playerId != busRunnerId) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Only the bus loser can play bus route.',
          'Kun busstaperen kan spille bussruta.',
        ),
      );
    }
    final String? guessRaw = command.payload['guess'] as String?;
    if (guessRaw == null) {
      return _reject(_state, 'Missing bus guess.');
    }
    final BusGuess guess;
    try {
      guess = BusGuess.values.byName(guessRaw);
    } on ArgumentError {
      return _reject(_state, 'Invalid bus guess.');
    }

    final GameState next = _engine.playBusGuess(_state.gameState, guess);
    return _state.copyWith(
      stage: _stageFromPhase(next.phase),
      gameState: next,
      clearLastError: true,
    );
  }

  HostedSessionState _handleAssignDrinks(HostedSessionCommand command) {
    final HostedPendingDrinkDistribution? pending =
        _state.pendingDrinkDistribution;
    if (pending == null) {
      return _state;
    }
    if (command.playerId != pending.sourcePlayerId) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Only the giving player can assign drinks now.',
          'Kun spilleren som deler ut kan fordele na.',
        ),
      );
    }

    final Object? rawTargets = command.payload['targets'];
    if (rawTargets is! Map<dynamic, dynamic>) {
      return _reject(_state, 'Missing target assignment map.');
    }
    final Map<int, int> increments = <int, int>{};
    for (final MapEntry<dynamic, dynamic> entry in rawTargets.entries) {
      final int target = entry.key is int
          ? entry.key as int
          : int.tryParse(entry.key.toString()) ?? -1;
      final int amount = entry.value is int
          ? entry.value as int
          : int.tryParse(entry.value.toString()) ?? -1;
      if (target <= 0 || amount <= 0) {
        continue;
      }
      if (!_state.playerOrder.contains(target)) {
        continue;
      }
      if (target == pending.sourcePlayerId) {
        continue;
      }
      increments[target] = (increments[target] ?? 0) + amount;
    }
    if (increments.isEmpty) {
      return _reject(_state, 'No valid drink targets provided.');
    }

    int incrementTotal = 0;
    for (final int value in increments.values) {
      incrementTotal += value;
    }
    if (incrementTotal > pending.remainingDrinks) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Assigned drinks exceed remaining amount.',
          'Fordelte drikker overstiger gjenstaende antall.',
        ),
      );
    }

    final Map<int, int> assigned = Map<int, int>.from(
      pending.assignedDrinksByTarget,
    );
    increments.forEach((int key, int value) {
      assigned[key] = (assigned[key] ?? 0) + value;
    });
    final HostedPendingDrinkDistribution nextPending = pending.copyWith(
      assignedDrinksByTarget: assigned,
    );
    if (!nextPending.isComplete) {
      return _state.copyWith(
        pendingDrinkDistribution: nextPending,
        clearLastError: true,
      );
    }

    final Map<int, int> penalties = Map<int, int>.from(
      _state.pendingDrinkPenaltyByPlayer,
    );
    nextPending.assignedDrinksByTarget.forEach((int target, int drinks) {
      penalties[target] = (penalties[target] ?? 0) + drinks;
    });
    final GameState logged = _appendDrinkDistributionLog(
      _state.gameState,
      nextPending,
    );

    final List<HostedPendingDrinkDistribution> queue =
        List<HostedPendingDrinkDistribution>.from(
          _state.queuedDrinkDistributions,
        );
    HostedPendingDrinkDistribution? nextQueueHead;
    if (queue.isNotEmpty) {
      nextQueueHead = queue.removeAt(0);
    }

    return _state.copyWith(
      gameState: logged,
      pendingDrinkDistribution: nextQueueHead,
      queuedDrinkDistributions: queue,
      pendingDrinkPenaltyByPlayer: penalties,
      clearPendingDrinkDistribution: nextQueueHead == null,
      clearLastError: true,
    );
  }

  HostedSessionState _handleAcknowledgeDrinks(HostedSessionCommand command) {
    final int existing =
        _state.pendingDrinkPenaltyByPlayer[command.playerId] ?? 0;
    if (existing <= 0) {
      return _state;
    }
    final Map<int, int> penalties = Map<int, int>.from(
      _state.pendingDrinkPenaltyByPlayer,
    )..remove(command.playerId);
    return _state.copyWith(
      pendingDrinkPenaltyByPlayer: penalties,
      clearLastError: true,
    );
  }

  HostedSessionState _handleToggleAutoPlay(HostedSessionCommand command) {
    if (!_isHost(command.playerId)) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Only host can control auto play.',
          'Kun verten kan styre autospill.',
        ),
      );
    }
    final bool nextEnabled =
        command.payload['enabled'] as bool? ??
        !_state.gameState.autoPlay.enabled;
    final GameState next = _state.gameState.copyWith(
      autoPlay: _state.gameState.autoPlay.copyWith(enabled: nextEnabled),
    );
    return _state.copyWith(gameState: next, clearLastError: true);
  }

  HostedSessionState _handleSetAutoPlayDelayMs(HostedSessionCommand command) {
    if (!_isHost(command.playerId)) {
      return _reject(
        _state,
        _tr(
          _state.gameState.language,
          'Only host can control auto play.',
          'Kun verten kan styre autospill.',
        ),
      );
    }
    final int delayRaw = command.payload['delayMs'] as int? ?? 1500;
    final int delay = delayRaw.clamp(350, 60000);
    final GameState next = _state.gameState.copyWith(
      autoPlay: _state.gameState.autoPlay.copyWith(delayMs: delay),
    );
    return _state.copyWith(gameState: next, clearLastError: true);
  }

  HostedSessionState _queueDrinkDistributions(
    HostedSessionState base,
    List<HostedPendingDrinkDistribution> additions,
  ) {
    if (additions.isEmpty) {
      return base;
    }
    final HostedPendingDrinkDistribution? pending =
        base.pendingDrinkDistribution;
    if (pending == null) {
      if (additions.length == 1) {
        return base.copyWith(
          pendingDrinkDistribution: additions.first,
          clearLastError: true,
        );
      }
      return base.copyWith(
        pendingDrinkDistribution: additions.first,
        queuedDrinkDistributions: <HostedPendingDrinkDistribution>[
          ...base.queuedDrinkDistributions,
          ...additions.sublist(1),
        ],
        clearLastError: true,
      );
    }
    return base.copyWith(
      queuedDrinkDistributions: <HostedPendingDrinkDistribution>[
        ...base.queuedDrinkDistributions,
        ...additions,
      ],
      clearLastError: true,
    );
  }

  List<HostedParticipant> _orderedParticipants() {
    final List<HostedParticipant> byOrder = <HostedParticipant>[];
    for (final int id in _state.playerOrder) {
      final HostedParticipant? participant = _state.participantById(id);
      if (participant != null) {
        byOrder.add(participant);
      }
    }
    final Set<int> included = byOrder
        .map((HostedParticipant participant) => participant.playerId)
        .toSet();
    for (final HostedParticipant participant in _state.participants) {
      if (!included.contains(participant.playerId)) {
        byOrder.add(participant);
      }
    }
    return byOrder;
  }

  _WarmupHostedOutcome _warmupOutcome({
    required GameState previous,
    required GameState next,
    required int actorIndex,
    required WarmupGuess guess,
  }) {
    final List<PlayingCard> nextHand = next.players[actorIndex].hand;
    if (nextHand.isEmpty) {
      return const _WarmupHostedOutcome(
        giveOutDrinks: 0,
        drinkDrinks: 0,
        reason: '',
      );
    }
    final PlayingCard drawn = nextHand.last;
    final List<PlayingCard> previousHand = previous.players[actorIndex].hand;
    final int round = previous.warmupRound;
    if (round == 1) {
      final WarmupGuess actual = drawn.suit.isBlack
          ? WarmupGuess.black
          : WarmupGuess.red;
      final bool correct = guess == actual;
      return _WarmupHostedOutcome(
        giveOutDrinks: correct ? 1 : 0,
        drinkDrinks: correct ? 0 : 1,
        reason: 'Warmup round 1',
      );
    }
    if (round == 2 && previousHand.isNotEmpty) {
      final int reference = previousHand.first.rank;
      final int relation = _compare(drawn.rank, reference);
      if (relation > 0 && guess == WarmupGuess.above) {
        return const _WarmupHostedOutcome(
          giveOutDrinks: 2,
          drinkDrinks: 0,
          reason: 'Warmup round 2',
        );
      }
      if (relation < 0 && guess == WarmupGuess.below) {
        return const _WarmupHostedOutcome(
          giveOutDrinks: 2,
          drinkDrinks: 0,
          reason: 'Warmup round 2',
        );
      }
      if (relation == 0 && guess == WarmupGuess.same) {
        return const _WarmupHostedOutcome(
          giveOutDrinks: 4,
          drinkDrinks: 0,
          reason: 'Warmup round 2',
        );
      }
      return _WarmupHostedOutcome(
        giveOutDrinks: 0,
        drinkDrinks: relation == 0 ? 4 : 2,
        reason: 'Warmup round 2',
      );
    }
    if (round == 3 && previousHand.length >= 2) {
      final int low = previousHand[0].rank < previousHand[1].rank
          ? previousHand[0].rank
          : previousHand[1].rank;
      final int high = previousHand[0].rank > previousHand[1].rank
          ? previousHand[0].rank
          : previousHand[1].rank;
      if (guess == WarmupGuess.same) {
        return _WarmupHostedOutcome(
          giveOutDrinks: (drawn.rank == low || drawn.rank == high) ? 6 : 0,
          drinkDrinks: (drawn.rank == low || drawn.rank == high) ? 0 : 3,
          reason: 'Warmup round 3',
        );
      }
      if (drawn.rank == low || drawn.rank == high) {
        return const _WarmupHostedOutcome(
          giveOutDrinks: 0,
          drinkDrinks: 6,
          reason: 'Warmup round 3',
        );
      }
      if (guess == WarmupGuess.between) {
        final bool correct = drawn.rank > low && drawn.rank < high;
        return _WarmupHostedOutcome(
          giveOutDrinks: correct ? 3 : 0,
          drinkDrinks: correct ? 0 : 3,
          reason: 'Warmup round 3',
        );
      }
      final bool correct = drawn.rank < low || drawn.rank > high;
      return _WarmupHostedOutcome(
        giveOutDrinks: correct ? 3 : 0,
        drinkDrinks: correct ? 0 : 3,
        reason: 'Warmup round 3',
      );
    }
    final bool suitMatch = guess == drawn.suit.warmupGuess;
    return _WarmupHostedOutcome(
      giveOutDrinks: suitMatch ? 4 : 0,
      drinkDrinks: suitMatch ? 0 : 4,
      reason: 'Warmup round 4',
    );
  }

  List<HostedPendingDrinkDistribution> _pyramidDistributions({
    required GameState previous,
    required GameState next,
  }) {
    if (previous.phase != GamePhase.pyramid) {
      return const <HostedPendingDrinkDistribution>[];
    }
    final int targetIndex = _engine.pyramidSlotForStep(
      step: previous.pyramidRevealIndex,
      reversePyramid: previous.reversePyramid,
    );
    final int base = _engine.pyramidDrinksForIndex(
      index: targetIndex,
      reversePyramid: previous.reversePyramid,
    );
    final List<HostedPendingDrinkDistribution> distributions =
        <HostedPendingDrinkDistribution>[];
    for (int index = 0; index < previous.players.length; index += 1) {
      final int before = previous.players[index].hand.length;
      final int after = next.players[index].hand.length;
      if (before <= after) {
        continue;
      }
      final int matched = before - after;
      final int drinks = matched * base;
      final int? playerId = _state.playerIdForIndex(index);
      if (playerId == null) {
        continue;
      }
      distributions.add(
        HostedPendingDrinkDistribution(
          sourcePlayerId: playerId,
          totalDrinks: drinks,
          assignedDrinksByTarget: const <int, int>{},
          reason: 'Pyramid',
        ),
      );
    }
    return distributions;
  }

  GameState _appendDrinkDistributionLog(
    GameState gameState,
    HostedPendingDrinkDistribution distribution,
  ) {
    final List<String> chunks = <String>[];
    distribution.assignedDrinksByTarget.forEach((int playerId, int value) {
      final int? index = _state.playerIndexForId(playerId);
      if (index == null || index >= gameState.players.length) {
        return;
      }
      chunks.add('${gameState.players[index].name} x$value');
    });
    final int? sourceIndex = _state.playerIndexForId(
      distribution.sourcePlayerId,
    );
    final String sourceName = sourceIndex == null
        ? 'Player ${distribution.sourcePlayerId}'
        : gameState.players[sourceIndex].name;
    final String message = _tr(
      gameState.language,
      '$sourceName assigned ${distribution.totalDrinks} drink(s): ${chunks.join(', ')}.',
      '$sourceName fordelte ${distribution.totalDrinks}: ${chunks.join(', ')}.',
    );
    final List<String> log = <String>[message, ...gameState.log];
    if (log.length > GameEngine.maxLogItems) {
      log.removeRange(GameEngine.maxLogItems, log.length);
    }
    return gameState.copyWith(
      bannerTone: BannerTone.info,
      banner: message,
      log: log,
    );
  }

  int? _busRunnerPlayerId(HostedSessionState state) {
    if (state.gameState.busRunnerIndex == null) {
      return null;
    }
    return state.playerIdForIndex(state.gameState.busRunnerIndex!);
  }

  bool _isHost(int playerId) => _state.hostPlayerId == playerId;

  HostedSessionStage _stageFromPhase(GamePhase phase) {
    if (phase == GamePhase.setup) {
      return HostedSessionStage.lobby;
    }
    if (phase == GamePhase.finished) {
      return HostedSessionStage.finished;
    }
    return HostedSessionStage.inGame;
  }

  HostedSessionState _reject(HostedSessionState state, String error) {
    return state.copyWith(lastError: error);
  }

  int _compare(int a, int b) {
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
}

class _WarmupHostedOutcome {
  const _WarmupHostedOutcome({
    required this.giveOutDrinks,
    required this.drinkDrinks,
    required this.reason,
  });

  final int giveOutDrinks;
  final int drinkDrinks;
  final String reason;
}
