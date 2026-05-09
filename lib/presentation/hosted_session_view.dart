import 'dart:async';
import 'dart:math' as math;

import 'package:bussruta_app/application/hosted_lan_transport.dart';
import 'package:bussruta_app/application/hosted_session_controller.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:bussruta_app/presentation/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const double _hostedCardAspect = 0.7;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _host = TextEditingController();
  Map<int, int> _draftTargets = <int, int>{};
  int? _draftSource;
  bool _emulatorCommandCopied = false;
  Timer? _copyFeedbackTimer;
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
    _copyFeedbackTimer?.cancel();
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
    final String? networkDiagnostic = widget.controller.networkDiagnostic;
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
                      if (networkDiagnostic != null &&
                          networkDiagnostic.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          collapsedIconColor: const Color(0xFF6D4F33),
                          iconColor: const Color(0xFF6D4F33),
                          title: Text(
                            tr(
                              language,
                              'Advanced diagnostics',
                              'Avanserte diagnoser',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF6D4F33),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          children: <Widget>[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SelectableText(
                                networkDiagnostic,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Color(0xFF4B3524),
                                ),
                              ),
                            ),
                          ],
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
                          'Host address (host or host:port)',
                          'Vertsadresse (host eller host:port)',
                        ),
                        border: const OutlineInputBorder(),
                        hintText: '10.0.2.2:45879',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        language,
                        'If no LAN games appear, enter the host address shown on the host device and use the same PIN.',
                        'Hvis ingen LAN-spill vises, skriv inn vertsadressen som vises pa vertsenheten og bruk samme PIN.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6D4F33),
                        fontWeight: FontWeight.w600,
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
                          'No LAN games found yet. On Android emulators, manual host address + PIN is often needed.',
                          'Ingen LAN-spill funnet ennå. Pa Android-emulatorer trengs ofte vertsadresse + PIN manuelt.',
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
    final String? hostAddress = widget.controller.hostAddress;
    final int? hostPort = widget.controller.hostPort;
    final int joinPort = hostPort ?? hostedSessionPort;
    final String emulatorForwardCommand = hostedEmulatorForwardCommand(
      joinPort,
    );
    final bool emulatorAddress = hostAddress != null
        ? hostedAddressLooksLikeEmulatorNat(hostAddress)
        : false;

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
                    if (hostAddress != null) ...<Widget>[
                      const SizedBox(height: 10),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF174A36),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x66FFD89A)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                tr(
                                  language,
                                  'Use this for emulator/manual join',
                                  'Bruk dette for emulator/manuell joining',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFFF4E8D6),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                '$hostAddress:$joinPort',
                                style: const TextStyle(
                                  color: Color(0xFFFFD06A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (emulatorAddress) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  tr(
                                    language,
                                    'Emulator fallback target (after adb forward): 10.0.2.2:$joinPort',
                                    'Emulator-fallback (etter adb forward): 10.0.2.2:$joinPort',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFF4E8D6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  emulatorForwardCommand,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD06A),
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    unawaited(
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: emulatorForwardCommand,
                                        ),
                                      ),
                                    );
                                    _markEmulatorCommandCopied();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFF4E8D6),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                  icon: Icon(
                                    _emulatorCommandCopied
                                        ? Icons.check
                                        : Icons.copy,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _emulatorCommandCopied
                                        ? tr(language, 'Copied', 'Kopiert')
                                        : tr(
                                            language,
                                            'Copy adb command',
                                            'Kopier adb-kommando',
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
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

  void _markEmulatorCommandCopied() {
    _copyFeedbackTimer?.cancel();
    setState(() {
      _emulatorCommandCopied = true;
    });
    _copyFeedbackTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _emulatorCommandCopied = false;
      });
    });
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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _surfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                _phaseChip(
                                  icon: Icons.style,
                                  label: phaseLabel(
                                    language,
                                    view.phase,
                                    view.warmupRound,
                                  ),
                                ),
                                _phaseChip(
                                  icon: Icons.person,
                                  label: _turnText(
                                    language: language,
                                    view: view,
                                    myTurn: myTurn,
                                    viewerName: projection.viewerName,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              tr(
                                language,
                                'You are ${projection.viewerName}.',
                                'Du er ${projection.viewerName}.',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF5B422D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status !=
                          HostedConnectionStatus.connected) ...<Widget>[
                        const SizedBox(height: 8),
                        _surfaceCard(
                          color: const Color(0xFFFFF3DE),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                _connectionVisual(status).icon,
                                color: _connectionVisual(status).color,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _connectionVisual(status).subtitle,
                                  style: TextStyle(
                                    color: _connectionVisual(status).color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (view.banner.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        _bannerCard(view.banner, view.bannerTone),
                      ],
                      const SizedBox(height: 10),
                      _tablePanel(
                        projection: projection,
                        connected: connected,
                        blocked: blocked,
                        myTurn: myTurn,
                      ),
                      if (projection.giveOutPromptDrinks > 0) ...<Widget>[
                        const SizedBox(height: 8),
                        _promptCard(
                          label: tr(
                            language,
                            'Give out drinks',
                            'Del ut drikker',
                          ),
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
                            style: const TextStyle(
                              color: Color(0xFF684C34),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (view.phase != GamePhase.finished) ...<Widget>[
                        const SizedBox(height: 10),
                        _ownHandPanel(projection.ownHand),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _phaseChip({required IconData icon, required String label}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2C2A8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: const Color(0xFFA45A35)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5F4229),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerCard(String message, BannerTone tone) {
    final (
      Color fill,
      Color border,
      Color text,
      IconData icon,
    ) = switch (tone) {
      BannerTone.success => (
        const Color(0xFFE0F0E0),
        const Color(0xFF2F9A57),
        const Color(0xFF20663B),
        Icons.check_circle_outline,
      ),
      BannerTone.fail => (
        const Color(0xFFF6E4DE),
        const Color(0xFFD26D5F),
        const Color(0xFF8F3A2F),
        Icons.error_outline,
      ),
      _ => (
        const Color(0xFFF5ECDC),
        const Color(0xFFD3B18A),
        const Color(0xFF6A4D2F),
        Icons.info_outline,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: text),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: text, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tablePanel({
    required HostedProjectedView projection,
    required bool connected,
    required bool blocked,
    required bool myTurn,
  }) {
    final HostedPublicView view = projection.publicView;
    final bool hostCanReveal =
        projection.canUseHostTools && !blocked && connected;
    final String sectionTitle = switch (view.phase) {
      GamePhase.warmup => tr(widget.language, 'Public table', 'Offentlig bord'),
      GamePhase.pyramid => tr(widget.language, 'Pyramid table', 'Pyramidebord'),
      GamePhase.tiebreak => tr(
        widget.language,
        'Tie-break table',
        'Tie-break-bord',
      ),
      GamePhase.bussetup ||
      GamePhase.bus ||
      GamePhase.finished => tr(widget.language, 'Bus table', 'Bussbord'),
      _ => tr(widget.language, 'Table', 'Bord'),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF226C4D), Color(0xFF1A563D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF6D432D), width: 1.6),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  sectionTitle,
                  style: const TextStyle(
                    color: Color(0xFFF8E9D8),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (view.busRunnerPlayerId != null)
                  _tag(
                    _nameForPlayer(view.players, view.busRunnerPlayerId),
                    const Color(0xFFE2B356),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (view.phase != GamePhase.pyramid) ...<Widget>[
              _publicPlayerChips(
                players: view.players,
                currentTurnPlayerId: view.currentTurnPlayerId,
                viewerPlayerId: projection.viewerPlayerId,
              ),
              const SizedBox(height: 12),
            ],
            if (view.phase == GamePhase.warmup)
              _warmupButtons(
                enabled: myTurn && !blocked && connected,
                round: view.warmupRound,
              ),
            if (view.phase == GamePhase.pyramid) ...<Widget>[
              _pyramidPublicPanel(
                cards: view.pyramidCards,
                revealIndex: view.pyramidRevealIndex,
                onReveal: hostCanReveal
                    ? widget.controller.revealPyramidNext
                    : null,
              ),
              const SizedBox(height: 12),
              _publicPlayerChips(
                players: view.players,
                currentTurnPlayerId: view.currentTurnPlayerId,
                viewerPlayerId: projection.viewerPlayerId,
              ),
            ],
            if (view.phase == GamePhase.tiebreak)
              _tieBreakPanel(
                tieBreak: view.tieBreak,
                onRunRound: hostCanReveal
                    ? widget.controller.runTieBreakRound
                    : null,
              ),
            if (view.busRoute != null) ...<Widget>[
              _busRouteView(
                route: view.busRoute!,
                canControl:
                    projection.canControlBusRoute && !blocked && connected,
                phase: view.phase,
                players: view.players,
                busRunnerPlayerId: view.busRunnerPlayerId,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _publicPlayerChips({
    required List<HostedPublicPlayer> players,
    required int? currentTurnPlayerId,
    required int viewerPlayerId,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: players.map((HostedPublicPlayer player) {
        final bool activeTurn = currentTurnPlayerId == player.playerId;
        final bool isViewer = player.playerId == viewerPlayerId;
        final Color color = !player.connected
            ? const Color(0xFF8A6E64)
            : activeTurn
            ? const Color(0xFF2E9C5B)
            : isViewer
            ? const Color(0xFFE2B356)
            : const Color(0xFFF2E8D5);
        final Color textColor = !player.connected
            ? const Color(0xFFEBD8D1)
            : (activeTurn || isViewer)
            ? const Color(0xFF183728)
            : const Color(0xFF5E422D);
        final String label =
            '${player.name} - ${player.handCount} ${tr(widget.language, 'cards', 'kort')}';
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activeTurn
                  ? const Color(0xFFA3E2B9)
                  : const Color(0x40FFFFFF),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (player.isHost)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.workspace_premium,
                      size: 16,
                      color: textColor,
                    ),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
    final List<HostedPublicPlayer> targets = players;
    int draftTotal = 0;
    for (final int value in _draftTargets.values) {
      draftTotal += value;
    }
    final int remain = pending.remainingDrinks - draftTotal;

    return _surfaceCard(
      color: const Color(0xFFF1E7D8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            tr(
              widget.language,
              'Assign drinks (${pending.remainingDrinks} left)',
              'Fordel drikker (${pending.remainingDrinks} igjen)',
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF5B422D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pending.reason,
            style: const TextStyle(
              color: Color(0xFF846145),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final HostedPublicPlayer player in targets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F4EC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3CFB8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          player.name,
                          style: const TextStyle(
                            color: Color(0xFF5B422D),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
                        color: const Color(0xFFA45A35),
                      ),
                      Text(
                        '${_draftTargets[player.playerId] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5B422D),
                        ),
                      ),
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
                        color: const Color(0xFFA45A35),
                      ),
                    ],
                  ),
                ),
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
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFA45A35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
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

    final String title = switch (round) {
      1 => tr(widget.language, 'Round 1: guess color', 'Runde 1: gjett farge'),
      2 => tr(
        widget.language,
        'Round 2: higher, lower, or same',
        'Runde 2: høyere, lavere eller lik',
      ),
      3 => tr(
        widget.language,
        'Round 3: between, outside, or same',
        'Runde 3: mellom, utenfor eller lik',
      ),
      _ => tr(widget.language, 'Round 4: guess suit', 'Runde 4: gjett sort'),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xAA143E2D),
        border: Border.all(color: const Color(0x66FFD89A)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF8E9D8),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double spacing = 10;
                final int columns = options.length == 4 ? 2 : options.length;
                final double itemWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: options.map((WarmupGuess guess) {
                    return SizedBox(
                      width: itemWidth,
                      child: FilledButton(
                        onPressed: enabled
                            ? () => widget.controller.submitWarmupGuess(guess)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF3C978),
                          foregroundColor: const Color(0xFF513514),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          warmupGuessLabel(widget.language, guess),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pyramidPublicPanel({
    required List<PlayingCard?> cards,
    required int revealIndex,
    required VoidCallback? onReveal,
  }) {
    return _pyramidBoardPanel(
      cards: cards,
      revealIndex: revealIndex,
      onReveal: onReveal,
    );
    /*
    final List<PlayingCard> revealed = cards.whereType<PlayingCard>().toList(
      growable: false,
    );
    final bool hasMore = revealIndex < cards.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xAA143E2D),
        border: Border.all(color: const Color(0x66FFD89A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tr(widget.language, 'Pyramid reveal', 'Pyramideavdekking'),
              style: const TextStyle(
                color: Color(0xFFF8E9D8),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            if (revealed.isEmpty)
              Text(
                tr(
                  widget.language,
                  'No cards revealed yet.',
                  'Ingen kort er avdekket ennå.',
                ),
                style: const TextStyle(color: Color(0xFFF2E7D7)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: revealed
                    .map(
                      (PlayingCard card) =>
                          _playingCard(card, width: 62, height: 88),
                    )
                    .toList(),
              ),
            if (hasMore) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  _playingCard(null, showBack: true, width: 62, height: 88),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(
                        widget.language,
                        'Host reveals the next public pyramid card from the deck.',
                        'Verten avdekker neste offentlige pyramidekort fra bunken.',
                      ),
                      style: const TextStyle(color: Color(0xFFF2E7D7)),
                    ),
                  ),
                ],
              ),
            ],
            if (onReveal != null) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onReveal,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF3C978),
                  foregroundColor: const Color(0xFF513514),
                ),
                icon: const Icon(Icons.style),
                label: Text(tr(widget.language, 'Reveal next', 'Vis neste')),
              ),
            ],
          ],
        ),
      ),
    );
    */
  }

  Widget _pyramidBoardPanel({
    required List<PlayingCard?> cards,
    required int revealIndex,
    required VoidCallback? onReveal,
  }) {
    const List<List<int>> rows = <List<int>>[
      <int>[14],
      <int>[12, 13],
      <int>[9, 10, 11],
      <int>[5, 6, 7, 8],
      <int>[0, 1, 2, 3, 4],
    ];
    final bool hasMore = revealIndex < cards.length;
    final bool canReveal = hasMore && onReveal != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xAA143E2D),
        border: Border.all(color: const Color(0x66FFD89A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tr(widget.language, 'Pyramid reveal', 'Pyramideavdekking'),
              style: const TextStyle(
                color: Color(0xFFF8E9D8),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: canReveal ? onReveal : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: canReveal
                          ? const Color(0xFFE9C172)
                          : const Color(0x66FFFFFF),
                      width: canReveal ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _playingCard(
                      null,
                      showBack: true,
                      width: 64,
                      height: 92,
                      emphasized: canReveal,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasMore
                  ? tr(
                      widget.language,
                      canReveal
                          ? 'Tap deck to reveal next pyramid card.'
                          : 'Host reveals next pyramid card from the deck.',
                      canReveal
                          ? 'Trykk stokken for a avslore neste pyramidekort.'
                          : 'Verten avdekker neste pyramidekort fra stokken.',
                    )
                  : tr(
                      widget.language,
                      'All pyramid cards are revealed.',
                      'Alle pyramidekort er avdekket.',
                    ),
              style: const TextStyle(
                color: Color(0xFFF2E7D7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0x33000000),
                border: Border.all(color: const Color(0x38FFFFFF)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Column(
                  children: rows.map((List<int> row) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: row.map((int index) {
                          final PlayingCard? card = cards[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _pyramidSlotCard(card),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pyramidSlotCard(PlayingCard? card) {
    if (card != null) {
      return _playingCard(card, width: 52, height: 74);
    }
    return Container(
      width: 52,
      height: 74,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0x22313C34),
        border: Border.all(color: const Color(0x44FFFFFF)),
      ),
      child: const Center(
        child: Icon(Icons.circle, size: 8, color: Color(0x55FFFFFF)),
      ),
    );
  }

  Widget _tieBreakPanel({
    required TieBreakState? tieBreak,
    required VoidCallback? onRunRound,
  }) {
    if (tieBreak == null) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xAA143E2D),
        border: Border.all(color: const Color(0x66FFD89A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tr(widget.language, 'Tie-break reveal', 'Tie-break-avdekking'),
              style: const TextStyle(
                color: Color(0xFFF8E9D8),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tieBreak.contenders.map((int playerIndex) {
                HostedPublicPlayer? player;
                if (playerIndex >= 0 &&
                    playerIndex <
                        widget
                            .controller
                            .projection!
                            .publicView
                            .players
                            .length) {
                  player = widget
                      .controller
                      .projection!
                      .publicView
                      .players[playerIndex];
                }
                TieBreakDraw? draw;
                for (final TieBreakDraw entry in tieBreak.lastDraws) {
                  if (entry.playerIndex == playerIndex) {
                    draw = entry;
                    break;
                  }
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      player?.name ??
                          '${tr(widget.language, 'Player', 'Spiller')} ${playerIndex + 1}',
                      style: const TextStyle(
                        color: Color(0xFFF2E7D7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _playingCard(
                      draw?.card,
                      showBack: draw == null,
                      width: 72,
                      height: 102,
                      emphasized: draw != null,
                    ),
                  ],
                );
              }).toList(),
            ),
            if (onRunRound != null) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRunRound,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF3C978),
                  foregroundColor: const Color(0xFF513514),
                ),
                icon: const Icon(Icons.casino),
                label: Text(
                  tr(
                    widget.language,
                    'Run tie-break round',
                    'Kjør tie-break-runde',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _busRouteBoard({
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
    final bool setupPhase = phase == GamePhase.bussetup;
    final bool routePhase = phase == GamePhase.bus;
    final bool finishedPhase = phase == GamePhase.finished;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xAA143E2D),
        border: Border.all(color: const Color(0x66FFD89A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tr(widget.language, 'Bus route (public)', 'Bussrute (offentlig)'),
              style: const TextStyle(
                color: Color(0xFFF8E9D8),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: <Widget>[
                  _playingCard(
                    null,
                    showBack: true,
                    width: 62,
                    height: 88,
                    emphasized: routePhase,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      widget.language,
                      'Deck: ${route.deck.length}',
                      'Stokk: ${route.deck.length}',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFF2E7D7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double gap = 8;
                final int count = route.routeCards.length;
                final double maxCardWidth =
                    (constraints.maxWidth - gap * (count - 1)) / count;
                final double cardWidth = maxCardWidth.clamp(34, 56).toDouble();
                final double cardHeight = cardWidth / _hostedCardAspect;
                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(count, (int index) {
                        final bool isActive = routePhase && active == index;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index + 1 < count ? gap : 0,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFFE2B356)
                                    : const Color(0x28000000),
                                width: isActive ? 2.2 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              color: isActive
                                  ? const Color(0x22FFD88A)
                                  : Colors.transparent,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: _playingCard(
                                route.routeCards[index],
                                width: cardWidth,
                                height: cardHeight,
                                emphasized: isActive,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
            if (finishedPhase) ...<Widget>[
              const SizedBox(height: 14),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8E8D3).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      tr(widget.language, 'Route finished', 'Rute ferdig'),
                      style: const TextStyle(
                        color: Color(0xFF50301F),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (setupPhase && canControl) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          widget.controller.beginBusRoute(BusStartSide.left),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF3C978),
                        foregroundColor: const Color(0xFF513514),
                      ),
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
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF3C978),
                        foregroundColor: const Color(0xFF513514),
                      ),
                      child: Text(
                        tr(widget.language, 'Start right', 'Start hoyre'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (routePhase && canControl) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BusGuess.values
                    .map(
                      (BusGuess guess) => FilledButton(
                        onPressed: () => widget.controller.playBusGuess(guess),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF3C978),
                          foregroundColor: const Color(0xFF513514),
                        ),
                        child: Text(busGuessLabel(widget.language, guess)),
                      ),
                    )
                    .toList(),
              ),
            ],
            if ((setupPhase || routePhase) && !canControl) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                tr(
                  widget.language,
                  'Public view only. $runnerName is actively playing the bus route.',
                  'Offentlig visning. $runnerName spiller bussruta aktivt.',
                ),
                style: const TextStyle(
                  color: Color(0xFFF2E7D7),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _busRouteView({
    required BusRouteState route,
    required bool canControl,
    required GamePhase phase,
    required List<HostedPublicPlayer> players,
    required int? busRunnerPlayerId,
  }) {
    return _busRouteBoard(
      route: route,
      canControl: canControl,
      phase: phase,
      players: players,
      busRunnerPlayerId: busRunnerPlayerId,
    );
    /*
    final int active = route.progress < route.order.length
        ? route.order[route.progress]
        : -1;
    final String runnerName = _nameForPlayer(players, busRunnerPlayerId);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xAA143E2D),
        border: Border.all(color: const Color(0x66FFD89A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tr(widget.language, 'Bus route (public)', 'Bussrute (offentlig)'),
              style: const TextStyle(
                color: Color(0xFFF8E9D8),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List<Widget>.generate(route.routeCards.length, (
                int index,
              ) {
                final bool isActive = active == index && phase == GamePhase.bus;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFE2B356)
                          : const Color(0x33FFFFFF),
                      width: isActive ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: isActive
                        ? const Color(0x22FFD88A)
                        : Colors.transparent,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: _playingCard(
                      route.routeCards[index],
                      width: 58,
                      height: 82,
                      emphasized: isActive,
                    ),
                  ),
                );
              }),
            ),
            if (phase == GamePhase.bussetup && canControl) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          widget.controller.beginBusRoute(BusStartSide.left),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF3C978),
                        foregroundColor: const Color(0xFF513514),
                      ),
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
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF3C978),
                        foregroundColor: const Color(0xFF513514),
                      ),
                      child: Text(
                        tr(widget.language, 'Start right', 'Start høyre'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (phase == GamePhase.bus && canControl) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BusGuess.values
                    .map(
                      (BusGuess guess) => FilledButton(
                        onPressed: () => widget.controller.playBusGuess(guess),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF3C978),
                          foregroundColor: const Color(0xFF513514),
                        ),
                        child: Text(busGuessLabel(widget.language, guess)),
                      ),
                    )
                    .toList(),
              ),
            ],
            if ((phase == GamePhase.bussetup || phase == GamePhase.bus) &&
                !canControl) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                tr(
                  widget.language,
                  'Public view only. $runnerName is actively playing the bus route.',
                  'Offentlig visning. $runnerName spiller bussruta aktivt.',
                ),
                style: const TextStyle(
                  color: Color(0xFFF2E7D7),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    */
  }

  Widget _playingCard(
    PlayingCard? card, {
    required double width,
    required double height,
    bool showBack = false,
    bool emphasized = false,
  }) {
    final bool back = showBack || card == null;
    final double radius = width * 0.18;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: back ? const Color(0xFFB8CBE0) : const Color(0xFFCEBCA8),
          width: emphasized ? 1.4 : 1.0,
        ),
        color: back ? const Color(0xFF163E5A) : const Color(0xFFFFFCF7),
        gradient: back
            ? const LinearGradient(
                colors: <Color>[Color(0xFF214B4A), Color(0xFF132B35)],
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
            color: const Color(
              0x22000000,
            ).withValues(alpha: emphasized ? 0.2 : 0.13),
            blurRadius: emphasized ? 12 : 9,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: back
            ? _hostedCardBack(radius: radius)
            : _hostedCardFace(card, width: width, height: height),
      ),
    );
  }

  Widget _hostedCardFace(
    PlayingCard card, {
    required double width,
    required double height,
  }) {
    final bool red = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final Color ink = red ? const Color(0xFFBE3030) : const Color(0xFF232323);
    final double cornerFont = width < 36
        ? 7
        : width < 52
        ? 9.5
        : 12;
    final double centerFont = width < 36
        ? 12
        : width < 52
        ? 18
        : 24;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: _HostedCornerMark(
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
              child: _HostedCornerMark(
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

  Widget _hostedCardBack({required double radius}) {
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
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
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
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                borderRadius: BorderRadius.circular(math.max(2, radius - 1.4)),
              ),
            ),
          ),
        ),
        Positioned(
          left: 9,
          right: 9,
          top: 11,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0x33FFE08F),
            ),
            child: const SizedBox(height: 3),
          ),
        ),
        Positioned(
          left: 13,
          right: 13,
          bottom: 13,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.18),
            ),
            child: const SizedBox(height: 2),
          ),
        ),
        const Center(
          child: RotatedBox(
            quarterTurns: 1,
            child: Icon(
              Icons.directions_bus_filled_rounded,
              color: Color(0xFFFFD155),
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  String _suitGlyphForDisplay(Suit suit) {
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

  Widget _surfaceCard({required Widget child, Color? color}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF7F0E6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFDF8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
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

class _HostedCornerMark extends StatelessWidget {
  const _HostedCornerMark({
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
