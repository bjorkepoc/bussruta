import 'package:bussruta_app/application/hosted_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
