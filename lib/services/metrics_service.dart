import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/metrics_data.dart';

class MetricsService {
  final Map<String, List<MetricsSnapshot>> _history = {};
  final Map<String, int> _lastSentBytes = {};
  final Map<String, int> _lastRecvBytes = {};
  final Map<String, DateTime> _lastPollTime = {};

  static const int maxHistoryLength = 40;

  List<MetricsSnapshot> getHistory(String profileId) => _history[profileId] ?? [];

  /// Computes aggregated metrics history across all running agents
  List<MetricsSnapshot> getAggregatedHistory() {
    if (_history.isEmpty) return [];

    final snapshots = <MetricsSnapshot>[];
    final allTimestamps = <DateTime>[];

    for (final list in _history.values) {
      if (list.isNotEmpty) {
        allTimestamps.add(list.last.timestamp);
      }
    }

    if (allTimestamps.isEmpty) return [];

    double totalUp = 0;
    double totalDown = 0;
    int totalStreams = 0;
    int totalConns = 0;

    for (final list in _history.values) {
      if (list.isNotEmpty) {
        final last = list.last;
        totalUp += last.uploadBytesPerSec;
        totalDown += last.downloadBytesPerSec;
        totalStreams += last.activeStreams;
        totalConns += last.totalConnections;
      }
    }

    snapshots.add(MetricsSnapshot(
      timestamp: DateTime.now(),
      uploadBytesPerSec: totalUp,
      downloadBytesPerSec: totalDown,
      activeStreams: totalStreams,
      totalConnections: totalConns,
    ));

    return snapshots;
  }

  /// Polls Prometheus endpoint at :port/metrics
  Future<MetricsSnapshot?> pollMetrics(String profileId, int port) async {
    final url = Uri.parse('http://127.0.0.1:$port/metrics');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;

      final now = DateTime.now();
      final body = response.body;

      int totalSent = _extractMetricInt(body, 'webrtc_gateway_bytes_sent_total');
      int totalRecv = _extractMetricInt(body, 'webrtc_gateway_bytes_received_total');
      int activeStreams = _extractMetricInt(body, 'webrtc_gateway_active_streams');
      int totalConns = _extractMetricInt(body, 'webrtc_gateway_connections_total');
      double rtt = _extractMetricDouble(body, 'webrtc_gateway_rtt_seconds') * 1000.0;

      double upSpeed = 0;
      double downSpeed = 0;

      if (_lastPollTime.containsKey(profileId)) {
        final elapsedSec = now.difference(_lastPollTime[profileId]!).inMilliseconds / 1000.0;
        if (elapsedSec > 0.1) {
          final sentDiff = totalSent - (_lastSentBytes[profileId] ?? totalSent);
          final recvDiff = totalRecv - (_lastRecvBytes[profileId] ?? totalRecv);
          upSpeed = (sentDiff > 0 ? sentDiff : 0) / elapsedSec;
          downSpeed = (recvDiff > 0 ? recvDiff : 0) / elapsedSec;
        }
      }

      _lastSentBytes[profileId] = totalSent;
      _lastRecvBytes[profileId] = totalRecv;
      _lastPollTime[profileId] = now;

      final snapshot = MetricsSnapshot(
        timestamp: now,
        uploadBytesPerSec: upSpeed,
        downloadBytesPerSec: downSpeed,
        activeStreams: activeStreams,
        totalConnections: totalConns,
        rttMs: rtt,
        connectionType: 'Direct (P2P)',
      );

      final list = _history.putIfAbsent(profileId, () => []);
      if (list.length >= maxHistoryLength) {
        list.removeAt(0);
      }
      list.add(snapshot);

      return snapshot;
    } catch (_) {
      return null;
    }
  }

  int _extractMetricInt(String body, String name) {
    final regex = RegExp('^$name\\s+(\\d+)', multiLine: true);
    final match = regex.firstMatch(body);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  double _extractMetricDouble(String body, String name) {
    final regex = RegExp('^$name\\s+([\\d.]+)', multiLine: true);
    final match = regex.firstMatch(body);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  void clearProfile(String profileId) {
    _history.remove(profileId);
    _lastSentBytes.remove(profileId);
    _lastRecvBytes.remove(profileId);
    _lastPollTime.remove(profileId);
  }
}
