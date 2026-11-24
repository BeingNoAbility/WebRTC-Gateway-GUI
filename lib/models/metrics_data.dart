class MetricsSnapshot {
  final DateTime timestamp;
  final double uploadBytesPerSec;
  final double downloadBytesPerSec;
  final int activeStreams;
  final int totalConnections;
  final int streamRejectionsTotal;

  const MetricsSnapshot({
    required this.timestamp,
    this.uploadBytesPerSec = 0,
    this.downloadBytesPerSec = 0,
    this.activeStreams = 0,
    this.totalConnections = 0,
    this.streamRejectionsTotal = 0,
  });

  factory MetricsSnapshot.empty() => MetricsSnapshot(timestamp: DateTime.now());
}
