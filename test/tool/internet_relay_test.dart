import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/internet_relay.dart';

void main() {
  group('InternetRelayServer', () {
    test(
      'creates a room and relays messages between host and client',
      () async {
        final InternetRelayServer server = InternetRelayServer();
        await server.start();
        addTearDown(server.close);

        final WebSocket host = await WebSocket.connect(server.uri.toString());
        final StreamIterator<Map<String, dynamic>> hostMessages = _messages(
          host,
        );
        addTearDown(host.close);
        addTearDown(hostMessages.cancel);

        host.add(
          jsonEncode(<String, dynamic>{
            'type': 'host.create',
            'roomKey': 'ROOM42',
          }),
        );
        expect(await _next(hostMessages), <String, dynamic>{
          'type': 'room.created',
          'roomKey': 'ROOM42',
        });

        final WebSocket client = await WebSocket.connect(server.uri.toString());
        final StreamIterator<Map<String, dynamic>> clientMessages = _messages(
          client,
        );
        addTearDown(client.close);
        addTearDown(clientMessages.cancel);

        client.add(
          jsonEncode(<String, dynamic>{
            'type': 'player.join',
            'roomKey': 'ROOM42',
            'payload': <String, dynamic>{'type': 'join', 'name': 'Client'},
          }),
        );

        final Map<String, dynamic> relayJoin = await _next(clientMessages);
        expect(relayJoin['type'], 'relay.joined');
        final String clientId = relayJoin['clientId'] as String;
        expect(clientId, isNotEmpty);

        expect(await _next(hostMessages), <String, dynamic>{
          'type': 'client.connected',
          'clientId': clientId,
        });
        expect(await _next(hostMessages), <String, dynamic>{
          'type': 'client.message',
          'clientId': clientId,
          'payload': <String, dynamic>{'type': 'join', 'name': 'Client'},
        });

        client.add(
          jsonEncode(<String, dynamic>{
            'type': 'client.message',
            'payload': <String, dynamic>{'type': 'command', 'guess': 'above'},
          }),
        );
        expect(await _next(hostMessages), <String, dynamic>{
          'type': 'client.message',
          'clientId': clientId,
          'payload': <String, dynamic>{'type': 'command', 'guess': 'above'},
        });

        host.add(
          jsonEncode(<String, dynamic>{
            'type': 'host.message',
            'clientId': clientId,
            'payload': <String, dynamic>{'type': 'snapshot', 'turn': 1},
          }),
        );
        expect(await _next(clientMessages), <String, dynamic>{
          'type': 'snapshot',
          'turn': 1,
        });
      },
    );

    test('rejects missing rooms without registering the client', () async {
      final InternetRelayServer server = InternetRelayServer();
      await server.start();
      addTearDown(server.close);

      final WebSocket client = await WebSocket.connect(server.uri.toString());
      final StreamIterator<Map<String, dynamic>> messages = _messages(client);
      addTearDown(client.close);
      addTearDown(messages.cancel);

      client.add(
        jsonEncode(<String, dynamic>{
          'type': 'player.join',
          'roomKey': 'MISSING',
        }),
      );

      expect(await _next(messages), <String, dynamic>{
        'type': 'error',
        'message': 'Room not found.',
      });
    });

    test('rejects role messages before a socket joins a room', () async {
      final InternetRelayServer server = InternetRelayServer();
      await server.start();
      addTearDown(server.close);

      final WebSocket socket = await WebSocket.connect(server.uri.toString());
      final StreamIterator<Map<String, dynamic>> messages = _messages(socket);
      addTearDown(socket.close);
      addTearDown(messages.cancel);

      socket.add(
        jsonEncode(<String, dynamic>{
          'type': 'client.message',
          'payload': <String, dynamic>{'type': 'command'},
        }),
      );

      expect(await _next(messages), <String, dynamic>{
        'type': 'error',
        'message': 'Socket is not registered.',
      });
    });

    test('broadcasts host session close to clients', () async {
      final InternetRelayServer server = InternetRelayServer();
      await server.start();
      addTearDown(server.close);

      final WebSocket host = await WebSocket.connect(server.uri.toString());
      final StreamIterator<Map<String, dynamic>> hostMessages = _messages(host);
      addTearDown(host.close);
      addTearDown(hostMessages.cancel);
      host.add(
        jsonEncode(<String, dynamic>{
          'type': 'host.create',
          'roomKey': 'CLOSE1',
        }),
      );
      await _next(hostMessages);

      final WebSocket client = await WebSocket.connect(server.uri.toString());
      final StreamIterator<Map<String, dynamic>> clientMessages = _messages(
        client,
      );
      addTearDown(client.close);
      addTearDown(clientMessages.cancel);
      client.add(
        jsonEncode(<String, dynamic>{
          'type': 'player.join',
          'roomKey': 'CLOSE1',
        }),
      );
      await _next(clientMessages);
      await _next(hostMessages);

      host.add(
        jsonEncode(<String, dynamic>{
          'type': 'host.close',
          'message': 'Host ended the session.',
        }),
      );

      expect(await _next(clientMessages), <String, dynamic>{
        'type': 'session_closed',
        'message': 'Host ended the session.',
      });
    });
  });
}

StreamIterator<Map<String, dynamic>> _messages(WebSocket socket) {
  return StreamIterator<Map<String, dynamic>>(
    socket.map(
      (dynamic raw) => jsonDecode(raw as String) as Map<String, dynamic>,
    ),
  );
}

Future<Map<String, dynamic>> _next(
  StreamIterator<Map<String, dynamic>> messages,
) async {
  final bool hasNext = await messages.moveNext().timeout(
    const Duration(seconds: 2),
  );
  if (!hasNext) {
    throw StateError('Expected another relay message.');
  }
  return messages.current;
}
