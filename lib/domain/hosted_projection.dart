import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';

HostedProjectedView projectHostedView({
  required HostedSessionState session,
  required int viewerPlayerId,
}) {
  final HostedParticipant? viewer = session.participantById(viewerPlayerId);
  final int? viewerIndex = session.playerIndexForId(viewerPlayerId);
  final List<PlayingCard> ownHand = viewerIndex == null
      ? const <PlayingCard>[]
      : session.gameState.players[viewerIndex].hand;

  final int? currentTurnPlayerId = _currentTurnPlayerId(session);
  final int? busRunnerPlayerId = session.gameState.busRunnerIndex == null
      ? null
      : session.playerIdForIndex(session.gameState.busRunnerIndex!);
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
      busRunnerPlayerId == viewerPlayerId &&
      session.pendingDrinkDistribution == null;

  return HostedProjectedView(
    viewerPlayerId: viewerPlayerId,
    viewerName: viewer?.name ?? 'Player $viewerPlayerId',
    isHost: session.hostPlayerId == viewerPlayerId,
    publicView: HostedPublicView(
      sessionPin: session.sessionPin,
      stage: session.stage,
      phase: session.gameState.phase,
      language: session.gameState.language,
      players: _buildPublicPlayers(session),
      currentTurnPlayerId: currentTurnPlayerId,
      warmupRound: session.gameState.warmupRound,
      pyramidCards: session.gameState.pyramidCards,
      pyramidRevealIndex: session.gameState.pyramidRevealIndex,
      busRunnerPlayerId: busRunnerPlayerId,
      busRoute: session.gameState.busRoute,
      banner: session.gameState.banner,
      bannerTone: session.gameState.bannerTone,
      pendingDrinkDistribution: session.pendingDrinkDistribution,
    ),
    ownHand: ownHand,
    giveOutPromptDrinks: giveOutPromptDrinks,
    drinkPromptDrinks: drinkPromptDrinks,
    canControlBusRoute: canControlBusRoute,
    canUseHostTools: session.hostPlayerId == viewerPlayerId,
  );
}

List<HostedPublicPlayer> _buildPublicPlayers(HostedSessionState session) {
  final List<HostedPublicPlayer> players = <HostedPublicPlayer>[];
  for (int i = 0; i < session.participants.length; i += 1) {
    final HostedParticipant participant = session.participants[i];
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
