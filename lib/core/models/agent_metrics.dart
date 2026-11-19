class AgentMetrics {
  final int activePeers;
  final int activeStreams;
  final int maxStreams;
  final int streamRejections;
  final int rxBytesTotal;
  final int txBytesTotal;
  final double rxSpeedBytesPerSec;
  final double txSpeedBytesPerSec;
  final DateTime timestamp;

  const AgentMetrics({
    this.activePeers = 0,
    this.activeStreams = 0,
    this.maxStreams = 512,
    this.streamRejections = 0,
    this.rxBytesTotal = 0,
    this.txBytesTotal = 0,
    this.rxSpeedBytesPerSec = 0.0,
    this.txSpeedBytesPerSec = 0.0,
    required this.timestamp,
  });

  factory AgentMetrics.initial() {
    return AgentMetrics(timestamp: DateTime.now());
  }

  factory AgentMetrics.parsePrometheus(
    String prometheusText, {
    AgentMetrics? previousMetrics,
  }) {
    int peers = 0;
    int streams = 0;
    int maxStreams = 512;
    int rejections = 0;
    int rxTotal = 0;
    int txTotal = 0;

    final lines = prometheusText.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('webrtc_gateway_active_peers')) {
        peers = _parseValue(line);
      } else if (line.startsWith('webrtc_gateway_active_streams')) {
        streams = _parseValue(line);
      } else if (line.startsWith('webrtc_gateway_max_streams')) {
        maxStreams = _parseValue(line);
      } else if (line.startsWith('webrtc_gateway_stream_rejections_total')) {
        rejections = _parseValue(line);
      } else if (line.startsWith('webrtc_gateway_traffic_rx_bytes_total')) {
        rxTotal = _parseValue(line);
      } else if (line.startsWith('webrtc_gateway_traffic_tx_bytes_total')) {
        txTotal = _parseValue(line);
      }
    }

    final now = DateTime.now();
    double rxSpeed = 0.0;
    double txSpeed = 0.0;

    if (previousMetrics != null) {
      final timeDiffSec =
          now.difference(previousMetrics.timestamp).inMilliseconds / 1000.0;
      if (timeDiffSec > 0.1) {
        if (rxTotal >= previousMetrics.rxBytesTotal) {
          rxSpeed = (rxTotal - previousMetrics.rxBytesTotal) / timeDiffSec;
        }
        if (txTotal >= previousMetrics.txBytesTotal) {
          txSpeed = (txTotal - previousMetrics.txBytesTotal) / timeDiffSec;
        }
      }
    }

    return AgentMetrics(
      activePeers: peers,
      activeStreams: streams,
      maxStreams: maxStreams,
      streamRejections: rejections,
      rxBytesTotal: rxTotal,
      txBytesTotal: txTotal,
      rxSpeedBytesPerSec: rxSpeed,
      txSpeedBytesPerSec: txSpeed,
      timestamp: now,
    );
  }

  static int _parseValue(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return int.tryParse(parts.last) ?? 0;
    }
    return 0;
  }

  static String formatBytes(num bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double b = bytes.toDouble();
    while (b >= 1024 && i < suffixes.length - 1) {
      b /= 1024;
      i++;
    }
    return '${b.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  static String formatSpeed(double bytesPerSec) {
    return '${formatBytes(bytesPerSec)}/s';
  }
}
