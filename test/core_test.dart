import 'package:flutter_test/flutter_test.dart';
import 'package:webrtc_gateway_gui/models/agent_profile.dart';
import 'package:webrtc_gateway_gui/models/app_settings.dart';
import 'package:webrtc_gateway_gui/models/signal_profile.dart';
import 'package:webrtc_gateway_gui/services/diagnostic_service.dart';
import 'package:webrtc_gateway_gui/services/update_service.dart';

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

    test('Upstream agent.example.yaml map parses correctly', () {
      final upstreamMap = {
        'node_id': 'nas-web',
        'signal': 'wss://signal.example.com/ws',
        'signal_secret': 'cluster-secret-key-123',
        'access_secret': 'visitor-secret',
        'target': 'http://127.0.0.1:8080',
        'stun_servers': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
        'max_trunks': 4,
        'max_streams': 512,
      };

      final profile = AgentProfile.fromUpstreamMap(upstreamMap);
      expect(profile.nodeId, 'nas-web');
      expect(profile.signalUrl, 'wss://signal.example.com/ws');
      expect(profile.signalSecret, 'cluster-secret-key-123');
      expect(profile.accessSecret, 'visitor-secret');
      expect(profile.target, 'http://127.0.0.1:8080');
      expect(profile.maxTrunks, 4);
      expect(profile.maxStreams, 512);
      expect(profile.stunServers.length, 2);
    });
  });

  group('SignalServerConfig Unit Tests', () {
    test('Upstream server.example.yaml map parses and exports correctly', () {
      final upstreamMap = {
        'addr': ':8888',
        'allowed_origins': '*',
        'portal_domain': 'portal.example.com',
        'signal_secret': 'cluster-secret-key-123',
        'static': '/var/www/html',
        'tls_auto': true,
        'max_ip_conns': 128,
        'metrics_addr': ':9090',
      };

      final config = SignalServerConfig.fromUpstreamMap(upstreamMap);
      expect(config.addr, ':8888');
      expect(config.allowedOrigins, '*');
      expect(config.portalDomain, 'portal.example.com');
      expect(config.signalSecret, 'cluster-secret-key-123');
      expect(config.staticDir, '/var/www/html');
      expect(config.tlsAuto, isTrue);
      expect(config.maxIpConns, 128);

      final yaml = config.toYamlString();
      expect(yaml, contains('addr: ":8888"'));
      expect(yaml, contains('tls_auto: true'));
      expect(yaml, contains('portal_domain: "portal.example.com"'));
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

  group('AppSettings and Scaling Tests', () {
    test('AppSettings JSON serialization supports fontScale, autoDpi, and mirror', () {
      final settings = AppSettings(
        fontScale: 1.15,
        autoDpi: false,
        customDpiScale: 1.25,
        githubMirror: 'https://mirror.ghproxy.com/',
      );

      final json = settings.toJson();
      expect(json['font_scale'], 1.15);
      expect(json['auto_dpi'], false);
      expect(json['custom_dpi_scale'], 1.25);
      expect(json['github_mirror'], 'https://mirror.ghproxy.com/');

      final parsed = AppSettings.fromJson(json);
      expect(parsed.fontScale, 1.15);
      expect(parsed.autoDpi, false);
      expect(parsed.customDpiScale, 1.25);
      expect(parsed.githubMirror, 'https://mirror.ghproxy.com/');
    });
  });

  group('UpdateService Mirror Formatting Tests', () {
    test('formatUrlWithMirror prepends proxy correctly or keeps direct', () {
      const rawUrl = 'https://github.com/BeingNoAbility/WebRTC-Gateway/releases/download/v3.1.11/agent.exe';
      
      expect(
        UpdateService.formatUrlWithMirror(rawUrl, 'https://ghproxy.net/'),
        'https://ghproxy.net/https://github.com/BeingNoAbility/WebRTC-Gateway/releases/download/v3.1.11/agent.exe',
      );

      expect(
        UpdateService.formatUrlWithMirror(rawUrl, '直接访问 (Direct)'),
        rawUrl,
      );

      expect(
        UpdateService.formatUrlWithMirror(rawUrl, ''),
        rawUrl,
      );
    });
  });
}
