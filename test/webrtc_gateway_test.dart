import 'package:flutter_test/flutter_test.dart';
import 'package:webrtc_gateway_gui/core/models/agent_config.dart';
import 'package:webrtc_gateway_gui/core/models/agent_instance.dart';
import 'package:webrtc_gateway_gui/core/models/agent_metrics.dart';
import 'package:webrtc_gateway_gui/core/utils/hmac_signer.dart';

void main() {
  group('HmacSigner tests', () {
    test('HMAC-SHA256 signature computation matches Go implementation', () {
      const secret = 'my-secret-key-123';
      const nodeId = 'nas-node';
      const exp = 1750000000;

      final sign = HmacSigner.generateShareSignature(nodeId, exp, secret);
      expect(sign, isNotEmpty);
      expect(sign.length, equals(64)); // SHA256 hex string is 64 characters
    });

    test('generateShareLink formats valid URL with fragment and signature', () {
      const portalUrl = 'http://127.0.0.1:8888';
      const nodeId = 'nas-node';
      const secret = 'my-secret-key-123';

      final link = HmacSigner.generateShareLink(
        portalUrl: portalUrl,
        nodeId: nodeId,
        accessSecret: secret,
        duration: const Duration(hours: 24),
      );

      expect(link, startsWith('http://127.0.0.1:8888/#nas-node?exp='));
      expect(link, contains('&sign='));

      final parsed = HmacSigner.parseShareLink(link);
      expect(parsed, isNotNull);
      expect(parsed!['nodeId'], equals('nas-node'));
      expect(parsed['portalUrl'], equals('http://127.0.0.1:8888'));
      expect(parsed['exp'], isNotNull);
      expect(parsed['sign'], isNotNull);
      expect(parsed['isExpired'], isFalse);
    });

    test('generateShareLink with empty secret produces direct public link', () {
      final link = HmacSigner.generateShareLink(
        portalUrl: 'http://signal.example.com:8888',
        nodeId: 'public-node',
        accessSecret: '',
        duration: const Duration(hours: 1),
      );

      expect(link, equals('http://signal.example.com:8888/#public-node'));
    });
  });

  group('AgentConfig tests', () {
    test('AgentConfig CLI flags generation', () {
      final config = AgentConfig(
        nodeId: 'vault-1',
        mode: AgentMode.reverseProxy,
        target: 'http://127.0.0.1:3000',
        signal: 'ws://127.0.0.1:8888/ws',
        signalSecret: 'cluster-secret',
        accessSecret: 'visitor-pass',
      );

      final args = config.toCliArgs();
      expect(args, contains('-node-id'));
      expect(args[args.indexOf('-node-id') + 1], equals('vault-1'));
      expect(args, contains('-target'));
      expect(
        args[args.indexOf('-target') + 1],
        equals('http://127.0.0.1:3000'),
      );
      expect(args, contains('-signal'));
      expect(
        args[args.indexOf('-signal') + 1],
        equals('ws://127.0.0.1:8888/ws'),
      );
      expect(args, contains('-signal-secret'));
      expect(
        args[args.indexOf('-signal-secret') + 1],
        equals('cluster-secret'),
      );
      expect(args, contains('-access-secret'));
      expect(args[args.indexOf('-access-secret') + 1], equals('visitor-pass'));
    });

    test('AgentConfig Directory Mode CLI flags', () {
      final config = AgentConfig(
        nodeId: 'dir-node',
        mode: AgentMode.directory,
        dir: 'C:\\SharedData',
      );

      final args = config.toCliArgs();
      expect(args, contains('-dir'));
      expect(args[args.indexOf('-dir') + 1], equals('C:\\SharedData'));
      expect(args.contains('-target'), isFalse);
    });

    test('AgentConfig Single File Mode CLI flags', () {
      final config = AgentConfig(
        nodeId: 'file-node',
        mode: AgentMode.singleFile,
        file: 'C:\\Data\\archive.zip',
      );

      final args = config.toCliArgs();
      expect(args, contains('-file'));
      expect(args[args.indexOf('-file') + 1], equals('C:\\Data\\archive.zip'));
      expect(args.contains('-target'), isFalse);
    });
  });

  group('AgentMetrics Prometheus parser tests', () {
    test('Parses standard Prometheus metrics text', () {
      const prometheusOutput = '''
# HELP webrtc_gateway_active_peers Current number of active WebRTC peer connections
# TYPE webrtc_gateway_active_peers gauge
webrtc_gateway_active_peers{node_id="nas"} 3

# HELP webrtc_gateway_active_streams Current number of active P2PMux logical streams
# TYPE webrtc_gateway_active_streams gauge
webrtc_gateway_active_streams{node_id="nas"} 12

# HELP webrtc_gateway_max_streams Configured maximum concurrent streams threshold
# TYPE webrtc_gateway_max_streams gauge
webrtc_gateway_max_streams{node_id="nas"} 512

# HELP webrtc_gateway_traffic_rx_bytes_total Total bytes received
# TYPE webrtc_gateway_traffic_rx_bytes_total counter
webrtc_gateway_traffic_rx_bytes_total{node_id="nas"} 2048000

# HELP webrtc_gateway_traffic_tx_bytes_total Total bytes sent
# TYPE webrtc_gateway_traffic_tx_bytes_total counter
webrtc_gateway_traffic_tx_bytes_total{node_id="nas"} 4096000
''';

      final metrics = AgentMetrics.parsePrometheus(prometheusOutput);
      expect(metrics.activePeers, equals(3));
      expect(metrics.activeStreams, equals(12));
      expect(metrics.maxStreams, equals(512));
      expect(metrics.rxBytesTotal, equals(2048000));
      expect(metrics.txBytesTotal, equals(4096000));
    });

    test('formatBytes and formatSpeed', () {
      expect(AgentMetrics.formatBytes(500), equals('500.0 B'));
      expect(AgentMetrics.formatBytes(2048), equals('2.0 KB'));
      expect(AgentMetrics.formatBytes(10485760), equals('10.0 MB'));
      expect(AgentMetrics.formatSpeed(1048576), equals('1.0 MB/s'));
    });
  });

  group('AgentInstance multi-agent tests', () {
    test('AgentInstance JSON serialization and restoration', () {
      final instance = AgentInstance(
        id: 'agent-nas-1',
        name: '家庭 NAS 反代',
        config: AgentConfig(
          nodeId: 'nas-web',
          mode: AgentMode.reverseProxy,
          target: 'http://192.168.1.100:5000',
          metricsAddr: '127.0.0.1:9092',
        ),
        autoStart: true,
      );

      final json = instance.toJson();
      final restored = AgentInstance.fromJson(json);

      expect(restored.id, equals('agent-nas-1'));
      expect(restored.name, equals('家庭 NAS 反代'));
      expect(restored.config.nodeId, equals('nas-web'));
      expect(restored.config.target, equals('http://192.168.1.100:5000'));
      expect(restored.config.metricsAddr, equals('127.0.0.1:9092'));
      expect(restored.autoStart, isTrue);
    });
  });
}
