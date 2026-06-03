import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'start helper rejects ports already owned by another process',
    () async {
      if (!Platform.isWindows) {
        return;
      }

      final ServerSocket occupied = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(occupied.close);

      final ProcessResult result = await Process.run('powershell', <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'tool\\start_lan_web.ps1',
        '-RelayPort',
        occupied.port.toString(),
        '-WebPort',
        occupied.port.toString(),
      ]);

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('already in use by a non-Bussruta process'),
      );
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test(
    'stop helper leaves ports owned by another process running',
    () async {
      if (!Platform.isWindows) {
        return;
      }

      final int occupiedPort = await _unusedTcpPort();
      final Process dummy = await Process.start('powershell', <String>[
        '-NoProfile',
        '-Command',
        '''
\$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), $occupiedPort)
\$listener.Start()
try { Start-Sleep -Seconds 30 } finally { \$listener.Stop() }
''',
      ]);
      addTearDown(() => dummy.kill());
      await _waitForTcpPort(occupiedPort);

      final ProcessResult result = await Process.run('powershell', <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'tool\\start_lan_web.ps1',
        '-RelayPort',
        occupiedPort.toString(),
        '-WebPort',
        occupiedPort.toString(),
        '-Stop',
      ]);

      expect(result.exitCode, 0);
      final int? dummyExitCode = await dummy.exitCode
          .then<int?>((int value) => value)
          .timeout(const Duration(milliseconds: 500), onTimeout: () => null);
      expect(dummyExitCode, isNull);
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('Leaving non-Bussruta process'),
      );
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}

Future<int> _unusedTcpPort() async {
  final ServerSocket socket = await ServerSocket.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  final int port = socket.port;
  await socket.close();
  return port;
}

Future<void> _waitForTcpPort(int port) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final Socket socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 100),
      );
      socket.destroy();
      return;
    } on Object {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }
  fail('Timed out waiting for dummy listener on port $port.');
}
