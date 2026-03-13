import 'dart:async';
import 'dart:math' as math;

import 'package:bussruta_app/application/hosted_lan_transport.dart';
import 'package:bussruta_app/application/hosted_session_controller.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:bussruta_app/presentation/strings.dart';
import 'package:flutter/material.dart';

class HostedSessionView extends StatefulWidget {
  const HostedSessionView({
    super.key,
    required this.controller,
    required this.language,
    required this.onBackToModeChooser,
  });

  final HostedSessionController controller;
  final AppLanguage language;
  final VoidCallback onBackToModeChooser;

  @override
  State<HostedSessionView> createState() => _HostedSessionViewState();
}

class _HostedSessionViewState extends State<HostedSessionView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _host = TextEditingController();
  Map<int, int> _draftTargets = <int, int>{};
  int? _draftSource;
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _name.text = widget.language == AppLanguage.no ? 'Spiller' : 'Player';
    unawaited(widget.controller.initialize(language: widget.language));
  }

  @override
  void didUpdateWidget(covariant HostedSessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.language != oldWidget.language) {
      widget.controller.setLanguage(widget.language);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _host.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        _showMessages();
        final HostedProjectedView? projection = widget.controller.projection;
        if (!widget.controller.hasActiveSession || projection == null) {
          return _buildEntry();
        }
        _syncDraft(projection);
        if (projection.publicView.phase == GamePhase.setup) {
          return _buildLobby(projection);
        }
        return _buildGame(projection);
      },
    );
  }

  Widget _buildEntry() {
    final AppLanguage language = widget.language;
    final HostedConnectionStatus status = widget.controller.connectionStatus;
    final _ConnectionVisual statusVisual = _connectionVisual(status);
    final bool busy =
        status == HostedConnectionStatus.joining ||
        status == HostedConnectionStatus.reconnecting;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBackToModeChooser,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(tr(language, 'Hosted mode', 'Hostet modus')),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF3ECDD), Color(0xFFE7D5C1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (status != HostedConnectionStatus.idle)
                _surfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(statusVisual.icon, color: statusVisual.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusVisual.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusVisual.subtitle,
                        style: TextStyle(color: statusVisual.color),
                      ),
                      if (busy) ...<Widget>[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              _surfaceCard(
                child: TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: tr(language, 'Your name', 'Ditt navn'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _surfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr(language, 'Host a LAN game', 'Host et LAN-spill'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => widget.controller.startHosting(
                                hostName: _name.text,
                              ),
                        icon: const Icon(Icons.wifi_tethering),
                        label: Text(tr(language, 'Host game', 'Host spill')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _surfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr(
                        language,
                        'Join a hosted game',
                        'Bli med i hostet spill',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pin,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr(language, 'PIN code', 'PIN-kode'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _host,
                      decoration: InputDecoration(
                        labelText: tr(
                          language,
                          'Host address (optional)',
                          'Vertsadresse (valgfri)',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () {
                                widget.controller.joinByPin(
                                  pin: _pin.text,
                                  playerName: _name.text,
                                  hostAddress: _host.text.trim().isEmpty
                                      ? null
                                      : _host.text.trim(),
                                );
                              },
                        icon: const Icon(Icons.login),
                        label: Text(
                          tr(language, 'Join by PIN', 'Bli med via PIN'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _surfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr(
                        language,
                        'Available local games',
                        'Tilgjengelige lokale spill',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (widget.controller.discoveries.isEmpty)
                      Text(
                        tr(
                          language,
                          'No LAN games found.',
                          'Ingen LAN-spill funnet.',
                        ),
                      )
                    else
                      ...widget.controller.discoveries.map((
                        HostedDiscoveryEntry entry,
                      ) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.hub),
                            title: Text('${entry.hostName} - PIN ${entry.pin}'),
                            subtitle: Text(
                              '${entry.hostAddress}:${entry.hostPort}',
                            ),
                            trailing: FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => widget.controller.joinByDiscovery(
                                      entry: entry,
                                      playerName: _name.text,
                                    ),
                              child: Text(tr(language, 'Join', 'Bli med')),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLobby(HostedProjectedView projection) {
    final AppLanguage language = widget.language;
    final HostedPublicView view = projection.publicView;
    final HostedConnectionStatus status = widget.controller.connectionStatus;
    final _ConnectionVisual visual = _connectionVisual(status);
    final int connectedCount = view.players
        .where((HostedPublicPlayer player) => player.connected)
        .length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            widget.controller.leaveSession();
            widget.onBackToModeChooser();
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(tr(language, 'Hosted lobby', 'Hostet lobby')),
        actions: <Widget>[
          TextButton(
            onPressed: widget.controller.leaveSession,
            child: Text(tr(language, 'Leave', 'Forlat')),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF3ECDD), Color(0xFFE7D5C1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _surfaceCard(
                child: Row(
                  children: <Widget>[
                    Icon(visual.icon, color: visual.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        visual.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _surfaceCard(
                color: const Color(0xFFF8E8D3),
                child: Column(
                  children: <Widget>[
                    Text(
                      tr(language, 'Session PIN', 'Sesjon PIN'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      view.sessionPin,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        language,
                        '$connectedCount / ${view.players.length} connected',
                        '$connectedCount / ${view.players.length} tilkoblet',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _surfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr(language, 'Players', 'Spillere'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...view.players.asMap().entries.map((
                      MapEntry<int, HostedPublicPlayer> entry,
                    ) {
                      final HostedPublicPlayer player = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F3EA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: player.connected
                                  ? const Color(0xFFB9D5C1)
                                  : const Color(0xFFE1C5C5),
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE5D4BE),
                              child: Text('${entry.key + 1}'),
                            ),
                            title: Row(
                              children: <Widget>[
                                Expanded(child: Text(player.name)),
                                if (player.isHost)
                                  _tag(
                                    tr(language, 'Host', 'Vert'),
                                    const Color(0xFF1C6A43),
                                  ),
                              ],
                            ),
                            trailing: _tag(
                              player.connected
                                  ? tr(language, 'Connected', 'Tilkoblet')
                                  : tr(language, 'Disconnected', 'Frakoblet'),
                              player.connected
                                  ? const Color(0xFF1B8A49)
                                  : const Color(0xFFB93838),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (projection.canUseHostTools)
                FilledButton.icon(
                  onPressed: widget.controller.startHostedGame,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    tr(language, 'Start hosted game', 'Start hostet spill'),
                  ),
                )
              else
                _surfaceCard(
                  child: Text(
                    tr(
                      language,
                      'Waiting for host to start the game.',
                      'Venter pa at verten starter spillet.',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame(HostedProjectedView projection) {
    final AppLanguage language = widget.language;
    final HostedPublicView view = projection.publicView;
    final HostedConnectionStatus status = widget.controller.connectionStatus;
    final bool connected = status == HostedConnectionStatus.connected;
    final bool myTurn = view.currentTurnPlayerId == projection.viewerPlayerId;
    final HostedPendingDrinkDistribution? pending =
        view.pendingDrinkDistribution;
    final bool isPendingSource =
        pending != null && pending.sourcePlayerId == projection.viewerPlayerId;
    final bool blocked = pending != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            widget.controller.leaveSession();
            widget.onBackToModeChooser();
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Hosted - PIN ${view.sessionPin}'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: _connectionChip(_connectionVisual(status))),
          ),
          if (projection.canUseHostTools)
            IconButton(
              onPressed: connected ? _showAutoPlaySheet : null,
              icon: const Icon(Icons.smart_toy),
            ),
          if (projection.canUseHostTools)
            IconButton(
              onPressed: _showLogSheet,
              icon: const Icon(Icons.article),
            ),
          if (projection.canUseHostTools)
            IconButton(
              onPressed: connected
                  ? widget.controller.resetHostedGameToLobby
                  : null,
              icon: const Icon(Icons.restart_alt),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFEFE2D2), Color(0xFFE4CFB8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              _surfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      phaseLabel(language, view.phase, view.warmupRound),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        language,
                        'You are ${projection.viewerName}.',
                        'Du er ${projection.viewerName}.',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _turnText(
                        language: language,
                        view: view,
                        myTurn: myTurn,
                        viewerName: projection.viewerName,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (status != HostedConnectionStatus.connected) ...<Widget>[
                const SizedBox(height: 8),
                _surfaceCard(
                  color: const Color(0xFFFFF4E5),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _connectionVisual(status).icon,
                        color: _connectionVisual(status).color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_connectionVisual(status).subtitle)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _ownHandPanel(projection.ownHand),
              if (projection.giveOutPromptDrinks > 0) ...<Widget>[
                const SizedBox(height: 8),
                _promptCard(
                  label: tr(language, 'Give out drinks', 'Del ut drikker'),
                  amount: projection.giveOutPromptDrinks,
                  color: const Color(0xFF1A8B47),
                  action: null,
                ),
              ],
              if (projection.drinkPromptDrinks > 0) ...<Widget>[
                const SizedBox(height: 8),
                _promptCard(
                  label: tr(language, 'You drink', 'Du drikker'),
                  amount: projection.drinkPromptDrinks,
                  color: const Color(0xFFB93838),
                  action: connected
                      ? widget.controller.acknowledgeDrinks
                      : null,
                ),
              ],
              if (isPendingSource) ...<Widget>[
                const SizedBox(height: 8),
                _distributionCard(pending, view.players, connected),
              ],
              if (blocked && !isPendingSource) ...<Widget>[
                const SizedBox(height: 8),
                _surfaceCard(
                  color: const Color(0xFFF8F2E8),
                  child: Text(
                    tr(
                      language,
                      'Waiting for another player to distribute drinks.',
                      'Venter pa at en annen spiller fordeler drikker.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _surfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: view.players.map((HostedPublicPlayer player) {
                        final bool isTurnPlayer =
                            view.currentTurnPlayerId == player.playerId;
                        final String text = isTurnPlayer
                            ? '${player.name} (${tr(language, 'turn', 'tur')})'
                            : player.name;
                        return _tag(
                          '$text: ${player.handCount}',
                          player.connected
                              ? const Color(0xFF325A86)
                              : const Color(0xFF826767),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    if (view.phase == GamePhase.warmup)
                      _warmupButtons(
                        enabled: myTurn && !blocked && connected,
                        round: view.warmupRound,
                      ),
                    if (view.phase == GamePhase.pyramid)
                      _pyramidPublicPanel(
                        cards: view.pyramidCards,
                        revealIndex: view.pyramidRevealIndex,
                        onReveal:
                            projection.canUseHostTools && !blocked && connected
                            ? widget.controller.revealPyramidNext
                            : null,
                      ),
                    if (view.phase == GamePhase.tiebreak)
                      FilledButton.tonalIcon(
                        onPressed:
                            projection.canUseHostTools && !blocked && connected
                            ? widget.controller.runTieBreakRound
                            : null,
                        icon: const Icon(Icons.filter_9_plus),
                        label: Text(
                          tr(
                            language,
                            'Run tie-break round',
                            'Kjor tie-break-runde',
                          ),
                        ),
                      ),
                    if (view.busRoute != null) ...<Widget>[
                      const SizedBox(height: 8),
                      _busRouteView(
                        route: view.busRoute!,
                        canControl:
                            projection.canControlBusRoute &&
                            !blocked &&
                            connected,
                        phase: view.phase,
                        players: view.players,
                        busRunnerPlayerId: view.busRunnerPlayerId,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownHandPanel(List<PlayingCard> hand) {
    return _surfaceCard(
      color: const Color(0xFF1F4A38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            tr(widget.language, 'Your hand', 'Din hand'),
            style: const TextStyle(
              color: Color(0xFFF6EFE3),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 190,
            child: hand.isEmpty
                ? Center(
                    child: Text(
                      tr(widget.language, 'No cards yet', 'Ingen kort ennå'),
                      style: const TextStyle(color: Color(0xFFE9DDCA)),
                    ),
                  )
                : LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          const double cardWidth = 98;
                          const double cardHeight = 138;
                          final int count = hand.length;
                          final double maxSpan = math.max(
                            0,
                            constraints.maxWidth - cardWidth,
                          );
                          final double step = count <= 1
                              ? 0
                              : (maxSpan / (count - 1))
                                    .clamp(22, 54)
                                    .toDouble();
                          final double usedWidth =
                              cardWidth + (count - 1) * step;
                          final double leftStart = math.max(
                            0,
                            (constraints.maxWidth - usedWidth) / 2,
                          );
                          return Stack(
                            clipBehavior: Clip.none,
                            children: List<Widget>.generate(count, (int index) {
                              final double angle =
                                  (index - (count - 1) / 2) * 0.075;
                              return Positioned(
                                left: leftStart + index * step,
                                top: 18 + angle.abs() * 20,
                                child: Transform.rotate(
                                  angle: angle,
                                  child: _playingCard(
                                    hand[index],
                                    width: cardWidth,
                                    height: cardHeight,
                                    emphasized: true,
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _promptCard({
    required String label,
    required int amount,
    required Color color,
    required VoidCallback? action,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _flash, curve: Curves.easeInOut),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$amount',
                      style: TextStyle(
                        color: color,
                        fontSize: 42,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null)
                FilledButton(
                  onPressed: action,
                  child: Text(tr(widget.language, 'Done', 'Ferdig')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _distributionCard(
    HostedPendingDrinkDistribution pending,
    List<HostedPublicPlayer> players,
    bool enabled,
  ) {
    final List<HostedPublicPlayer> targets = players
        .where(
          (HostedPublicPlayer player) =>
              player.playerId != pending.sourcePlayerId,
        )
        .toList();
    int draftTotal = 0;
    for (final int value in _draftTargets.values) {
      draftTotal += value;
    }
    final int remain = pending.remainingDrinks - draftTotal;

    return _surfaceCard(
      color: const Color(0xFFEAF7EE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            tr(
              widget.language,
              'Assign drinks (${pending.remainingDrinks} left)',
              'Fordel drikker (${pending.remainingDrinks} igjen)',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final HostedPublicPlayer player in targets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(player.name)),
                  IconButton(
                    onPressed: !enabled
                        ? null
                        : () {
                            final int current =
                                _draftTargets[player.playerId] ?? 0;
                            if (current <= 0) {
                              return;
                            }
                            final Map<int, int> next = Map<int, int>.from(
                              _draftTargets,
                            );
                            if (current == 1) {
                              next.remove(player.playerId);
                            } else {
                              next[player.playerId] = current - 1;
                            }
                            setState(() {
                              _draftTargets = next;
                            });
                          },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${_draftTargets[player.playerId] ?? 0}'),
                  IconButton(
                    onPressed: !enabled || remain <= 0
                        ? null
                        : () {
                            final Map<int, int> next = Map<int, int>.from(
                              _draftTargets,
                            );
                            next[player.playerId] =
                                (next[player.playerId] ?? 0) + 1;
                            setState(() {
                              _draftTargets = next;
                            });
                          },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: !enabled || draftTotal <= 0
                ? null
                : () {
                    widget.controller.assignDrinks(_draftTargets);
                    setState(() {
                      _draftTargets = <int, int>{};
                    });
                  },
            icon: const Icon(Icons.send),
            label: Text(
              tr(widget.language, 'Send assignment', 'Send fordeling'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warmupButtons({required bool enabled, required int round}) {
    final List<WarmupGuess> options = switch (round) {
      1 => const <WarmupGuess>[WarmupGuess.black, WarmupGuess.red],
      2 => const <WarmupGuess>[
        WarmupGuess.above,
        WarmupGuess.below,
        WarmupGuess.same,
      ],
      3 => const <WarmupGuess>[
        WarmupGuess.between,
        WarmupGuess.outside,
        WarmupGuess.same,
      ],
      _ => const <WarmupGuess>[
        WarmupGuess.clubs,
        WarmupGuess.diamonds,
        WarmupGuess.hearts,
        WarmupGuess.spades,
      ],
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((WarmupGuess guess) {
        return SizedBox(
          width: 140,
          child: FilledButton.tonal(
            onPressed: enabled
                ? () => widget.controller.submitWarmupGuess(guess)
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              warmupGuessLabel(widget.language, guess),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _pyramidPublicPanel({
    required List<PlayingCard?> cards,
    required int revealIndex,
    required VoidCallback? onReveal,
  }) {
    final List<PlayingCard> revealed = cards.whereType<PlayingCard>().toList(
      growable: false,
    );
    final bool hasMore = revealIndex < cards.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          tr(
            widget.language,
            'Revealed pyramid cards',
            'Avdekkede pyramidekort',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (revealed.isEmpty)
          Text(
            tr(
              widget.language,
              'No cards revealed yet.',
              'Ingen kort er avdekket ennå.',
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: revealed
                .map(
                  (PlayingCard card) =>
                      _playingCard(card, width: 58, height: 82),
                )
                .toList(),
          ),
        if (hasMore) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _playingCard(null, showBack: true, width: 58, height: 82),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(
                    widget.language,
                    'Next reveal comes from the deck.',
                    'Neste avdekking kommer fra bunken.',
                  ),
                ),
              ),
            ],
          ),
        ],
        if (onReveal != null) ...<Widget>[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onReveal,
            icon: const Icon(Icons.visibility),
            label: Text(tr(widget.language, 'Reveal next', 'Vis neste')),
          ),
        ],
      ],
    );
  }

  Widget _busRouteView({
    required BusRouteState route,
    required bool canControl,
    required GamePhase phase,
    required List<HostedPublicPlayer> players,
    required int? busRunnerPlayerId,
  }) {
    final int active = route.progress < route.order.length
        ? route.order[route.progress]
        : -1;
    final String runnerName = _nameForPlayer(players, busRunnerPlayerId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          tr(widget.language, 'Bus route (public)', 'Bussrute (offentlig)'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(route.routeCards.length, (int index) {
            final bool isActive = active == index && phase == GamePhase.bus;
            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF18824A)
                      : const Color(0xFFCFBA9D),
                  width: isActive ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _playingCard(
                  route.routeCards[index],
                  width: 52,
                  height: 74,
                ),
              ),
            );
          }),
        ),
        if (phase == GamePhase.bussetup && canControl) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      widget.controller.beginBusRoute(BusStartSide.left),
                  child: Text(
                    tr(widget.language, 'Start left', 'Start venstre'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      widget.controller.beginBusRoute(BusStartSide.right),
                  child: Text(
                    tr(widget.language, 'Start right', 'Start hoyre'),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (phase == GamePhase.bus && canControl) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BusGuess.values
                .map(
                  (BusGuess guess) => FilledButton.tonal(
                    onPressed: () => widget.controller.playBusGuess(guess),
                    child: Text(busGuessLabel(widget.language, guess)),
                  ),
                )
                .toList(),
          ),
        ],
        if ((phase == GamePhase.bussetup || phase == GamePhase.bus) &&
            !canControl) ...<Widget>[
          const SizedBox(height: 10),
          _surfaceCard(
            color: const Color(0xFFF8F2E8),
            child: Text(
              tr(
                widget.language,
                'Public view only. $runnerName is actively playing the bus route.',
                'Offentlig visning. $runnerName spiller bussruta aktivt.',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _playingCard(
    PlayingCard? card, {
    required double width,
    required double height,
    bool showBack = false,
    bool emphasized = false,
  }) {
    final bool red = card?.suit == Suit.hearts || card?.suit == Suit.diamonds;
    final bool back = showBack || card == null;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.16),
        border: Border.all(
          color: back ? const Color(0xFFB9CDE1) : const Color(0xFFCDB79F),
          width: emphasized ? 1.5 : 1.0,
        ),
        gradient: back
            ? const LinearGradient(
                colors: <Color>[Color(0xFF244D70), Color(0xFF102C40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: <Color>[Color(0xFFFFFEFB), Color(0xFFF5EFE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: emphasized ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          back ? 'B' : card.shortLabel(),
          style: TextStyle(
            fontSize: emphasized ? 29 : 19,
            fontWeight: FontWeight.w900,
            color: back
                ? const Color(0xFFEFF5FF)
                : (red ? const Color(0xFFB93838) : const Color(0xFF202020)),
          ),
        ),
      ),
    );
  }

  Widget _surfaceCard({required Widget child, Color? color}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x13000000),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }

  Widget _connectionChip(_ConnectionVisual visual) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: visual.color.withValues(alpha: 0.12),
        border: Border.all(color: visual.color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          visual.title,
          style: TextStyle(
            color: visual.color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _turnText({
    required AppLanguage language,
    required HostedPublicView view,
    required bool myTurn,
    required String viewerName,
  }) {
    if (myTurn) {
      return tr(language, 'Your turn', 'Din tur');
    }
    final String actor = _nameForPlayer(view.players, view.currentTurnPlayerId);
    if (actor.isEmpty) {
      return tr(
        language,
        'Waiting for next action',
        'Venter pa neste handling',
      );
    }
    return tr(language, 'Waiting for $actor', 'Venter pa $actor');
  }

  String _nameForPlayer(List<HostedPublicPlayer> players, int? playerId) {
    if (playerId == null) {
      return '';
    }
    for (final HostedPublicPlayer player in players) {
      if (player.playerId == playerId) {
        return player.name;
      }
    }
    return 'Player $playerId';
  }

  _ConnectionVisual _connectionVisual(HostedConnectionStatus status) {
    final AppLanguage language = widget.language;
    return switch (status) {
      HostedConnectionStatus.idle => _ConnectionVisual(
        icon: Icons.pause_circle_outline,
        color: const Color(0xFF6F6F6F),
        title: tr(language, 'Idle', 'Inaktiv'),
        subtitle: tr(
          language,
          'Not connected to a hosted session.',
          'Ikke koblet til en hostet sesjon.',
        ),
      ),
      HostedConnectionStatus.joining => _ConnectionVisual(
        icon: Icons.sync,
        color: const Color(0xFF335E98),
        title: tr(language, 'Joining', 'Kobler til'),
        subtitle: tr(
          language,
          'Joining host session.',
          'Kobler til host-sesjon.',
        ),
      ),
      HostedConnectionStatus.connected => _ConnectionVisual(
        icon: Icons.wifi,
        color: const Color(0xFF1B8A49),
        title: tr(language, 'Connected', 'Tilkoblet'),
        subtitle: tr(
          language,
          'Live session is active.',
          'Live sesjon er aktiv.',
        ),
      ),
      HostedConnectionStatus.reconnecting => _ConnectionVisual(
        icon: Icons.wifi_find,
        color: const Color(0xFF9E6A13),
        title: tr(language, 'Reconnecting', 'Kobler til igjen'),
        subtitle: tr(
          language,
          'Trying to reclaim your seat.',
          'Prover a hente tilbake plassen din.',
        ),
      ),
      HostedConnectionStatus.disconnected => _ConnectionVisual(
        icon: Icons.wifi_off,
        color: const Color(0xFFB36319),
        title: tr(language, 'Disconnected', 'Frakoblet'),
        subtitle: tr(language, 'Connection dropped.', 'Tilkoblingen falt ut.'),
      ),
      HostedConnectionStatus.hostUnavailable => _ConnectionVisual(
        icon: Icons.portable_wifi_off,
        color: const Color(0xFFB93838),
        title: tr(language, 'Host unavailable', 'Vert utilgjengelig'),
        subtitle: tr(
          language,
          'Host cannot be reached.',
          'Finner ikke verten.',
        ),
      ),
      HostedConnectionStatus.sessionClosed => _ConnectionVisual(
        icon: Icons.event_busy,
        color: const Color(0xFF7A4D9B),
        title: tr(language, 'Session closed', 'Sesjon avsluttet'),
        subtitle: tr(
          language,
          'Host ended the session.',
          'Verten avsluttet sesjonen.',
        ),
      ),
    };
  }

  void _syncDraft(HostedProjectedView projection) {
    final HostedPendingDrinkDistribution? pending =
        projection.publicView.pendingDrinkDistribution;
    if (pending == null ||
        pending.sourcePlayerId != projection.viewerPlayerId) {
      _draftTargets = <int, int>{};
      _draftSource = null;
      return;
    }
    if (_draftSource != pending.sourcePlayerId) {
      _draftTargets = <int, int>{};
      _draftSource = pending.sourcePlayerId;
    }
  }

  void _showMessages() {
    final String? error = widget.controller.consumeErrorMessage();
    if (error != null && error.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      });
    }
    final String? info = widget.controller.consumeInfoMessage();
    if (info != null && info.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(info)));
        }
      });
    }
  }

  Future<void> _showAutoPlaySheet() {
    final HostedProjectedView? projection = widget.controller.projection;
    if (projection == null) {
      return Future<void>.value();
    }
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        final HostedPublicView view = projection.publicView;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tr(widget.language, 'Auto play', 'Autospill'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile(
                value: view.autoPlayEnabled,
                onChanged: (bool value) =>
                    widget.controller.toggleAutoPlay(value),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tr(widget.language, 'Enable auto play', 'Aktiver autospill'),
                ),
              ),
              Slider(
                min: 350,
                max: 60000,
                divisions: 40,
                value: view.autoPlayDelayMs.toDouble(),
                onChanged: (double value) =>
                    widget.controller.setAutoPlayDelayMs(value.round()),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLogSheet() {
    final List<String> log = widget.controller.hostGameLog;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tr(widget.language, 'Game log', 'Spilllogg'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: log.isEmpty
                    ? Center(
                        child: Text(
                          tr(
                            widget.language,
                            'No events yet.',
                            'Ingen hendelser ennå.',
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: log.length,
                        itemBuilder: (BuildContext context, int index) =>
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(log[index]),
                            ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionVisual {
  const _ConnectionVisual({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}
