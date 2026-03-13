import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/presentation/game_table_view.dart';
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
  _AppMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final GameState state = widget.controller.state;
        if (_selectedMode == _AppMode.hosted &&
            state.phase != GamePhase.setup) {
          _selectedMode = _AppMode.local;
        }
        if (_selectedMode == null && state.phase != GamePhase.setup) {
          _selectedMode = _AppMode.local;
        }

        if (_selectedMode != _AppMode.hosted) {
          _maybeShowTransient(state);
        }

        return MaterialApp(
          title: 'Bussruta',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF9A4726),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF3EBDD),
          ),
          home: _buildHome(state),
        );
      },
    );
  }

  Widget _buildHome(GameState state) {
    final _AppMode? selectedMode = _selectedMode;
    if (selectedMode == null && state.phase == GamePhase.setup) {
      return _StartModeScreen(
        language: state.language,
        onSelectLocal: () {
          setState(() {
            _selectedMode = _AppMode.local;
          });
        },
        onSelectHosted: () {
          setState(() {
            _selectedMode = _AppMode.hosted;
          });
        },
      );
    }

    if (selectedMode == _AppMode.hosted && state.phase == GamePhase.setup) {
      return _HostedEntryScreen(
        language: state.language,
        onBack: () {
          setState(() {
            _selectedMode = null;
          });
        },
      );
    }

    if (state.phase == GamePhase.setup) {
      return _SetupScreen(
        controller: widget.controller,
        onBackToModeChooser: () {
          setState(() {
            _selectedMode = null;
          });
        },
      );
    }

    return _GameScreen(controller: widget.controller);
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
  const _SetupScreen({required this.controller, this.onBackToModeChooser});

  final GameController controller;
  final VoidCallback? onBackToModeChooser;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final AppLanguage lang = state.language;
    final SetupDraft draft = state.setupDraft;
    final List<String> names = draft.names;

    return Scaffold(
      appBar: AppBar(
        leading: onBackToModeChooser == null
            ? null
            : IconButton(
                onPressed: onBackToModeChooser,
                icon: const Icon(Icons.arrow_back),
              ),
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
                      segments: const <ButtonSegment<AppLanguage>>[
                        ButtonSegment<AppLanguage>(
                          value: AppLanguage.en,
                          label: Text('EN'),
                        ),
                        ButtonSegment<AppLanguage>(
                          value: AppLanguage.no,
                          label: Text('NO'),
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
                                onChanged: (String value) {
                                  controller.setPlayerName(i, value);
                                },
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
        title: const Text('Bussruta'),
        actions: <Widget>[
          PopupMenuButton<_GameMenuAction>(
            tooltip: tr(lang, 'More', 'Mer'),
            onSelected: (_GameMenuAction action) {
              switch (action) {
                case _GameMenuAction.autoPlay:
                  _showAutoPlaySheet(context, controller);
                  break;
                case _GameMenuAction.log:
                  _showLogSheet(context, state);
                  break;
                case _GameMenuAction.newGame:
                  controller.resetToSetup();
                  break;
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_GameMenuAction>>[
                  PopupMenuItem<_GameMenuAction>(
                    value: _GameMenuAction.autoPlay,
                    child: Text(tr(lang, 'Auto play', 'Autospill')),
                  ),
                  PopupMenuItem<_GameMenuAction>(
                    value: _GameMenuAction.log,
                    child: Text(tr(lang, 'Game log', 'Spilllogg')),
                  ),
                  PopupMenuItem<_GameMenuAction>(
                    value: _GameMenuAction.newGame,
                    child: Text(tr(lang, 'New game', 'Nytt spill')),
                  ),
                ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _StatusStrip(controller: controller),
            ),
            if (state.banner.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _BannerCard(state: state),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GameTableView(controller: controller, state: state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogSheet(BuildContext context, GameState state) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        final AppLanguage lang = state.language;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tr(lang, 'Game log', 'Spilllogg'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: state.log.isEmpty
                    ? Center(
                        child: Text(
                          tr(lang, 'No events yet.', 'Ingen hendelser ennå.'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.log.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(state.log[index]),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAutoPlaySheet(
    BuildContext context,
    GameController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, _) {
            final GameState state = controller.state;
            final AppLanguage lang = state.language;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tr(lang, 'Auto play', 'Autospill'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: state.autoPlay.enabled,
                    onChanged: controller.toggleAutoPlay,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tr(lang, 'Enable auto play', 'Aktiver autospill'),
                    ),
                  ),
                  Text(
                    tr(
                      lang,
                      'Delay: ${(state.autoPlay.delayMs / 1000).toStringAsFixed(1)}s',
                      'Forsinkelse: ${(state.autoPlay.delayMs / 1000).toStringAsFixed(1)}s',
                    ),
                  ),
                  Slider(
                    min: 350,
                    max: 60000,
                    divisions: 40,
                    value: state.autoPlay.delayMs.toDouble(),
                    onChanged: (double value) {
                      controller.setAutoPlayDelayMs(value.round());
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final AppLanguage lang = state.language;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Chip(
            avatar: const Icon(Icons.style, size: 18),
            label: Text(phaseLabel(lang, state.phase, state.warmupRound)),
          ),
          Chip(
            avatar: const Icon(Icons.layers, size: 18),
            label: Text(
              tr(
                lang,
                'Deck ${_deckCount(state)}',
                'Stokk ${_deckCount(state)}',
              ),
            ),
          ),
          if (_focusLabel(state, lang) case final String focus)
            Chip(
              avatar: const Icon(Icons.person, size: 18),
              label: Text(focus),
            ),
        ],
      ),
    );
  }

  static int _deckCount(GameState state) {
    switch (state.phase) {
      case GamePhase.setup:
        return 52;
      case GamePhase.tiebreak:
        return state.tieBreak?.deck.length ?? 0;
      case GamePhase.bussetup:
      case GamePhase.bus:
      case GamePhase.finished:
        return state.busRoute?.deck.length ?? 0;
      case GamePhase.warmup:
      case GamePhase.pyramid:
        return state.deck.length;
    }
  }

  static String? _focusLabel(GameState state, AppLanguage lang) {
    if (state.phase == GamePhase.warmup) {
      return tr(
        lang,
        'Turn: ${state.players[state.currentPlayerIndex].name}',
        'Tur: ${state.players[state.currentPlayerIndex].name}',
      );
    }
    if ((state.phase == GamePhase.bussetup ||
            state.phase == GamePhase.bus ||
            state.phase == GamePhase.finished) &&
        state.busRunnerIndex != null) {
      return tr(
        lang,
        'Runner: ${state.players[state.busRunnerIndex!].name}',
        'Kjorer: ${state.players[state.busRunnerIndex!].name}',
      );
    }
    if (state.phase == GamePhase.tiebreak && state.tieBreak != null) {
      return tr(
        lang,
        'Contenders: ${state.tieBreak!.contenders.length}',
        'Deltakere: ${state.tieBreak!.contenders.length}',
      );
    }
    return null;
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final Color tone = switch (state.bannerTone) {
      BannerTone.info => Theme.of(context).colorScheme.primary,
      BannerTone.success => const Color(0xFF18824A),
      BannerTone.fail => const Color(0xFFB93838),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.55)),
      ),
      child: Text(state.banner),
    );
  }
}

enum _GameMenuAction { autoPlay, log, newGame }

enum _AppMode { local, hosted }

class _StartModeScreen extends StatelessWidget {
  const _StartModeScreen({
    required this.language,
    required this.onSelectLocal,
    required this.onSelectHosted,
  });

  final AppLanguage language;
  final VoidCallback onSelectLocal;
  final VoidCallback onSelectHosted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bussruta')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    tr(language, 'Choose game mode', 'Velg spillmodus'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onSelectLocal,
                    icon: const Icon(Icons.table_restaurant),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    label: Text(tr(language, 'Local', 'Lokal')),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onSelectHosted,
                    icon: const Icon(Icons.hub),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    label: Text(tr(language, 'Hosted', 'Hostet')),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      language,
                      'Local: everyone plays on one device. Hosted: one player per device.',
                      'Lokal: alle spiller pa en enhet. Hostet: en spiller per enhet.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HostedEntryScreen extends StatelessWidget {
  const _HostedEntryScreen({required this.language, required this.onBack});

  final AppLanguage language;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(tr(language, 'Hosted setup', 'Hostet oppsett')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr(
              language,
              'Hosted mode foundation is being added in this implementation.',
              'Hostet modus bygges ut i denne implementasjonen.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
