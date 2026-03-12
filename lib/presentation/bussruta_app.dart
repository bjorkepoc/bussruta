import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/presentation/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BussrutaApp extends StatefulWidget {
  const BussrutaApp({super.key, required this.controller});

  final GameController controller;

  @override
  State<BussrutaApp> createState() => _BussrutaAppState();
}

class _BussrutaAppState extends State<BussrutaApp> {
  String _lastBanner = '';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final GameState state = widget.controller.state;
        _maybeShowTransient(state);

        return MaterialApp(
          title: 'Bussruta',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFFB3541E),
            useMaterial3: true,
          ),
          home: state.phase == GamePhase.setup
              ? _SetupScreen(controller: widget.controller)
              : _GameScreen(controller: widget.controller),
        );
      },
    );
  }

  void _maybeShowTransient(GameState state) {
    if (_lastBanner != state.banner && state.banner.isNotEmpty) {
      _lastBanner = state.banner;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        if (state.bannerTone == BannerTone.success) {
          await HapticFeedback.lightImpact();
        } else if (state.bannerTone == BannerTone.fail) {
          await HapticFeedback.mediumImpact();
        }
      });
    }

    final String? error = widget.controller.consumeErrorMessage();
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      });
    }
  }
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final AppLanguage lang = state.language;
    final SetupDraft draft = state.setupDraft;
    final List<String> names = draft.names;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(lang, 'Bussruta Setup', 'Bussruta Oppsett')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr(lang, 'Language', 'Sprak'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<AppLanguage>(
                      segments: <ButtonSegment<AppLanguage>>[
                        ButtonSegment<AppLanguage>(
                          value: AppLanguage.en,
                          label: const Text('EN'),
                        ),
                        ButtonSegment<AppLanguage>(
                          value: AppLanguage.no,
                          label: const Text('NO'),
                        ),
                      ],
                      selected: <AppLanguage>{lang},
                      onSelectionChanged: (Set<AppLanguage> selected) {
                        controller.setLanguage(selected.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr(
                        lang,
                        'Players: ${draft.playerCount}',
                        'Spillere: ${draft.playerCount}',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      min: 1,
                      max: 9,
                      divisions: 8,
                      value: draft.playerCount.toDouble(),
                      onChanged: (double value) {
                        controller.setPlayerCount(value.round());
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: controller.addPlayer,
                          icon: const Icon(Icons.person_add),
                          label: Text(
                            tr(lang, 'Add player', 'Legg til spiller'),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: controller.removePlayer,
                          icon: const Icon(Icons.person_remove),
                          label: Text(
                            tr(lang, 'Remove player', 'Fjern spiller'),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: controller.randomizeSetupNames,
                          icon: const Icon(Icons.casino),
                          label: Text(tr(lang, 'Randomize', 'Tilfeldige')),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.hardResetSetup,
                          icon: const Icon(Icons.restart_alt),
                          label: Text(
                            tr(lang, 'Reset setup', 'Nullstill oppsett'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: draft.reversePyramid,
                      onChanged: controller.setReversePyramid,
                      title: Text(
                        tr(
                          lang,
                          'Reverse pyramid drinks (bottom = 5, top = 1)',
                          'Reverser pyramide (nederst = 5, overst = 1)',
                        ),
                      ),
                    ),
                    const Divider(),
                    for (int i = 0; i < names.length; i += 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                key: ValueKey<String>('name_${i}_${names[i]}'),
                                initialValue: names[i],
                                decoration: InputDecoration(
                                  labelText:
                                      '${tr(lang, 'Player', 'Spiller')} ${i + 1}',
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (String value) =>
                                    controller.setPlayerName(i, value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => controller.removePlayerAt(i),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: controller.startGameFromSetup,
              icon: const Icon(Icons.play_arrow),
              label: Text(tr(lang, 'Start game', 'Start spill')),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                lang,
                'Flow: 4 warmup rounds -> pyramid -> tie-break if needed -> bus route.',
                'Flyt: 4 oppvarmingsrunder -> pyramide -> tie-break ved behov -> bussrute.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameScreen extends StatelessWidget {
  const _GameScreen({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final AppLanguage lang = state.language;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bussruta'),
        actions: <Widget>[
          IconButton(
            onPressed: controller.resetToSetup,
            icon: const Icon(Icons.refresh),
            tooltip: tr(lang, 'New game', 'Nytt spill'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _PhaseHeader(state: state),
            if (state.banner.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _toneColor(
                    context,
                    state.bannerTone,
                  ).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _toneColor(context, state.bannerTone),
                  ),
                ),
                child: Text(state.banner),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _PlayersPanel(state: state),
                    const SizedBox(height: 8),
                    _PhaseBoard(controller: controller),
                    const SizedBox(height: 8),
                    _AutoPlayPanel(controller: controller),
                    const SizedBox(height: 8),
                    _LogPanel(state: state),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _toneColor(BuildContext context, BannerTone tone) {
    switch (tone) {
      case BannerTone.info:
        return Theme.of(context).colorScheme.primary;
      case BannerTone.success:
        return Colors.green.shade700;
      case BannerTone.fail:
        return Colors.red.shade700;
    }
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = state.language;
    final int deckCount = switch (state.phase) {
      GamePhase.setup => 52,
      GamePhase.tiebreak => state.tieBreak?.deck.length ?? 0,
      GamePhase.bussetup ||
      GamePhase.bus ||
      GamePhase.finished => state.busRoute?.deck.length ?? 0,
      _ => state.deck.length,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  phaseLabel(lang, state.phase, state.warmupRound),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(tr(lang, 'Deck: $deckCount', 'Kortstokk: $deckCount')),
              ],
            ),
          ),
          if (state.phase == GamePhase.bus && state.busRoute != null)
            Chip(
              label: Text(
                tr(
                  lang,
                  'Stop ${state.busRoute!.progress + 1}/5',
                  'Stopp ${state.busRoute!.progress + 1}/5',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayersPanel extends StatelessWidget {
  const _PlayersPanel({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final int? activeIndex = switch (state.phase) {
      GamePhase.warmup => state.currentPlayerIndex,
      GamePhase.bussetup ||
      GamePhase.bus ||
      GamePhase.finished => state.busRunnerIndex,
      _ => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (int i = 0; i < state.players.length; i += 1)
              Chip(
                avatar: i == activeIndex
                    ? const Icon(Icons.play_arrow, size: 18)
                    : null,
                label: Text(
                  '${state.players[i].name} (${state.players[i].hand.length})',
                ),
                backgroundColor: state.pyramidHighlightPlayers.contains(i)
                    ? Colors.amber.shade100
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseBoard extends StatelessWidget {
  const _PhaseBoard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    switch (state.phase) {
      case GamePhase.warmup:
        return _WarmupBoard(controller: controller);
      case GamePhase.pyramid:
        return _PyramidBoard(controller: controller);
      case GamePhase.tiebreak:
        return _TieBreakBoard(controller: controller);
      case GamePhase.bussetup:
        return _BusSetupBoard(controller: controller);
      case GamePhase.bus:
        return _BusBoard(controller: controller);
      case GamePhase.finished:
        return _FinishedBoard(controller: controller);
      case GamePhase.setup:
        return const SizedBox.shrink();
    }
  }
}

class _WarmupBoard extends StatelessWidget {
  const _WarmupBoard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final AppLanguage lang = state.language;
    final PlayerState player = state.players[state.currentPlayerIndex];

    final List<WarmupGuess> options = switch (state.warmupRound) {
      1 => <WarmupGuess>[WarmupGuess.black, WarmupGuess.red],
      2 => <WarmupGuess>[
        WarmupGuess.above,
        WarmupGuess.below,
        WarmupGuess.same,
      ],
      3 => <WarmupGuess>[
        WarmupGuess.between,
        WarmupGuess.outside,
        WarmupGuess.same,
      ],
      _ => <WarmupGuess>[
        WarmupGuess.clubs,
        WarmupGuess.diamonds,
        WarmupGuess.hearts,
        WarmupGuess.spades,
      ],
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              tr(lang, 'Active: ${player.name}', 'Aktiv: ${player.name}'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (WarmupGuess guess) => FilledButton.tonal(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        controller.playWarmupGuess(guess);
                      },
                      child: Text(warmupGuessLabel(lang, guess)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            _HandCards(hand: player.hand),
          ],
        ),
      ),
    );
  }
}

class _PyramidBoard extends StatelessWidget {
  const _PyramidBoard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final int normalizedStep = state.pyramidRevealIndex.clamp(0, 14);
    final int nextSlot = state.reversePyramid
        ? 14 - normalizedStep
        : normalizedStep;
    final List<List<int>> rows = <List<int>>[
      <int>[14],
      <int>[12, 13],
      <int>[9, 10, 11],
      <int>[5, 6, 7, 8],
      <int>[0, 1, 2, 3, 4],
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            for (final List<int> row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row
                      .map(
                        (int index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _PyramidSlot(
                            card: state.pyramidCards[index],
                            isActive: index == nextSlot,
                            onTap: index == nextSlot
                                ? () {
                                    HapticFeedback.selectionClick();
                                    controller.revealPyramidNext();
                                  }
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TieBreakBoard extends StatelessWidget {
  const _TieBreakBoard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final TieBreakState tie = state.tieBreak!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Round ${tie.round}'),
            const SizedBox(height: 8),
            for (final int contender in tie.contenders)
              ListTile(
                dense: true,
                title: Text(state.players[contender].name),
                trailing: Text(_drawForContender(tie, contender) ?? '--'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                controller.runTieBreakRound();
              },
              child: Text(
                tr(
                  state.language,
                  'Draw tie-break cards',
                  'Trekk tie-break kort',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _drawForContender(TieBreakState tie, int contender) {
    for (final TieBreakDraw draw in tie.lastDraws) {
      if (draw.playerIndex == contender) {
        return draw.card.shortLabel();
      }
    }
    return null;
  }
}

class _BusSetupBoard extends StatelessWidget {
  const _BusSetupBoard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final BusRouteState bus = state.busRoute!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: bus.routeCards
                  .map(
                    (PlayingCard card) => _CardFace(label: card.shortLabel()),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () =>
                        controller.beginBusRoute(BusStartSide.left),
                    child: Text(
                      tr(state.language, 'Start Left', 'Start venstre'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () =>
                        controller.beginBusRoute(BusStartSide.right),
                    child: Text(
                      tr(state.language, 'Start Right', 'Start hoyre'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BusBoard extends StatelessWidget {
  const _BusBoard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final AppLanguage lang = state.language;
    final BusRouteState bus = state.busRoute!;
    final int activeStep = bus.order[bus.progress];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(bus.routeCards.length, (int i) {
                final bool isActive = i == activeStep;
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _CardFace(label: bus.routeCards[i].shortLabel()),
                );
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: BusGuess.values
                  .map(
                    (BusGuess guess) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilledButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            controller.playBusGuess(guess);
                          },
                          child: Text(busGuessLabel(lang, guess)),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(tr(lang, 'Recent route events', 'Siste hendelser')),
            const SizedBox(height: 4),
            for (final BusHistoryEntry event in bus.history.reversed.take(5))
              Text(
                '- ${event.message}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _FinishedBoard extends StatelessWidget {
  const _FinishedBoard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = controller.state.language;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              tr(lang, 'Game complete', 'Spill ferdig'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: controller.resetToSetup,
              icon: const Icon(Icons.refresh),
              label: Text(tr(lang, 'New game', 'Nytt spill')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoPlayPanel extends StatelessWidget {
  const _AutoPlayPanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final AppLanguage lang = state.language;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(tr(lang, 'Auto play', 'Autospill')),
                const Spacer(),
                Switch(
                  value: state.autoPlay.enabled,
                  onChanged: controller.toggleAutoPlay,
                ),
              ],
            ),
            Slider(
              value: state.autoPlay.delayMs.toDouble(),
              min: 350,
              max: 60000,
              divisions: 40,
              label: '${(state.autoPlay.delayMs / 1000).toStringAsFixed(1)}s',
              onChanged: (double value) =>
                  controller.setAutoPlayDelayMs(value.round()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = state.language;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(tr(lang, 'Game log', 'Spilllogg')),
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListView.builder(
            itemCount: state.log.length,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  state.log[index],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HandCards extends StatelessWidget {
  const _HandCards({required this.hand});

  final List<PlayingCard> hand;

  @override
  Widget build(BuildContext context) {
    if (hand.isEmpty) {
      return const Text('-');
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: hand
          .map((PlayingCard card) => _CardFace(label: card.shortLabel()))
          .toList(),
    );
  }
}

class _PyramidSlot extends StatelessWidget {
  const _PyramidSlot({
    required this.card,
    required this.isActive,
    required this.onTap,
  });

  final PlayingCard? card;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 46,
          height: 62,
          decoration: BoxDecoration(
            color: card == null ? Colors.blueGrey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade400,
              width: isActive ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: card == null
              ? const Icon(Icons.style, size: 18)
              : Text(card!.shortLabel()),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(label),
    );
  }
}
