import 'package:bussruta_app/application/hosted_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });
}
