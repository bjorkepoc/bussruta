import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bussruta_app/application/hosted_lan_transport.dart';
import 'package:bussruta_app/application/hosted_session_runtime.dart';
import 'package:bussruta_app/domain/game_engine.dart';
import 'package:bussruta_app/domain/game_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostedLan transport', () {
    test('hosts on the deterministic LAN session port', () async {
      final HostedLanHostServer server = await _startServer();
      addTearDown(() => server.close(broadcastSessionClosed: false));

      expect(server.port, hostedSessionPort);
    });

    test('closes unauthenticated sockets that exceed the line limit', () async {
      final HostedLanHostServer server = await _startServer();
      addTearDown(() => server.close(broadcastSessionClosed: false));

      final Socket socket = await Socket.connect('127.0.0.1', server.port);
      addTearDown(socket.destroy);
      final Completer<void> closed = Completer<void>();
      final StreamSubscription<List<int>> socketSub = socket.listen(
        (_) {},
        onDone: () {
          if (!closed.isCompleted) {
            closed.complete();
          }
        },
        onError: (_) {
          if (!closed.isCompleted) {
            closed.complete();
          }
        },
      );
      addTearDown(socketSub.cancel);

      socket.add(List<int>.filled(70 * 1024, 'a'.codeUnitAt(0)));
      await socket.flush();

      expect(await _completesSoon(closed.future), isTrue);
    });

    test('binds discovery entries to the UDP source address', () async {
      final HostedLanDiscovery discovery = HostedLanDiscovery();
      addTearDown(discovery.stop);
      await discovery.start();

      final Future<List<HostedDiscoveryEntry>> update = discovery.updates
          .firstWhere(
            (List<HostedDiscoveryEntry> entries) => entries.any(
              (HostedDiscoveryEntry entry) => entry.pin == '9876',
            ),
          );
      final RawDatagramSocket sender = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(sender.close);

      sender.send(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'type': 'bussruta-host-v1',
            'name': 'Spoofed host',
            'pin': '9876',
            'port': 45879,
            'hostAddress': '203.0.113.42',
          }),
        ),
        InternetAddress.loopbackIPv4,
        hostedDiscoveryPort,
      );

      final List<HostedDiscoveryEntry> entries = await update.timeout(
        const Duration(seconds: 2),
      );
      final HostedDiscoveryEntry entry = entries.firstWhere(
        (HostedDiscoveryEntry value) => value.pin == '9876',
      );

      expect(entry.hostAddress, InternetAddress.loopbackIPv4.address);
    });

    test('fails join when the host sends a malformed projection', () async {
      final ServerSocket fakeHost = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(fakeHost.close);
      fakeHost.listen((Socket socket) {
        socket.writeln(
          jsonEncode(<String, dynamic>{
            'type': 'joined',
            'playerId': 2,
            'playerToken': 'token',
            'projection': _projectionJson(pyramidCards: <dynamic>[null]),
          }),
        );
      });

      await expectLater(
        HostedLanClientConnection.connect(
          hostAddress: '127.0.0.1',
          hostPort: fakeHost.port,
          pin: '1234',
          playerName: 'Client',
          timeout: const Duration(seconds: 1),
        ),
        throwsA(contains('Invalid projection from host.')),
      );
    });

    test('reconnects to same seat when reconnect token matches', () async {
      final HostedLanHostServer server = await _startServer();
      bool serverClosed = false;
      addTearDown(() async {
        if (serverClosed) {
          return;
        }
        serverClosed = true;
        await server.close(broadcastSessionClosed: false);
      });

      final HostedLanClientConnection firstClient =
          await HostedLanClientConnection.connect(
            hostAddress: '127.0.0.1',
            hostPort: server.port,
            pin: '1234',
            playerName: 'Alice',
          );
      bool firstClosed = false;
      addTearDown(() async {
        if (firstClosed) {
          return;
        }
        firstClosed = true;
        await firstClient.close();
      });

      final int seatId = firstClient.playerId!;
      final String token = firstClient.playerToken!;
      await firstClient.close();
      firstClosed = true;

      await _waitFor(
        () => server.state.participantById(seatId)?.connected == false,
      );

      final HostedLanClientConnection reconnectClient =
          await HostedLanClientConnection.connect(
            hostAddress: '127.0.0.1',
            hostPort: server.port,
            pin: '1234',
            playerName: 'Alice',
            playerToken: token,
            requestedPlayerId: seatId,
          );
      bool reconnectClosed = false;
      addTearDown(() async {
        if (reconnectClosed) {
          return;
        }
        reconnectClosed = true;
        await reconnectClient.close();
      });

      expect(reconnectClient.playerId, seatId);
      expect(server.state.participants.length, 2);
      expect(server.state.participantById(seatId)?.connected, isTrue);
    });

    test(
      'join response is not followed by duplicate snapshot to same client',
      () async {
        final HostedLanHostServer server = await _startServer();
        bool serverClosed = false;
        addTearDown(() async {
          if (serverClosed) {
            return;
          }
          serverClosed = true;
          await server.close(broadcastSessionClosed: false);
        });

        final Socket socket = await Socket.connect('127.0.0.1', server.port);
        addTearDown(socket.destroy);
        final Stream<String> lines = socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .asBroadcastStream();

        socket.writeln(
          jsonEncode(<String, dynamic>{
            'type': 'join',
            'pin': '1234',
            'name': 'No duplicate',
          }),
        );
        await socket.flush();

        final Map<String, dynamic> first =
            jsonDecode(await lines.first.timeout(const Duration(seconds: 2)))
                as Map<String, dynamic>;
        expect(first['type'], 'joined');

        final String duplicate = await lines.first.timeout(
          const Duration(milliseconds: 250),
          onTimeout: () => '',
        );
        expect(duplicate, isEmpty);
      },
    );

    test('marks participant disconnected when client socket closes', () async {
      final HostedLanHostServer server = await _startServer();
      bool serverClosed = false;
      addTearDown(() async {
        if (serverClosed) {
          return;
        }
        serverClosed = true;
        await server.close(broadcastSessionClosed: false);
      });

      final HostedLanClientConnection client =
          await HostedLanClientConnection.connect(
            hostAddress: '127.0.0.1',
            hostPort: server.port,
            pin: '1234',
            playerName: 'Bob',
          );
      final int playerId = client.playerId!;
      await client.close();

      await _waitFor(
        () => server.state.participantById(playerId)?.connected == false,
      );
      expect(server.state.participantById(playerId)?.connected, isFalse);
    });

    test('notifies clients when host closes the session', () async {
      final HostedLanHostServer server = await _startServer();
      bool serverClosed = false;
      addTearDown(() async {
        if (serverClosed) {
          return;
        }
        serverClosed = true;
        await server.close(broadcastSessionClosed: false);
      });

      final HostedLanClientConnection client =
          await HostedLanClientConnection.connect(
            hostAddress: '127.0.0.1',
            hostPort: server.port,
            pin: '1234',
            playerName: 'Carol',
          );
      bool clientClosed = false;
      addTearDown(() async {
        if (clientClosed) {
          return;
        }
        clientClosed = true;
        await client.close();
      });

      final Future<HostedClientIssue> issueFuture = client.issues.firstWhere(
        (HostedClientIssue issue) =>
            issue.code == HostedClientIssueCode.sessionClosed,
      );

      await server.close(reason: 'Session closed for test.');
      serverClosed = true;
      final HostedClientIssue issue = await issueFuture.timeout(
        const Duration(seconds: 2),
      );

      expect(issue.code, HostedClientIssueCode.sessionClosed);
      expect(issue.message, 'Session closed for test.');
    });
  });
}

Future<bool> _completesSoon(Future<void> future) async {
  try {
    await future.timeout(const Duration(seconds: 2));
    return true;
  } on TimeoutException {
    return false;
  } catch (_) {
    return true;
  }
}

Map<String, dynamic> _projectionJson({required List<dynamic> pyramidCards}) {
  return HostedProjectedView(
    viewerPlayerId: 2,
    viewerName: 'Client',
    isHost: false,
    publicView: HostedPublicView(
      sessionPin: '1234',
      stage: HostedSessionStage.inGame,
      phase: GamePhase.pyramid,
      language: AppLanguage.en,
      players: const <HostedPublicPlayer>[
        HostedPublicPlayer(
          playerId: 2,
          name: 'Client',
          isHost: false,
          connected: true,
          handCount: 0,
        ),
      ],
      currentTurnPlayerId: null,
      warmupRound: 1,
      pyramidCards: List<PlayingCard?>.filled(15, null),
      pyramidRevealIndex: 0,
      tieBreak: null,
      busRunnerPlayerId: null,
      busRoute: null,
      banner: '',
      bannerTone: BannerTone.info,
      pendingDrinkDistribution: null,
      autoPlayEnabled: false,
      autoPlayDelayMs: 1500,
    ),
    ownHand: const <PlayingCard>[],
    giveOutPromptDrinks: 0,
    drinkPromptDrinks: 0,
    canControlBusRoute: false,
    canUseHostTools: false,
  ).toJson()..update(
    'publicView',
    (dynamic value) =>
        (value as Map<String, dynamic>)..['pyramidCards'] = pyramidCards,
  );
}

Future<HostedLanHostServer> _startServer() async {
  Object? lastError;
  for (int attempt = 0; attempt < 8; attempt += 1) {
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
    final HostedLanHostServer server = HostedLanHostServer(
      runtime: runtime,
      hostName: 'Host',
      pin: '1234',
    );
    try {
      await server.start();
      return server;
    } on SocketException catch (error) {
      lastError = error;
      await server.close(broadcastSessionClosed: false);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }
  throw StateError('Could not start test LAN server: $lastError');
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
