import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/metrics_data.dart';

class SignalMetricsSnapshot {
  final DateTime timestamp;
  final int registeredNodes;
  final int activeClients;
  final int signalingMessagesTotal;
  final int ratelimitRejectedTotal;

  SignalMetricsSnapshot({
    required this.timestamp,
    required this.registeredNodes,
    required this.activeClients,
    required this.signalingMessagesTotal,
    required this.ratelimitRejectedTotal,
  });
}

class MetricsService {
  final Map<String, List<MetricsSnapshot>> _history = {};
  final Map<String, int> _lastSentBytes = {};
  final Map<String, int> _lastRecvBytes = {};
  final Map<String, DateTime> _lastPollTime = {};

  SignalMetricsSnapshot? _latestSignalMetrics;
  SignalMetricsSnapshot? get latestSignalMetrics => _latestSignalMetrics;

  static const int maxHistoryLength = 40;

  List<MetricsSnapshot> getHistory(String profileId) => _history[profileId] ?? [];

  /// Computes aggregated metrics history across all running agents
  List<MetricsSnapshot> getAggregatedHistory() {
    if (_history.isEmpty) return [];

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

    final now = DateTime.now();
    return [
      MetricsSnapshot(
        timestamp: now,
        uploadBytesPerSec: totalUp,
        downloadBytesPerSec: totalDown,
        activeStreams: totalStreams,
        totalConnections: totalConns,
      ),
    ];
  }

  /// Polls Agent Prometheus endpoint at :port/metrics
  Future<MetricsSnapshot?> pollMetrics(String profileId, int port) async {
    final url = Uri.parse('http://127.0.0.1:$port/metrics');
    try {
      final response = await http.get(url).timeout(const Duration(milliseconds: 1500));
      if (response.statusCode != 200) return null;

      final now = DateTime.now();
      final body = response.body;

      // Extract official Go metrics matching pkg/agent/metrics.go
      int totalSent = _extractMetricInt(body, 'webrtc_gateway_traffic_bytes_total', labelFilter: 'direction="tx"');
      int totalRecv = _extractMetricInt(body, 'webrtc_gateway_traffic_bytes_total', labelFilter: 'direction="rx"');
      int activeStreams = _extractMetricInt(body, 'webrtc_gateway_active_streams');
      int activePeers = _extractMetricInt(body, 'webrtc_gateway_active_peers');

      double upSpeed = 0;
      double downSpeed = 0;

      if (_lastPollTime.containsKey(profileId)) {
        final elapsedSec = now.difference(_lastPollTime[profileId]!).inMilliseconds / 1000.0;
        if (elapsedSec > 0.1) {
          final lastSent = _lastSentBytes[profileId] ?? totalSent;
          final lastRecv = _lastRecvBytes[profileId] ?? totalRecv;
          final sentDiff = totalSent - lastSent;
          final recvDiff = totalRecv - lastRecv;
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
        totalConnections: activePeers,
        rttMs: 0.0,
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

  /// Polls Signal server metrics endpoint
  Future<SignalMetricsSnapshot?> pollSignalMetrics(String listenAddr, [String? dedicatedMetricsAddr]) async {
    Uri? url;
    if (dedicatedMetricsAddr != null && dedicatedMetricsAddr.isNotEmpty) {
      final clean = dedicatedMetricsAddr.startsWith(':') ? '127.0.0.1$dedicatedMetricsAddr' : dedicatedMetricsAddr;
      url = Uri.parse('http://$clean/metrics');
    } else {
      final clean = listenAddr.startsWith(':') ? '127.0.0.1$listenAddr' : listenAddr;
      url = Uri.parse('http://$clean/metrics');
    }

    try {
      final response = await http.get(url).timeout(const Duration(milliseconds: 1500));
      if (response.statusCode != 200) return null;

      final body = response.body;
      final snapshot = SignalMetricsSnapshot(
        timestamp: DateTime.now(),
        registeredNodes: _extractMetricInt(body, 'webrtc_gateway_registered_nodes'),
        activeClients: _extractMetricInt(body, 'webrtc_gateway_active_clients'),
        signalingMessagesTotal: _extractMetricInt(body, 'webrtc_gateway_signaling_messages_total'),
        ratelimitRejectedTotal: _extractMetricInt(body, 'webrtc_gateway_ratelimit_rejected_total'),
      );

      _latestSignalMetrics = snapshot;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  int _extractMetricInt(String body, String name, {String? labelFilter}) {
    final lines = body.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith(name)) {
        if (labelFilter != null && !line.contains(labelFilter)) {
          continue;
        }
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          return int.tryParse(parts.last) ?? 0;
        }
      }
    }
    return 0;
  }

  void clearProfile(String profileId) {
    _history.remove(profileId);
    _lastSentBytes.remove(profileId);
    _lastRecvBytes.remove(profileId);
    _lastPollTime.remove(profileId);
  }

  void clearSignal() {
    _latestSignalMetrics = null;
  }
}
