import 'dart:async';

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBackToModeChooser,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(tr(language, 'Hosted mode', 'Hostet modus')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: tr(language, 'Your name', 'Ditt navn'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () =>
                  widget.controller.startHosting(hostName: _name.text),
              icon: const Icon(Icons.wifi_tethering),
              label: Text(tr(language, 'Host game', 'Host spill')),
            ),
            const SizedBox(height: 14),
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
            OutlinedButton.icon(
              onPressed: () {
                widget.controller.joinByPin(
                  pin: _pin.text,
                  playerName: _name.text,
                  hostAddress: _host.text.trim().isEmpty
                      ? null
                      : _host.text.trim(),
                );
              },
              icon: const Icon(Icons.login),
              label: Text(tr(language, 'Join by PIN', 'Bli med via PIN')),
            ),
            const SizedBox(height: 14),
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
                tr(language, 'No LAN games found.', 'Ingen LAN-spill funnet.'),
              )
            else
              ...widget.controller.discoveries.map((
                HostedDiscoveryEntry entry,
              ) {
                return Card(
                  child: ListTile(
                    title: Text('${entry.hostName} • PIN ${entry.pin}'),
                    subtitle: Text('${entry.hostAddress}:${entry.hostPort}'),
                    trailing: FilledButton(
                      onPressed: () => widget.controller.joinByDiscovery(
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
    );
  }

  Widget _buildLobby(HostedProjectedView projection) {
    final AppLanguage language = widget.language;
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    Text(tr(language, 'Share PIN', 'Del PIN')),
                    const SizedBox(height: 8),
                    Text(
                      projection.publicView.sessionPin,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...projection.publicView.players.map((HostedPublicPlayer player) {
              return ListTile(
                leading: Icon(
                  player.connected ? Icons.check_circle : Icons.cancel,
                  color: player.connected
                      ? const Color(0xFF18824A)
                      : const Color(0xFFB93838),
                ),
                title: Text(
                  player.isHost
                      ? '${player.name} (${tr(language, 'Host', 'Vert')})'
                      : player.name,
                ),
              );
            }),
            const SizedBox(height: 10),
            if (projection.canUseHostTools)
              FilledButton(
                onPressed: widget.controller.startHostedGame,
                child: Text(
                  tr(language, 'Start hosted game', 'Start hostet spill'),
                ),
              )
            else
              Text(
                tr(
                  language,
                  'Waiting for host to start.',
                  'Venter pa at verten starter.',
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame(HostedProjectedView projection) {
    final AppLanguage language = widget.language;
    final HostedPublicView view = projection.publicView;
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
        title: Text('Hosted • PIN ${view.sessionPin}'),
        actions: <Widget>[
          if (projection.canUseHostTools)
            IconButton(
              onPressed: _showAutoPlaySheet,
              icon: const Icon(Icons.smart_toy),
            ),
          if (projection.canUseHostTools)
            IconButton(
              onPressed: _showLogSheet,
              icon: const Icon(Icons.article),
            ),
          if (projection.canUseHostTools)
            IconButton(
              onPressed: widget.controller.resetHostedGameToLobby,
              icon: const Icon(Icons.restart_alt),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(
                      label: Text(
                        phaseLabel(language, view.phase, view.warmupRound),
                      ),
                    ),
                    Chip(
                      label: Text(
                        tr(
                          language,
                          'You: ${projection.viewerName}',
                          'Du: ${projection.viewerName}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _bigOwnHand(projection.ownHand),
            if (projection.giveOutPromptDrinks > 0)
              _promptCard(
                tr(language, 'Give out', 'Del ut'),
                projection.giveOutPromptDrinks,
                const Color(0xFF1A8B47),
                null,
              ),
            if (projection.drinkPromptDrinks > 0)
              _promptCard(
                tr(language, 'Drink', 'Drikk'),
                projection.drinkPromptDrinks,
                const Color(0xFFB93838),
                widget.controller.acknowledgeDrinks,
              ),
            if (isPendingSource) _distributionCard(pending, view.players),
            if (blocked && !isPendingSource)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    tr(
                      language,
                      'Waiting for drink distribution.',
                      'Venter pa drikkefordeling.',
                    ),
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: view.players
                          .map(
                            (HostedPublicPlayer p) =>
                                Chip(label: Text('${p.name}: ${p.handCount}')),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    if (view.phase == GamePhase.warmup)
                      _warmupButtons(myTurn && !blocked, view.warmupRound),
                    if (view.phase == GamePhase.pyramid) ...<Widget>[
                      _pyramidGrid(view.pyramidCards),
                      if (projection.canUseHostTools && !blocked)
                        FilledButton(
                          onPressed: widget.controller.revealPyramidNext,
                          child: Text(tr(language, 'Reveal next', 'Vis neste')),
                        ),
                    ],
                    if (view.phase == GamePhase.tiebreak &&
                        projection.canUseHostTools)
                      FilledButton(
                        onPressed: blocked
                            ? null
                            : widget.controller.runTieBreakRound,
                        child: Text(
                          tr(language, 'Run tie-break', 'Kjor tie-break'),
                        ),
                      ),
                    if (view.busRoute != null)
                      _busRouteView(
                        view.busRoute!,
                        projection.canControlBusRoute && !blocked,
                        view.phase,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigOwnHand(List<PlayingCard> hand) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 138,
          child: hand.isEmpty
              ? Center(
                  child: Text(tr(widget.language, 'No cards', 'Ingen kort')),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: hand.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, int index) =>
                      _card(hand[index], large: true),
                ),
        ),
      ),
    );
  }

  Widget _promptCard(
    String label,
    int amount,
    Color color,
    VoidCallback? action,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _flash, curve: Curves.easeInOut),
      child: Card(
        color: color.withValues(alpha: 0.14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$label: $amount',
                  style: TextStyle(
                    color: color,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
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
  ) {
    final List<HostedPublicPlayer> targets = players
        .where((HostedPublicPlayer p) => p.playerId != pending.sourcePlayerId)
        .toList();
    int draftTotal = 0;
    for (final int value in _draftTargets.values) {
      draftTotal += value;
    }
    final int remain = pending.remainingDrinks - draftTotal;

    return Card(
      color: const Color(0xFFEAF7EE),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tr(
                widget.language,
                'Assign drinks (${pending.remainingDrinks} left)',
                'Fordel drikker (${pending.remainingDrinks} igjen)',
              ),
            ),
            const SizedBox(height: 8),
            for (final HostedPublicPlayer player in targets)
              Row(
                children: <Widget>[
                  Expanded(child: Text(player.name)),
                  IconButton(
                    onPressed: () {
                      final int current = _draftTargets[player.playerId] ?? 0;
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
                    onPressed: remain <= 0
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
            FilledButton.icon(
              onPressed: draftTotal <= 0
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
      ),
    );
  }

  Widget _warmupButtons(bool enabled, int round) {
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
      children: options
          .map(
            (WarmupGuess option) => FilledButton.tonal(
              onPressed: enabled
                  ? () => widget.controller.submitWarmupGuess(option)
                  : null,
              child: Text(warmupGuessLabel(widget.language, option)),
            ),
          )
          .toList(),
    );
  }

  Widget _pyramidGrid(List<PlayingCard?> cards) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: cards.map((PlayingCard? card) => _card(card)).toList(),
    );
  }

  Widget _busRouteView(BusRouteState route, bool canControl, GamePhase phase) {
    final int active = route.progress < route.order.length
        ? route.order[route.progress]
        : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(route.routeCards.length, (int index) {
            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: active == index
                      ? const Color(0xFF18824A)
                      : const Color(0xFFCCCCCC),
                  width: active == index ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _card(route.routeCards[index]),
              ),
            );
          }),
        ),
        if (phase == GamePhase.bussetup && canControl) ...<Widget>[
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
      ],
    );
  }

  Widget _card(PlayingCard? card, {bool large = false}) {
    final bool red = card?.suit == Suit.hearts || card?.suit == Suit.diamonds;
    return Container(
      width: large ? 90 : 48,
      height: large ? 128 : 68,
      decoration: BoxDecoration(
        color: card == null ? const Color(0xFFE2E2E2) : Colors.white,
        border: Border.all(color: const Color(0xFFCDB79F)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          card?.shortLabel() ?? '??',
          style: TextStyle(
            fontSize: large ? 24 : 14,
            fontWeight: FontWeight.w800,
            color: red ? const Color(0xFFB93838) : const Color(0xFF202020),
          ),
        ),
      ),
    );
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
              Text(tr(widget.language, 'Auto play', 'Autospill')),
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
              Text(tr(widget.language, 'Game log', 'Spilllogg')),
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
