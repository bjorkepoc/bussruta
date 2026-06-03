import 'package:bussruta_app/application/hosted_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/internet_relay.dart';

void main() {
  group('HostedSessionController manual target parsing', () {
    test('accepts host only input', () {
      final HostedJoinHostInput parsed = parseHostedJoinHostInput('10.0.2.2');
      expect(parsed.host, '10.0.2.2');
      expect(parsed.port, isNull);
    });

    test('accepts host and port input', () {
      final HostedJoinHostInput parsed = parseHostedJoinHostInput(
        '10.0.2.2:45879',
      );
      expect(parsed.host, '10.0.2.2');
      expect(parsed.port, 45879);
    });

    test('accepts scheme-prefixed address input', () {
      final HostedJoinHostInput parsed = parseHostedJoinHostInput(
        'tcp://10.0.2.2:45879',
      );
      expect(parsed.host, '10.0.2.2');
      expect(parsed.port, 45879);
    });

    test('rejects invalid host port', () {
      expect(
        () => parseHostedJoinHostInput('10.0.2.2:99999'),
        throwsFormatException,
      );
    });
  });

  group('HostedSessionController join targets', () {
    test('keeps normal LAN address as single target', () {
      expect(hostedJoinAddressCandidates('192.168.1.44'), <String>[
        '192.168.1.44',
      ]);
    });

    test('adds emulator host fallback for 10.0.2.x addresses', () {
      expect(hostedJoinAddressCandidates('10.0.2.15'), <String>[
        '10.0.2.15',
        '10.0.2.2',
      ]);
    });

    test('does not duplicate emulator fallback when already 10.0.2.2', () {
      expect(hostedJoinAddressCandidates('10.0.2.2'), <String>['10.0.2.2']);
    });

    test(
      'formats emulator adb forward command for the hosted session port',
      () {
        expect(
          hostedEmulatorForwardCommand(45879),
          'adb -s <host-emulator> forward tcp:45879 tcp:45879',
        );
      },
    );

    test('normalizes relay host input to websocket URL', () {
      expect(
        parseHostedRelayUri('192.168.1.20:8080').toString(),
        'ws://192.168.1.20:8080/ws',
      );
      expect(
        parseHostedRelayUri('wss://relay.example/ws').toString(),
        'wss://relay.example/ws',
      );
    });

    test('formats relay share details for browser players', () {
      expect(
        hostedRelayShareText(
          appUrl: 'http://192.168.1.20:8081/',
          relayUrl: 'ws://192.168.1.20:8080/ws',
          roomKey: '1234',
        ),
        [
          'Open: http://192.168.1.20:8081/',
          'Relay URL: ws://192.168.1.20:8080/ws',
          'Room key: 1234',
        ].join('\n'),
      );
    });

    test('uses entered room key when starting relay host room', () async {
      final InternetRelayServer relay = InternetRelayServer();
      await relay.start();
      final HostedSessionController controller = HostedSessionController(
        enableLanDiscovery: false,
      );

      try {
        await controller.startRelayHosting(
          hostName: 'Host',
          relayUrl: relay.uri.toString(),
          roomKey: '4242',
        );

        expect(controller.connectionStatus, HostedConnectionStatus.connected);
        expect(controller.relayRoomKey, '4242');
        expect(controller.sessionPin, '4242');
      } finally {
        await controller.leaveSession();
        controller.dispose();
        await relay.close();
      }
    });

    test(
      'generates non-trivial relay room key when host leaves key blank',
      () async {
        final InternetRelayServer relay = InternetRelayServer();
        await relay.start();
        final HostedSessionController controller = HostedSessionController(
          enableLanDiscovery: false,
        );

        try {
          await controller.startRelayHosting(
            hostName: 'Host',
            relayUrl: relay.uri.toString(),
          );

          expect(controller.connectionStatus, HostedConnectionStatus.connected);
          expect(controller.relayRoomKey, isNotNull);
          expect(controller.relayRoomKey, isNot(matches(RegExp(r'^\d{4}$'))));
          expect(controller.relayRoomKey!.length, greaterThanOrEqualTo(6));
          expect(controller.sessionPin, controller.relayRoomKey);
        } finally {
          await controller.leaveSession();
          controller.dispose();
          await relay.close();
        }
      },
    );
  });
}
