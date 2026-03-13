import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bussruta_app/application/hosted_session_runtime.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:bussruta_app/domain/hosted_projection.dart';

const int hostedDiscoveryPort = 45878;
const String _announcementType = 'bussruta-host-v1';

class HostedDiscoveryEntry {
  const HostedDiscoveryEntry({
    required this.pin,
    required this.hostName,
    required this.hostAddress,
    required this.hostPort,
    required this.lastSeenUtcMillis,
  });

  final String pin;
  final String hostName;
  final String hostAddress;
  final int hostPort;
  final int lastSeenUtcMillis;

  HostedDiscoveryEntry copyWith({
    String? pin,
    String? hostName,
    String? hostAddress,
    int? hostPort,
    int? lastSeenUtcMillis,
  }) {
    return HostedDiscoveryEntry(
      pin: pin ?? this.pin,
      hostName: hostName ?? this.hostName,
      hostAddress: hostAddress ?? this.hostAddress,
      hostPort: hostPort ?? this.hostPort,
      lastSeenUtcMillis: lastSeenUtcMillis ?? this.lastSeenUtcMillis,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pin': pin,
      'hostName': hostName,
      'hostAddress': hostAddress,
      'hostPort': hostPort,
      'lastSeenUtcMillis': lastSeenUtcMillis,
    };
  }
}

class HostedLanDiscovery {
  RawDatagramSocket? _socket;
  Timer? _cleanupTimer;
  final Map<String, HostedDiscoveryEntry> _entriesByKey =
      <String, HostedDiscoveryEntry>{};
  final StreamController<List<HostedDiscoveryEntry>> _updates =
      StreamController<List<HostedDiscoveryEntry>>.broadcast();

  Stream<List<HostedDiscoveryEntry>> get updates => _updates.stream;

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
      hostedDiscoveryPort,
      reuseAddress: true,
      reusePort: true,
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
      if (pin.isEmpty || port <= 0) {
        return null;
      }
      return HostedDiscoveryEntry(
        pin: pin,
        hostName: (json['name'] as String? ?? 'Host').trim(),
        hostAddress: datagram.address.address,
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

  ServerSocket? _server;
  RawDatagramSocket? _beaconSocket;
  Timer? _beaconTimer;
  int _nextPlayerId = 2;
  String? _hostAddress;
  final Map<Socket, int> _playerIdBySocket = <Socket, int>{};
  final Map<int, Socket> _socketByPlayerId = <int, Socket>{};
  final StreamController<HostedSessionState> _stateUpdates =
      StreamController<HostedSessionState>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();

  Stream<HostedSessionState> get stateUpdates => _stateUpdates.stream;
  Stream<String> get errors => _errors.stream;
  HostedSessionState get state => runtime.state;
  int get port => _server?.port ?? 0;

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
      shared: false,
    );
    _nextPlayerId = runtime.state.playerOrder.fold<int>(1, max<int>) + 1;
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
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (String line) => _handleClientLine(socket, line),
          onError: (_) => _handleDisconnect(socket),
          onDone: () => _handleDisconnect(socket),
          cancelOnError: true,
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
    final int playerId = _nextPlayerId;
    _nextPlayerId += 1;

    runtime.addParticipant(
      playerId: playerId,
      name: name.isEmpty ? 'Player $playerId' : name,
      connected: true,
    );
    _playerIdBySocket[socket] = playerId;
    _socketByPlayerId[playerId] = socket;
    _send(socket, <String, dynamic>{
      'type': 'joined',
      'playerId': playerId,
      'projection': projectionForPlayer(playerId).toJson(),
    });
    _emitState();
    _broadcastSnapshots();
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

  void _broadcastSnapshots() {
    final List<MapEntry<int, Socket>> entries = _socketByPlayerId.entries
        .toList(growable: false);
    for (final MapEntry<int, Socket> entry in entries) {
      _send(entry.value, <String, dynamic>{
        'type': 'snapshot',
        'projection': projectionForPlayer(entry.key).toJson(),
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
      for (final NetworkInterface iface in interfaces) {
        for (final InternetAddress address in iface.addresses) {
          if (address.address.startsWith('169.254.')) {
            continue;
          }
          return address.address;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _send(Socket socket, Map<String, dynamic> payload) {
    try {
      socket.writeln(jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> close() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _beaconSocket?.close();
    _beaconSocket = null;
    for (final Socket socket in _socketByPlayerId.values) {
      socket.destroy();
    }
    _socketByPlayerId.clear();
    _playerIdBySocket.clear();
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
  }) : _socket = socket,
       _pin = pin,
       _playerName = playerName;

  final Socket _socket;
  final String _pin;
  final String _playerName;
  final StreamController<HostedProjectedView> _projectionUpdates =
      StreamController<HostedProjectedView>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();
  final Completer<void> _joined = Completer<void>();
  HostedProjectedView? _projection;
  int? _playerId;

  Stream<HostedProjectedView> get projectionUpdates =>
      _projectionUpdates.stream;
  Stream<String> get errors => _errors.stream;
  HostedProjectedView? get projection => _projection;
  int? get playerId => _playerId;

  static Future<HostedLanClientConnection> connect({
    required String hostAddress,
    required int hostPort,
    required String pin,
    required String playerName,
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
    );
    connection._listen();
    connection._sendJoin();
    await connection._joined.future.timeout(timeout);
    return connection;
  }

  void _listen() {
    _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleLine,
          onError: (_) {
            _errors.add('Connection error.');
          },
          onDone: () {
            _errors.add('Disconnected from host.');
          },
          cancelOnError: true,
        );
  }

  void _sendJoin() {
    _send(<String, dynamic>{'type': 'join', 'pin': _pin, 'name': _playerName});
  }

  void _handleLine(String line) {
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      _errors.add('Invalid message from host.');
      return;
    }
    final String? type = envelope['type'] as String?;
    if (type == null) {
      return;
    }
    switch (type) {
      case 'joined':
        _playerId = envelope['playerId'] as int?;
        final Map<String, dynamic>? projectionMap =
            envelope['projection'] as Map<String, dynamic>?;
        if (projectionMap != null) {
          _projection = HostedProjectedView.fromJson(projectionMap);
          _projectionUpdates.add(_projection!);
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
        _projection = HostedProjectedView.fromJson(projectionMap);
        _projectionUpdates.add(_projection!);
        break;
      case 'error':
        final String message = envelope['message'] as String? ?? 'Host error.';
        _errors.add(message);
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

  void sendCommand(HostedSessionCommand command) {
    if (_playerId == null) {
      _errors.add('Join not completed yet.');
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
    _socket.writeln(jsonEncode(envelope));
  }

  Future<void> close() async {
    await _socket.flush();
    await _socket.close();
    await _projectionUpdates.close();
    await _errors.close();
  }
}
