import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bussruta_app/application/hosted_session_runtime.dart';
import 'package:bussruta_app/application/hosted_transport_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:bussruta_app/domain/hosted_projection.dart';

export 'hosted_transport_models.dart';

const String _announcementType = 'bussruta-host-v1';
const int _maxHostedLanMessageBytes = 64 * 1024;
const int _lineFeed = 10;
const int _carriageReturn = 13;
const int _playerTokenRandomMax = 0x100000000;

StreamSubscription<List<int>> _listenForHostedLanLines({
  required Socket socket,
  required void Function(String line) onLine,
  required void Function(Object error) onError,
  required void Function() onDone,
}) {
  final List<int> pending = <int>[];
  bool closed = false;

  void closeForInvalidFrame() {
    if (closed) {
      return;
    }
    closed = true;
    onDone();
    socket.destroy();
  }

  return socket.cast<List<int>>().listen(
    (List<int> chunk) {
      if (closed) {
        return;
      }
      pending.addAll(chunk);
      while (!closed) {
        final int newlineIndex = pending.indexOf(_lineFeed);
        if (newlineIndex < 0) {
          if (pending.length > _maxHostedLanMessageBytes) {
            closeForInvalidFrame();
          }
          return;
        }
        if (newlineIndex > _maxHostedLanMessageBytes) {
          closeForInvalidFrame();
          return;
        }
        final List<int> lineBytes = pending.sublist(0, newlineIndex);
        pending.removeRange(0, newlineIndex + 1);
        if (lineBytes.isNotEmpty && lineBytes.last == _carriageReturn) {
          lineBytes.removeLast();
        }
        try {
          onLine(utf8.decode(lineBytes, allowMalformed: false));
        } catch (error) {
          if (!closed) {
            closed = true;
            onError(error);
            socket.destroy();
          }
          return;
        }
      }
    },
    onError: (Object error) {
      if (closed) {
        return;
      }
      closed = true;
      onError(error);
    },
    onDone: () {
      if (closed) {
        return;
      }
      closed = true;
      onDone();
    },
    cancelOnError: true,
  );
}

class HostedLanDiscovery {
  HostedLanDiscovery({int discoveryPort = hostedDiscoveryPort})
    : _discoveryPort = discoveryPort;

  final int _discoveryPort;
  RawDatagramSocket? _socket;
  Timer? _cleanupTimer;
  final Map<String, HostedDiscoveryEntry> _entriesByKey =
      <String, HostedDiscoveryEntry>{};
  final StreamController<List<HostedDiscoveryEntry>> _updates =
      StreamController<List<HostedDiscoveryEntry>>.broadcast();

  Stream<List<HostedDiscoveryEntry>> get updates => _updates.stream;

  int get port => _socket?.port ?? _discoveryPort;

  List<HostedDiscoveryEntry> get entries {
    final List<HostedDiscoveryEntry> list = _entriesByKey.values.toList();
    list.sort(
      (HostedDiscoveryEntry a, HostedDiscoveryEntry b) =>
          b.lastSeenUtcMillis.compareTo(a.lastSeenUtcMillis),
    );
    return list;
  }

  Future<void> start() async {
    if (_socket != null) {
      return;
    }
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _discoveryPort,
      reuseAddress: true,
      reusePort: !(Platform.isWindows || Platform.isAndroid),
    );
    _socket!.listen(_onSocketEvent);
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pruneStaleEntries(),
    );
  }

  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _socket == null) {
      return;
    }
    while (true) {
      final Datagram? datagram = _socket!.receive();
      if (datagram == null) {
        break;
      }
      final HostedDiscoveryEntry? entry = _decodeDiscoveryDatagram(datagram);
      if (entry == null) {
        continue;
      }
      final String key = '${entry.hostAddress}:${entry.hostPort}:${entry.pin}';
      _entriesByKey[key] = entry;
      _emit();
    }
  }

  HostedDiscoveryEntry? _decodeDiscoveryDatagram(Datagram datagram) {
    try {
      final Map<String, dynamic> json =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (json['type'] != _announcementType) {
        return null;
      }
      final String pin = (json['pin'] as String? ?? '').trim();
      final int port = json['port'] as int? ?? 0;
      final String hostAddress = datagram.address.address.trim();
      if (pin.isEmpty || port <= 0 || hostAddress.isEmpty) {
        return null;
      }
      return HostedDiscoveryEntry(
        pin: pin,
        hostName: (json['name'] as String? ?? 'Host').trim(),
        hostAddress: hostAddress,
        hostPort: port,
        lastSeenUtcMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  void _pruneStaleEntries() {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    bool changed = false;
    _entriesByKey.removeWhere((String _, HostedDiscoveryEntry value) {
      final bool stale = now - value.lastSeenUtcMillis > 6000;
      if (stale) {
        changed = true;
      }
      return stale;
    });
    if (changed) {
      _emit();
    }
  }

  void _emit() {
    _updates.add(entries);
  }

  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _socket?.close();
    _socket = null;
    _entriesByKey.clear();
    await _updates.close();
  }
}

class HostedLanHostServer {
  HostedLanHostServer({
    required this.runtime,
    required this.hostName,
    required this.pin,
  });

  final HostedSessionRuntime runtime;
  final String hostName;
  final String pin;
  final Random _random = Random.secure();

  ServerSocket? _server;
  RawDatagramSocket? _beaconSocket;
  Timer? _beaconTimer;
  int _nextPlayerId = 2;
  String? _hostAddress;
  final Map<Socket, int> _playerIdBySocket = <Socket, int>{};
  final Map<int, Socket> _socketByPlayerId = <int, Socket>{};
  final Map<String, int> _playerIdByToken = <String, int>{};
  final Map<int, String> _tokenByPlayerId = <int, String>{};
  final StreamController<HostedSessionState> _stateUpdates =
      StreamController<HostedSessionState>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();

  Stream<HostedSessionState> get stateUpdates => _stateUpdates.stream;
  Stream<String> get errors => _errors.stream;
  HostedSessionState get state => runtime.state;
  String? get hostAddress => _hostAddress;
  int get port => _server?.port ?? 0;

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      hostedSessionPort,
      shared: false,
    );
    _nextPlayerId = runtime.state.playerOrder.fold<int>(1, max<int>) + 1;
    _ensureTokenForPlayer(runtime.state.hostPlayerId);
    _server!.listen(_handleSocket);
    _hostAddress = await _resolveHostAddress();
    await _startBeacon();
    _emitState();
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

  void _handleSocket(Socket socket) {
    _listenForHostedLanLines(
      socket: socket,
      onLine: (String line) => _handleClientLine(socket, line),
      onError: (_) => _handleDisconnect(socket),
      onDone: () => _handleDisconnect(socket),
    );
  }

  void _handleClientLine(Socket socket, String line) {
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      _send(socket, <String, dynamic>{
        'type': 'error',
        'message': 'Invalid JSON payload.',
      });
      return;
    }
    final String? type = envelope['type'] as String?;
    if (type == null) {
      _send(socket, <String, dynamic>{
        'type': 'error',
        'message': 'Missing message type.',
      });
      return;
    }
    switch (type) {
      case 'join':
        _handleJoin(socket, envelope);
        break;
      case 'command':
        _handleCommand(socket, envelope);
        break;
      case 'ping':
        _send(socket, <String, dynamic>{'type': 'pong'});
        break;
      default:
        _send(socket, <String, dynamic>{
          'type': 'error',
          'message': 'Unknown message type.',
        });
        break;
    }
  }

  void _handleJoin(Socket socket, Map<String, dynamic> envelope) {
    final String incomingPin = (envelope['pin'] as String? ?? '').trim();
    if (incomingPin != pin) {
      _send(socket, <String, dynamic>{
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
      _send(socket, <String, dynamic>{
        'type': 'error',
        'message': 'Reconnect token required for seat reclaim.',
      });
      return;
    }
    if (incomingToken != null && incomingToken.isNotEmpty) {
      final int? mappedId = _playerIdByToken[incomingToken];
      if (mappedId == null) {
        if (requestedPlayerId != null) {
          _send(socket, <String, dynamic>{
            'type': 'error',
            'message': 'Invalid reconnect token.',
          });
          return;
        }
      } else {
        if (requestedPlayerId != null && requestedPlayerId != mappedId) {
          _send(socket, <String, dynamic>{
            'type': 'error',
            'message': 'Reconnect token does not match requested seat.',
          });
          return;
        }
        _reclaimSeat(
          socket: socket,
          playerId: mappedId,
          playerToken: incomingToken,
        );
        return;
      }
    }

    final int playerId = _nextPlayerId;
    _nextPlayerId += 1;

    runtime.addParticipant(
      playerId: playerId,
      name: name.isEmpty ? 'Player $playerId' : name,
      connected: true,
    );
    if (runtime.state.participantById(playerId) == null) {
      _send(socket, <String, dynamic>{
        'type': 'error',
        'message': runtime.state.lastError ?? 'Could not join this session.',
      });
      return;
    }

    final String playerToken = _ensureTokenForPlayer(playerId);
    _playerIdBySocket[socket] = playerId;
    _socketByPlayerId[playerId] = socket;
    _send(socket, <String, dynamic>{
      'type': 'joined',
      'playerId': playerId,
      'playerToken': playerToken,
      'reconnected': false,
      'projection': projectionForPlayer(playerId).toJson(),
    });
    _emitState();
    _broadcastSnapshots(exceptPlayerId: playerId);
  }

  void _handleCommand(Socket socket, Map<String, dynamic> envelope) {
    final int? playerId = _playerIdBySocket[socket];
    if (playerId == null) {
      _send(socket, <String, dynamic>{
        'type': 'error',
        'message': 'Join the session before sending commands.',
      });
      return;
    }
    final Object? rawCommand = envelope['command'];
    if (rawCommand is! Map<String, dynamic>) {
      _send(socket, <String, dynamic>{
        'type': 'error',
        'message': 'Missing hosted command payload.',
      });
      return;
    }

    HostedSessionCommand parsed;
    try {
      parsed = HostedSessionCommand.fromJson(rawCommand);
    } catch (_) {
      _send(socket, <String, dynamic>{
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
      _send(socket, <String, dynamic>{
        'type': 'error',
        'message': runtime.state.lastError,
      });
    }
    _emitState();
    _broadcastSnapshots();
  }

  void _handleDisconnect(Socket socket) {
    final int? playerId = _playerIdBySocket.remove(socket);
    if (playerId == null) {
      socket.destroy();
      return;
    }
    _socketByPlayerId.remove(playerId);
    runtime.updateParticipantConnection(playerId: playerId, connected: false);
    _emitState();
    _broadcastSnapshots();
    socket.destroy();
  }

  void _reclaimSeat({
    required Socket socket,
    required int playerId,
    required String playerToken,
  }) {
    final HostedParticipant? participant = runtime.state.participantById(
      playerId,
    );
    if (participant == null) {
      _send(socket, <String, dynamic>{
        'type': 'error',
        'message': 'Requested seat is not available.',
      });
      return;
    }
    if (participant.isHost) {
      _send(socket, <String, dynamic>{
        'type': 'error',
        'message': 'Host seat cannot be reclaimed by client.',
      });
      return;
    }

    final Socket? previousSocket = _socketByPlayerId[playerId];
    if (previousSocket != null && previousSocket != socket) {
      _playerIdBySocket.remove(previousSocket);
      previousSocket.destroy();
    }
    _playerIdBySocket[socket] = playerId;
    _socketByPlayerId[playerId] = socket;
    runtime.updateParticipantConnection(playerId: playerId, connected: true);

    _send(socket, <String, dynamic>{
      'type': 'joined',
      'playerId': playerId,
      'playerToken': playerToken,
      'reconnected': true,
      'projection': projectionForPlayer(playerId).toJson(),
    });
    _emitState();
    _broadcastSnapshots(exceptPlayerId: playerId);
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
    final int a = _random.nextInt(_playerTokenRandomMax);
    final int b = _random.nextInt(_playerTokenRandomMax);
    final int c = _random.nextInt(_playerTokenRandomMax);
    return '$a-$b-$c';
  }

  Future<void> _startBeacon() async {
    _beaconSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
    _beaconSocket!.broadcastEnabled = true;
    _beaconTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sendBeacon();
    });
    _sendBeacon();
  }

  void _sendBeacon() {
    if (_beaconSocket == null || _server == null) {
      return;
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      'type': _announcementType,
      'name': hostName,
      'pin': pin,
      'port': _server!.port,
      'hostAddress': _hostAddress,
      'timestampUtcMillis': DateTime.now().toUtc().millisecondsSinceEpoch,
    };
    final List<int> bytes = utf8.encode(jsonEncode(payload));
    _beaconSocket!.send(
      bytes,
      InternetAddress('255.255.255.255'),
      hostedDiscoveryPort,
    );
  }

  void _broadcastSnapshots({int? exceptPlayerId}) {
    final List<MapEntry<int, Socket>> entries = _socketByPlayerId.entries
        .toList(growable: false);
    if (entries.isEmpty) {
      return;
    }
    final HostedSessionState session = runtime.state;
    final HostedPublicView publicView = projectHostedPublicView(
      session: session,
    );
    final Map<String, dynamic> publicViewJson = publicView.toJson();
    for (final MapEntry<int, Socket> entry in entries) {
      if (entry.key == exceptPlayerId) {
        continue;
      }
      final HostedProjectedView projection = projectHostedView(
        session: session,
        viewerPlayerId: entry.key,
        publicView: publicView,
      );
      _send(entry.value, <String, dynamic>{
        'type': 'snapshot',
        'projection': projection.toJson(publicViewJson: publicViewJson),
      });
    }
  }

  void _emitState() {
    _stateUpdates.add(runtime.state);
  }

  Future<String?> _resolveHostAddress() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      String? fallback;
      for (final NetworkInterface iface in interfaces) {
        for (final InternetAddress address in iface.addresses) {
          final String value = address.address;
          if (value.startsWith('169.254.')) {
            continue;
          }
          if (_isPrivateIpv4(value)) {
            return value;
          }
          fallback ??= value;
        }
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  bool _isPrivateIpv4(String address) {
    if (address.startsWith('10.') || address.startsWith('192.168.')) {
      return true;
    }
    if (!address.startsWith('172.')) {
      return false;
    }
    final List<String> parts = address.split('.');
    if (parts.length < 2) {
      return false;
    }
    final int? second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  void _send(Socket socket, Map<String, dynamic> payload) {
    try {
      socket.writeln(jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> close({
    String reason = 'Host ended the session.',
    bool broadcastSessionClosed = true,
  }) async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _beaconSocket?.close();
    _beaconSocket = null;
    final List<Socket> sockets = _socketByPlayerId.values.toList(
      growable: false,
    );
    if (broadcastSessionClosed) {
      for (final Socket socket in sockets) {
        _send(socket, <String, dynamic>{
          'type': 'session_closed',
          'message': reason,
        });
      }
      for (final Socket socket in sockets) {
        try {
          await socket.flush();
        } catch (_) {}
      }
    }
    for (final Socket socket in sockets) {
      try {
        await socket.close();
      } catch (_) {
        socket.destroy();
      }
    }
    _socketByPlayerId.clear();
    _playerIdBySocket.clear();
    _playerIdByToken.clear();
    _tokenByPlayerId.clear();
    await _server?.close();
    _server = null;
    await _stateUpdates.close();
    await _errors.close();
  }
}

class HostedLanClientConnection {
  HostedLanClientConnection._({
    required Socket socket,
    required String pin,
    required String playerName,
    this.initialPlayerToken,
    this.requestedPlayerId,
  }) : _socket = socket,
       _pin = pin,
       _playerName = playerName;

  final Socket _socket;
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
  StreamSubscription<List<int>>? _socketSub;

  Stream<HostedProjectedView> get projectionUpdates =>
      _projectionUpdates.stream;
  Stream<HostedClientIssue> get issues => _issues.stream;
  HostedProjectedView? get projection => _projection;
  int? get playerId => _playerId;
  String? get playerToken => _playerToken;

  static Future<HostedLanClientConnection> connect({
    required String hostAddress,
    required int hostPort,
    required String pin,
    required String playerName,
    String? playerToken,
    int? requestedPlayerId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final Socket socket = await Socket.connect(
      hostAddress,
      hostPort,
      timeout: timeout,
    );
    final HostedLanClientConnection connection = HostedLanClientConnection._(
      socket: socket,
      pin: pin,
      playerName: playerName,
      initialPlayerToken: playerToken,
      requestedPlayerId: requestedPlayerId,
    );
    connection._listen();
    connection._sendJoin();
    await connection._joined.future.timeout(timeout);
    return connection;
  }

  void _listen() {
    _socketSub = _listenForHostedLanLines(
      socket: _socket,
      onLine: _handleLine,
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
                ? 'Could not connect to host: $details'
                : 'Connection error: $details',
          ),
        );
        if (joinPending) {
          _joined.completeError('Connection error: $details');
        }
      },
      onDone: () {
        if (_sessionClosedReceived || _closingLocally) {
          return;
        }
        _emitIssue(
          const HostedClientIssue(
            code: HostedClientIssueCode.disconnected,
            message: 'Disconnected from host.',
          ),
        );
        if (!_joined.isCompleted) {
          _joined.completeError(
            'Disconnected from host before join completed.',
          );
        }
      },
    );
  }

  void _sendJoin() {
    _send(<String, dynamic>{
      'type': 'join',
      'pin': _pin,
      'name': _playerName,
      if (initialPlayerToken != null && initialPlayerToken!.trim().isNotEmpty)
        'playerToken': initialPlayerToken!.trim(),
      if (requestedPlayerId != null) 'requestedPlayerId': requestedPlayerId,
    });
  }

  void _handleLine(String line) {
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      _emitIssue(
        const HostedClientIssue(
          code: HostedClientIssueCode.genericError,
          message: 'Invalid message from host.',
        ),
      );
      return;
    }
    final String? type = envelope['type'] as String?;
    if (type == null) {
      return;
    }
    switch (type) {
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
        final String message = envelope['message'] as String? ?? 'Host error.';
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
          _socket.destroy();
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
        _socket.destroy();
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
      'type': 'command',
      'command': safeCommand.toJson(),
    });
  }

  void _send(Map<String, dynamic> envelope) {
    if (_closingLocally) {
      return;
    }
    try {
      _socket.writeln(jsonEncode(envelope));
    } catch (_) {
      _emitIssue(
        const HostedClientIssue(
          code: HostedClientIssueCode.disconnected,
          message: 'Disconnected from host.',
        ),
      );
    }
  }

  Future<void> close() async {
    if (_closingLocally) {
      return;
    }
    _closingLocally = true;
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _socket.flush();
      await _socket.close();
    } catch (_) {}
    await _projectionUpdates.close();
    await _issues.close();
  }

  void _emitProjection(HostedProjectedView projection) {
    if (_closingLocally) {
      return;
    }
    try {
      _projectionUpdates.add(projection);
    } catch (_) {}
  }

  void _emitIssue(HostedClientIssue issue) {
    if (_closingLocally) {
      return;
    }
    try {
      _issues.add(issue);
    } catch (_) {}
  }
}
