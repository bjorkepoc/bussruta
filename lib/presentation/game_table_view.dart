import 'dart:async';
import 'dart:math' as math;

import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/presentation/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GameTableView extends StatefulWidget {
  const GameTableView({
    super.key,
    required this.controller,
    required this.state,
  });

  final GameController controller;
  final GameState state;

  @override
  State<GameTableView> createState() => _GameTableViewState();
}

class _GameTableViewState extends State<GameTableView> {
  final Map<int, int> _visibleHandCounts = <int, int>{};
  final Set<int> _revealedPyramidSlots = <int>{};
  final Set<int> _visibleTieSlots = <int>{};
  final Set<int> _tieFaceUpSlots = <int>{};
  final Map<String, int> _visibleBusZoneCounts = <String, int>{};
  final List<_FlightCard> _flights = <_FlightCard>[];

  Size _stageSize = Size.zero;
  int _visibleRouteCards = 0;
  int _flightSeed = 0;
  int _tieRevealToken = 0;

  @override
  void initState() {
    super.initState();
    _syncVisibleFromState(widget.state);
  }

  @override
  void didUpdateWidget(covariant GameTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clampVisibleState(widget.state);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _stageSize == Size.zero) {
        return;
      }
      _runStateDiffs(oldWidget.state, widget.state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _stageSize = constraints.biggest;
        final GameState state = widget.state;
        final Rect tableRect = _tableRect(_stageSize, state.phase);
        final double? warmupPanelTop = state.phase == GamePhase.warmup
            ? _warmupPanelRect(
                tableRect,
                _warmupOptions(state.warmupRound).length,
              ).top
            : null;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Color(0xFFF4ECE1), Color(0xFFEAD9C8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _buildAtmosphere(),
              _TableShell(rect: tableRect),
              if (_showSeats(state.phase))
                ...List<Widget>.generate(state.players.length, (int index) {
                  final bool pyramidDock = state.phase == GamePhase.pyramid;
                  final bool compact =
                      pyramidDock ||
                      (state.phase == GamePhase.warmup
                          ? state.players.length >= 5
                          : state.players.length >= 6);
                  final Size seatFootprint = _seatFootprint(
                    compact,
                    phase: state.phase,
                  );
                  final Offset position = _seatCenter(
                    index: index,
                    total: state.players.length,
                    phase: state.phase,
                    rect: tableRect,
                    warmupPanelTop: warmupPanelTop,
                  );
                  return Positioned(
                    left: position.dx,
                    top: position.dy,
                    child: Transform.translate(
                      offset: Offset(
                        -seatFootprint.width / 2,
                        -seatFootprint.height / 2,
                      ),
                      child: _SeatChip(
                        player: state.players[index],
                        language: state.language,
                        visibleCards: state.players[index].hand
                            .take(_visibleHandCounts[index] ?? 0)
                            .toList(),
                        dockMode: pyramidDock,
                        compact: compact,
                        active:
                            state.phase == GamePhase.warmup &&
                            state.currentPlayerIndex == index,
                        winner:
                            state.phase == GamePhase.pyramid &&
                            state.pyramidHighlightPlayers.contains(index),
                        runner:
                            (state.phase == GamePhase.bussetup ||
                                state.phase == GamePhase.bus ||
                                state.phase == GamePhase.finished) &&
                            state.busRunnerIndex == index,
                      ),
                    ),
                  );
                }),
              if (state.phase == GamePhase.warmup)
                _buildWarmupOverlay(tableRect),
              if (state.phase == GamePhase.pyramid)
                _buildPyramidOverlay(tableRect),
              if (state.phase == GamePhase.tiebreak)
                _buildTieBreakOverlay(tableRect),
              if (state.phase == GamePhase.bussetup ||
                  state.phase == GamePhase.bus ||
                  state.phase == GamePhase.finished)
                _buildBusOverlay(tableRect),
              if (state.phase == GamePhase.finished)
                _buildCelebration(tableRect),
              ..._buildFlights(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAtmosphere() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: const <Widget>[
            _GlowBlob(
              alignment: Alignment(-0.9, -0.8),
              color: Color(0x40FFFFFF),
              size: 180,
            ),
            _GlowBlob(
              alignment: Alignment(0.95, -0.3),
              color: Color(0x24B3541E),
              size: 220,
            ),
            _GlowBlob(
              alignment: Alignment(0.0, 1.1),
              color: Color(0x1F215646),
              size: 260,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarmupOverlay(Rect tableRect) {
    final GameState state = widget.state;
    final AppLanguage lang = state.language;
    final List<WarmupGuess> options = _warmupOptions(state.warmupRound);
    final int optionColumns = _warmupPanelColumns(options.length);
    final Offset deckCenter = _warmupDeckCenter(tableRect);
    final Rect deckRect = Rect.fromCenter(
      center: deckCenter,
      width: _CardMetrics.medium.width,
      height: _CardMetrics.medium.height,
    );
    final Rect panelRect = _warmupPanelRect(tableRect, options.length);

    return Stack(
      children: <Widget>[
        Positioned(
          left: deckRect.left,
          top: deckRect.top - 8,
          width: deckRect.width,
          height: deckRect.height + 12,
          child: _DeckStack(
            label: tr(lang, 'DEAL', 'TREKK'),
            deckCount: state.deck.length,
            ready: true,
          ),
        ),
        Positioned(
          left: panelRect.left,
          top: panelRect.top,
          width: panelRect.width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xCC113726), Color(0xCC1D4D37)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0x66FFD89A)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _warmupRoundPrompt(lang, state.warmupRound),
                    style: const TextStyle(
                      color: Color(0xFFF7EDDC),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final double spacing = 8;
                          final double itemWidth =
                              (constraints.maxWidth -
                                  spacing * (optionColumns - 1)) /
                              optionColumns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: options.map((WarmupGuess guess) {
                              return SizedBox(
                                width: itemWidth,
                                child: _WarmupActionCard(
                                  label: warmupGuessLabel(lang, guess),
                                  onTap: () async {
                                    await HapticFeedback.selectionClick();
                                    widget.controller.playWarmupGuess(guess);
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPyramidOverlay(Rect tableRect) {
    final GameState state = widget.state;
    final AppLanguage lang = state.language;
    final _PyramidLayout layout = _pyramidLayout(tableRect);
    final List<Rect> slotRects = layout.slotRects;
    final int nextSlot = state.pyramidRevealIndex >= 15
        ? -1
        : (state.reversePyramid
              ? 14 - state.pyramidRevealIndex.clamp(0, 14)
              : state.pyramidRevealIndex.clamp(0, 14));
    final bool canRevealNext = nextSlot >= 0;

    return Stack(
      children: <Widget>[
        Positioned.fromRect(
          rect: layout.boardRect,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0x1A102E23), Color(0x121D4B3A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: const Color(0x56FFD89A)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: layout.deckRect,
          child: GestureDetector(
            onTap: canRevealNext
                ? () async {
                    await HapticFeedback.selectionClick();
                    widget.controller.revealPyramidNext();
                  }
                : null,
            child: _DeckStack(
              label: tr(lang, 'PYR', 'PYR'),
              deckCount: state.deck.length,
              ready: canRevealNext,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: layout.hintRect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xA61A3B2D),
              border: Border.all(color: const Color(0x5BFFE4A7)),
            ),
            child: Center(
              child: Text(
                tr(
                  lang,
                  'Tap deck to reveal next pyramid card',
                  'Trykk stokken for a avslore neste pyramidekort',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF8F1E3),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
        for (int index = 0; index < slotRects.length; index += 1)
          if (_revealedPyramidSlots.contains(index))
            Positioned.fromRect(
              rect: slotRects[index],
              child: _PyramidSlotCard(
                card: state.pyramidCards[index],
                faceUp: true,
                active: false,
                onTap: null,
              ),
            )
          else if (index == nextSlot)
            Positioned.fromRect(
              rect: slotRects[index],
              child: const _PyramidRevealTarget(),
            ),
      ],
    );
  }

  Widget _buildTieBreakOverlay(Rect tableRect) {
    final GameState state = widget.state;
    final AppLanguage lang = state.language;
    final TieBreakState tie = state.tieBreak!;
    final _TieLayout layout = _tieLayout(tableRect, tie.contenders.length);
    final String instruction;
    final bool winnerLocked =
        state.busRunnerIndex != null && tie.lastDraws.isNotEmpty;
    if (winnerLocked) {
      instruction = tr(
        lang,
        '${state.players[state.busRunnerIndex!].name} wins tie-break',
        '${state.players[state.busRunnerIndex!].name} vinner tie-break',
      );
    } else if (tie.lastDraws.isEmpty) {
      instruction = tr(
        lang,
        'Tap deck to deal facedown cards',
        'Trykk stokken for a dele ut kort med baksiden opp',
      );
    } else if (_tieFaceUpSlots.length < tie.lastDraws.length) {
      instruction = tr(lang, 'Dealing cards...', 'Deler ut kort...');
    } else {
      instruction = tr(
        lang,
        'Reveal complete - next tie-break action incoming',
        'Avsloring ferdig - neste tie-break handling kommer',
      );
    }

    return Stack(
      children: <Widget>[
        Positioned.fromRect(
          rect: layout.deckRect,
          child: GestureDetector(
            onTap: winnerLocked
                ? null
                : () async {
                    await HapticFeedback.selectionClick();
                    widget.controller.runTieBreakRound();
                  },
            child: _DeckStack(
              label: tr(lang, 'TIE', 'TIE'),
              deckCount: tie.deck.length,
              ready: !winnerLocked,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: layout.instructionRect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xA4203328),
              border: Border.all(
                color: winnerLocked
                    ? const Color(0x88FFE4A7)
                    : const Color(0x55FFFFFF),
              ),
            ),
            child: Center(
              child: Text(
                instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF8F2E9),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
        for (int index = 0; index < tie.contenders.length; index += 1)
          ..._buildTieContenderWidgets(
            rect: layout.slotRects[index],
            playerIndex: tie.contenders[index],
            tie: tie,
          ),
      ],
    );
  }

  List<Widget> _buildTieContenderWidgets({
    required Rect rect,
    required int playerIndex,
    required TieBreakState tie,
  }) {
    final GameState state = widget.state;
    TieBreakDraw? draw;
    for (final TieBreakDraw entry in tie.lastDraws) {
      if (entry.playerIndex == playerIndex) {
        draw = entry;
        break;
      }
    }
    final bool dealt = _visibleTieSlots.contains(playerIndex) && draw != null;
    final bool faceUp = dealt && _tieFaceUpSlots.contains(playerIndex);

    return <Widget>[
      Positioned(
        left: rect.left - 10,
        top: rect.top - 34,
        width: rect.width + 20,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0x90203328),
            border: Border.all(color: const Color(0x55FFE4A7)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              state.players[playerIndex].name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF8F2E9),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: rect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Center(
            child: dealt
                ? _PlayingCardView(
                    card: faceUp ? draw.card : null,
                    faceUp: faceUp,
                    size: _CardVisualSize.medium,
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SizedBox(
                      width: _CardMetrics.medium.width - 4,
                      height: _CardMetrics.medium.height - 4,
                    ),
                  ),
          ),
        ),
      ),
    ];
  }

  Widget _buildBusOverlay(Rect tableRect) {
    final GameState state = widget.state;
    final AppLanguage lang = state.language;
    final BusRouteState bus = state.busRoute!;
    final _BusLayout layout = _busLayout(tableRect, phase: state.phase);
    final int activeIndex = state.phase == GamePhase.bus
        ? bus.order[bus.progress]
        : -1;

    return Stack(
      children: <Widget>[
        Positioned.fromRect(
          rect: layout.deckRect,
          child: _DeckStack(
            label: tr(lang, 'BUS', 'BUS'),
            deckCount: bus.deck.length,
            ready: state.phase == GamePhase.bus,
          ),
        ),
        if (state.phase != GamePhase.finished)
          Positioned.fromRect(
            rect: layout.instructionRect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xA5203328),
                border: Border.all(color: const Color(0x55FFFFFF)),
              ),
              child: Center(
                child: Text(
                  state.phase == GamePhase.bussetup
                      ? tr(
                          lang,
                          'Choose which side to start from',
                          'Velg hvilken side ruten starter fra',
                        )
                      : tr(
                          lang,
                          'Play above, below, or same on active card',
                          'Spill over, under eller samme pa aktivt kort',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF8F2E9),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ),
        for (int step = 0; step < bus.routeCards.length; step += 1)
          ..._buildBusStopWidgets(
            step: step,
            active: state.phase == GamePhase.bus && activeIndex == step,
            layout: layout,
          ),
        if (state.phase == GamePhase.bussetup)
          Builder(
            builder: (BuildContext context) {
              final double controlsWidth = math.min(tableRect.width - 24, 340);
              return Positioned(
                left: tableRect.center.dx - controlsWidth / 2,
                top: layout.controlsTop,
                width: controlsWidth,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () =>
                            widget.controller.beginBusRoute(BusStartSide.left),
                        child: Text(tr(lang, 'Start Left', 'Start venstre')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () =>
                            widget.controller.beginBusRoute(BusStartSide.right),
                        child: Text(tr(lang, 'Start Right', 'Start hoyre')),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  List<Widget> _buildBusStopWidgets({
    required int step,
    required bool active,
    required _BusLayout layout,
  }) {
    final GameState state = widget.state;
    final BusRouteState bus = state.busRoute!;
    final AppLanguage lang = state.language;
    final List<Widget> widgets = <Widget>[];
    final BusZoneStack lane = bus.overlays[step];
    final BusZoneTone tone = bus.zoneTone[step];
    final int visibleRouteCount = _visibleRouteCards.clamp(
      0,
      bus.routeCards.length,
    );
    final int highCount = _visibleCountForBusZone(step, 'high');
    final int lowCount = _visibleCountForBusZone(step, 'low');
    final int sameCount = _visibleCountForBusZone(step, 'same');

    if (active || highCount > 0) {
      widgets.add(
        Positioned.fromRect(
          rect: layout.highRects[step],
          child: _BusZone(
            label: active ? tr(lang, 'Above', 'Over') : '',
            active: active,
            tone: active ? tone.high : null,
            onTap: active
                ? () async {
                    await HapticFeedback.selectionClick();
                    widget.controller.playBusGuess(BusGuess.above);
                  }
                : null,
            child: _StackPile(
              cards: lane.high.take(highCount).toList(),
              size: _CardVisualSize.medium,
            ),
          ),
        ),
      );
    }

    widgets.add(
      Positioned.fromRect(
        rect: layout.baseRects[step],
        child: _BusBase(
          active: active,
          tone: active ? tone.same : null,
          sameButtonLabel: active ? tr(lang, 'Same', 'Samme') : null,
          sameCount: sameCount,
          onSame: active
              ? () async {
                  await HapticFeedback.selectionClick();
                  widget.controller.playBusGuess(BusGuess.same);
                }
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Opacity(
                opacity: active ? 1 : 0.9,
                child: _PlayingCardView(
                  card: step < visibleRouteCount ? bus.routeCards[step] : null,
                  faceUp: step < visibleRouteCount,
                  size: _CardVisualSize.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (active || lowCount > 0) {
      widgets.add(
        Positioned.fromRect(
          rect: layout.lowRects[step],
          child: _BusZone(
            label: active ? tr(lang, 'Below', 'Under') : '',
            active: active,
            tone: active ? tone.low : null,
            onTap: active
                ? () async {
                    await HapticFeedback.selectionClick();
                    widget.controller.playBusGuess(BusGuess.below);
                  }
                : null,
            child: _StackPile(
              cards: lane.low.take(lowCount).toList(),
              size: _CardVisualSize.medium,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildCelebration(Rect tableRect) {
    final AppLanguage lang = widget.state.language;
    final _BusLayout layout = _busLayout(tableRect, phase: GamePhase.finished);
    final double width = math.min(320, tableRect.width - 24);
    final double targetCenterY =
        (layout.deckRect.center.dy + layout.baseRects[2].center.dy) / 2;
    final double top = (targetCenterY - 80).clamp(
      tableRect.top + 24,
      layout.baseRects[2].top - 24,
    );
    return Positioned(
      left: tableRect.center.dx - width / 2,
      top: top,
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8E8D3).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                tr(lang, 'Route finished', 'Rute ferdig'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF50301F),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.state.banner,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5D3B27)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.controller.resetToSetup,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(tr(lang, 'New game', 'Nytt spill')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFlights() {
    return _flights.map((_FlightCard flight) {
      return Positioned.fill(
        key: ValueKey<int>(flight.id),
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: flight.duration,
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              final Offset position = Offset.lerp(
                flight.from,
                flight.to,
                value,
              )!;
              return Stack(
                children: <Widget>[
                  Positioned(
                    left: position.dx - flight.metrics.width / 2,
                    top: position.dy - flight.metrics.height / 2,
                    child: Transform.rotate(
                      angle: (1 - value) * flight.rotation,
                      child: child,
                    ),
                  ),
                ],
              );
            },
            child: _PlayingCardView(
              card: flight.card,
              faceUp: flight.faceUp,
              size: flight.size,
            ),
          ),
        ),
      );
    }).toList();
  }

  void _syncVisibleFromState(GameState state) {
    _visibleHandCounts
      ..clear()
      ..addEntries(
        List<MapEntry<int, int>>.generate(
          state.players.length,
          (int index) =>
              MapEntry<int, int>(index, state.players[index].hand.length),
        ),
      );

    _revealedPyramidSlots
      ..clear()
      ..addAll(
        List<int>.generate(
          state.pyramidCards.length,
          (int index) => index,
        ).where((int index) => state.pyramidCards[index] != null),
      );

    _visibleTieSlots
      ..clear()
      ..addAll(
        state.tieBreak?.lastDraws
                .map((TieBreakDraw draw) => draw.playerIndex)
                .toSet() ??
            <int>{},
      );
    _tieFaceUpSlots
      ..clear()
      ..addAll(_visibleTieSlots);

    _visibleRouteCards = state.busRoute?.routeCards.length ?? 0;
    _visibleBusZoneCounts.clear();
    if (state.busRoute != null) {
      for (int step = 0; step < state.busRoute!.overlays.length; step += 1) {
        final BusZoneStack lane = state.busRoute!.overlays[step];
        _visibleBusZoneCounts['$step-high'] = lane.high.length;
        _visibleBusZoneCounts['$step-low'] = lane.low.length;
        _visibleBusZoneCounts['$step-same'] = lane.same.length;
      }
    }
  }

  void _clampVisibleState(GameState state) {
    for (int index = 0; index < state.players.length; index += 1) {
      final int count = state.players[index].hand.length;
      final int current = _visibleHandCounts[index] ?? count;
      _visibleHandCounts[index] = current.clamp(0, count);
    }

    _revealedPyramidSlots.removeWhere((int index) {
      return index >= state.pyramidCards.length ||
          state.pyramidCards[index] == null;
    });

    final Set<int> visibleTiePlayers =
        state.tieBreak?.lastDraws
            .map((TieBreakDraw draw) => draw.playerIndex)
            .toSet() ??
        <int>{};
    _visibleTieSlots.removeWhere((int playerIndex) {
      return !visibleTiePlayers.contains(playerIndex);
    });
    _tieFaceUpSlots.removeWhere((int playerIndex) {
      return !_visibleTieSlots.contains(playerIndex);
    });

    if (state.busRoute == null) {
      _visibleRouteCards = 0;
      _visibleBusZoneCounts.clear();
      return;
    }

    _visibleRouteCards = _visibleRouteCards.clamp(
      0,
      state.busRoute!.routeCards.length,
    );
    for (int step = 0; step < state.busRoute!.overlays.length; step += 1) {
      final BusZoneStack lane = state.busRoute!.overlays[step];
      _visibleBusZoneCounts['$step-high'] =
          (_visibleBusZoneCounts['$step-high'] ?? lane.high.length).clamp(
            0,
            lane.high.length,
          );
      _visibleBusZoneCounts['$step-low'] =
          (_visibleBusZoneCounts['$step-low'] ?? lane.low.length).clamp(
            0,
            lane.low.length,
          );
      _visibleBusZoneCounts['$step-same'] =
          (_visibleBusZoneCounts['$step-same'] ?? lane.same.length).clamp(
            0,
            lane.same.length,
          );
    }
  }

  void _runStateDiffs(GameState previous, GameState next) {
    if (previous.players.length == next.players.length) {
      _animateWarmupDeals(previous, next);
    } else {
      _syncVisibleFromState(next);
    }
    _animatePyramidReveal(previous, next);
    _animateTieBreak(previous, next);
    _animateBusRouteDeal(previous, next);
    _animateBusGuess(previous, next);
  }

  void _animateWarmupDeals(GameState previous, GameState next) {
    final Rect tableRect = _tableRect(_stageSize, GamePhase.warmup);
    final int warmupRound = previous.phase == GamePhase.warmup
        ? previous.warmupRound
        : next.warmupRound;
    final double warmupPanelTop = _warmupPanelRect(
      tableRect,
      _warmupOptions(warmupRound).length,
    ).top;
    for (int index = 0; index < next.players.length; index += 1) {
      final int previousCount = previous.players[index].hand.length;
      final int nextCount = next.players[index].hand.length;
      if (nextCount <= previousCount) {
        _visibleHandCounts[index] = nextCount;
        continue;
      }

      _visibleHandCounts[index] = previousCount;
      for (
        int cardIndex = previousCount;
        cardIndex < nextCount;
        cardIndex += 1
      ) {
        final PlayingCard card = next.players[index].hand[cardIndex];
        final Offset target = _seatCardTarget(
          index: index,
          total: next.players.length,
          phaseHint: previous.phase == GamePhase.warmup
              ? GamePhase.warmup
              : next.phase,
          rect: tableRect,
          warmupPanelTop: warmupPanelTop,
        );
        _queueFlight(
          card: card,
          faceUp: true,
          from: _warmupDeckCenter(tableRect),
          to: target,
          size: _CardVisualSize.small,
          delay: Duration(milliseconds: 120 * (cardIndex - previousCount)),
          onDone: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _visibleHandCounts[index] = (_visibleHandCounts[index] ?? 0) + 1;
            });
          },
        );
      }
    }
  }

  void _animatePyramidReveal(GameState previous, GameState next) {
    final Rect tableRect = _tableRect(_stageSize, GamePhase.pyramid);
    final List<Rect> slotRects = _pyramidSlotRects(tableRect);
    for (int index = 0; index < next.pyramidCards.length; index += 1) {
      if (previous.pyramidCards[index] == null &&
          next.pyramidCards[index] != null) {
        _revealedPyramidSlots.remove(index);
        _queueFlight(
          card: next.pyramidCards[index],
          faceUp: true,
          from: _pyramidDeckCenter(tableRect),
          to: slotRects[index].center,
          size: _CardVisualSize.small,
          onDone: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _revealedPyramidSlots.add(index);
            });
          },
        );
      }
    }
  }

  void _animateTieBreak(GameState previous, GameState next) {
    if (next.tieBreak == null || next.tieBreak!.lastDraws.isEmpty) {
      _visibleTieSlots.clear();
      _tieFaceUpSlots.clear();
      return;
    }

    final TieBreakState? previousTie = previous.tieBreak;
    final TieBreakState nextTie = next.tieBreak!;
    if (previousTie != null &&
        previousTie.round == nextTie.round &&
        _sameTieDraws(previousTie.lastDraws, nextTie.lastDraws)) {
      return;
    }

    final int revealToken = ++_tieRevealToken;
    _visibleTieSlots.clear();
    _tieFaceUpSlots.clear();

    final Rect tableRect = _tableRect(_stageSize, GamePhase.tiebreak);
    final _TieLayout layout = _tieLayout(tableRect, nextTie.contenders.length);
    int landedCount = 0;
    final int total = nextTie.lastDraws.length;
    final List<int> revealedPlayers = nextTie.lastDraws
        .map((TieBreakDraw draw) => draw.playerIndex)
        .toList();

    for (int index = 0; index < total; index += 1) {
      final TieBreakDraw draw = nextTie.lastDraws[index];
      _visibleTieSlots.remove(draw.playerIndex);
      _queueFlight(
        card: draw.card,
        faceUp: false,
        from: layout.deckRect.center,
        to: layout.slotRects[index].center,
        size: _CardVisualSize.medium,
        delay: Duration(milliseconds: 220 * index),
        duration: const Duration(milliseconds: 680),
        onDone: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _visibleTieSlots.add(draw.playerIndex);
          });
          landedCount += 1;
          if (landedCount != total || revealToken != _tieRevealToken) {
            return;
          }
          Future<void>.delayed(const Duration(milliseconds: 720), () {
            if (!mounted || revealToken != _tieRevealToken) {
              return;
            }
            HapticFeedback.mediumImpact();
            setState(() {
              _tieFaceUpSlots
                ..clear()
                ..addAll(revealedPlayers);
            });
            if (next.busRunnerIndex != null &&
                next.phase == GamePhase.tiebreak) {
              Future<void>.delayed(const Duration(milliseconds: 900), () {
                if (!mounted || revealToken != _tieRevealToken) {
                  return;
                }
                final GameState current = widget.state;
                if (current.phase == GamePhase.tiebreak &&
                    current.busRunnerIndex != null &&
                    (current.tieBreak?.lastDraws.isNotEmpty ?? false)) {
                  widget.controller.runTieBreakRound();
                }
              });
            }
          });
        },
      );
    }
  }

  void _animateBusRouteDeal(GameState previous, GameState next) {
    if (next.busRoute == null) {
      _visibleRouteCards = 0;
      _visibleBusZoneCounts.clear();
      return;
    }
    if (previous.busRoute != null) {
      return;
    }

    _visibleRouteCards = 0;
    _visibleBusZoneCounts.clear();
    final Rect tableRect = _tableRect(_stageSize, GamePhase.bus);
    final _BusLayout layout = _busLayout(tableRect, phase: GamePhase.bus);
    for (int index = 0; index < next.busRoute!.routeCards.length; index += 1) {
      final PlayingCard card = next.busRoute!.routeCards[index];
      _queueFlight(
        card: card,
        faceUp: true,
        from: _busDeckCenter(tableRect),
        to: layout.baseRects[index].center,
        size: _CardVisualSize.medium,
        delay: Duration(milliseconds: 110 * index),
        onDone: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _visibleRouteCards = math.max(_visibleRouteCards, index + 1);
          });
        },
      );
    }
  }

  void _animateBusGuess(GameState previous, GameState next) {
    if (previous.busRoute == null || next.busRoute == null) {
      return;
    }

    final Rect tableRect = _tableRect(_stageSize, GamePhase.bus);
    final _BusLayout layout = _busLayout(tableRect, phase: GamePhase.bus);
    for (int step = 0; step < next.busRoute!.overlays.length; step += 1) {
      _animateBusZoneDelta(
        previousCards: previous.busRoute!.overlays[step].high,
        nextCards: next.busRoute!.overlays[step].high,
        zoneKey: '$step-high',
        target: layout.highRects[step].center,
      );
      _animateBusZoneDelta(
        previousCards: previous.busRoute!.overlays[step].low,
        nextCards: next.busRoute!.overlays[step].low,
        zoneKey: '$step-low',
        target: layout.lowRects[step].center,
      );
      _animateBusZoneDelta(
        previousCards: previous.busRoute!.overlays[step].same,
        nextCards: next.busRoute!.overlays[step].same,
        zoneKey: '$step-same',
        target: layout.baseRects[step].topLeft + const Offset(14, 18),
      );
    }
  }

  void _animateBusZoneDelta({
    required List<PlayingCard> previousCards,
    required List<PlayingCard> nextCards,
    required String zoneKey,
    required Offset target,
  }) {
    if (nextCards.length <= previousCards.length) {
      _visibleBusZoneCounts[zoneKey] = nextCards.length;
      return;
    }

    _visibleBusZoneCounts[zoneKey] = previousCards.length;
    for (
      int index = previousCards.length;
      index < nextCards.length;
      index += 1
    ) {
      final PlayingCard card = nextCards[index];
      final bool laneCard =
          zoneKey.endsWith('-high') || zoneKey.endsWith('-low');
      _queueFlight(
        card: card,
        faceUp: true,
        from: _busDeckCenter(_tableRect(_stageSize, GamePhase.bus)),
        to: target,
        size: laneCard ? _CardVisualSize.medium : _CardVisualSize.extraSmall,
        onDone: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _visibleBusZoneCounts[zoneKey] =
                (_visibleBusZoneCounts[zoneKey] ?? 0) + 1;
          });
        },
      );
    }
  }

  void _queueFlight({
    required PlayingCard? card,
    required bool faceUp,
    required Offset from,
    required Offset to,
    required _CardVisualSize size,
    required VoidCallback onDone,
    Duration delay = Duration.zero,
    Duration duration = const Duration(milliseconds: 520),
  }) {
    final _FlightCard flight = _FlightCard(
      id: _flightSeed += 1,
      card: card,
      faceUp: faceUp,
      from: from,
      to: to,
      size: size,
      duration: duration,
      rotation: (math.Random(_flightSeed).nextDouble() - 0.5) * 0.26,
    );

    Future<void>.delayed(delay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _flights.add(flight);
      });
      Future<void>.delayed(duration, () {
        if (!mounted) {
          return;
        }
        setState(() {
          _flights.removeWhere((_FlightCard item) => item.id == flight.id);
        });
        onDone();
      });
    });
  }

  List<WarmupGuess> _warmupOptions(int round) {
    switch (round) {
      case 1:
        return const <WarmupGuess>[WarmupGuess.black, WarmupGuess.red];
      case 2:
        return const <WarmupGuess>[
          WarmupGuess.above,
          WarmupGuess.below,
          WarmupGuess.same,
        ];
      case 3:
        return const <WarmupGuess>[
          WarmupGuess.between,
          WarmupGuess.outside,
          WarmupGuess.same,
        ];
      default:
        return const <WarmupGuess>[
          WarmupGuess.clubs,
          WarmupGuess.diamonds,
          WarmupGuess.hearts,
          WarmupGuess.spades,
        ];
    }
  }

  String _warmupRoundPrompt(AppLanguage language, int round) {
    switch (round) {
      case 1:
        return tr(language, 'Round 1: guess color', 'Runde 1: gjett farge');
      case 2:
        return tr(
          language,
          'Round 2: compare with first card',
          'Runde 2: sammenlign med forste kort',
        );
      case 3:
        return tr(
          language,
          'Round 3: between, outside, or same',
          'Runde 3: mellom, utenfor, eller samme',
        );
      default:
        return tr(language, 'Round 4: guess suit', 'Runde 4: gjett sort');
    }
  }

  int _warmupPanelColumns(int optionCount) {
    if (optionCount <= 1) {
      return 1;
    }
    return optionCount == 4 ? 2 : optionCount;
  }

  double _warmupPanelHeight(int optionCount) {
    final int columns = _warmupPanelColumns(optionCount);
    final int rows = (optionCount / columns).ceil();
    return math.min(188, math.max(112, 58 + rows * 52 + (rows - 1) * 8));
  }

  Rect _warmupPanelRect(Rect tableRect, int optionCount) {
    final double panelWidth = math.min(
      _stageSize.width - 20,
      optionCount == 4 ? 380 : 420,
    );
    final double panelHeight = _warmupPanelHeight(optionCount);
    final double panelTop = math.min(
      tableRect.bottom + 28,
      _stageSize.height - panelHeight - 8,
    );
    return Rect.fromLTWH(
      (_stageSize.width - panelWidth) / 2,
      panelTop,
      panelWidth,
      panelHeight,
    );
  }

  Rect _tableRect(Size size, [GamePhase? phase]) {
    final bool warmup = phase == GamePhase.warmup;
    final bool routePhase =
        phase == GamePhase.bussetup ||
        phase == GamePhase.bus ||
        phase == GamePhase.finished;
    final double width = math.min(size.width - (warmup ? 10 : 8), 980);
    final double desiredHeight = warmup
        ? size.height * 0.82
        : routePhase
        ? size.height * 0.95
        : size.height * 0.96;
    final double height = math.min(
      size.height - (warmup ? 84 : 10),
      math.max(warmup ? 360 : 380, desiredHeight),
    );
    return Rect.fromCenter(
      center: Offset(
        size.width / 2,
        warmup ? (size.height / 2) - 10 : size.height / 2,
      ),
      width: width,
      height: height,
    );
  }

  bool _showSeats(GamePhase phase) {
    return phase == GamePhase.warmup || phase == GamePhase.pyramid;
  }

  Size _seatFootprint(bool compact, {required GamePhase phase}) {
    if (!compact) {
      return const Size(142, 144);
    }
    if (phase == GamePhase.pyramid) {
      return const Size(94, 96);
    }
    return const Size(102, 108);
  }

  Offset _seatCenter({
    required int index,
    required int total,
    required GamePhase phase,
    required Rect rect,
    double? warmupPanelTop,
  }) {
    final bool compact = phase == GamePhase.pyramid || total >= 5;
    final Size seatFootprint = _seatFootprint(compact, phase: phase);
    final bool oddCount = total.isOdd;
    final int sideSlots = oddCount ? (total - 1) ~/ 2 : total ~/ 2;
    final double edgeInsetX = seatFootprint.width / 2 + 10;
    final double leftX = rect.left + edgeInsetX;
    final double rightX = rect.right - edgeInsetX;
    final double bottomCenterY =
        rect.bottom -
        seatFootprint.height / 2 -
        (phase == GamePhase.pyramid ? 10 : 14);
    if (sideSlots <= 0) {
      return Offset(rect.center.dx, bottomCenterY);
    }

    final double topRail = phase == GamePhase.pyramid
        ? _pyramidLayout(rect).hintRect.bottom + seatFootprint.height / 2
        : rect.top + seatFootprint.height / 2 + 14;
    final double bottomRail =
        rect.bottom -
        seatFootprint.height / 2 -
        (phase == GamePhase.pyramid ? 30 : 18);
    final double warmupBottomCap = phase == GamePhase.warmup
        ? (warmupPanelTop ?? rect.bottom) - seatFootprint.height / 2 - 10
        : bottomRail;
    final double limitedBottom = math.min(bottomRail, warmupBottomCap);
    final double safeTop = topRail;
    final double safeBottom = math.max(topRail, limitedBottom);
    final List<double> sideYs = List<double>.generate(sideSlots, (int slot) {
      final double fraction = sideSlots == 1 ? 0.5 : slot / (sideSlots - 1);
      return safeTop + (safeBottom - safeTop) * fraction;
    });
    if (phase == GamePhase.warmup && oddCount && sideSlots > 1) {
      final int lowermostIndex = sideYs.length - 1;
      sideYs[lowermostIndex] = math.max(safeTop, sideYs[lowermostIndex] - 12);
    }
    final List<Offset> leftTopToBottom = sideYs
        .map((double y) => Offset(leftX, y))
        .toList();
    final List<Offset> rightTopToBottom = sideYs
        .map((double y) => Offset(rightX, y))
        .toList();
    final List<Offset> clockwiseFromTopLeft = <Offset>[];

    clockwiseFromTopLeft.add(leftTopToBottom.first);
    clockwiseFromTopLeft.addAll(rightTopToBottom);
    if (oddCount) {
      clockwiseFromTopLeft.add(
        Offset(
          rect.center.dx,
          bottomCenterY.clamp(safeTop, safeBottom).toDouble(),
        ),
      );
    }
    for (int slot = leftTopToBottom.length - 1; slot >= 1; slot -= 1) {
      clockwiseFromTopLeft.add(leftTopToBottom[slot]);
    }

    if (clockwiseFromTopLeft.isEmpty) {
      return Offset(rect.center.dx, bottomCenterY);
    }
    return clockwiseFromTopLeft[index % clockwiseFromTopLeft.length];
  }

  Offset _seatCardTarget({
    required int index,
    required int total,
    required GamePhase phaseHint,
    required Rect rect,
    double? warmupPanelTop,
  }) {
    final Offset center = _seatCenter(
      index: index,
      total: total,
      phase: phaseHint,
      rect: rect,
      warmupPanelTop: warmupPanelTop,
    );
    final bool compact =
        phaseHint == GamePhase.pyramid ||
        (phaseHint == GamePhase.warmup ? total >= 5 : total >= 6);
    final double offsetY = phaseHint == GamePhase.pyramid
        ? 12
        : compact
        ? 18
        : 26;
    return center + Offset(0, offsetY);
  }

  Offset _warmupDeckCenter(Rect rect) {
    return Offset(rect.center.dx, rect.center.dy - 20);
  }

  Offset _pyramidDeckCenter(Rect rect) {
    return _pyramidLayout(rect).deckRect.center;
  }

  Offset _tieDeckCenter(Rect rect) {
    return Offset(rect.center.dx, rect.top + 108);
  }

  Offset _busDeckCenter(Rect rect) {
    return Offset(rect.center.dx, rect.top + 96);
  }

  List<Rect> _pyramidSlotRects(Rect rect) {
    return _pyramidLayout(rect).slotRects;
  }

  _PyramidLayout _pyramidLayout(Rect rect) {
    const List<List<int>> rows = <List<int>>[
      <int>[14],
      <int>[12, 13],
      <int>[9, 10, 11],
      <int>[5, 6, 7, 8],
      <int>[0, 1, 2, 3, 4],
    ];
    final Rect deckRect = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + 96),
      width: _CardMetrics.medium.width,
      height: _CardMetrics.medium.height,
    );
    final double hintWidth = math.min(rect.width - 32, 316);
    final Rect hintRect = Rect.fromCenter(
      center: Offset(rect.center.dx, deckRect.bottom + 23),
      width: hintWidth,
      height: 36,
    );

    final List<Rect> slotRects = List<Rect>.filled(15, Rect.zero);
    const double gapX = 14;
    const double gapY = 12;
    final Size cardSize = _CardMetrics.small;
    final double totalHeight =
        rows.length * cardSize.height + (rows.length - 1) * gapY;
    final double baseRowWidth =
        rows.last.length * cardSize.width + (rows.last.length - 1) * gapX;
    final double minTop = hintRect.bottom + 14;
    final double maxTop = math.max(minTop, rect.bottom - totalHeight - 26);
    final double preferredTop = rect.center.dy - totalHeight / 2 + 24;
    final double slotTop = (preferredTop.clamp(minTop, maxTop) as num)
        .toDouble();
    double top = slotTop;

    for (final List<int> row in rows) {
      final double rowWidth =
          row.length * cardSize.width + (row.length - 1) * gapX;
      double left = rect.center.dx - rowWidth / 2;
      for (final int slotIndex in row) {
        slotRects[slotIndex] = Rect.fromLTWH(
          left,
          top,
          cardSize.width,
          cardSize.height,
        );
        left += cardSize.width + gapX;
      }
      top += cardSize.height + gapY;
    }
    final Rect boardRect = Rect.fromCenter(
      center: Offset(rect.center.dx, slotTop + totalHeight / 2),
      width: baseRowWidth + 52,
      height: totalHeight + 44,
    );

    return _PyramidLayout(
      deckRect: deckRect,
      hintRect: hintRect,
      boardRect: boardRect,
      slotRects: slotRects,
    );
  }

  _TieLayout _tieLayout(Rect rect, int total) {
    final Rect deckRect = Rect.fromCenter(
      center: _tieDeckCenter(rect),
      width: _CardMetrics.medium.width,
      height: _CardMetrics.medium.height,
    );
    final Rect instructionRect = Rect.fromCenter(
      center: Offset(rect.center.dx, deckRect.bottom + 28),
      width: math.min(rect.width - 32, 332),
      height: 40,
    );
    final List<Rect> slotRects = _tieSlotRects(
      rect,
      total,
      startY: instructionRect.bottom + 18,
    );
    return _TieLayout(
      deckRect: deckRect,
      instructionRect: instructionRect,
      slotRects: slotRects,
    );
  }

  List<Rect> _tieSlotRects(Rect rect, int total, {double? startY}) {
    final Size cardSize = _CardMetrics.medium;
    final int columns = total <= 3 ? total : (total <= 6 ? 3 : 4);
    final int rows = (total / columns).ceil();
    const double gapX = 12;
    double gapY = 30;
    final double gridWidth = columns * cardSize.width + (columns - 1) * gapX;
    double gridHeight = rows * cardSize.height + (rows - 1) * gapY;
    final double startX = rect.center.dx - gridWidth / 2;
    final double top = startY ?? (rect.center.dy - gridHeight / 2 + 54);
    final double maxHeight = rect.bottom - 22 - top;
    if (rows > 1 && gridHeight > maxHeight) {
      gapY = ((maxHeight - rows * cardSize.height) / (rows - 1)).clamp(14, 30);
      gridHeight = rows * cardSize.height + (rows - 1) * gapY;
    }
    final double adjustedTop = startY == null
        ? top
        : top + math.max(0, (maxHeight - gridHeight) / 2);

    return List<Rect>.generate(total, (int index) {
      final int row = index ~/ columns;
      final int column = index % columns;
      return Rect.fromLTWH(
        startX + column * (cardSize.width + gapX),
        adjustedTop + row * (cardSize.height + gapY),
        cardSize.width,
        cardSize.height,
      );
    });
  }

  _BusLayout _busLayout(Rect rect, {required GamePhase phase}) {
    const int columns = 5;
    const double minGap = 2;
    const double maxGap = 11;
    final double availableWidth = math.max(280, rect.width - 20);
    final double minColumnWidth = _CardMetrics.medium.width + 2;
    final double maxColumnWidth = _CardMetrics.medium.width + 18;
    double columnWidth = maxColumnWidth;
    double gap = maxGap;
    double totalWidth = columns * columnWidth + (columns - 1) * gap;

    if (totalWidth > availableWidth) {
      columnWidth = ((availableWidth - (columns - 1) * minGap) / columns).clamp(
        minColumnWidth,
        maxColumnWidth,
      );
      final double leftover = availableWidth - columns * columnWidth;
      gap = (leftover / (columns - 1)).clamp(minGap, maxGap);
      totalWidth = columns * columnWidth + (columns - 1) * gap;
    }

    final double zoneWidth = (columnWidth - 10).clamp(
      _CardMetrics.medium.width + 2,
      _CardMetrics.medium.width + 16,
    );
    final double zoneHeight = _CardMetrics.medium.height + 22;
    final double baseHeight = _CardMetrics.medium.height + 14;
    const double laneGap = 12;
    final double startX = rect.center.dx - totalWidth / 2;
    final Rect deckRect = Rect.fromCenter(
      center: _busDeckCenter(rect),
      width: _CardMetrics.medium.width,
      height: _CardMetrics.medium.height,
    );
    final Rect instructionRect = Rect.fromCenter(
      center: Offset(rect.center.dx, deckRect.bottom + 30),
      width: math.min(rect.width - 28, 340),
      height: 40,
    );
    final double minBaseTop = instructionRect.bottom + zoneHeight + laneGap + 8;
    final double bottomPad = phase == GamePhase.bussetup ? 74 : 22;
    final double maxBaseTop = math.max(
      minBaseTop,
      rect.bottom - baseHeight - zoneHeight - laneGap - bottomPad,
    );
    final double baseTop = (minBaseTop + 24).clamp(minBaseTop, maxBaseTop);

    final List<Rect> highRects = <Rect>[];
    final List<Rect> baseRects = <Rect>[];
    final List<Rect> lowRects = <Rect>[];

    for (int index = 0; index < columns; index += 1) {
      final double left = startX + index * (columnWidth + gap);
      final double zoneLeft = left + (columnWidth - zoneWidth) / 2;
      highRects.add(
        Rect.fromLTWH(
          zoneLeft,
          baseTop - zoneHeight - laneGap,
          zoneWidth,
          zoneHeight,
        ),
      );
      baseRects.add(Rect.fromLTWH(left, baseTop, columnWidth, baseHeight));
      lowRects.add(
        Rect.fromLTWH(
          zoneLeft,
          baseTop + baseHeight + laneGap,
          zoneWidth,
          zoneHeight,
        ),
      );
    }

    return _BusLayout(
      deckRect: deckRect,
      instructionRect: instructionRect,
      highRects: highRects,
      baseRects: baseRects,
      lowRects: lowRects,
      controlsTop: lowRects.first.bottom + 16,
    );
  }

  int _visibleCountForBusZone(int step, String placement) {
    return _visibleBusZoneCounts['$step-$placement'] ?? 0;
  }

  bool _sameTieDraws(List<TieBreakDraw> a, List<TieBreakDraw> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index += 1) {
      if (a[index].playerIndex != b[index].playerIndex) {
        return false;
      }
      if (!_sameCard(a[index].card, b[index].card)) {
        return false;
      }
    }
    return true;
  }

  bool _sameCard(PlayingCard a, PlayingCard b) {
    return a.rank == b.rank && a.suit == b.suit;
  }
}

class _TableShell extends StatelessWidget {
  const _TableShell({required this.rect});

  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rect.height / 2),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF63402D), Color(0xFF41281D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(rect.height / 2),
              gradient: const RadialGradient(
                colors: <Color>[Color(0xFF449370), Color(0xFF1F5D46)],
                center: Alignment(-0.1, -0.25),
                radius: 1.15,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 20,
                  top: 18,
                  width: rect.width * 0.4,
                  height: rect.height * 0.25,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: 32,
                  bottom: 30,
                  width: rect.width * 0.28,
                  height: rect.height * 0.18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: <BoxShadow>[
              BoxShadow(color: color, blurRadius: size * 0.45),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({
    required this.player,
    required this.language,
    required this.visibleCards,
    required this.dockMode,
    required this.compact,
    required this.active,
    required this.winner,
    required this.runner,
  });

  final PlayerState player;
  final AppLanguage language;
  final List<PlayingCard> visibleCards;
  final bool dockMode;
  final bool compact;
  final bool active;
  final bool winner;
  final bool runner;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = winner
        ? const Color(0xFF18A14B)
        : active
        ? const Color(0xFF1F8262)
        : runner
        ? const Color(0xFFD66F2D)
        : const Color(0x553B281E);
    final String handCountLabel = tr(
      language,
      '${player.hand.length} cards',
      '${player.hand.length} kort',
    );
    final double compactChipWidth = dockMode ? 92 : 102;
    final double compactHandWidth = dockMode ? 84 : 96;
    final double compactHandCanvasWidth = dockMode ? 76 : 88;
    final double compactHandHeight = visibleCards.isEmpty
        ? (dockMode ? 30 : 34)
        : (dockMode ? 52 : 58);
    final double compactNameSize = dockMode ? 11 : 12;
    final double compactCountSize = dockMode ? 9 : 10;

    if (compact) {
      return AnimatedScale(
        scale: active ? 1.04 : 1,
        duration: const Duration(milliseconds: 240),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: compactChipWidth,
              padding: EdgeInsets.symmetric(
                horizontal: dockMode ? 8 : 10,
                vertical: dockMode ? 7 : 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: active ? 1.8 : 1.1,
                ),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xF8F4EBDD), Color(0xF0E6D8C2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: active
                        ? const Color(0x441F8262)
                        : const Color(0x18000000),
                    blurRadius: active ? 18 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compactNameSize,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4A2D20),
                    ),
                  ),
                  SizedBox(height: dockMode ? 1.5 : 2),
                  Text(
                    handCountLabel,
                    style: TextStyle(
                      fontSize: compactCountSize,
                      color: const Color(0xFF6B5445),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: compactHandWidth,
              height: compactHandHeight,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: active
                      ? Colors.white.withValues(alpha: 0.44)
                      : Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: visibleCards.isEmpty
                  ? Center(
                      child: Text(
                        tr(language, 'No cards', 'Ingen kort'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF1E7D8),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: compactHandCanvasWidth,
                      height: dockMode ? 42 : 48,
                      child: _OverlappedHand(
                        cards: visibleCards,
                        size: _CardVisualSize.small,
                        canvasWidth: compactHandCanvasWidth,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return AnimatedScale(
      scale: active ? 1.04 : 1,
      duration: const Duration(milliseconds: 240),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: 142,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: active ? 1.8 : 1.1),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFF4E8D8), Color(0xFFEBDCC8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: active ? const Color(0x441F8262) : const Color(0x22000000),
              blurRadius: active ? 20 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4A2D20),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              handCountLabel,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B5445)),
            ),
            const SizedBox(height: 8),
            if (visibleCards.isEmpty)
              Text(
                tr(language, 'No cards', 'Ingen kort'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF806A5A)),
              )
            else
              SizedBox(
                width: 130,
                height: 84,
                child: _OverlappedHand(
                  cards: visibleCards,
                  size: _CardVisualSize.medium,
                  canvasWidth: 130,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverlappedHand extends StatelessWidget {
  const _OverlappedHand({
    required this.cards,
    required this.size,
    required this.canvasWidth,
  });

  final List<PlayingCard> cards;
  final _CardVisualSize size;
  final double canvasWidth;

  @override
  Widget build(BuildContext context) {
    final Size metrics = switch (size) {
      _CardVisualSize.extraSmall => _CardMetrics.extraSmall,
      _CardVisualSize.small => _CardMetrics.small,
      _CardVisualSize.medium => _CardMetrics.medium,
    };
    final double overlap = switch (size) {
      _CardVisualSize.extraSmall => 11,
      _CardVisualSize.small => 14,
      _CardVisualSize.medium => 18,
    };
    final int count = cards.length.clamp(0, 5);
    final List<PlayingCard> display = cards.take(count).toList();
    final double totalWidth =
        metrics.width + (display.length - 1).clamp(0, 10) * overlap;
    final double leftStart = math.max(0, (canvasWidth - totalWidth) / 2);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        for (int index = 0; index < display.length; index += 1)
          Positioned(
            left: leftStart + index * overlap,
            child: Transform.rotate(
              angle: (index - (display.length - 1) / 2) * 0.05,
              child: _PlayingCardView(
                card: display[index],
                faceUp: true,
                size: size,
              ),
            ),
          ),
      ],
    );
  }
}

class _DeckStack extends StatelessWidget {
  const _DeckStack({
    required this.label,
    required this.deckCount,
    required this.ready,
  });

  final String label;
  final int deckCount;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      minWidth: 0,
      maxWidth: _CardMetrics.medium.width + 12,
      minHeight: 0,
      maxHeight: _CardMetrics.medium.height + 40,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Transform.translate(
                offset: const Offset(-4, 4),
                child: const _PlayingCardView(
                  faceUp: false,
                  size: _CardVisualSize.medium,
                ),
              ),
              Transform.translate(
                offset: const Offset(2, -2),
                child: const _PlayingCardView(
                  faceUp: false,
                  size: _CardVisualSize.medium,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: ready
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x55FFE69F),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: const _PlayingCardView(
                  faceUp: false,
                  size: _CardVisualSize.medium,
                ),
              ),
              SizedBox(
                width: _CardMetrics.medium.width,
                height: _CardMetrics.medium.height,
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFF7F4FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$deckCount',
            style: const TextStyle(
              color: Color(0xFFF8F2E9),
              fontWeight: FontWeight.w800,
              shadows: <Shadow>[
                Shadow(color: Color(0x66000000), blurRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PyramidSlotCard extends StatelessWidget {
  const _PyramidSlotCard({
    required this.card,
    required this.faceUp,
    required this.active,
    required this.onTap,
  });

  final PlayingCard? card;
  final bool faceUp;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(
      _CardMetrics.small.width * 0.18,
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: active
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x77FFE4A7),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: _PlayingCardView(
          card: faceUp ? card : null,
          faceUp: faceUp,
          size: _CardVisualSize.small,
        ),
      ),
    );
  }
}

class _PyramidRevealTarget extends StatelessWidget {
  const _PyramidRevealTarget();

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(
      _CardMetrics.small.width * 0.18,
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: const Color(0xAAFFE4A7), width: 1.6),
        gradient: const LinearGradient(
          colors: <Color>[Color(0x44FFE4A7), Color(0x16FFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x66FFE4A7), blurRadius: 14, spreadRadius: 1),
        ],
      ),
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(
            color: Color(0xFFF7F1E2),
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}

class _WarmupActionCard extends StatelessWidget {
  const _WarmupActionCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFF8D89A), Color(0xFFE4B466)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xB0684328)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF422214),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusZone extends StatelessWidget {
  const _BusZone({
    required this.label,
    required this.active,
    required this.tone,
    required this.child,
    required this.onTap,
  });

  final String label;
  final bool active;
  final BannerTone? tone;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!active && tone == null) {
      return IgnorePointer(child: Center(child: child));
    }

    final Color background = switch (tone) {
      BannerTone.success => const Color(0x4425A363),
      BannerTone.fail => const Color(0x48B93838),
      _ => active ? const Color(0x20FFF4D0) : const Color(0x12FFFFFF),
    };
    final Color border = switch (tone) {
      BannerTone.success => const Color(0xAA23945B),
      BannerTone.fail => const Color(0xAAB93838),
      _ => active ? const Color(0xCCFFE4A7) : const Color(0x52FFFFFF),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: <Color>[background, background.withValues(alpha: 0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: border, width: active ? 1.4 : 1),
              boxShadow: active
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x32FFE69F),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(4, label.isEmpty ? 4 : 16, 4, 4),
                  child: Center(child: child),
                ),
                if (label.isNotEmpty)
                  Positioned(
                    top: 5,
                    left: 0,
                    right: 0,
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF8F2E9),
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusBase extends StatelessWidget {
  const _BusBase({
    required this.active,
    required this.tone,
    required this.child,
    required this.sameButtonLabel,
    required this.sameCount,
    required this.onSame,
  });

  final bool active;
  final BannerTone? tone;
  final Widget child;
  final String? sameButtonLabel;
  final int sameCount;
  final VoidCallback? onSame;

  @override
  Widget build(BuildContext context) {
    if (!active && tone == null && sameButtonLabel == null) {
      return IgnorePointer(child: Center(child: child));
    }

    final Color border = active
        ? const Color(0x99FFE4A7)
        : tone == BannerTone.success
        ? const Color(0xAA23945B)
        : tone == BannerTone.fail
        ? const Color(0xAAB93838)
        : const Color(0x26FFFFFF);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: active ? 1.6 : 1.1),
        gradient: LinearGradient(
          colors: <Color>[
            active ? const Color(0x1FFFF4D0) : const Color(0x10FFFFFF),
            const Color(0x0FFFFFFF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: active
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x2EFFE69F),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          ),
          Center(child: child),
          if (sameCount > 0)
            Positioned(
              left: sameButtonLabel == null ? 10 : 16,
              top: sameButtonLabel == null ? 6 : 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xA01D3B2F),
                  border: Border.all(color: const Color(0x66FFE4A7)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Text(
                    '$sameCount',
                    style: const TextStyle(
                      color: Color(0xFFF8F2E9),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          if (sameButtonLabel != null)
            Positioned(
              left: 16,
              top: -4,
              child: FilledButton.tonal(
                onPressed: onSame,
                style: FilledButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  sameButtonLabel!,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StackPile extends StatelessWidget {
  const _StackPile({required this.cards, required this.size});

  final List<PlayingCard> cards;
  final _CardVisualSize size;

  @override
  Widget build(BuildContext context) {
    final List<PlayingCard> visible = cards.length <= 4
        ? cards
        : cards.sublist(cards.length - 4);
    final Size metrics = switch (size) {
      _CardVisualSize.extraSmall => _CardMetrics.extraSmall,
      _CardVisualSize.small => _CardMetrics.small,
      _CardVisualSize.medium => _CardMetrics.medium,
    };
    final double offsetX = math.max(2, metrics.width * 0.08);
    final double offsetY = size == _CardVisualSize.medium
        ? math.max(9, metrics.height * 0.2)
        : math.max(4, metrics.height * 0.12);
    final double width =
        metrics.width + (visible.length - 1).clamp(0, 8) * offsetX;
    final double height =
        metrics.height + (visible.length - 1).clamp(0, 8) * offsetY;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int index = 0; index < visible.length; index += 1)
            Positioned(
              left: index * offsetX,
              top: index * offsetY,
              child: Transform.rotate(
                angle: (index - visible.length / 2) * 0.03,
                child: _PlayingCardView(
                  card: visible[index],
                  faceUp: true,
                  size: size,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayingCardView extends StatelessWidget {
  const _PlayingCardView({this.card, required this.faceUp, required this.size});

  final PlayingCard? card;
  final bool faceUp;
  final _CardVisualSize size;

  @override
  Widget build(BuildContext context) {
    final Size metrics = switch (size) {
      _CardVisualSize.extraSmall => _CardMetrics.extraSmall,
      _CardVisualSize.small => _CardMetrics.small,
      _CardVisualSize.medium => _CardMetrics.medium,
    };
    final double radius = metrics.width * 0.18;

    return SizedBox(
      width: metrics.width,
      height: metrics.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: faceUp ? const Color(0xFFFFFCF7) : const Color(0xFF163E5A),
          border: Border.all(
            color: faceUp ? const Color(0xFFCEBCA8) : const Color(0xFFB8CBE0),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
          gradient: faceUp
              ? const LinearGradient(
                  colors: <Color>[Color(0xFFFFFEFB), Color(0xFFF5EFE5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: <Color>[Color(0xFF214B4A), Color(0xFF132B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: faceUp && card != null
              ? _CardFace(card: card!, size: size)
              : _CardBack(size: size, borderRadius: radius),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.size});

  final PlayingCard card;
  final _CardVisualSize size;

  @override
  Widget build(BuildContext context) {
    final bool red = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final Color ink = red ? const Color(0xFFBE3030) : const Color(0xFF232323);
    final double cornerFont = switch (size) {
      _CardVisualSize.extraSmall => 7,
      _CardVisualSize.small => 10,
      _CardVisualSize.medium => 12,
    };
    final double centerFont = switch (size) {
      _CardVisualSize.extraSmall => 12,
      _CardVisualSize.small => 18,
      _CardVisualSize.medium => 24,
    };

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: _CornerMark(
              label: card.rankLabel,
              suit: _suitGlyphForDisplay(card.suit),
              color: ink,
              fontSize: cornerFont,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              _suitGlyphForDisplay(card.suit),
              style: TextStyle(
                color: ink,
                fontSize: centerFont,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: RotatedBox(
              quarterTurns: 2,
              child: _CornerMark(
                label: card.rankLabel,
                suit: _suitGlyphForDisplay(card.suit),
                color: ink,
                fontSize: cornerFont,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _suitGlyphForDisplay(Suit suit) {
    switch (suit) {
      case Suit.clubs:
        return '\u2663';
      case Suit.diamonds:
        return '\u2666';
      case Suit.hearts:
        return '\u2665';
      case Suit.spades:
        return '\u2660';
    }
  }

  // ignore: unused_element
  static String _suitGlyph(Suit suit) {
    switch (suit) {
      case Suit.clubs:
        return '♣';
      case Suit.diamonds:
        return '♦';
      case Suit.hearts:
        return '♥';
      case Suit.spades:
        return '♠';
    }
  }
}

class _CornerMark extends StatelessWidget {
  const _CornerMark({
    required this.label,
    required this.suit,
    required this.color,
    required this.fontSize,
  });

  final String label;
  final String suit;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            height: 1,
          ),
        ),
        Text(
          suit,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.size, required this.borderRadius});

  final _CardVisualSize size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final double inset = switch (size) {
      _CardVisualSize.extraSmall => 3,
      _CardVisualSize.small => 4,
      _CardVisualSize.medium => 5,
    };
    final double iconSize = switch (size) {
      _CardVisualSize.extraSmall => 11,
      _CardVisualSize.small => 16,
      _CardVisualSize.medium => 22,
    };

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF224F4E), Color(0xFF17313F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.06),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          left: inset,
          right: inset,
          top: inset,
          bottom: inset,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
              borderRadius: BorderRadius.circular(
                math.max(2, borderRadius - 1.4),
              ),
            ),
          ),
        ),
        Positioned(
          left: inset + 4,
          right: inset + 4,
          top: inset + 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0x33FFE08F),
            ),
            child: const SizedBox(height: 3),
          ),
        ),
        Positioned(
          left: inset + 8,
          right: inset + 8,
          bottom: inset + 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.18),
            ),
            child: const SizedBox(height: 2),
          ),
        ),
        Center(
          child: Transform.translate(
            offset: Offset(0, size == _CardVisualSize.extraSmall ? 0 : -1),
            child: RotatedBox(
              quarterTurns: 1,
              child: Icon(
                Icons.directions_bus_filled_rounded,
                color: const Color(0xFFFFD155),
                size: iconSize,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _CardVisualSize { extraSmall, small, medium }

class _CardMetrics {
  static const Size extraSmall = Size(24, 34);
  static const Size small = Size(42, 60);
  static const Size medium = Size(56, 80);
}

class _FlightCard {
  const _FlightCard({
    required this.id,
    required this.card,
    required this.faceUp,
    required this.from,
    required this.to,
    required this.size,
    required this.duration,
    required this.rotation,
  });

  final int id;
  final PlayingCard? card;
  final bool faceUp;
  final Offset from;
  final Offset to;
  final _CardVisualSize size;
  final Duration duration;
  final double rotation;

  Size get metrics {
    switch (size) {
      case _CardVisualSize.extraSmall:
        return _CardMetrics.extraSmall;
      case _CardVisualSize.small:
        return _CardMetrics.small;
      case _CardVisualSize.medium:
        return _CardMetrics.medium;
    }
  }
}

class _PyramidLayout {
  const _PyramidLayout({
    required this.deckRect,
    required this.hintRect,
    required this.boardRect,
    required this.slotRects,
  });

  final Rect deckRect;
  final Rect hintRect;
  final Rect boardRect;
  final List<Rect> slotRects;
}

class _TieLayout {
  const _TieLayout({
    required this.deckRect,
    required this.instructionRect,
    required this.slotRects,
  });

  final Rect deckRect;
  final Rect instructionRect;
  final List<Rect> slotRects;
}

class _BusLayout {
  const _BusLayout({
    required this.deckRect,
    required this.instructionRect,
    required this.highRects,
    required this.baseRects,
    required this.lowRects,
    required this.controlsTop,
  });

  final Rect deckRect;
  final Rect instructionRect;
  final List<Rect> highRects;
  final List<Rect> baseRects;
  final List<Rect> lowRects;
  final double controlsTop;
}
