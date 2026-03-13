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
    final String hostHint =
        server.hostAddress == null ? '' : ' ${server.hostAddress}:${server.port}';
    _infoMessage = _tr(
      'Hosting started. Share PIN $pin.$hostHint',
      'Hosting startet. Del PIN $pin.$hostHint',
    );
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
    final String? address = hostAddress?.trim().isNotEmpty == true
        ? hostAddress!.trim()
        : match?.hostAddress;
    final int? port = hostPort ??
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
    _flowState = HostedFlowState.joiningLobby;
    _connectionStatus = HostedConnectionStatus.joining;
    notifyListeners();
    final String resolvedName = playerName.trim().isEmpty
        ? _fallbackGuestName()
        : playerName.trim();
    try {
      final HostedLanClientConnection client =
          await HostedLanClientConnection.connect(
            hostAddress: hostAddress,
            hostPort: hostPort,
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
      _lastHostAddress = hostAddress;
      _lastHostPort = hostPort;
      _lastPin = pin;
      _lastPlayerName = resolvedName;
      _lastPlayerToken = client.playerToken;
      _lastPlayerId = client.playerId;
      _reconnectAttempt = 0;
      _bindClient(client);
      notifyListeners();
    } catch (error) {
      _flowState = HostedFlowState.idle;
      _connectionStatus = HostedConnectionStatus.hostUnavailable;
      _errorMessage = _tr(
        'Could not join hosted game: $error',
        'Kunne ikke bli med i hostet spill: $error',
      );
      notifyListeners();
    }
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
        notifyListeners();
        return;
      case HostedClientIssueCode.disconnected:
        _connectionStatus = HostedConnectionStatus.disconnected;
        _infoMessage = _tr(
          'Connection dropped. Trying to reconnect...',
          'Tilkoblingen falt ut. Prover a koble til igjen...',
        );
        _startReconnectLoop();
        notifyListeners();
        return;
      case HostedClientIssueCode.hostUnavailable:
        _connectionStatus = HostedConnectionStatus.hostUnavailable;
        _errorMessage = issue.message;
        unawaited(_clearRemoteSessionState());
        notifyListeners();
        return;
      case HostedClientIssueCode.sessionClosed:
        _connectionStatus = HostedConnectionStatus.sessionClosed;
        _infoMessage = issue.message;
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
