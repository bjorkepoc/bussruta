import 'dart:async';

import 'package:bussruta_app/application/game_controller.dart';
import 'package:bussruta_app/application/hosted_session_controller.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/presentation/app_theme.dart';
import 'package:bussruta_app/presentation/game_table_view.dart';
import 'package:bussruta_app/presentation/help_view.dart';
import 'package:bussruta_app/presentation/hosted_session_view.dart';
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
  bool _onboardingLaunchQueued = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  late final HostedSessionController _hostedController =
      HostedSessionController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bussruta',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: AppTheme.buildTheme(),
      home: AnimatedBuilder(
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
          if (widget.controller.initialized &&
              !_onboardingLaunchQueued &&
              !widget.controller.onboardingSeen &&
              _selectedMode == null &&
              state.phase == GamePhase.setup) {
            _onboardingLaunchQueued = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(
                _openIntro(language: state.language, markSeenOnExit: true),
              );
            });
          }

          return _buildHome(state);
        },
      ),
    );
  }

  Widget _buildHome(GameState state) {
    final _AppMode? selectedMode = _selectedMode;
    if (selectedMode == null && state.phase == GamePhase.setup) {
      return _StartModeScreen(
        language: state.language,
        onLanguageSelected: widget.controller.setLanguage,
        onOpenRules: () => _openRules(language: state.language),
        onOpenIntro: () =>
            _openIntro(language: state.language, markSeenOnExit: true),
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
      return HostedSessionView(
        controller: _hostedController,
        language: state.language,
        onBackToModeChooser: () {
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

    return _GameScreen(
      controller: widget.controller,
      onOpenRules: () => _openRules(language: state.language),
      onOpenIntro: () =>
          _openIntro(language: state.language, markSeenOnExit: true),
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
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(error)),
        );
      });
    }
  }

  Future<void> _openRules({required AppLanguage language}) async {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return RulesHelpScreen(
            language: language,
            onOpenIntro: () {
              unawaited(_openIntro(language: language, markSeenOnExit: true));
            },
          );
        },
      ),
    );
  }

  Future<void> _openIntro({
    required AppLanguage language,
    required bool markSeenOnExit,
  }) async {
    if (!mounted) {
      return;
    }
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    final bool? completed = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            OnboardingIntroScreen(language: language),
      ),
    );
    if (markSeenOnExit && completed == true) {
      widget.controller.markOnboardingSeen();
    }
  }

  @override
  void dispose() {
    _hostedController.dispose();
    super.dispose();
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
    final VoidCallback? backToModeChooser = onBackToModeChooser;

    final Widget scaffold = Scaffold(
      appBar: AppBar(
        leading: backToModeChooser == null
            ? null
            : IconButton(
                tooltip: tr(lang, 'Back to mode chooser', 'Tilbake til valg'),
                onPressed: backToModeChooser,
                icon: const Icon(Icons.arrow_back),
              ),
        title: Text(tr(lang, 'Bussruta Setup', 'Bussruta Oppsett')),
        actions: <Widget>[
          _LanguageMenu(language: lang, onSelected: controller.setLanguage),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: AppSurfaceCard(
          tone: AppSurfaceTone.accent,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tr(lang, 'Ready to deal?', 'Klar til å dele ut?'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.startGameFromSetup,
                  icon: const Icon(Icons.play_arrow),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  label: Text(
                    tr(lang, 'Start game', 'Start spill'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: AppTheme.tableBackground(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AppSurfaceCard(
                tone: AppSurfaceTone.accent,
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
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        lang,
                        'Choose the table size before dealing.',
                        'Velg bordstørrelse for utdeling.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
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
              const SizedBox(height: 12),
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: draft.reversePyramid,
                      onChanged: controller.setReversePyramid,
                      title: Text(
                        tr(
                          lang,
                          'Reverse pyramid drinks (bottom = 5, top = 1)',
                          'Reverser pyramide (nederst = 5, øverst = 1)',
                        ),
                      ),
                    ),
                    const Divider(),
                    Text(
                      tr(lang, 'Player names', 'Spillernavn'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
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
                              tooltip: tr(
                                lang,
                                'Remove player ${i + 1}',
                                'Fjern spiller ${i + 1}',
                              ),
                              onPressed: () => controller.removePlayerAt(i),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
      ),
    );
    if (backToModeChooser == null) {
      return scaffold;
    }
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          backToModeChooser();
        }
      },
      child: scaffold,
    );
  }
}

class _GameScreen extends StatelessWidget {
  const _GameScreen({
    required this.controller,
    required this.onOpenRules,
    required this.onOpenIntro,
  });

  final GameController controller;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenIntro;

  @override
  Widget build(BuildContext context) {
    final GameState state = controller.state;
    final AppLanguage lang = state.language;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bussruta'),
        actions: <Widget>[
          _LanguageMenu(language: lang, onSelected: controller.setLanguage),
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
                case _GameMenuAction.rules:
                  onOpenRules();
                  break;
                case _GameMenuAction.intro:
                  onOpenIntro();
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
                    value: _GameMenuAction.rules,
                    child: Text(tr(lang, 'Rules', 'Regler')),
                  ),
                  PopupMenuItem<_GameMenuAction>(
                    value: _GameMenuAction.intro,
                    child: Text(tr(lang, 'Quick intro', 'Rask intro')),
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
      body: DecoratedBox(
        decoration: AppTheme.tableBackground(),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _StatusStrip(controller: controller),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: GameTableView(
                          controller: controller,
                          state: state,
                        ),
                      ),
                      if (state.banner.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: _BannerCard(state: state),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
          child: AppSurfaceCard(
            padding: const EdgeInsets.all(16),
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
              child: AppSurfaceCard(
                padding: const EdgeInsets.all(16),
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

    return AppSurfaceCard(
      tone: AppSurfaceTone.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            AppStatusChip(
              icon: Icons.style,
              label: phaseLabel(lang, state.phase, state.warmupRound),
            ),
            if (_focusLabel(state, lang) case final String focus)
              AppStatusChip(icon: Icons.person, label: focus),
          ],
        ),
      ),
    );
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
        'Kjører: ${state.players[state.busRunnerIndex!].name}',
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
    return AppBanner(
      message: state.banner,
      tone: switch (state.bannerTone) {
        BannerTone.info => AppBannerTone.info,
        BannerTone.success => AppBannerTone.success,
        BannerTone.fail => AppBannerTone.fail,
      },
    );
  }
}

enum _GameMenuAction { autoPlay, log, rules, intro, newGame }

enum _AppMode { local, hosted }

class _StartModeScreen extends StatelessWidget {
  const _StartModeScreen({
    required this.language,
    required this.onLanguageSelected,
    required this.onOpenRules,
    required this.onOpenIntro,
    required this.onSelectLocal,
    required this.onSelectHosted,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageSelected;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenIntro;
  final VoidCallback onSelectLocal;
  final VoidCallback onSelectHosted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(decoration: AppTheme.tableBackground()),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double topPadding = constraints.maxHeight < 680
                      ? 10
                      : 14;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, topPadding, 20, 24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Align(
                              alignment: Alignment.centerRight,
                              child: _LanguageMenu(
                                language: language,
                                onSelected: onLanguageSelected,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Icon(
                              Icons.local_bar,
                              color: AppTheme.gold,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bussruta',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.cream,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr(
                                language,
                                'The social card game. Local on one device or hosted over your network.',
                                'Det sosiale kortspillet. Lokalt på en enhet eller hostet over nettverket.',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.cream.withValues(
                                      alpha: 0.78,
                                    ),
                                    height: 1.32,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            _ModeChoiceCard(
                              icon: Icons.groups,
                              title: tr(language, 'Local', 'Lokal'),
                              description: tr(
                                language,
                                'Play together on one device.',
                                'Spill sammen på en enhet.',
                              ),
                              onTap: onSelectLocal,
                            ),
                            const SizedBox(height: 12),
                            _ModeChoiceCard(
                              icon: Icons.hub,
                              title: tr(language, 'Hosted', 'Hostet'),
                              description: tr(
                                language,
                                'Host or join a game over your network.',
                                'Host eller bli med over nettverket.',
                              ),
                              onTap: onSelectHosted,
                            ),
                            const SizedBox(height: 18),
                            AppSurfaceCard(
                              padding: const EdgeInsets.all(8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: <Widget>[
                                  OutlinedButton.icon(
                                    onPressed: onOpenRules,
                                    icon: const Icon(Icons.menu_book_outlined),
                                    label: Text(
                                      tr(
                                        language,
                                        'How to play',
                                        'Hvordan spille',
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: onOpenIntro,
                                    icon: const Icon(Icons.slideshow),
                                    label: Text(
                                      tr(language, 'Quick intro', 'Rask intro'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChoiceCard extends StatelessWidget {
  const _ModeChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AppSurfaceCard(
          tone: AppSurfaceTone.accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: <Widget>[
              Icon(icon, color: AppTheme.gold, size: 38),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.cream.withValues(alpha: 0.78),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.cream),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.language, required this.onSelected});

  final AppLanguage language;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLanguage>(
      tooltip: tr(language, 'Language', 'Språk'),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppLanguage>>[
        PopupMenuItem<AppLanguage>(
          value: AppLanguage.en,
          child: Row(
            children: <Widget>[
              Icon(
                language == AppLanguage.en ? Icons.check : Icons.language,
                size: 18,
              ),
              const SizedBox(width: 10),
              const Text('English (EN)'),
            ],
          ),
        ),
        PopupMenuItem<AppLanguage>(
          value: AppLanguage.no,
          child: Row(
            children: <Widget>[
              Icon(
                language == AppLanguage.no ? Icons.check : Icons.language,
                size: 18,
              ),
              const SizedBox(width: 10),
              const Text('Norsk (NO)'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.language),
            const SizedBox(width: 6),
            Text(
              language == AppLanguage.no ? 'NO' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
