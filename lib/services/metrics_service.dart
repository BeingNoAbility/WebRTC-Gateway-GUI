import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/metrics_data.dart';
import '../models/signal_profile.dart';

class SignalMetricsSnapshot {
  final DateTime timestamp;
  final int registeredNodes;
  final int activeClients;
  final int signalingMessagesTotal;
  final int ratelimitRejectedTotal;

  const SignalMetricsSnapshot({
    required this.timestamp,
    required this.registeredNodes,
    required this.activeClients,
    required this.signalingMessagesTotal,
    required this.ratelimitRejectedTotal,
  });
}

class AgentParsedMetrics {
  final int totalSentBytes;
  final int totalRecvBytes;
  final int activeStreams;
  final int activePeers;
  final int streamRejectionsTotal;

  const AgentParsedMetrics({
    required this.totalSentBytes,
    required this.totalRecvBytes,
    required this.activeStreams,
    required this.activePeers,
    required this.streamRejectionsTotal,
  });
}

class MetricsService {
  final Map<String, List<MetricsSnapshot>> _history = {};
  final Map<String, int> _lastSentBytes = {};
  final Map<String, int> _lastRecvBytes = {};
  final Map<String, DateTime> _lastPollTime = {};

  final http.Client _httpClient;
  final http.Client _insecureHttpsClient;

  SignalMetricsSnapshot? _latestSignalMetrics;
  SignalMetricsSnapshot? get latestSignalMetrics => _latestSignalMetrics;

  static const int maxHistoryLength = 40;

  MetricsService({http.Client? httpClient, http.Client? insecureHttpsClient})
      : _httpClient = httpClient ?? http.Client(),
        _insecureHttpsClient = insecureHttpsClient ?? _buildLocalSelfSignedClient();

  static http.Client _buildLocalSelfSignedClient() {
    final ioHttp = HttpClient()
      ..badCertificateCallback = (cert, host, port) =>
          host == '127.0.0.1' || host == 'localhost' || host == '::1';
    return IOClient(ioHttp);
  }

  List<MetricsSnapshot> getHistory(String profileId) =>
      List.unmodifiable(_history[profileId] ?? const []);

  /// Computes timestamp-aligned aggregated time series across given profile IDs.
  List<MetricsSnapshot> getAggregatedTimeSeries(Iterable<String> profileIds) {
    final buckets = <int, List<MetricsSnapshot>>{};
    for (final id in profileIds) {
      final list = _history[id];
      if (list == null || list.isEmpty) continue;
      for (final snap in list) {
        final secKey = snap.timestamp.millisecondsSinceEpoch ~/ 1000;
        buckets.putIfAbsent(secKey, () => []).add(snap);
      }
    }
    if (buckets.isEmpty) return const [];

    final sortedKeys = buckets.keys.toList()..sort();
    final trimmedKeys = sortedKeys.length > maxHistoryLength
        ? sortedKeys.sublist(sortedKeys.length - maxHistoryLength)
        : sortedKeys;

    return trimmedKeys.map((secKey) {
      final items = buckets[secKey]!;
      var up = 0.0;
      var down = 0.0;
      var streams = 0;
      var conns = 0;
      var rejections = 0;
      for (final item in items) {
        up += item.uploadBytesPerSec;
        down += item.downloadBytesPerSec;
        streams += item.activeStreams;
        conns += item.totalConnections;
        rejections += item.streamRejectionsTotal;
      }
      return MetricsSnapshot(
        timestamp: DateTime.fromMillisecondsSinceEpoch(secKey * 1000),
        uploadBytesPerSec: up,
        downloadBytesPerSec: down,
        activeStreams: streams,
        totalConnections: conns,
        streamRejectionsTotal: rejections,
      );
    }).toList();
  }

  /// Parses Prometheus metrics text emitted by `pkg/agent/metrics.go`.
  static AgentParsedMetrics parseAgentMetrics(String body) {
    return AgentParsedMetrics(
      totalSentBytes: extractMetricInt(
        body,
        'webrtc_gateway_traffic_bytes_total',
        labelFilter: 'direction="tx"',
      ),
      totalRecvBytes: extractMetricInt(
        body,
        'webrtc_gateway_traffic_bytes_total',
        labelFilter: 'direction="rx"',
      ),
      activeStreams: extractMetricInt(body, 'webrtc_gateway_active_streams'),
      activePeers: extractMetricInt(body, 'webrtc_gateway_active_peers'),
      streamRejectionsTotal: extractMetricInt(
        body,
        'webrtc_gateway_stream_rejections_total',
      ),
    );
  }

  /// Parses Prometheus metrics text emitted by `pkg/signaling/metrics.go`.
  static SignalMetricsSnapshot parseSignalMetrics(String body) {
    return SignalMetricsSnapshot(
      timestamp: DateTime.now(),
      registeredNodes: extractMetricInt(
        body,
        'webrtc_gateway_registered_nodes',
      ),
      activeClients: extractMetricInt(
        body,
        'webrtc_gateway_active_clients',
      ),
      signalingMessagesTotal: extractMetricInt(
        body,
        'webrtc_gateway_signaling_messages_total',
      ),
      ratelimitRejectedTotal: extractMetricInt(
        body,
        'webrtc_gateway_ratelimit_rejected_total',
      ),
    );
  }

  /// Polls Agent Prometheus endpoint at `http://127.0.0.1:<port>/metrics`.
  Future<MetricsSnapshot?> pollMetrics(String profileId, int port) async {
    final url = Uri.parse('http://127.0.0.1:$port/metrics');
    try {
      final response = await _httpClient
          .get(url)
          .timeout(const Duration(milliseconds: 1500));
      if (response.statusCode != 200) return null;

      final now = DateTime.now();
      final parsed = parseAgentMetrics(response.body);

      var upSpeed = 0.0;
      var downSpeed = 0.0;

      if (_lastPollTime.containsKey(profileId)) {
        final elapsedSec =
            now.difference(_lastPollTime[profileId]!).inMilliseconds / 1000.0;
        if (elapsedSec > 0.1) {
          final lastSent = _lastSentBytes[profileId] ?? parsed.totalSentBytes;
          final lastRecv = _lastRecvBytes[profileId] ?? parsed.totalRecvBytes;
          final sentDiff = parsed.totalSentBytes - lastSent;
          final recvDiff = parsed.totalRecvBytes - lastRecv;
          upSpeed = (sentDiff >= 0 ? sentDiff : 0) / elapsedSec;
          downSpeed = (recvDiff >= 0 ? recvDiff : 0) / elapsedSec;
        }
      }

      _lastSentBytes[profileId] = parsed.totalSentBytes;
      _lastRecvBytes[profileId] = parsed.totalRecvBytes;
      _lastPollTime[profileId] = now;

      final snapshot = MetricsSnapshot(
        timestamp: now,
        uploadBytesPerSec: upSpeed,
        downloadBytesPerSec: downSpeed,
        activeStreams: parsed.activeStreams,
        totalConnections: parsed.activePeers,
        streamRejectionsTotal: parsed.streamRejectionsTotal,
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

  /// Polls Signal server metrics endpoint, supporting both dedicated HTTP port and main TLS listener.
  Future<SignalMetricsSnapshot?> pollSignalMetrics(
    SignalServerConfig config,
  ) async {
    final Uri url;
    final http.Client client;

    if (config.metricsAddr.trim().isNotEmpty) {
      final hostPort = SignalServerConfig.normalizeLoopbackHostPort(
        config.metricsAddr,
      );
      url = Uri.parse('http://$hostPort/metrics');
      client = _httpClient;
    } else {
      final hostPort = SignalServerConfig.normalizeLoopbackHostPort(config.addr);
      final scheme = config.usesTls ? 'https' : 'http';
      url = Uri.parse('$scheme://$hostPort/metrics');
      client = config.usesTls ? _insecureHttpsClient : _httpClient;
    }

    try {
      final response = await client
          .get(url)
          .timeout(const Duration(milliseconds: 1500));
      if (response.statusCode != 200) return null;

      final snapshot = parseSignalMetrics(response.body);
      _latestSignalMetrics = snapshot;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  static int extractMetricInt(
    String body,
    String name, {
    String? labelFilter,
  }) {
    final lines = body.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final matchesExactName = line == name ||
          line.startsWith('$name{') ||
          line.startsWith('$name ') ||
          line.startsWith('$name\t');
      if (!matchesExactName) continue;

      if (labelFilter != null && !line.contains(labelFilter)) {
        continue;
      }

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final rawVal = parts.last;
        final asInt = int.tryParse(rawVal);
        if (asInt != null) return asInt;
        final asDouble = double.tryParse(rawVal);
        if (asDouble != null && asDouble.isFinite) return asDouble.round();
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

  void dispose() {
    _httpClient.close();
    _insecureHttpsClient.close();
  }
}
