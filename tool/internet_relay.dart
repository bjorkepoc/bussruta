import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const int defaultInternetRelayPort = 8080;
const int maxInternetRelayMessageBytes = 64 * 1024;

Future<void> main(List<String> args) async {
  final InternetRelayServer server = InternetRelayServer();
  final int port = _portFromArgs(args);
  await server.start(address: InternetAddress.anyIPv4, port: port);
  stdout.writeln('Bussruta internet relay listening on ${server.uri}');
  stdout.writeln('Press Ctrl+C to stop.');

  final Completer<void> stop = Completer<void>();
  late final StreamSubscription<ProcessSignal> sigintSub;
  sigintSub = ProcessSignal.sigint.watch().listen((_) {
    if (!stop.isCompleted) {
      stop.complete();
    }
  });

  await stop.future;
  await sigintSub.cancel();
  await server.close();
}

int _portFromArgs(List<String> args) {
  for (int i = 0; i < args.length; i += 1) {
    if (args[i] == '--port' && i + 1 < args.length) {
      return int.parse(args[i + 1]);
    }
  }
  final String? envPort = Platform.environment['PORT'];
  if (envPort != null && envPort.trim().isNotEmpty) {
    return int.parse(envPort);
  }
  return defaultInternetRelayPort;
}

class InternetRelayServer {
  InternetRelayServer({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  final Map<String, _RelayRoom> _rooms = <String, _RelayRoom>{};
  HttpServer? _server;
  int _nextClientId = 1;

  Uri get uri {
    final HttpServer? server = _server;
    if (server == null) {
      throw StateError('InternetRelayServer has not been started.');
    }
    final InternetAddress address = server.address;
    final String host = address == InternetAddress.anyIPv4
        ? InternetAddress.loopbackIPv4.address
        : address.address;
    return Uri(scheme: 'ws', host: host, port: server.port, path: '/ws');
  }

  Future<void> start({InternetAddress? address, int port = 0}) async {
    if (_server != null) {
      return;
    }
    _server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    _server!.listen(_handleRequest);
  }

  Future<void> close() async {
    for (final _RelayRoom room in _rooms.values.toList(growable: false)) {
      await room.close('Relay server stopped.');
    }
    _rooms.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != '/ws' ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final WebSocket socket = await WebSocketTransformer.upgrade(request);
    _RelayPeer? peer;
    socket.listen(
      (dynamic raw) {
        if (raw is! String) {
          _sendError(socket, 'Only text JSON messages are supported.');
          return;
        }
        if (utf8.encode(raw).length > maxInternetRelayMessageBytes) {
          _sendError(socket, 'Relay message exceeds size limit.');
          socket.close(WebSocketStatus.messageTooBig, 'Message too large.');
          return;
        }
        _handleMessage(
          socket,
          raw,
          currentPeer: peer,
          setPeer: (value) {
            peer = value;
          },
        );
      },
      onDone: () => _handlePeerClosed(peer),
      onError: (_) => _handlePeerClosed(peer),
      cancelOnError: true,
    );
  }

  void _handleMessage(
    WebSocket socket,
    String raw, {
    required _RelayPeer? currentPeer,
    required void Function(_RelayPeer peer) setPeer,
  }) {
    final Map<String, dynamic>? message = _decodeObject(raw);
    if (message == null) {
      _sendError(socket, 'Invalid JSON object.');
      return;
    }
    final String type = message['type'] as String? ?? '';
    switch (type) {
      case 'host.create':
        if (currentPeer != null) {
          _sendError(socket, 'Socket is already registered.');
          return;
        }
        final _RelayPeer? host = _createRoom(socket, message);
        if (host != null) {
          setPeer(host);
        }
        return;
      case 'player.join':
        if (currentPeer != null) {
          _sendError(socket, 'Socket is already registered.');
          return;
        }
        final _RelayPeer? client = _joinRoom(socket, message);
        if (client != null) {
          setPeer(client);
        }
        return;
      case 'client.message':
        if (currentPeer == null) {
          _sendError(socket, 'Socket is not registered.');
          return;
        }
        _forwardClientMessage(currentPeer, message);
        return;
      case 'host.message':
        if (currentPeer == null) {
          _sendError(socket, 'Socket is not registered.');
          return;
        }
        _forwardHostMessage(currentPeer, message);
        return;
      case 'host.broadcast':
        if (currentPeer == null) {
          _sendError(socket, 'Socket is not registered.');
          return;
        }
        _broadcastHostMessage(currentPeer, message);
        return;
      case 'host.close':
        if (currentPeer == null) {
          _sendError(socket, 'Socket is not registered.');
          return;
        }
        _closeHostRoom(currentPeer, message);
        return;
      default:
        _sendError(socket, 'Unknown relay message type.');
        return;
    }
  }

  _RelayPeer? _createRoom(WebSocket socket, Map<String, dynamic> message) {
    final String requestedKey = (message['roomKey'] as String? ?? '').trim();
    final String roomKey = requestedKey.isEmpty ? _newRoomKey() : requestedKey;
    if (_rooms.containsKey(roomKey)) {
      _sendError(socket, 'Room already exists.');
      return null;
    }
    final _RelayPeer host = _RelayPeer.host(socket: socket, roomKey: roomKey);
    _rooms[roomKey] = _RelayRoom(roomKey: roomKey, host: host);
    _send(socket, <String, dynamic>{
      'type': 'room.created',
      'roomKey': roomKey,
    });
    return host;
  }

  _RelayPeer? _joinRoom(WebSocket socket, Map<String, dynamic> message) {
    final String roomKey = (message['roomKey'] as String? ?? '').trim();
    final _RelayRoom? room = _rooms[roomKey];
    if (room == null || room.host.socket.closeCode != null) {
      _sendError(socket, 'Room not found.');
      return null;
    }
    final String clientId = 'client-${_nextClientId++}';
    final _RelayPeer client = _RelayPeer.client(
      socket: socket,
      roomKey: roomKey,
      clientId: clientId,
    );
    room.clients[clientId] = client;
    _send(socket, <String, dynamic>{
      'type': 'relay.joined',
      'roomKey': roomKey,
      'clientId': clientId,
    });
    _send(room.host.socket, <String, dynamic>{
      'type': 'client.connected',
      'clientId': clientId,
    });
    final Object? payload = message['payload'];
    if (payload is Map<String, dynamic>) {
      _send(room.host.socket, <String, dynamic>{
        'type': 'client.message',
        'clientId': clientId,
        'payload': payload,
      });
    }
    return client;
  }

  void _forwardClientMessage(_RelayPeer? peer, Map<String, dynamic> message) {
    if (peer == null || peer.clientId == null) {
      _sendError(peer?.socket, 'Only clients can send client messages.');
      return;
    }
    final _RelayRoom? room = _rooms[peer.roomKey];
    if (room == null) {
      _sendError(peer.socket, 'Room no longer exists.');
      return;
    }
    final Object? payload = message['payload'];
    if (payload is! Map<String, dynamic>) {
      _sendError(peer.socket, 'Missing client message payload.');
      return;
    }
    _send(room.host.socket, <String, dynamic>{
      'type': 'client.message',
      'clientId': peer.clientId,
      'payload': payload,
    });
  }

  void _forwardHostMessage(_RelayPeer? peer, Map<String, dynamic> message) {
    if (peer == null || !peer.isHost) {
      _sendError(peer?.socket, 'Only host can send host messages.');
      return;
    }
    final _RelayRoom? room = _rooms[peer.roomKey];
    final String clientId = message['clientId'] as String? ?? '';
    final Object? payload = message['payload'];
    if (room == null || payload is! Map<String, dynamic>) {
      _sendError(peer.socket, 'Missing host message payload.');
      return;
    }
    final _RelayPeer? client = room.clients[clientId];
    if (client == null) {
      _sendError(peer.socket, 'Client not found.');
      return;
    }
    _send(client.socket, payload);
  }

  void _broadcastHostMessage(_RelayPeer? peer, Map<String, dynamic> message) {
    if (peer == null || !peer.isHost) {
      _sendError(peer?.socket, 'Only host can broadcast messages.');
      return;
    }
    final _RelayRoom? room = _rooms[peer.roomKey];
    final Object? payload = message['payload'];
    if (room == null || payload is! Map<String, dynamic>) {
      _sendError(peer.socket, 'Missing broadcast payload.');
      return;
    }
    for (final _RelayPeer client in room.clients.values) {
      _send(client.socket, payload);
    }
  }

  void _closeHostRoom(_RelayPeer? peer, Map<String, dynamic> message) {
    if (peer == null || !peer.isHost) {
      _sendError(peer?.socket, 'Only host can close a room.');
      return;
    }
    final _RelayRoom? room = _rooms.remove(peer.roomKey);
    if (room == null) {
      return;
    }
    final String reason =
        message['message'] as String? ?? 'Host ended the session.';
    unawaited(room.close(reason));
  }

  void _handlePeerClosed(_RelayPeer? peer) {
    if (peer == null) {
      return;
    }
    final _RelayRoom? room = _rooms[peer.roomKey];
    if (room == null) {
      return;
    }
    if (peer.isHost) {
      _rooms.remove(peer.roomKey);
      unawaited(room.close('Host disconnected.'));
      return;
    }
    room.clients.remove(peer.clientId);
    _send(room.host.socket, <String, dynamic>{
      'type': 'client.disconnected',
      'clientId': peer.clientId,
    });
  }

  String _newRoomKey() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    for (int attempt = 0; attempt < 100; attempt += 1) {
      final String key = List<String>.generate(
        6,
        (_) => alphabet[_random.nextInt(alphabet.length)],
      ).join();
      if (!_rooms.containsKey(key)) {
        return key;
      }
    }
    throw StateError('Could not allocate a relay room key.');
  }
}

class _RelayRoom {
  _RelayRoom({required this.roomKey, required this.host});

  final String roomKey;
  final _RelayPeer host;
  final Map<String, _RelayPeer> clients = <String, _RelayPeer>{};

  Future<void> close(String reason) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'type': 'session_closed',
      'message': reason,
    };
    for (final _RelayPeer client in clients.values.toList(growable: false)) {
      _send(client.socket, payload);
      await client.socket.close(WebSocketStatus.normalClosure, reason);
    }
    clients.clear();
    await host.socket.close(WebSocketStatus.normalClosure, reason);
  }
}

class _RelayPeer {
  const _RelayPeer.host({required this.socket, required this.roomKey})
    : clientId = null;

  const _RelayPeer.client({
    required this.socket,
    required this.roomKey,
    required this.clientId,
  });

  final WebSocket socket;
  final String roomKey;
  final String? clientId;

  bool get isHost => clientId == null;
}

Map<String, dynamic>? _decodeObject(String raw) {
  try {
    final Object? value = jsonDecode(raw);
    return value is Map<String, dynamic> ? value : null;
  } catch (_) {
    return null;
  }
}

void _send(WebSocket socket, Map<String, dynamic> payload) {
  if (socket.closeCode != null) {
    return;
  }
  socket.add(jsonEncode(payload));
}

void _sendError(WebSocket? socket, String message) {
  if (socket == null || socket.closeCode != null) {
    return;
  }
  _send(socket, <String, dynamic>{'type': 'error', 'message': message});
}
