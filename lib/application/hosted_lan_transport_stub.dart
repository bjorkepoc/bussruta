import 'dart:async';

import 'package:bussruta_app/application/hosted_session_runtime.dart';
import 'package:bussruta_app/application/hosted_transport_models.dart';
import 'package:bussruta_app/domain/hosted_models.dart';
import 'package:bussruta_app/domain/hosted_projection.dart';

class HostedLanDiscovery {
  final StreamController<List<HostedDiscoveryEntry>> _updates =
      StreamController<List<HostedDiscoveryEntry>>.broadcast();

  Stream<List<HostedDiscoveryEntry>> get updates => _updates.stream;
  List<HostedDiscoveryEntry> get entries => const <HostedDiscoveryEntry>[];

  Future<void> start() async {}

  Future<void> stop() async {
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

  Stream<HostedSessionState> get stateUpdates =>
      const Stream<HostedSessionState>.empty();
  Stream<String> get errors => const Stream<String>.empty();
  HostedSessionState get state => runtime.state;
  String? get hostAddress => null;
  int get port => 0;

  Future<void> start() async {
    throw UnsupportedError('LAN hosting is not available in the browser.');
  }

  HostedSessionState applyLocalCommand(HostedSessionCommand command) {
    throw UnsupportedError('LAN hosting is not available in the browser.');
  }

  HostedProjectedView projectionForPlayer(int playerId) {
    return projectHostedView(session: runtime.state, viewerPlayerId: playerId);
  }

  HostedProjectedView projectionForHost() {
    return projectionForPlayer(runtime.state.hostPlayerId);
  }

  Future<void> close({
    String reason = 'Host ended the session.',
    bool broadcastSessionClosed = true,
  }) async {}
}

class HostedLanClientConnection {
  HostedLanClientConnection._();

  Stream<HostedProjectedView> get projectionUpdates =>
      const Stream<HostedProjectedView>.empty();
  Stream<HostedClientIssue> get issues =>
      const Stream<HostedClientIssue>.empty();
  HostedProjectedView? get projection => null;
  int? get playerId => null;
  String? get playerToken => null;

  static Future<HostedLanClientConnection> connect({
    required String hostAddress,
    required int hostPort,
    required String pin,
    required String playerName,
    String? playerToken,
    int? requestedPlayerId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    throw UnsupportedError('LAN joining is not available in the browser.');
  }

  void sendCommand(HostedSessionCommand command) {}

  Future<void> close() async {}
}
