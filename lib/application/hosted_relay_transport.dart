import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bussruta_app/application/hosted_session_runtime.dart';
import 'package:bussruta_app/application/hosted_transport_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:bussruta_app/domain/hosted_projection.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HostedRelayHostConnection {
  HostedRelayHostConnection._({
    required WebSocketChannel channel,
    required this.runtime,
    required this.hostName,
    required String roomKey,
  }) : _channel = channel,
       _roomKey = roomKey;

  final WebSocketChannel _channel;
  final HostedSessionRuntime runtime;
  final String hostName;
  final Random _random = Random.secure();
  final Map<String, int> _playerIdByClientId = <String, int>{};
  final Map<int, String> _clientIdByPlayerId = <int, String>{};
  final Map<String, int> _playerIdByToken = <String, int>{};
  final Map<int, String> _tokenByPlayerId = <int, String>{};
  final StreamController<HostedSessionState> _stateUpdates =
      StreamController<HostedSessionState>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();
  final Completer<void> _roomCreated = Completer<void>();
  StreamSubscription<dynamic>? _socketSub;
  String _roomKey;
  bool _closingLocally = false;

  Stream<HostedSessionState> get stateUpdates => _stateUpdates.stream;
  Stream<String> get errors => _errors.stream;
  HostedSessionState get state => runtime.state;
  String get roomKey => _roomKey;

  static Future<HostedRelayHostConnection> start({
    required Uri relayUri,
    required HostedSessionRuntime runtime,
    required String hostName,
    required String roomKey,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final HostedRelayHostConnection connection = HostedRelayHostConnection._(
      channel: WebSocketChannel.connect(relayUri),
      runtime: runtime,
      hostName: hostName,
      roomKey: roomKey,
    );
    connection._listen();
    connection._ensureTokenForPlayer(runtime.state.hostPlayerId);
    connection._send(<String, dynamic>{
      'type': 'host.create',
      'roomKey': roomKey,
    });
    try {
      await connection._roomCreated.future.timeout(timeout);
    } catch (_) {
      await connection.close(broadcastSessionClosed: false);
      rethrow;
    }
    connection._emitState();
    return connection;
  }

  HostedSessionState applyLocalCommand(HostedSessionCommand command) {
    runtime.applyCommand(command);
    _emitState();
    _broadcastSnapshots();
    return runtime.state;
  }

  HostedProjectedView projectionForPlayer(int playerId) {
    return projectHostedView(session: runtime.state, viewerPlayerId: playerId);
  }

  HostedProjectedView projectionForHost() {
    return projectionForPlayer(runtime.state.hostPlayerId);
  }

  void _listen() {
    _socketSub = _channel.stream.listen(
      (dynamic raw) {
        if (raw is! String) {
          _emitError('Invalid relay message.');
          return;
        }
        _handleMessage(raw);
      },
      onDone: () {
        if (!_closingLocally) {
          _emitError('Relay disconnected.');
        }
        if (!_roomCreated.isCompleted) {
          _roomCreated.completeError('Relay disconnected.');
        }
      },
      onError: (Object error) {
        final String message = 'Relay connection error: $error';
        _emitError(message);
        if (!_roomCreated.isCompleted) {
          _roomCreated.completeError(message);
        }
      },
      cancelOnError: true,
    );
  }

  void _handleMessage(String raw) {
    final Map<String, dynamic>? envelope = _decodeObject(raw);
    if (envelope == null) {
      _emitError('Invalid relay JSON.');
      return;
    }
    final String type = envelope['type'] as String? ?? '';
    switch (type) {
      case 'room.created':
        _roomKey = envelope['roomKey'] as String? ?? _roomKey;
        if (!_roomCreated.isCompleted) {
          _roomCreated.complete();
        }
        return;
      case 'client.connected':
        return;
      case 'client.message':
        final String clientId = envelope['clientId'] as String? ?? '';
        final Object? payload = envelope['payload'];
        if (clientId.isEmpty || payload is! Map<String, dynamic>) {
          _emitError('Invalid client relay message.');
          return;
        }
        _handleClientPayload(clientId, payload);
        return;
      case 'client.disconnected':
        _handleClientDisconnect(envelope['clientId'] as String? ?? '');
        return;
      case 'error':
        final String message = envelope['message'] as String? ?? 'Relay error.';
        if (!_roomCreated.isCompleted) {
          _roomCreated.completeError(message);
        }
        _emitError(message);
        return;
      default:
        return;
    }
  }

  void _handleClientPayload(String clientId, Map<String, dynamic> payload) {
    final String type = payload['type'] as String? ?? '';
    switch (type) {
      case 'join':
        _handleJoin(clientId, payload);
        return;
      case 'command':
        _handleCommand(clientId, payload);
        return;
      case 'ping':
        _sendToClient(clientId, <String, dynamic>{'type': 'pong'});
        return;
      default:
        _sendToClient(clientId, <String, dynamic>{
          'type': 'error',
          'message': 'Unknown message type.',
        });
        return;
    }
  }

  void _handleJoin(String clientId, Map<String, dynamic> envelope) {
    final String incomingPin = (envelope['pin'] as String? ?? '').trim();
    if (incomingPin != runtime.state.sessionPin) {
      _sendToClient(clientId, <String, dynamic>{
        'type': 'error',
        'message': 'PIN code mismatch.',
      });
      return;
    }
    final String name = (envelope['name'] as String? ?? '').trim();
    final String? incomingToken = (envelope['playerToken'] as String?)?.trim();
    final int? requestedPlayerId = envelope['requestedPlayerId'] as int?;

    if (requestedPlayerId != null &&
        (incomingToken == null || incomingToken.isEmpty)) {
      _sendToClient(clientId, <String, dynamic>{
        'type': 'error',
        'message': 'Reconnect token required for seat reclaim.',
      });
      return;
    }
    if (incomingToken != null && incomingToken.isNotEmpty) {
      final int? mappedId = _playerIdByToken[incomingToken];
      if (mappedId == null) {
        if (requestedPlayerId != null) {
          _sendToClient(clientId, <String, dynamic>{
            'type': 'error',
            'message': 'Invalid reconnect token.',
          });
          return;
        }
      } else {
        if (requestedPlayerId != null && requestedPlayerId != mappedId) {
          _sendToClient(clientId, <String, dynamic>{
            'type': 'error',
            'message': 'Reconnect token does not match requested seat.',
          });
          return;
        }
        _reclaimSeat(
          clientId: clientId,
          playerId: mappedId,
          playerToken: incomingToken,
        );
        return;
      }
    }

    final int playerId = runtime.state.playerOrder.fold<int>(1, max<int>) + 1;
    runtime.addParticipant(
      playerId: playerId,
      name: name.isEmpty ? 'Player $playerId' : name,
      connected: true,
    );
    if (runtime.state.participantById(playerId) == null) {
      _sendToClient(clientId, <String, dynamic>{
        'type': 'error',
        'message': runtime.state.lastError ?? 'Could not join this session.',
      });
      return;
    }

    final String playerToken = _ensureTokenForPlayer(playerId);
    _playerIdByClientId[clientId] = playerId;
    _clientIdByPlayerId[playerId] = clientId;
    _sendToClient(clientId, <String, dynamic>{
      'type': 'joined',
      'playerId': playerId,
      'playerToken': playerToken,
      'reconnected': false,
      'projection': projectionForPlayer(playerId).toJson(),
    });
    _emitState();
    _broadcastSnapshots();
  }

  void _handleCommand(String clientId, Map<String, dynamic> envelope) {
    final int? playerId = _playerIdByClientId[clientId];
    if (playerId == null) {
      _sendToClient(clientId, <String, dynamic>{
        'type': 'error',
        'message': 'Join the session before sending commands.',
      });
      return;
    }
    final Object? rawCommand = envelope['command'];
    if (rawCommand is! Map<String, dynamic>) {
      _sendToClient(clientId, <String, dynamic>{
        'type': 'error',
        'message': 'Missing hosted command payload.',
      });
      return;
    }

    HostedSessionCommand parsed;
    try {
      parsed = HostedSessionCommand.fromJson(rawCommand);
    } catch (_) {
      _sendToClient(clientId, <String, dynamic>{
        'type': 'error',
        'message': 'Invalid command payload.',
      });
      return;
    }
    final HostedSessionCommand command = HostedSessionCommand(
      type: parsed.type,
      playerId: playerId,
      payload: parsed.payload,
    );
    runtime.applyCommand(command);
    if (runtime.state.lastError != null &&
        runtime.state.lastError!.trim().isNotEmpty) {
      _sendToClient(clientId, <String, dynamic>{
        'type': 'error',
        'message': runtime.state.lastError,
      });
    }
    _emitState();
    _broadcastSnapshots();
  }

  void _handleClientDisconnect(String clientId) {
    final int? playerId = _playerIdByClientId.remove(clientId);
    if (playerId == null) {
      return;
    }
    _clientIdByPlayerId.remove(playerId);
    runtime.updateParticipantConnection(playerId: playerId, connected: false);
    _emitState();
    _broadcastSnapshots();
  }

  void _reclaimSeat({
    required String clientId,
    required int playerId,
    required String playerToken,
  }) {
    final HostedParticipant? participant = runtime.state.participantById(
      playerId,
    );
    if (participant == null) {
      _sendToClient(clientId, <String, dynamic>{
        'type': 'error',
        'message': 'Requested seat is not available.',
      });
      return;
    }
    if (participant.isHost) {
      _sendToClient(clientId, <String, dynamic>{
        'type': 'error',
        'message': 'Host seat cannot be reclaimed by client.',
      });
      return;
    }

    final String? previousClientId = _clientIdByPlayerId[playerId];
    if (previousClientId != null && previousClientId != clientId) {
      _playerIdByClientId.remove(previousClientId);
    }
    _playerIdByClientId[clientId] = playerId;
    _clientIdByPlayerId[playerId] = clientId;
    runtime.updateParticipantConnection(playerId: playerId, connected: true);
    _sendToClient(clientId, <String, dynamic>{
      'type': 'joined',
      'playerId': playerId,
      'playerToken': playerToken,
      'reconnected': true,
      'projection': projectionForPlayer(playerId).toJson(),
    });
    _emitState();
    _broadcastSnapshots();
  }

  String _ensureTokenForPlayer(int playerId) {
    final String? existing = _tokenByPlayerId[playerId];
    if (existing != null) {
      return existing;
    }
    final String token = _newPlayerToken();
    _tokenByPlayerId[playerId] = token;
    _playerIdByToken[token] = playerId;
    return token;
  }

  String _newPlayerToken() {
    final int a = _random.nextInt(1 << 32);
    final int b = _random.nextInt(1 << 32);
    final int c = _random.nextInt(1 << 32);
    return '$a-$b-$c';
  }

  void _broadcastSnapshots() {
    final List<MapEntry<int, String>> entries = _clientIdByPlayerId.entries
        .toList(growable: false);
    for (final MapEntry<int, String> entry in entries) {
      _sendToClient(entry.value, <String, dynamic>{
        'type': 'snapshot',
        'projection': projectionForPlayer(entry.key).toJson(),
      });
    }
  }

  void _sendToClient(String clientId, Map<String, dynamic> payload) {
    _send(<String, dynamic>{
      'type': 'host.message',
      'clientId': clientId,
      'payload': payload,
    });
  }

  void _emitState() {
    if (!_closingLocally) {
      _stateUpdates.add(runtime.state);
    }
  }

  void _emitError(String message) {
    if (!_closingLocally) {
      _errors.add(message);
    }
  }

  void _send(Map<String, dynamic> envelope) {
    if (_closingLocally) {
      return;
    }
    _channel.sink.add(jsonEncode(envelope));
  }

  Future<void> close({
    String reason = 'Host ended the session.',
    bool broadcastSessionClosed = true,
  }) async {
    if (_closingLocally) {
      return;
    }
    if (broadcastSessionClosed) {
      _send(<String, dynamic>{'type': 'host.close', 'message': reason});
    }
    _closingLocally = true;
    await _socketSub?.cancel();
    _socketSub = null;
    await _channel.sink.close();
    _playerIdByClientId.clear();
    _clientIdByPlayerId.clear();
    _playerIdByToken.clear();
    _tokenByPlayerId.clear();
    await _stateUpdates.close();
    await _errors.close();
  }
}

class HostedRelayClientConnection {
  HostedRelayClientConnection._({
    required WebSocketChannel channel,
    required String roomKey,
    required String pin,
    required String playerName,
    this.initialPlayerToken,
    this.requestedPlayerId,
  }) : _channel = channel,
       _roomKey = roomKey,
       _pin = pin,
       _playerName = playerName;

  final WebSocketChannel _channel;
  final String _roomKey;
  final String _pin;
  final String _playerName;
  final String? initialPlayerToken;
  final int? requestedPlayerId;
  final StreamController<HostedProjectedView> _projectionUpdates =
      StreamController<HostedProjectedView>.broadcast();
  final StreamController<HostedClientIssue> _issues =
      StreamController<HostedClientIssue>.broadcast();
  final Completer<void> _joined = Completer<void>();
  HostedProjectedView? _projection;
  int? _playerId;
  String? _playerToken;
  bool _sessionClosedReceived = false;
  bool _closingLocally = false;
  StreamSubscription<dynamic>? _socketSub;

  Stream<HostedProjectedView> get projectionUpdates =>
      _projectionUpdates.stream;
  Stream<HostedClientIssue> get issues => _issues.stream;
  HostedProjectedView? get projection => _projection;
  int? get playerId => _playerId;
  String? get playerToken => _playerToken;

  static Future<HostedRelayClientConnection> connect({
    required Uri relayUri,
    required String roomKey,
    required String pin,
    required String playerName,
    String? playerToken,
    int? requestedPlayerId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final HostedRelayClientConnection connection =
        HostedRelayClientConnection._(
          channel: WebSocketChannel.connect(relayUri),
          roomKey: roomKey,
          pin: pin,
          playerName: playerName,
          initialPlayerToken: playerToken,
          requestedPlayerId: requestedPlayerId,
        );
    connection._listen();
    connection._sendJoin();
    try {
      await connection._joined.future.timeout(timeout);
    } catch (_) {
      await connection.close();
      rethrow;
    }
    return connection;
  }

  void _listen() {
    _socketSub = _channel.stream.listen(
      (dynamic raw) {
        if (raw is! String) {
          _emitIssue(
            const HostedClientIssue(
              code: HostedClientIssueCode.genericError,
              message: 'Invalid message from relay.',
            ),
          );
          return;
        }
        _handleLine(raw);
      },
      onError: (Object error) {
        if (_closingLocally) {
          return;
        }
        final bool joinPending = !_joined.isCompleted;
        final String details = error.toString();
        _emitIssue(
          HostedClientIssue(
            code: joinPending
                ? HostedClientIssueCode.hostUnavailable
                : HostedClientIssueCode.disconnected,
            message: joinPending
                ? 'Could not connect to relay: $details'
                : 'Relay connection error: $details',
          ),
        );
        if (joinPending) {
          _joined.completeError('Relay connection error: $details');
        }
      },
      onDone: () {
        if (_sessionClosedReceived || _closingLocally) {
          return;
        }
        _emitIssue(
          const HostedClientIssue(
            code: HostedClientIssueCode.disconnected,
            message: 'Disconnected from relay.',
          ),
        );
        if (!_joined.isCompleted) {
          _joined.completeError(
            'Disconnected from relay before join completed.',
          );
        }
      },
      cancelOnError: true,
    );
  }

  void _sendJoin() {
    _send(<String, dynamic>{
      'type': 'player.join',
      'roomKey': _roomKey,
      'payload': <String, dynamic>{
        'type': 'join',
        'pin': _pin,
        'name': _playerName,
        if (initialPlayerToken != null && initialPlayerToken!.trim().isNotEmpty)
          'playerToken': initialPlayerToken!.trim(),
        if (requestedPlayerId != null) 'requestedPlayerId': requestedPlayerId,
      },
    });
  }

  void _handleLine(String line) {
    final Map<String, dynamic>? envelope = _decodeObject(line);
    if (envelope == null) {
      _emitIssue(
        const HostedClientIssue(
          code: HostedClientIssueCode.genericError,
          message: 'Invalid message from relay.',
        ),
      );
      return;
    }
    final String? type = envelope['type'] as String?;
    if (type == null) {
      return;
    }
    switch (type) {
      case 'relay.joined':
        break;
      case 'joined':
        _playerId = envelope['playerId'] as int?;
        _playerToken = envelope['playerToken'] as String? ?? _playerToken;
        final Map<String, dynamic>? projectionMap =
            envelope['projection'] as Map<String, dynamic>?;
        if (projectionMap != null) {
          final HostedProjectedView? projection = _parseProjection(
            projectionMap,
            joinPending: true,
          );
          if (projection == null) {
            return;
          }
          _projection = projection;
          _emitProjection(projection);
        }
        if (!_joined.isCompleted) {
          _joined.complete();
        }
        break;
      case 'snapshot':
        final Map<String, dynamic>? projectionMap =
            envelope['projection'] as Map<String, dynamic>?;
        if (projectionMap == null) {
          break;
        }
        final HostedProjectedView? projection = _parseProjection(
          projectionMap,
          joinPending: false,
        );
        if (projection == null) {
          break;
        }
        _projection = projection;
        _emitProjection(projection);
        break;
      case 'error':
        final String message = envelope['message'] as String? ?? 'Relay error.';
        final bool joinPending = !_joined.isCompleted;
        _emitIssue(
          HostedClientIssue(
            code: joinPending
                ? HostedClientIssueCode.hostUnavailable
                : HostedClientIssueCode.genericError,
            message: message,
          ),
        );
        if (joinPending) {
          _joined.completeError(message);
          _closingLocally = true;
          unawaited(_channel.sink.close());
        }
        break;
      case 'session_closed':
        final String message =
            envelope['message'] as String? ?? 'Session closed by host.';
        _sessionClosedReceived = true;
        _emitIssue(
          HostedClientIssue(
            code: HostedClientIssueCode.sessionClosed,
            message: message,
          ),
        );
        if (!_joined.isCompleted) {
          _joined.completeError(message);
        }
        break;
      case 'pong':
        break;
      default:
        break;
    }
  }

  HostedProjectedView? _parseProjection(
    Map<String, dynamic> projectionMap, {
    required bool joinPending,
  }) {
    try {
      return HostedProjectedView.fromJson(projectionMap);
    } catch (_) {
      const String message = 'Invalid projection from host.';
      _emitIssue(
        HostedClientIssue(
          code: joinPending
              ? HostedClientIssueCode.hostUnavailable
              : HostedClientIssueCode.genericError,
          message: message,
        ),
      );
      if (joinPending && !_joined.isCompleted) {
        _joined.completeError(message);
        _closingLocally = true;
        unawaited(_channel.sink.close());
      }
      return null;
    }
  }

  void sendCommand(HostedSessionCommand command) {
    if (_playerId == null) {
      _emitIssue(
        const HostedClientIssue(
          code: HostedClientIssueCode.genericError,
          message: 'Join not completed yet.',
        ),
      );
      return;
    }
    final HostedSessionCommand safeCommand = HostedSessionCommand(
      type: command.type,
      playerId: _playerId!,
      payload: command.payload,
    );
    _send(<String, dynamic>{
      'type': 'client.message',
      'payload': <String, dynamic>{
        'type': 'command',
        'command': safeCommand.toJson(),
      },
    });
  }

  void _send(Map<String, dynamic> envelope) {
    if (_closingLocally) {
      return;
    }
    _channel.sink.add(jsonEncode(envelope));
  }

  Future<void> close() async {
    if (_closingLocally) {
      return;
    }
    _closingLocally = true;
    await _socketSub?.cancel();
    _socketSub = null;
    await _channel.sink.close();
    await _projectionUpdates.close();
    await _issues.close();
  }

  void _emitProjection(HostedProjectedView projection) {
    if (!_closingLocally) {
      _projectionUpdates.add(projection);
    }
  }

  void _emitIssue(HostedClientIssue issue) {
    if (!_closingLocally) {
      _issues.add(issue);
    }
  }
}

Map<String, dynamic>? _decodeObject(String raw) {
  try {
    final Object? value = jsonDecode(raw);
    return value is Map<String, dynamic> ? value : null;
  } catch (_) {
    return null;
  }
}
