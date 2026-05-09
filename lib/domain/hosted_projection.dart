import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';

HostedProjectedView projectHostedView({
  required HostedSessionState session,
  required int viewerPlayerId,
  HostedPublicView? publicView,
}) {
  final HostedParticipant? viewer = session.participantById(viewerPlayerId);
  final int? viewerIndex = session.playerIndexForId(viewerPlayerId);
  final List<PlayingCard> ownHand = viewerIndex == null
      ? const <PlayingCard>[]
      : session.gameState.players[viewerIndex].hand;

  final HostedPublicView resolvedPublicView =
      publicView ?? projectHostedPublicView(session: session);
  final int giveOutPromptDrinks =
      (session.pendingDrinkDistribution != null &&
          session.pendingDrinkDistribution!.sourcePlayerId == viewerPlayerId)
      ? session.pendingDrinkDistribution!.remainingDrinks
      : 0;
  final int drinkPromptDrinks =
      session.pendingDrinkPenaltyByPlayer[viewerPlayerId] ?? 0;
  final bool inBus =
      session.gameState.phase == GamePhase.bussetup ||
      session.gameState.phase == GamePhase.bus ||
      session.gameState.phase == GamePhase.finished;
  final bool canControlBusRoute =
      inBus &&
      resolvedPublicView.busRunnerPlayerId == viewerPlayerId &&
      session.pendingDrinkDistribution == null;

  return HostedProjectedView(
    viewerPlayerId: viewerPlayerId,
    viewerName: viewer?.name ?? 'Player $viewerPlayerId',
    isHost: session.hostPlayerId == viewerPlayerId,
    publicView: resolvedPublicView,
    ownHand: ownHand,
    giveOutPromptDrinks: giveOutPromptDrinks,
    drinkPromptDrinks: drinkPromptDrinks,
    canControlBusRoute: canControlBusRoute,
    canUseHostTools: session.hostPlayerId == viewerPlayerId,
  );
}

HostedPublicView projectHostedPublicView({
  required HostedSessionState session,
}) {
  final int? busRunnerPlayerId = session.gameState.busRunnerIndex == null
      ? null
      : session.playerIdForIndex(session.gameState.busRunnerIndex!);

  return HostedPublicView(
    sessionPin: session.sessionPin,
    stage: session.stage,
    phase: session.gameState.phase,
    language: session.gameState.language,
    players: _buildPublicPlayers(session),
    currentTurnPlayerId: _currentTurnPlayerId(session),
    warmupRound: session.gameState.warmupRound,
    pyramidCards: session.gameState.pyramidCards,
    pyramidRevealIndex: session.gameState.pyramidRevealIndex,
    tieBreak: session.gameState.tieBreak == null
        ? null
        : HostedPublicTieBreakState.fromTieBreak(session.gameState.tieBreak!),
    busRunnerPlayerId: busRunnerPlayerId,
    busRoute: session.gameState.busRoute == null
        ? null
        : HostedPublicBusRouteState.fromBusRoute(session.gameState.busRoute!),
    banner: session.gameState.banner,
    bannerTone: session.gameState.bannerTone,
    pendingDrinkDistribution: session.pendingDrinkDistribution,
    autoPlayEnabled: session.gameState.autoPlay.enabled,
    autoPlayDelayMs: session.gameState.autoPlay.delayMs,
  );
}

List<HostedPublicPlayer> _buildPublicPlayers(HostedSessionState session) {
  final List<HostedPublicPlayer> players = <HostedPublicPlayer>[];
  final Set<int> seen = <int>{};
  for (final int playerId in session.playerOrder) {
    final HostedParticipant? participant = session.participantById(playerId);
    if (participant == null) {
      continue;
    }
    seen.add(playerId);
    final int? playerIndex = session.playerIndexForId(participant.playerId);
    final int handCount = playerIndex == null
        ? 0
        : session.gameState.players[playerIndex].hand.length;
    players.add(
      HostedPublicPlayer(
        playerId: participant.playerId,
        name: participant.name,
        isHost: participant.isHost,
        connected: participant.connected,
        handCount: handCount,
      ),
    );
  }
  for (final HostedParticipant participant in session.participants) {
    if (seen.contains(participant.playerId)) {
      continue;
    }
    final int? playerIndex = session.playerIndexForId(participant.playerId);
    final int handCount = playerIndex == null
        ? 0
        : session.gameState.players[playerIndex].hand.length;
    players.add(
      HostedPublicPlayer(
        playerId: participant.playerId,
        name: participant.name,
        isHost: participant.isHost,
        connected: participant.connected,
        handCount: handCount,
      ),
    );
  }
  return players;
}

int? _currentTurnPlayerId(HostedSessionState session) {
  if (session.gameState.phase != GamePhase.warmup) {
    return null;
  }
  return session.playerIdForIndex(session.gameState.currentPlayerIndex);
}
