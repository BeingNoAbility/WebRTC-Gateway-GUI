import 'package:flutter_test/flutter_test.dart';
import 'package:webrtc_gateway_gui/models/agent_profile.dart';
import 'package:webrtc_gateway_gui/services/diagnostic_service.dart';

void main() {
  group('AgentProfile Unit Tests', () {
    test('Profile to YAML and JSON serialization works correctly', () {
      final profile = AgentProfile(
        id: 'test_node_1',
        name: 'NAS Media',
        nodeId: 'nas-media-01',
        mode: TunnelMode.target,
        target: 'http://127.0.0.1:8096',
        signalUrl: 'wss://signal.mycluster.org/ws',
        signalSecret: 'cluster-secret-key',
        accessSecret: 'guest-pass-123',
        maxTrunks: 6,
        maxStreams: 1024,
      );

      final json = profile.toJson();
      expect(json['node_id'], 'nas-media-01');
      expect(json['max_trunks'], 6);
      expect(json['mode'], 'target');

      final reconstructed = AgentProfile.fromJson(json);
      expect(reconstructed.id, profile.id);
      expect(reconstructed.name, profile.name);
      expect(reconstructed.nodeId, profile.nodeId);
      expect(reconstructed.maxTrunks, 6);

      final yamlStr = profile.toYamlString(metricsPort: 9095);
      expect(yamlStr, contains('node_id: "nas-media-01"'));
      expect(yamlStr, contains('target: "http://127.0.0.1:8096"'));
      expect(yamlStr, contains('max_trunks: 6'));
      expect(yamlStr, contains('metrics_addr: ":9095"'));
      expect(yamlStr, contains('signal_secret: "cluster-secret-key"'));
    });

    test('directPortalUrl computes correct link from signalUrl', () {
      final profile1 = AgentProfile(
        id: 'p1',
        name: 'Node 1',
        nodeId: 'alpha',
        signalUrl: 'wss://signal.company.com/ws',
      );
      expect(profile1.directPortalUrl, 'https://signal.company.com/#alpha');

      final profile2 = AgentProfile(
        id: 'p2',
        name: 'Node 2',
        nodeId: 'beta',
        signalUrl: 'ws://192.168.1.50:8888/ws',
      );
      expect(profile2.directPortalUrl, 'http://192.168.1.50:8888/#beta');
    });

    test('formatShareCard generates clear visitor text', () {
      final profile = AgentProfile(
        id: 'p1',
        name: 'My Jellyfin',
        nodeId: 'jellyfin-home',
        signalUrl: 'https://signal.example.com',
        accessSecret: 'mypassword',
      );

      final card = profile.formatShareCard(expireHours: 24);
      expect(card, contains('My Jellyfin (jellyfin-home)'));
      expect(card, contains('mypassword'));
      expect(card, contains('24 小时内有效'));
      expect(card, contains('无需安装任何客户端'));
    });
  });

  group('DiagnosticService Unit Tests', () {
    test('Default STUN servers are configured', () {
      expect(DiagnosticService.defaultStunServers.isNotEmpty, isTrue);
      expect(DiagnosticService.defaultStunServers, contains('stun.cloudflare.com:3478'));
    });

    test('NatType display names are formatted for both zh and en', () {
      for (final type in NatType.values) {
        expect(type.displayNameZh.isNotEmpty, isTrue);
        expect(type.displayNameEn.isNotEmpty, isTrue);
      }
    });
  });
}
