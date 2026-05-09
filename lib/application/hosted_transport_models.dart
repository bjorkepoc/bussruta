const int hostedDiscoveryPort = 45878;
const int hostedSessionPort = 45879;

enum HostedClientIssueCode {
  genericError,
  disconnected,
  hostUnavailable,
  sessionClosed,
}

class HostedClientIssue {
  const HostedClientIssue({required this.code, required this.message});

  final HostedClientIssueCode code;
  final String message;
}

class HostedDiscoveryEntry {
  const HostedDiscoveryEntry({
    required this.pin,
    required this.hostName,
    required this.hostAddress,
    required this.hostPort,
    required this.lastSeenUtcMillis,
  });

  final String pin;
  final String hostName;
  final String hostAddress;
  final int hostPort;
  final int lastSeenUtcMillis;

  HostedDiscoveryEntry copyWith({
    String? pin,
    String? hostName,
    String? hostAddress,
    int? hostPort,
    int? lastSeenUtcMillis,
  }) {
    return HostedDiscoveryEntry(
      pin: pin ?? this.pin,
      hostName: hostName ?? this.hostName,
      hostAddress: hostAddress ?? this.hostAddress,
      hostPort: hostPort ?? this.hostPort,
      lastSeenUtcMillis: lastSeenUtcMillis ?? this.lastSeenUtcMillis,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pin': pin,
      'hostName': hostName,
      'hostAddress': hostAddress,
      'hostPort': hostPort,
      'lastSeenUtcMillis': lastSeenUtcMillis,
    };
  }
}
