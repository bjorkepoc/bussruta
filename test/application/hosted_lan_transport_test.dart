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

Future<HostedLanHostServer> _startServer() async {
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
  await server.start();
  return server;
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
