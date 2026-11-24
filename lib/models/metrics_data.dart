class MetricsSnapshot {
  final DateTime timestamp;
  final double uploadBytesPerSec;
  final double downloadBytesPerSec;
  final int activeStreams;
  final int totalConnections;
  final double rttMs;
  final String connectionType; // "Direct (P2P)" or "Relay (TURN)"

  const MetricsSnapshot({
    required this.timestamp,
    this.uploadBytesPerSec = 0,
    this.downloadBytesPerSec = 0,
    this.activeStreams = 0,
    this.totalConnections = 0,
    this.rttMs = 0,
    this.connectionType = 'Direct (P2P)',
  });

  factory MetricsSnapshot.empty() => MetricsSnapshot(timestamp: DateTime.now());
}

class ActiveStreamInfo {
  final int id;
  final String path;
  final String method;
  final String status;
  final int bytesTransferred;
  final Duration duration;

  const ActiveStreamInfo({
    required this.id,
    required this.path,
    required this.method,
    required this.status,
    required this.bytesTransferred,
    required this.duration,
  });
}
