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
  final Map<String, int> _visibleBusZoneCounts = <String, int>{};
  final List<_FlightCard> _flights = <_FlightCard>[];

  Size _stageSize = Size.zero;
  int _visibleRouteCards = 0;
  int _flightSeed = 0;

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
        final Rect tableRect = _tableRect(_stageSize);
        final GameState state = widget.state;

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
                  final Offset position = _seatCenter(
                    index: index,
                    total: state.players.length,
                    phase: state.phase,
                    rect: tableRect,
                  );
                  return Positioned(
                    left: position.dx,
                    top: position.dy,
                    child: Transform.translate(
                      offset: const Offset(-48, -26),
                      child: _SeatChip(
                        player: state.players[index],
                        language: state.language,
                        visibleCards: state.players[index].hand
                            .take(_visibleHandCounts[index] ?? 0)
                            .toList(),
                        compact:
                            state.phase == GamePhase.pyramid ||
                            state.players.length >= 6,
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
    final PlayerState player = state.players[state.currentPlayerIndex];
    final List<WarmupGuess> options = _warmupOptions(state.warmupRound);
    final Offset deckCenter = _warmupDeckCenter(tableRect);

    return Positioned(
      left: tableRect.center.dx - math.min(tableRect.width * 0.44, 176),
      top: deckCenter.dy - 72,
      width: math.min(tableRect.width * 0.88, 352),
      child: Column(
        children: <Widget>[
          Text(
            tr(lang, 'Active: ${player.name}', 'Aktiv: ${player.name}'),
            style: const TextStyle(
              color: Color(0xFFF8F2E9),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              shadows: <Shadow>[
                Shadow(color: Color(0x66000000), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DeckStack(
            label: tr(lang, 'DEAL', 'TREKK'),
            deckCount: state.deck.length,
            ready: true,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: options.map((WarmupGuess guess) {
              return FilledButton.tonal(
                onPressed: () async {
                  await HapticFeedback.selectionClick();
                  widget.controller.playWarmupGuess(guess);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4D2C1),
                  foregroundColor: const Color(0xFF53311E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                child: Text(warmupGuessLabel(lang, guess)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPyramidOverlay(Rect tableRect) {
    final GameState state = widget.state;
    final AppLanguage lang = state.language;
    final List<Rect> slotRects = _pyramidSlotRects(tableRect);
    final int nextSlot = state.pyramidRevealIndex >= 15
        ? -1
        : (state.reversePyramid
              ? 14 - state.pyramidRevealIndex.clamp(0, 14)
              : state.pyramidRevealIndex.clamp(0, 14));
    final Rect deckRect = Rect.fromCenter(
      center: _pyramidDeckCenter(tableRect),
      width: _CardMetrics.small.width,
      height: _CardMetrics.small.height,
    );

    return Stack(
      children: <Widget>[
        Positioned.fromRect(
          rect: deckRect,
          child: _DeckStack(
            label: tr(lang, 'PYR', 'PYR'),
            deckCount: state.deck.length,
            ready: false,
          ),
        ),
        Positioned(
          left: tableRect.left + 20,
          top: deckRect.bottom + 12,
          child: Text(
            tr(
              lang,
              'Tap the glowing next card',
              'Trykk pa det glodende kortet',
            ),
            style: const TextStyle(
              color: Color(0xFFF7EDDF),
              fontWeight: FontWeight.w700,
              shadows: <Shadow>[
                Shadow(color: Color(0x66000000), blurRadius: 6),
              ],
            ),
          ),
        ),
        for (int index = 0; index < slotRects.length; index += 1)
          Positioned.fromRect(
            rect: slotRects[index],
            child: _PyramidSlotCard(
              card: state.pyramidCards[index],
              faceUp: _revealedPyramidSlots.contains(index),
              active: index == nextSlot,
              onTap: index == nextSlot
                  ? () async {
                      await HapticFeedback.selectionClick();
                      widget.controller.revealPyramidNext();
                    }
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildTieBreakOverlay(Rect tableRect) {
    final GameState state = widget.state;
    final AppLanguage lang = state.language;
    final TieBreakState tie = state.tieBreak!;
    final Rect deckRect = Rect.fromCenter(
      center: _tieDeckCenter(tableRect),
      width: _CardMetrics.medium.width,
      height: _CardMetrics.medium.height,
    );
    final List<Rect> slotRects = _tieSlotRects(
      tableRect,
      tie.contenders.length,
    );

    return Stack(
      children: <Widget>[
        Positioned.fromRect(
          rect: deckRect,
          child: GestureDetector(
            onTap: () async {
              await HapticFeedback.selectionClick();
              widget.controller.runTieBreakRound();
            },
            child: _DeckStack(
              label: tr(lang, 'TIE', 'TIE'),
              deckCount: tie.deck.length,
              ready: true,
            ),
          ),
        ),
        Positioned(
          left: tableRect.center.dx - 110,
          top: deckRect.bottom + 10,
          width: 220,
          child: Text(
            tr(lang, 'Draw highest card', 'Trekk hoyeste kort'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF8F2E9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (int index = 0; index < tie.contenders.length; index += 1)
          ..._buildTieContenderWidgets(
            rect: slotRects[index],
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
    final bool showCard =
        _visibleTieSlots.contains(playerIndex) && draw != null;

    return <Widget>[
      Positioned(
        left: rect.left - 10,
        top: rect.top - 28,
        width: rect.width + 20,
        child: Text(
          state.players[playerIndex].name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF8F2E9),
            fontWeight: FontWeight.w700,
            shadows: <Shadow>[Shadow(color: Color(0x66000000), blurRadius: 6)],
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
            child: _PlayingCardView(
              card: showCard ? draw.card : null,
              faceUp: showCard,
              size: _CardVisualSize.medium,
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
    final _BusLayout layout = _busLayout(tableRect);
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
          Positioned(
            left: tableRect.center.dx - 120,
            top: layout.deckRect.bottom + 8,
            width: 240,
            child: Text(
              state.phase == GamePhase.bussetup
                  ? tr(
                      lang,
                      'Choose which side to start from',
                      'Velg hvilken side ruten starter fra',
                    )
                  : tr(
                      lang,
                      'Tap above, below, or same on the active stop',
                      'Trykk over, under eller samme pa aktivt stopp',
                    ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF8F2E9),
                fontWeight: FontWeight.w700,
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
          Positioned(
            left: tableRect.center.dx - 150,
            top: layout.controlsTop,
            width: 300,
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

    widgets.add(
      Positioned.fromRect(
        rect: layout.highRects[step],
        child: _BusZone(
          label: active ? tr(lang, 'Above', 'Over') : '',
          active: active,
          tone: tone.high,
          onTap: active
              ? () async {
                  await HapticFeedback.selectionClick();
                  widget.controller.playBusGuess(BusGuess.above);
                }
              : null,
          child: _StackPile(
            cards: lane.high
                .take(_visibleCountForBusZone(step, 'high'))
                .toList(),
            size: _CardVisualSize.extraSmall,
          ),
        ),
      ),
    );

    widgets.add(
      Positioned.fromRect(
        rect: layout.baseRects[step],
        child: _BusBase(
          active: active,
          tone: tone.same,
          sameButtonLabel: active ? tr(lang, 'Same', 'Samme') : null,
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
              _PlayingCardView(
                card: step < visibleRouteCount ? bus.routeCards[step] : null,
                faceUp: step < visibleRouteCount,
                size: _CardVisualSize.medium,
              ),
              Positioned(
                right: 8,
                bottom: 6,
                child: _StackPile(
                  cards: lane.same
                      .take(_visibleCountForBusZone(step, 'same'))
                      .toList(),
                  size: _CardVisualSize.extraSmall,
                  samePile: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    widgets.add(
      Positioned.fromRect(
        rect: layout.lowRects[step],
        child: _BusZone(
          label: active ? tr(lang, 'Below', 'Under') : '',
          active: active,
          tone: tone.low,
          onTap: active
              ? () async {
                  await HapticFeedback.selectionClick();
                  widget.controller.playBusGuess(BusGuess.below);
                }
              : null,
          child: _StackPile(
            cards: lane.low.take(_visibleCountForBusZone(step, 'low')).toList(),
            size: _CardVisualSize.extraSmall,
          ),
        ),
      ),
    );

    return widgets;
  }

  Widget _buildCelebration(Rect tableRect) {
    final AppLanguage lang = widget.state.language;
    return Positioned(
      left: tableRect.center.dx - 150,
      top: tableRect.top + 34,
      width: 300,
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
    final Rect tableRect = _tableRect(_stageSize);
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
    final Rect tableRect = _tableRect(_stageSize);
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
      return;
    }

    final TieBreakState? previousTie = previous.tieBreak;
    final TieBreakState nextTie = next.tieBreak!;
    if (previousTie != null &&
        previousTie.round == nextTie.round &&
        _sameTieDraws(previousTie.lastDraws, nextTie.lastDraws)) {
      return;
    }

    final Rect tableRect = _tableRect(_stageSize);
    for (int index = 0; index < nextTie.lastDraws.length; index += 1) {
      final TieBreakDraw draw = nextTie.lastDraws[index];
      _visibleTieSlots.remove(draw.playerIndex);
      _queueFlight(
        card: draw.card,
        faceUp: true,
        from: _tieDeckCenter(tableRect),
        to: _tieSlotCenter(draw.playerIndex, nextTie.contenders, tableRect),
        size: _CardVisualSize.medium,
        delay: Duration(milliseconds: 120 * index),
        onDone: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _visibleTieSlots.add(draw.playerIndex);
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
    final Rect tableRect = _tableRect(_stageSize);
    final _BusLayout layout = _busLayout(tableRect);
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

    final Rect tableRect = _tableRect(_stageSize);
    final _BusLayout layout = _busLayout(tableRect);
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
        target: layout.baseRects[step].center + const Offset(18, 20),
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
      _queueFlight(
        card: card,
        faceUp: true,
        from: _busDeckCenter(_tableRect(_stageSize)),
        to: target,
        size: _CardVisualSize.extraSmall,
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

  Rect _tableRect(Size size) {
    final double width = math.min(size.width - 12, 960);
    final double height = math.min(
      size.height - 12,
      math.max(360, size.height * 0.94),
    );
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
  }

  bool _showSeats(GamePhase phase) {
    return phase == GamePhase.warmup || phase == GamePhase.pyramid;
  }

  Offset _seatCenter({
    required int index,
    required int total,
    required GamePhase phase,
    required Rect rect,
  }) {
    if (phase == GamePhase.pyramid) {
      final int leftCount = (total / 2).ceil();
      final bool leftSide = index < leftCount;
      final int sideIndex = leftSide ? index : index - leftCount;
      final int sideTotal = leftSide ? leftCount : total - leftCount;
      final double fraction = sideTotal <= 1
          ? 0.5
          : sideIndex / (sideTotal - 1);
      final double x = leftSide ? rect.left + 68 : rect.right - 68;
      final double y = rect.top + 76 + fraction * (rect.height - 152);
      return Offset(x, y);
    }

    final double angleStep = math.pi * 2 / total;
    final double angle = -math.pi / 2 + angleStep * index;
    final double radiusX = rect.width * (total >= 7 ? 0.38 : 0.4);
    final double radiusY = rect.height * (total >= 7 ? 0.36 : 0.38);
    return Offset(
      rect.center.dx + math.cos(angle) * radiusX,
      rect.center.dy + math.sin(angle) * radiusY,
    );
  }

  Offset _seatCardTarget({
    required int index,
    required int total,
    required GamePhase phaseHint,
    required Rect rect,
  }) {
    final Offset center = _seatCenter(
      index: index,
      total: total,
      phase: phaseHint,
      rect: rect,
    );
    return center + const Offset(0, 16);
  }

  Offset _warmupDeckCenter(Rect rect) {
    return Offset(rect.center.dx, rect.center.dy - 20);
  }

  Offset _pyramidDeckCenter(Rect rect) {
    return Offset(rect.center.dx, rect.top + 96);
  }

  Offset _tieDeckCenter(Rect rect) {
    return Offset(rect.center.dx, rect.top + 112);
  }

  Offset _busDeckCenter(Rect rect) {
    return Offset(rect.center.dx, rect.top + 104);
  }

  List<Rect> _pyramidSlotRects(Rect rect) {
    const List<List<int>> rows = <List<int>>[
      <int>[14],
      <int>[12, 13],
      <int>[9, 10, 11],
      <int>[5, 6, 7, 8],
      <int>[0, 1, 2, 3, 4],
    ];
    final List<Rect> slotRects = List<Rect>.filled(15, Rect.zero);
    const double gapX = 8;
    const double gapY = 10;
    final Size cardSize = _CardMetrics.small;
    final double totalHeight =
        rows.length * cardSize.height + (rows.length - 1) * gapY;
    double top = rect.center.dy - totalHeight / 2 + 24;

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
    return slotRects;
  }

  List<Rect> _tieSlotRects(Rect rect, int total) {
    final Size cardSize = _CardMetrics.medium;
    final int columns = total <= 3 ? total : (total <= 6 ? 3 : 4);
    final int rows = (total / columns).ceil();
    const double gapX = 12;
    const double gapY = 30;
    final double gridWidth = columns * cardSize.width + (columns - 1) * gapX;
    final double gridHeight = rows * cardSize.height + (rows - 1) * gapY;
    final double startX = rect.center.dx - gridWidth / 2;
    final double startY = rect.center.dy - gridHeight / 2 + 54;

    return List<Rect>.generate(total, (int index) {
      final int row = index ~/ columns;
      final int column = index % columns;
      return Rect.fromLTWH(
        startX + column * (cardSize.width + gapX),
        startY + row * (cardSize.height + gapY),
        cardSize.width,
        cardSize.height,
      );
    });
  }

  Offset _tieSlotCenter(int playerIndex, List<int> contenders, Rect rect) {
    final int slotIndex = contenders.indexOf(playerIndex);
    return _tieSlotRects(rect, contenders.length)[slotIndex].center;
  }

  _BusLayout _busLayout(Rect rect) {
    final double stopWidth = math.min(72, (rect.width - 54) / 5);
    const double gap = 6;
    const double zoneHeight = 62;
    final double baseHeight = _CardMetrics.medium.height + 16;
    final double totalWidth = stopWidth * 5 + gap * 4;
    final double startX = rect.center.dx - totalWidth / 2;
    final double top = rect.top + 172;

    final List<Rect> highRects = <Rect>[];
    final List<Rect> baseRects = <Rect>[];
    final List<Rect> lowRects = <Rect>[];

    for (int index = 0; index < 5; index += 1) {
      final double left = startX + index * (stopWidth + gap);
      highRects.add(Rect.fromLTWH(left, top, stopWidth, zoneHeight));
      baseRects.add(
        Rect.fromLTWH(left, top + zoneHeight + 8, stopWidth, baseHeight),
      );
      lowRects.add(
        Rect.fromLTWH(
          left,
          top + zoneHeight + 8 + baseHeight + 8,
          stopWidth,
          zoneHeight,
        ),
      );
    }

    return _BusLayout(
      deckRect: Rect.fromCenter(
        center: _busDeckCenter(rect),
        width: _CardMetrics.medium.width,
        height: _CardMetrics.medium.height,
      ),
      highRects: highRects,
      baseRects: baseRects,
      lowRects: lowRects,
      controlsTop: lowRects.first.bottom + 18,
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
    required this.compact,
    required this.active,
    required this.winner,
    required this.runner,
  });

  final PlayerState player;
  final AppLanguage language;
  final List<PlayingCard> visibleCards;
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

    return AnimatedScale(
      scale: active ? 1.04 : 1,
      duration: const Duration(milliseconds: 240),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: compact ? 96 : 108,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 7 : 8,
        ),
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
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4A2D20),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tr(
                language,
                '${player.hand.length} cards',
                '${player.hand.length} kort',
              ),
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: const Color(0xFF6B5445),
              ),
            ),
            const SizedBox(height: 6),
            if (visibleCards.isEmpty)
              Text(
                tr(language, 'No cards', 'Ingen kort'),
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  color: const Color(0xFF806A5A),
                ),
              )
            else
              SizedBox(
                width: compact ? 76 : 84,
                height: compact ? 50 : 56,
                child: _OverlappedHand(
                  cards: visibleCards,
                  size: compact
                      ? _CardVisualSize.extraSmall
                      : _CardVisualSize.small,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverlappedHand extends StatelessWidget {
  const _OverlappedHand({required this.cards, required this.size});

  final List<PlayingCard> cards;
  final _CardVisualSize size;

  @override
  Widget build(BuildContext context) {
    final Size metrics = switch (size) {
      _CardVisualSize.extraSmall => _CardMetrics.extraSmall,
      _CardVisualSize.small => _CardMetrics.small,
      _CardVisualSize.medium => _CardMetrics.medium,
    };
    final double overlap = size == _CardVisualSize.small ? 14 : 10;
    final int count = cards.length.clamp(0, 4);
    final List<PlayingCard> display = cards.take(count).toList();
    final double totalWidth =
        metrics.width + (display.length - 1).clamp(0, 10) * overlap;
    final double leftStart = math.max(0, (84 - totalWidth) / 2);

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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
    final Color background = switch (tone) {
      BannerTone.success => const Color(0x3D25A363),
      BannerTone.fail => const Color(0x40B93838),
      _ => active ? const Color(0x22FFF4D0) : const Color(0x18FFFFFF),
    };
    final Color border = switch (tone) {
      BannerTone.success => const Color(0xAA23945B),
      BannerTone.fail => const Color(0xAAB93838),
      _ => active ? const Color(0xAAFFE4A7) : const Color(0x44FFFFFF),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: background,
            border: Border.all(color: border),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 4),
              if (label.isNotEmpty)
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF8F2E9),
                    letterSpacing: 0.8,
                  ),
                )
              else
                const SizedBox(height: 12),
              Expanded(child: Center(child: child)),
            ],
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
    required this.onSame,
  });

  final bool active;
  final BannerTone? tone;
  final Widget child;
  final String? sameButtonLabel;
  final VoidCallback? onSame;

  @override
  Widget build(BuildContext context) {
    final Color border = active
        ? const Color(0x99FFE4A7)
        : tone == BannerTone.success
        ? const Color(0xAA23945B)
        : tone == BannerTone.fail
        ? const Color(0xAAB93838)
        : Colors.transparent;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: active ? 1.6 : 1.1),
        color: active ? const Color(0x14FFF4D0) : Colors.transparent,
      ),
      child: Stack(
        children: <Widget>[
          Center(child: child),
          if (sameButtonLabel != null)
            Positioned(
              right: 6,
              top: 6,
              child: FilledButton.tonal(
                onPressed: onSame,
                style: FilledButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(sameButtonLabel!),
              ),
            ),
        ],
      ),
    );
  }
}

class _StackPile extends StatelessWidget {
  const _StackPile({
    required this.cards,
    required this.size,
    this.samePile = false,
  });

  final List<PlayingCard> cards;
  final _CardVisualSize size;
  final bool samePile;

  @override
  Widget build(BuildContext context) {
    final List<PlayingCard> visible = cards.length <= 4
        ? cards
        : cards.sublist(cards.length - 4);
    final double offsetX = samePile ? 6 : 8;
    final double offsetY = samePile ? 2 : 3;

    return SizedBox(
      width: samePile ? 30 : 52,
      height: samePile ? 26 : 34,
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

    return SizedBox(
      width: metrics.width,
      height: metrics.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(metrics.width * 0.18),
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
                  colors: <Color>[Color(0xFF244D70), Color(0xFF102C40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(metrics.width * 0.18),
          child: faceUp && card != null
              ? _CardFace(card: card!, size: size)
              : _CardBack(size: size),
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
              suit: _suitGlyph(card.suit),
              color: ink,
              fontSize: cornerFont,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              _suitGlyph(card.suit),
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
                suit: _suitGlyph(card.suit),
                color: ink,
                fontSize: cornerFont,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
  const _CardBack({required this.size});

  final _CardVisualSize size;

  @override
  Widget build(BuildContext context) {
    final double inset = switch (size) {
      _CardVisualSize.extraSmall => 3,
      _CardVisualSize.small => 4,
      _CardVisualSize.medium => 5,
    };

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF315E89), Color(0xFF173852)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        Center(
          child: Text(
            'B',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w900,
              fontSize: size == _CardVisualSize.extraSmall ? 12 : 18,
              letterSpacing: 1.4,
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

class _BusLayout {
  const _BusLayout({
    required this.deckRect,
    required this.highRects,
    required this.baseRects,
    required this.lowRects,
    required this.controlsTop,
  });

  final Rect deckRect;
  final List<Rect> highRects;
  final List<Rect> baseRects;
  final List<Rect> lowRects;
  final double controlsTop;
}
