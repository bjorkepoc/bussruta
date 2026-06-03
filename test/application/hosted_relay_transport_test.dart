import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bussruta_app/application/hosted_relay_transport.dart';
import 'package:bussruta_app/application/hosted_session_runtime.dart';
import 'package:bussruta_app/application/hosted_transport_models.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/internet_relay.dart';

void main() {
  group('Hosted relay transport', () {
    test(
      'hosts a room and sends player projections through the relay',
      () async {
        final InternetRelayServer relay = InternetRelayServer();
        await relay.start();
        addTearDown(relay.close);

        final HostedRelayHostConnection host = await _startRelayHost(relay.uri);
        addTearDown(() => host.close(broadcastSessionClosed: false));

        expect(host.roomKey, '1234');

        final HostedRelayClientConnection client =
            await HostedRelayClientConnection.connect(
              relayUri: relay.uri,
              roomKey: '1234',
              pin: '1234',
              playerName: 'Alice',
            );
        addTearDown(client.close);

        expect(client.playerId, isNotNull);
        expect(client.projection?.viewerName, 'Alice');
        expect(host.state.participantById(client.playerId!)?.connected, isTrue);

        final Future<HostedProjectedView> warmupProjection = client
            .projectionUpdates
            .firstWhere(
              (HostedProjectedView projection) =>
                  projection.publicView.phase == GamePhase.warmup,
            );

        host.applyLocalCommand(
          const HostedSessionCommand(
            type: HostedCommandType.startGame,
            playerId: 1,
          ),
        );

        expect(
          (await warmupProjection.timeout(
            const Duration(seconds: 2),
          )).publicView.phase,
          GamePhase.warmup,
        );
      },
    );

    test('marks relay clients disconnected when their socket closes', () async {
      final InternetRelayServer relay = InternetRelayServer();
      await relay.start();
      addTearDown(relay.close);

      final HostedRelayHostConnection host = await _startRelayHost(relay.uri);
      addTearDown(() => host.close(broadcastSessionClosed: false));

      final HostedRelayClientConnection client =
          await HostedRelayClientConnection.connect(
            relayUri: relay.uri,
            roomKey: '1234',
            pin: '1234',
            playerName: 'Bob',
          );
      final int playerId = client.playerId!;

      await client.close();

      await _waitFor(
        () => host.state.participantById(playerId)?.connected == false,
      );
      expect(host.state.participantById(playerId)?.connected, isFalse);
    });

    test('notifies relay clients when the host closes the room', () async {
      final InternetRelayServer relay = InternetRelayServer();
      await relay.start();
      addTearDown(relay.close);

      final HostedRelayHostConnection host = await _startRelayHost(relay.uri);

      final HostedRelayClientConnection client =
          await HostedRelayClientConnection.connect(
            relayUri: relay.uri,
            roomKey: '1234',
            pin: '1234',
            playerName: 'Carol',
          );
      addTearDown(client.close);

      final Future<HostedClientIssue> issueFuture = client.issues.firstWhere(
        (HostedClientIssue issue) =>
            issue.code == HostedClientIssueCode.sessionClosed,
      );

      await host.close(reason: 'Relay room closed.');
      final HostedClientIssue issue = await issueFuture.timeout(
        const Duration(seconds: 2),
      );

      expect(issue.code, HostedClientIssueCode.sessionClosed);
      expect(issue.message, 'Relay room closed.');
    });

    test(
      'join response is not followed by duplicate snapshot to same relay client',
      () async {
        final InternetRelayServer relay = InternetRelayServer();
        await relay.start();
        addTearDown(relay.close);

        final HostedRelayHostConnection host = await _startRelayHost(relay.uri);
        addTearDown(() => host.close(broadcastSessionClosed: false));

        final WebSocket client = await WebSocket.connect(relay.uri.toString());
        final StreamIterator<Map<String, dynamic>> clientMessages = _messages(
          client,
        );
        addTearDown(client.close);
        addTearDown(clientMessages.cancel);

        client.add(
          jsonEncode(<String, dynamic>{
            'type': 'player.join',
            'roomKey': '1234',
            'payload': <String, dynamic>{
              'type': 'join',
              'pin': '1234',
              'name': 'No duplicate',
            },
          }),
        );

        expect((await _next(clientMessages))['type'], 'relay.joined');
        expect((await _next(clientMessages))['type'], 'joined');

        final Map<String, dynamic>? duplicate = await _nextOrNull(
          clientMessages,
          timeout: const Duration(milliseconds: 250),
        );
        expect(duplicate, isNull);
      },
    );

    test('closes relay socket when join times out', () async {
      final InternetRelayServer relay = InternetRelayServer();
      await relay.start();
      addTearDown(relay.close);

      final WebSocket host = await WebSocket.connect(relay.uri.toString());
      final StreamIterator<Map<String, dynamic>> hostMessages = _messages(host);
      addTearDown(host.close);
      addTearDown(hostMessages.cancel);
      host.add(
        jsonEncode(<String, dynamic>{
          'type': 'host.create',
          'roomKey': 'SLOW1',
        }),
      );
      await _next(hostMessages);

      final Future<HostedRelayClientConnection> slowConnect =
          HostedRelayClientConnection.connect(
            relayUri: relay.uri,
            roomKey: 'SLOW1',
            pin: 'SLOW1',
            playerName: 'Slow client',
            timeout: const Duration(seconds: 1),
          );
      expect((await _next(hostMessages))['type'], 'client.connected');
      expect((await _next(hostMessages))['type'], 'client.message');
      await expectLater(slowConnect, throwsA(isA<TimeoutException>()));
      expect(await _next(hostMessages), <String, dynamic>{
        'type': 'client.disconnected',
        'clientId': 'client-1',
      });
    });
  });
}

Future<HostedRelayHostConnection> _startRelayHost(Uri relayUri) async {
  final HostedSessionRuntime runtime = HostedSessionRuntime(
    engine: GameEngine(),
    initialState: HostedSessionState.lobby(
      sessionPin: '1234',
      host: const HostedParticipant(
        playerId: 1,
        name: 'Host',
        isHost: true,
        connected: true,
      ),
      language: AppLanguage.en,
    ),
  );
  return HostedRelayHostConnection.start(
    relayUri: relayUri,
    runtime: runtime,
    hostName: 'Host',
    roomKey: '1234',
  );
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
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

Future<Map<String, dynamic>?> _nextOrNull(
  StreamIterator<Map<String, dynamic>> messages, {
  required Duration timeout,
}) async {
  final bool hasNext = await messages.moveNext().timeout(
    timeout,
    onTimeout: () => false,
  );
  return hasNext ? messages.current : null;
}
