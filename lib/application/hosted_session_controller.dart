import 'dart:async';
import 'dart:math';

import 'package:bussruta_app/application/hosted_lan_transport.dart';
import 'package:bussruta_app/application/hosted_session_runtime.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:bussruta_app/domain/hosted_projection.dart';
import 'package:flutter/widgets.dart';

enum HostedFlowState { idle, hostingLobby, joiningLobby, inGame }

enum HostedConnectionStatus {
  idle,
  joining,
  connected,
  reconnecting,
  disconnected,
  hostUnavailable,
  sessionClosed,
}

class HostedSessionController extends ChangeNotifier {
  HostedSessionController({GameEngine? engine})
    : _engine = engine ?? GameEngine();

  final GameEngine _engine;
  final HostedLanDiscovery _discovery = HostedLanDiscovery();
  final Random _random = Random();

  HostedFlowState _flowState = HostedFlowState.idle;
  HostedConnectionStatus _connectionStatus = HostedConnectionStatus.idle;
  bool _isHost = false;
  int? _localPlayerId;
  HostedLanHostServer? _hostServer;
  HostedLanClientConnection? _clientConnection;
  HostedProjectedView? _projection;
  List<HostedDiscoveryEntry> _discoveries = const <HostedDiscoveryEntry>[];
  String? _errorMessage;
  String? _infoMessage;
  String? _networkDiagnostic;
  AppLanguage _language = AppLanguage.en;
  StreamSubscription<List<HostedDiscoveryEntry>>? _discoverySub;
  StreamSubscription<HostedSessionState>? _hostStateSub;
  StreamSubscription<String>? _hostErrorsSub;
  StreamSubscription<HostedProjectedView>? _clientProjectionSub;
  StreamSubscription<HostedClientIssue>? _clientIssuesSub;
  Timer? _autoPlayTimer;
  bool _autoPlayRunning = false;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _sessionCloseInProgress = false;
  String? _lastHostAddress;
  int? _lastHostPort;
  String? _lastPin;
  String? _lastPlayerName;
  String? _lastPlayerToken;
  int? _lastPlayerId;
  int _reconnectAttempt = 0;
  bool _reconnectAttemptInFlight = false;

  HostedFlowState get flowState => _flowState;
  HostedConnectionStatus get connectionStatus => _connectionStatus;
  bool get isHost => _isHost;
  int? get localPlayerId => _localPlayerId;
  HostedProjectedView? get projection => _projection;
  List<HostedDiscoveryEntry> get discoveries => _discoveries;
  AppLanguage get language => _language;
  String? get sessionPin => _projection?.publicView.sessionPin;
  String? get hostAddress => _hostServer?.hostAddress;
  int? get hostPort => _hostServer?.port;
  String? get networkDiagnostic => _networkDiagnostic;
  List<String> get hostGameLog =>
      _hostServer?.state.gameState.log ?? const <String>[];
  bool get hasActiveSession =>
      _hostServer != null || _clientConnection != null || _projection != null;

  String? consumeErrorMessage() {
    final String? value = _errorMessage;
    _errorMessage = null;
    return value;
  }

  String? consumeInfoMessage() {
    final String? value = _infoMessage;
    _infoMessage = null;
    return value;
  }

  Future<void> initialize({required AppLanguage language}) async {
    _language = language;
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _discovery.start();
    _discoverySub = _discovery.updates.listen((
      List<HostedDiscoveryEntry> list,
    ) {
      _discoveries = list;
      notifyListeners();
    });
    _discoveries = _discovery.entries;
    notifyListeners();
  }

  void setLanguage(AppLanguage language) {
    _language = language;
    notifyListeners();
  }

  Future<void> startHosting({required String hostName}) async {
    await leaveSession();
    final String pin = _generatePin();
    final HostedParticipant host = HostedParticipant(
      playerId: 1,
      name: hostName.trim().isEmpty ? _fallbackHostName() : hostName.trim(),
      isHost: true,
      connected: true,
    );
    final HostedSessionRuntime runtime = HostedSessionRuntime(
      engine: _engine,
      initialState: HostedSessionState.lobby(
        sessionPin: pin,
        host: host,
        language: _language,
      ),
    );
    final HostedLanHostServer server = HostedLanHostServer(
      runtime: runtime,
      hostName: host.name,
      pin: pin,
    );
    await server.start();

    _hostServer = server;
    _clientConnection = null;
    _isHost = true;
    _localPlayerId = host.playerId;
    _flowState = HostedFlowState.hostingLobby;
    _connectionStatus = HostedConnectionStatus.connected;
    _projection = projectHostedView(
      session: server.state,
      viewerPlayerId: host.playerId,
    );
    _lastHostAddress = null;
    _lastHostPort = null;
    _lastPin = pin;
    _lastPlayerName = host.name;
    _lastPlayerToken = null;
    _lastPlayerId = host.playerId;
    _reconnectAttempt = 0;
    final String hostHint = server.hostAddress == null
        ? ''
        : ' ${server.hostAddress}:${server.port}';
    _infoMessage = _tr(
      'Hosting started. Share PIN $pin.$hostHint',
      'Hosting startet. Del PIN $pin.$hostHint',
    );
    _networkDiagnostic =
        'Host listening at ${server.hostAddress ?? '-'}:${server.port}';
    _bindHostServer(server);
    _syncHostAutoPlay();
    notifyListeners();
  }

  Future<void> joinByDiscovery({
    required HostedDiscoveryEntry entry,
    required String playerName,
    String? pinOverride,
  }) async {
    await joinByAddress(
      hostAddress: entry.hostAddress,
      hostPort: entry.hostPort,
      pin: pinOverride?.trim().isNotEmpty == true
          ? pinOverride!.trim()
          : entry.pin,
      playerName: playerName,
    );
  }

  Future<void> joinByPin({
    required String pin,
    required String playerName,
    String? hostAddress,
    int? hostPort,
  }) async {
    await leaveSession();
    final String normalizedPin = pin.trim();
    if (normalizedPin.isEmpty) {
      _errorMessage = _tr('Please enter PIN.', 'Skriv inn PIN.');
      notifyListeners();
      return;
    }
    HostedDiscoveryEntry? match;
    for (final HostedDiscoveryEntry candidate in _discoveries) {
      if (candidate.pin == normalizedPin) {
        match = candidate;
        break;
      }
    }
    HostedJoinHostInput? manualTarget;
    if (hostAddress != null && hostAddress.trim().isNotEmpty) {
      try {
        manualTarget = parseHostedJoinHostInput(hostAddress);
      } on FormatException {
        _errorMessage = _tr(
          'Host address is invalid. Use host or host:port.',
          'Vertsadresse er ugyldig. Bruk host eller host:port.',
        );
        notifyListeners();
        return;
      }
    }
    final String? address = manualTarget?.host ?? match?.hostAddress;
    final int? port =
        hostPort ??
        manualTarget?.port ??
        match?.hostPort ??
        (address == null ? null : hostedSessionPort);
    if (address == null || port == null) {
      _errorMessage = _tr(
        'PIN was not found automatically. Enter the host address shown by the host device.',
        'PIN ble ikke funnet automatisk. Skriv inn vertsadressen som vises pa verts-enheten.',
      );
      notifyListeners();
      return;
    }
    await joinByAddress(
      hostAddress: address,
      hostPort: port,
      pin: normalizedPin,
      playerName: playerName,
    );
  }

  Future<void> joinByAddress({
    required String hostAddress,
    required int hostPort,
    required String pin,
    required String playerName,
    String? playerToken,
    int? requestedPlayerId,
  }) async {
    await leaveSession();
    final HostedJoinHostInput target;
    try {
      target = parseHostedJoinHostInput(hostAddress);
    } on FormatException {
      _flowState = HostedFlowState.idle;
      _connectionStatus = HostedConnectionStatus.hostUnavailable;
      _networkDiagnostic = null;
      _errorMessage = _tr(
        'Host address is invalid. Use host or host:port.',
        'Vertsadresse er ugyldig. Bruk host eller host:port.',
      );
      notifyListeners();
      return;
    }
    final int targetPort = target.port ?? hostPort;
    if (targetPort < 1 || targetPort > 65535) {
      _flowState = HostedFlowState.idle;
      _connectionStatus = HostedConnectionStatus.hostUnavailable;
      _networkDiagnostic = null;
      _errorMessage = _tr('Host port is invalid.', 'Vertsport er ugyldig.');
      notifyListeners();
      return;
    }
    _flowState = HostedFlowState.joiningLobby;
    _connectionStatus = HostedConnectionStatus.joining;
    notifyListeners();
    final String resolvedName = playerName.trim().isEmpty
        ? _fallbackGuestName()
        : playerName.trim();
    final List<String> addressCandidates = hostedJoinAddressCandidates(
      target.host,
    );
    final List<String> failedTargets = <String>[];

    for (final String candidateAddress in addressCandidates) {
      try {
        final HostedLanClientConnection client =
            await HostedLanClientConnection.connect(
              hostAddress: candidateAddress,
              hostPort: targetPort,
              pin: pin,
              playerName: resolvedName,
              playerToken: playerToken,
              requestedPlayerId: requestedPlayerId,
            );
        _clientConnection = client;
        _hostServer = null;
        _isHost = false;
        _localPlayerId = client.playerId;
        _projection = client.projection;
        _flowState = HostedFlowState.inGame;
        _connectionStatus = HostedConnectionStatus.connected;
        _lastHostAddress = candidateAddress;
        _lastHostPort = targetPort;
        _lastPin = pin;
        _lastPlayerName = resolvedName;
        _lastPlayerToken = client.playerToken;
        _lastPlayerId = client.playerId;
        _reconnectAttempt = 0;
        _networkDiagnostic = 'Connected to $candidateAddress:$targetPort';
        if (candidateAddress != target.host) {
          _infoMessage = _tr(
            'Connected using emulator fallback target $candidateAddress:$targetPort.',
            'Koblet til med emulator-fallback $candidateAddress:$targetPort.',
          );
        }
        _bindClient(client);
        notifyListeners();
        return;
      } catch (error) {
        failedTargets.add('$candidateAddress:$targetPort -> $error');
      }
    }

    _flowState = HostedFlowState.idle;
    _connectionStatus = HostedConnectionStatus.hostUnavailable;
    _networkDiagnostic = failedTargets.isEmpty
        ? 'Join failed.'
        : 'Join failed. Tried ${failedTargets.join(' | ')}';
    _errorMessage = _tr(
      'Could not join hosted game. Check PIN, host address, and network connectivity.',
      'Kunne ikke bli med i hostet spill. Sjekk PIN, vertsadresse og nettverkstilkobling.',
    );
    notifyListeners();
  }

  void startHostedGame() {
    if (!_isHost || _localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.startGame,
        playerId: _localPlayerId!,
      ),
    );
  }

  void resetHostedGameToLobby() {
    if (_localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.resetToSetup,
        playerId: _localPlayerId!,
      ),
    );
  }

  void submitWarmupGuess(WarmupGuess guess) {
    if (_localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.warmupGuess,
        playerId: _localPlayerId!,
        payload: <String, dynamic>{'guess': guess.name},
      ),
    );
  }

  void revealPyramidNext() {
    if (_localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.revealPyramid,
        playerId: _localPlayerId!,
      ),
    );
  }

  void runTieBreakRound() {
    if (_localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.runTieBreakRound,
        playerId: _localPlayerId!,
      ),
    );
  }

  void beginBusRoute(BusStartSide side) {
    if (_localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.beginBusRoute,
        playerId: _localPlayerId!,
        payload: <String, dynamic>{'side': side.name},
      ),
    );
  }

  void playBusGuess(BusGuess guess) {
    if (_localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.playBusGuess,
        playerId: _localPlayerId!,
        payload: <String, dynamic>{'guess': guess.name},
      ),
    );
  }

  void assignDrinks(Map<int, int> targets) {
    if (_localPlayerId == null || targets.isEmpty) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.assignDrinks,
        playerId: _localPlayerId!,
        payload: <String, dynamic>{
          'targets': targets.map(
            (int key, int value) =>
                MapEntry<String, int>(key.toString(), value),
          ),
        },
      ),
    );
  }

  void acknowledgeDrinks() {
    if (_localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.acknowledgeDrinks,
        playerId: _localPlayerId!,
      ),
    );
  }

  void toggleAutoPlay([bool? enabled]) {
    if (_localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.toggleAutoPlay,
        playerId: _localPlayerId!,
        payload: enabled == null
            ? const <String, dynamic>{}
            : <String, dynamic>{'enabled': enabled},
      ),
    );
  }

  void setAutoPlayDelayMs(int delayMs) {
    if (_localPlayerId == null) {
      return;
    }
    _dispatch(
      HostedSessionCommand(
        type: HostedCommandType.setAutoPlayDelayMs,
        playerId: _localPlayerId!,
        payload: <String, dynamic>{'delayMs': delayMs},
      ),
    );
  }

  void _dispatch(HostedSessionCommand command) {
    if (_hostServer != null && _isHost) {
      final HostedSessionState state = _hostServer!.applyLocalCommand(command);
      _projection = projectHostedView(
        session: state,
        viewerPlayerId: _localPlayerId!,
      );
      _flowState = state.gameState.phase == GamePhase.setup
          ? HostedFlowState.hostingLobby
          : HostedFlowState.inGame;
      if (state.lastError != null && state.lastError!.trim().isNotEmpty) {
        _errorMessage = state.lastError;
      }
      _syncHostAutoPlay();
      notifyListeners();
      return;
    }
    if (_clientConnection != null) {
      _clientConnection!.sendCommand(command);
    }
  }

  void _bindHostServer(HostedLanHostServer server) {
    _hostStateSub?.cancel();
    _hostErrorsSub?.cancel();
    _hostStateSub = server.stateUpdates.listen((HostedSessionState state) {
      if (_localPlayerId == null) {
        return;
      }
      _projection = projectHostedView(
        session: state,
        viewerPlayerId: _localPlayerId!,
      );
      _flowState = state.gameState.phase == GamePhase.setup
          ? HostedFlowState.hostingLobby
          : HostedFlowState.inGame;
      _syncHostAutoPlay();
      notifyListeners();
    });
    _hostErrorsSub = server.errors.listen((String message) {
      _errorMessage = message;
      notifyListeners();
    });
  }

  void _bindClient(HostedLanClientConnection client) {
    _clientProjectionSub?.cancel();
    _clientIssuesSub?.cancel();
    _clientProjectionSub = client.projectionUpdates.listen((
      HostedProjectedView projection,
    ) {
      _projection = projection;
      _flowState = projection.publicView.phase == GamePhase.setup
          ? HostedFlowState.joiningLobby
          : HostedFlowState.inGame;
      _connectionStatus = HostedConnectionStatus.connected;
      _localPlayerId = client.playerId;
      _lastPlayerId = client.playerId;
      _lastPlayerToken = client.playerToken ?? _lastPlayerToken;
      _reconnectAttempt = 0;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _networkDiagnostic =
          'Connected as player ${client.playerId} via ${_lastHostAddress ?? '-'}:${_lastHostPort ?? 0}';
      notifyListeners();
    });
    _clientIssuesSub = client.issues.listen((HostedClientIssue issue) {
      _handleClientIssue(issue);
    });
  }

  void _handleClientIssue(HostedClientIssue issue) {
    if (_sessionCloseInProgress || _disposed) {
      return;
    }
    switch (issue.code) {
      case HostedClientIssueCode.genericError:
        if (_connectionStatus == HostedConnectionStatus.joining ||
            _connectionStatus == HostedConnectionStatus.reconnecting) {
          _connectionStatus = HostedConnectionStatus.hostUnavailable;
          _errorMessage = issue.message;
          unawaited(_clearRemoteSessionState());
          notifyListeners();
          return;
        }
        _errorMessage = issue.message;
        _networkDiagnostic = 'Issue: ${issue.message}';
        notifyListeners();
        return;
      case HostedClientIssueCode.disconnected:
        _connectionStatus = HostedConnectionStatus.disconnected;
        _infoMessage = _tr(
          'Connection dropped. Trying to reconnect...',
          'Tilkoblingen falt ut. Prover a koble til igjen...',
        );
        _startReconnectLoop();
        _networkDiagnostic =
            'Disconnected from ${_lastHostAddress ?? '-'}:${_lastHostPort ?? 0}';
        notifyListeners();
        return;
      case HostedClientIssueCode.hostUnavailable:
        _connectionStatus = HostedConnectionStatus.hostUnavailable;
        _errorMessage = issue.message;
        _networkDiagnostic = 'Host unavailable: ${issue.message}';
        unawaited(_clearRemoteSessionState());
        notifyListeners();
        return;
      case HostedClientIssueCode.sessionClosed:
        _connectionStatus = HostedConnectionStatus.sessionClosed;
        _infoMessage = issue.message;
        _networkDiagnostic = 'Session closed: ${issue.message}';
        _resetReconnectIdentity();
        unawaited(_clearRemoteSessionState());
        notifyListeners();
        return;
    }
  }

  void _startReconnectLoop() {
    if (_isHost) {
      return;
    }
    if (_lastHostAddress == null ||
        _lastHostPort == null ||
        _lastPin == null ||
        _lastPlayerName == null ||
        _lastPlayerToken == null ||
        _lastPlayerId == null) {
      _connectionStatus = HostedConnectionStatus.hostUnavailable;
      unawaited(_clearRemoteSessionState());
      notifyListeners();
      return;
    }
    if (_connectionStatus == HostedConnectionStatus.reconnecting) {
      return;
    }
    _connectionStatus = HostedConnectionStatus.reconnecting;
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    _reconnectAttemptInFlight = false;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 2), (
      Timer timer,
    ) async {
      if (_disposed || _sessionCloseInProgress || _isHost) {
        timer.cancel();
        return;
      }
      if (_reconnectAttempt >= 6) {
        timer.cancel();
        _connectionStatus = HostedConnectionStatus.hostUnavailable;
        _errorMessage = _tr(
          'Host unavailable. Reconnect failed.',
          'Vert utilgjengelig. Gjenoppkobling feilet.',
        );
        unawaited(_clearRemoteSessionState());
        notifyListeners();
        return;
      }
      if (_reconnectAttemptInFlight) {
        return;
      }
      _reconnectAttempt += 1;
      await _attemptReconnect();
    });
  }

  Future<void> _attemptReconnect() async {
    if (_reconnectAttemptInFlight) {
      return;
    }
    if (_lastHostAddress == null ||
        _lastHostPort == null ||
        _lastPin == null ||
        _lastPlayerName == null ||
        _lastPlayerToken == null ||
        _lastPlayerId == null) {
      return;
    }
    _reconnectAttemptInFlight = true;
    try {
      await _clientProjectionSub?.cancel();
      _clientProjectionSub = null;
      await _clientIssuesSub?.cancel();
      _clientIssuesSub = null;
      await _clientConnection?.close();
      _clientConnection = null;

      final HostedLanClientConnection client =
          await HostedLanClientConnection.connect(
            hostAddress: _lastHostAddress!,
            hostPort: _lastHostPort!,
            pin: _lastPin!,
            playerName: _lastPlayerName!,
            playerToken: _lastPlayerToken,
            requestedPlayerId: _lastPlayerId,
            timeout: const Duration(seconds: 4),
          );
      _clientConnection = client;
      _projection = client.projection;
      _localPlayerId = client.playerId;
      _lastPlayerId = client.playerId;
      _lastPlayerToken = client.playerToken ?? _lastPlayerToken;
      _flowState = _projection?.publicView.phase == GamePhase.setup
          ? HostedFlowState.joiningLobby
          : HostedFlowState.inGame;
      _bindClient(client);
      _connectionStatus = HostedConnectionStatus.connected;
      _infoMessage = _tr('Reconnected.', 'Koblet til igjen.');
      _networkDiagnostic =
          'Reconnected to ${_lastHostAddress!}:${_lastHostPort!}';
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempt = 0;
      notifyListeners();
    } catch (_) {
      // Keep retry loop alive until max attempts.
    } finally {
      _reconnectAttemptInFlight = false;
    }
  }

  Future<void> _clearRemoteSessionState() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttemptInFlight = false;
    await _clientProjectionSub?.cancel();
    _clientProjectionSub = null;
    await _clientIssuesSub?.cancel();
    _clientIssuesSub = null;
    await _clientConnection?.close();
    _clientConnection = null;
    _projection = null;
    _localPlayerId = null;
    _isHost = false;
    _flowState = HostedFlowState.idle;
    _networkDiagnostic = null;
  }

  Future<void> leaveSession() async {
    _sessionCloseInProgress = true;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    _autoPlayRunning = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttemptInFlight = false;
    await _hostStateSub?.cancel();
    _hostStateSub = null;
    await _hostErrorsSub?.cancel();
    _hostErrorsSub = null;
    await _clientProjectionSub?.cancel();
    _clientProjectionSub = null;
    await _clientIssuesSub?.cancel();
    _clientIssuesSub = null;

    await _hostServer?.close(
      reason: _tr('Host ended the session.', 'Verten avsluttet sesjonen.'),
      broadcastSessionClosed: true,
    );
    _hostServer = null;
    await _clientConnection?.close();
    _clientConnection = null;
    _projection = null;
    _localPlayerId = null;
    _isHost = false;
    _flowState = HostedFlowState.idle;
    _connectionStatus = HostedConnectionStatus.idle;
    _resetReconnectIdentity();
    _reconnectAttempt = 0;
    _networkDiagnostic = null;
    _sessionCloseInProgress = false;
    notifyListeners();
  }

  void _resetReconnectIdentity() {
    _lastHostAddress = null;
    _lastHostPort = null;
    _lastPin = null;
    _lastPlayerName = null;
    _lastPlayerToken = null;
    _lastPlayerId = null;
  }

  String _generatePin() {
    final int value = 1000 + _random.nextInt(9000);
    return value.toString();
  }

  String _fallbackHostName() {
    return _tr('Host', 'Vert');
  }

  String _fallbackGuestName() {
    return _tr('Player', 'Spiller');
  }

  String _tr(String en, String no) {
    return _language == AppLanguage.no ? no : en;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(leaveSession());
    unawaited(_discoverySub?.cancel());
    unawaited(_discovery.stop());
    super.dispose();
  }

  void _syncHostAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    if (!_isHost || _hostServer == null) {
      return;
    }
    final HostedSessionState state = _hostServer!.state;
    if (!state.gameState.autoPlay.enabled ||
        _autoPlayRunning ||
        state.pendingDrinkDistribution != null ||
        state.gameState.phase == GamePhase.setup ||
        state.gameState.phase == GamePhase.finished) {
      return;
    }
    _autoPlayTimer = Timer(
      Duration(milliseconds: state.gameState.autoPlay.delayMs),
      _runHostAutoPlayStep,
    );
  }

  void _runHostAutoPlayStep() {
    if (_autoPlayRunning || !_isHost || _hostServer == null) {
      return;
    }
    _autoPlayRunning = true;
    try {
      final HostedSessionState state = _hostServer!.state;
      if (!state.gameState.autoPlay.enabled) {
        return;
      }
      final HostedPendingDrinkDistribution? pending =
          state.pendingDrinkDistribution;
      if (pending != null) {
        final int? target = _firstAutoTarget(state, pending.sourcePlayerId);
        if (target != null) {
          _hostServer!.applyLocalCommand(
            HostedSessionCommand(
              type: HostedCommandType.assignDrinks,
              playerId: pending.sourcePlayerId,
              payload: <String, dynamic>{
                'targets': <String, int>{
                  target.toString(): pending.remainingDrinks,
                },
              },
            ),
          );
        }
        return;
      }
      final GameState game = state.gameState;
      if (game.phase == GamePhase.warmup) {
        final WarmupGuess guess = _engine.chooseWarmupGuessByStats(game);
        final int actor = state.playerOrder[game.currentPlayerIndex];
        _hostServer!.applyLocalCommand(
          HostedSessionCommand(
            type: HostedCommandType.warmupGuess,
            playerId: actor,
            payload: <String, dynamic>{'guess': guess.name},
          ),
        );
      } else if (game.phase == GamePhase.pyramid) {
        _hostServer!.applyLocalCommand(
          HostedSessionCommand(
            type: HostedCommandType.revealPyramid,
            playerId: state.hostPlayerId,
          ),
        );
      } else if (game.phase == GamePhase.tiebreak) {
        _hostServer!.applyLocalCommand(
          HostedSessionCommand(
            type: HostedCommandType.runTieBreakRound,
            playerId: state.hostPlayerId,
          ),
        );
      } else if (game.phase == GamePhase.bussetup) {
        final int? busRunnerId = game.busRunnerIndex == null
            ? null
            : state.playerIdForIndex(game.busRunnerIndex!);
        if (busRunnerId != null) {
          _hostServer!.applyLocalCommand(
            HostedSessionCommand(
              type: HostedCommandType.beginBusRoute,
              playerId: busRunnerId,
              payload: <String, dynamic>{'side': game.busStartSide.name},
            ),
          );
        }
      } else if (game.phase == GamePhase.bus) {
        final int? busRunnerId = game.busRunnerIndex == null
            ? null
            : state.playerIdForIndex(game.busRunnerIndex!);
        if (busRunnerId != null) {
          final BusGuess guess = _engine.chooseBusGuessByStats(game);
          _hostServer!.applyLocalCommand(
            HostedSessionCommand(
              type: HostedCommandType.playBusGuess,
              playerId: busRunnerId,
              payload: <String, dynamic>{'guess': guess.name},
            ),
          );
        }
      }
    } finally {
      _autoPlayRunning = false;
      _syncHostAutoPlay();
      notifyListeners();
    }
  }

  int? _firstAutoTarget(HostedSessionState state, int sourcePlayerId) {
    for (final int playerId in state.playerOrder) {
      if (playerId == sourcePlayerId) {
        continue;
      }
      return playerId;
    }
    return null;
  }
}

List<String> hostedJoinAddressCandidates(String hostAddress) {
  final String normalized = hostAddress.trim();
  if (normalized.isEmpty) {
    return const <String>[];
  }
  final List<String> addresses = <String>[normalized];
  if (hostedAddressLooksLikeEmulatorNat(normalized) &&
      normalized != '10.0.2.2') {
    addresses.add('10.0.2.2');
  }
  return addresses;
}

bool hostedAddressLooksLikeEmulatorNat(String address) {
  return address.startsWith('10.0.2.');
}

class HostedJoinHostInput {
  const HostedJoinHostInput({required this.host, required this.port});

  final String host;
  final int? port;
}

HostedJoinHostInput parseHostedJoinHostInput(String raw) {
  final String input = raw.trim();
  if (input.isEmpty) {
    throw const FormatException('Host address is empty.');
  }
  if (input.contains('://')) {
    final Uri? uri = Uri.tryParse(input);
    if (uri != null && uri.host.trim().isNotEmpty) {
      final int? uriPort = uri.hasPort && uri.port > 0 ? uri.port : null;
      return HostedJoinHostInput(host: uri.host.trim(), port: uriPort);
    }
  }
  if (input.startsWith('[')) {
    final int closingBracket = input.indexOf(']');
    if (closingBracket <= 1) {
      throw const FormatException('Invalid bracketed host.');
    }
    final String hostPart = input.substring(1, closingBracket).trim();
    if (hostPart.isEmpty) {
      throw const FormatException('Host is empty.');
    }
    if (closingBracket == input.length - 1) {
      return HostedJoinHostInput(host: hostPart, port: null);
    }
    final String suffix = input.substring(closingBracket + 1).trim();
    if (!suffix.startsWith(':')) {
      throw const FormatException('Unexpected suffix after host.');
    }
    final String portPart = suffix.substring(1).trim();
    final int port = _parseHostedJoinPort(portPart);
    return HostedJoinHostInput(host: hostPart, port: port);
  }

  final List<String> segments = input.split(':');
  if (segments.length == 2) {
    final String hostPart = segments[0].trim();
    final String portPart = segments[1].trim();
    if (hostPart.isEmpty) {
      throw const FormatException('Host is empty.');
    }
    final int port = _parseHostedJoinPort(portPart);
    return HostedJoinHostInput(host: hostPart, port: port);
  }

  return HostedJoinHostInput(host: input, port: null);
}

int _parseHostedJoinPort(String rawPort) {
  final String portText = rawPort.trim();
  final int? parsed = int.tryParse(portText);
  if (parsed == null || parsed < 1 || parsed > 65535) {
    throw const FormatException('Invalid host port.');
  }
  return parsed;
}
