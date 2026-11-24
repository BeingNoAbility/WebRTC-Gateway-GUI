import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:webrtc_gateway_gui/models/agent_profile.dart';
import 'package:webrtc_gateway_gui/models/app_settings.dart';
import 'package:webrtc_gateway_gui/models/signal_profile.dart';
import 'package:webrtc_gateway_gui/services/config_repository.dart';
import 'package:webrtc_gateway_gui/services/diagnostic_service.dart';
import 'package:webrtc_gateway_gui/services/metrics_service.dart';
import 'package:webrtc_gateway_gui/services/process_supervisor.dart';
import 'package:webrtc_gateway_gui/services/update_service.dart';
import 'package:yaml/yaml.dart';

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
        autoStart: true,
      );

      final json = profile.toJson();
      expect(json['node_id'], 'nas-media-01');
      expect(json['max_trunks'], 6);
      expect(json['mode'], 'target');
      expect(json['auto_start'], true);

      final reconstructed = AgentProfile.fromJson(json);
      expect(reconstructed.id, profile.id);
      expect(reconstructed.name, profile.name);
      expect(reconstructed.nodeId, profile.nodeId);
      expect(reconstructed.maxTrunks, 6);
      expect(reconstructed.autoStart, isTrue);

      final yamlStr = profile.toYamlString(metricsPort: 9095);
      expect(yamlStr, contains('node_id: "nas-media-01"'));
      expect(yamlStr, contains('target: "http://127.0.0.1:8096"'));
      expect(yamlStr, contains('max_trunks: 6'));
      expect(yamlStr, contains('metrics_addr: ":9095"'));
      expect(yamlStr, contains('signal_secret: "cluster-secret-key"'));
      expect(yamlStr, isNot(contains('allow_public')));
    });

    test('Windows backslash paths in YAML export are properly escaped', () {
      final profile = AgentProfile(
        id: 'win_dir',
        name: 'Windows Folder',
        nodeId: 'win-dir',
        mode: TunnelMode.dir,
        dirPath: r'C:\Users\Alice\Documents\My "Site"',
      );

      final yamlStr = profile.toYamlString();
      final dynamic parsed = loadYaml(yamlStr);
      expect(parsed, isA<YamlMap>());
      expect(
        (parsed as YamlMap)['dir'],
        r'C:\Users\Alice\Documents\My "Site"',
      );
    });

    test('directPortalUrl normalizes wildcard bind hosts and signal schemes', () {
      final p1 = AgentProfile(
        id: 'p1',
        name: 'Node 1',
        nodeId: 'alpha',
        signalUrl: 'wss://signal.company.com/ws',
      );
      expect(p1.directPortalUrl, 'https://signal.company.com/#alpha');

      final p2 = AgentProfile(
        id: 'p2',
        name: 'Node 2',
        nodeId: 'beta',
        signalUrl: 'ws://0.0.0.0:8888/ws',
      );
      expect(p2.directPortalUrl, 'http://127.0.0.1:8888/#beta');

      final p3 = AgentProfile(
        id: 'p3',
        name: 'Node 3',
        nodeId: 'gamma',
        signalUrl: 'ws://127.0.0.1:8888/ws',
        portalUrl: 'https://portal.custom.org/',
      );
      expect(p3.directPortalUrl, 'https://portal.custom.org/#gamma');
    });

    test('generateSignedShareUrl produces upstream-compatible HMAC-SHA256 link', () {
      final profile = AgentProfile(
        id: 'p1',
        name: 'Vault',
        nodeId: 'nas-web',
        signalUrl: 'wss://signal.example.com/ws',
        accessSecret: 'visitor-secret',
      );

      final fixedNow = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);
      final signed = profile.generateSignedShareUrl(
        duration: const Duration(hours: 1),
        now: fixedNow,
      );
      const expectedExp = 1700003600;
      final expectedSign = AgentProfile.computeShareSignature(
        nodeId: 'nas-web',
        exp: expectedExp,
        secret: 'visitor-secret',
      );
      expect(
        signed,
        'https://signal.example.com/#nas-web?exp=$expectedExp&sign=$expectedSign',
      );
      expect(expectedSign.length, 64);
    });

    test('formatShareCard protects password by default when signed', () {
      final profile = AgentProfile(
        id: 'p1',
        name: 'My Jellyfin',
        nodeId: 'jellyfin-home',
        signalUrl: 'wss://signal.example.com/ws',
        accessSecret: 'mypassword',
      );

      final defaultCard = profile.formatShareCard(expireHours: 24);
      expect(defaultCard, contains('My Jellyfin (jellyfin-home)'));
      expect(defaultCard, contains('sign='));
      expect(defaultCard, contains('24 小时内有效'));
      expect(defaultCard, isNot(contains('mypassword')));

      final withPwdCard = profile.formatShareCard(
        expireHours: 24,
        includePassword: true,
      );
      expect(withPwdCard, contains('mypassword'));
    });

    test('isValidGoDuration accepts valid Go durations and rejects 7d', () {
      expect(AgentProfile.isValidGoDuration(''), isTrue);
      expect(AgentProfile.isValidGoDuration('30m'), isTrue);
      expect(AgentProfile.isValidGoDuration('24h'), isTrue);
      expect(AgentProfile.isValidGoDuration('168h'), isTrue);
      expect(AgentProfile.isValidGoDuration('1h30m'), isTrue);
      expect(AgentProfile.isValidGoDuration('7d'), isFalse);
      expect(AgentProfile.isValidGoDuration('-1h'), isFalse);
      expect(AgentProfile.isValidGoDuration('abc'), isFalse);
    });

    test('Upstream agent.example.yaml map parses correctly', () {
      final upstreamMap = {
        'node_id': 'nas-web',
        'signal': 'wss://signal.example.com/ws',
        'signal_secret': 'cluster-secret-key-123',
        'access_secret': 'visitor-secret',
        'target': 'http://127.0.0.1:8080',
        'stun_servers': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
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
    test('Defaults prioritize security (strict same-origin, TLS auto)', () {
      final config = SignalServerConfig();
      expect(config.allowedOrigins, isEmpty);
      expect(config.tlsAuto, isTrue);
      expect(config.usesTls, isTrue);
      expect(config.portalWebUrl, 'https://127.0.0.1:8888');
    });

    test('normalizeLoopbackHostPort handles wildcard and IPv6 addresses', () {
      expect(SignalServerConfig.normalizeLoopbackHostPort(':8888'), '127.0.0.1:8888');
      expect(
        SignalServerConfig.normalizeLoopbackHostPort('0.0.0.0:9443'),
        '127.0.0.1:9443',
      );
      expect(
        SignalServerConfig.normalizeLoopbackHostPort('[::]:8443'),
        '127.0.0.1:8443',
      );
    });

    test('Upstream server.example.yaml map parses and escapes Windows paths', () {
      final upstreamMap = {
        'addr': ':8888',
        'allowed_origins': '*',
        'portal_domain': 'portal.example.com',
        'signal_secret': 'cluster-secret-key-123',
        'static': r'C:\web\dist',
        'tls_auto': true,
        'max_ip_conns': 128,
        'metrics_addr': ':9090',
      };

      final config = SignalServerConfig.fromUpstreamMap(upstreamMap);
      final yaml = config.toYamlString();
      final dynamic parsed = loadYaml(yaml);
      expect((parsed as YamlMap)['static'], r'C:\web\dist');
      expect(parsed['portal_domain'], 'portal.example.com');
      expect(parsed['max_ip_conns'], 128);
    });
  });

  group('ProcessSupervisor CLI Args Tests', () {
    test('buildAgentArgs emits exact official flags across modes', () {
      final dirProfile = AgentProfile(
        id: 'd1',
        name: 'Dir',
        nodeId: 'vault',
        mode: TunnelMode.dir,
        dirPath: r'C:\Data\Share',
        signalUrl: 'wss://sig.example.com/ws',
        accessSecret: '',
        allowPublic: true,
        maxTrunks: 6,
        maxStreams: 1024,
        insecure: true,
      );

      final args = ProcessSupervisor.buildAgentArgs(dirProfile, metricsPort: 9095);
      expect(args, containsAllInOrder(['-node-id', 'vault']));
      expect(args, containsAllInOrder(['-dir', r'C:\Data\Share']));
      expect(args, contains('-allow-public'));
      expect(args, contains('-insecure'));
      expect(args, containsAllInOrder(['-metrics-addr', ':9095']));
      expect(args, isNot(contains('-target')));
      expect(args, isNot(contains('-access-secret')));
    });

    test('buildSignalArgs handles tlsAuto and custom cert modes properly', () {
      final autoCfg = SignalServerConfig(addr: ':8443', tlsAuto: true);
      final autoArgs = ProcessSupervisor.buildSignalArgs(autoCfg);
      expect(autoArgs, contains('-tls-auto'));
      expect(autoArgs, isNot(contains('-tls-cert')));

      final certCfg = SignalServerConfig(
        addr: ':443',
        tlsAuto: false,
        tlsCert: '/etc/ssl/cert.pem',
        tlsKey: '/etc/ssl/key.pem',
        portalDomain: 'portal.example.com',
      );
      final certArgs = ProcessSupervisor.buildSignalArgs(certCfg);
      expect(certArgs, isNot(contains('-tls-auto')));
      expect(certArgs, containsAllInOrder(['-tls-cert', '/etc/ssl/cert.pem']));
      expect(certArgs, containsAllInOrder(['-portal-domain', 'portal.example.com']));
    });
  });

  group('ConfigRepository Atomic Persistence & Import Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('webrtc_gui_repo_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Concurrent saves serialize safely into valid JSON', () async {
      final repo = ConfigRepository(baseDirOverride: tempDir);
      await repo.init();

      for (var i = 0; i < 10; i++) {
        repo.addProfile(
          AgentProfile(
            id: 'node_$i',
            name: 'Node $i',
            nodeId: 'node-$i',
          ),
        );
        repo.updateSettings(AppSettings(fontScale: 1.0 + (i * 0.02)));
      }
      await repo.flush();
      expect(repo.lastSaveError, isNull);

      final reloaded = ConfigRepository(baseDirOverride: tempDir);
      await reloaded.init();
      expect(reloaded.profiles.length, 11); // 1 default + 10 added
    });

    test('importFromFile parses upstream YAML with Windows paths and rejects empty', () async {
      final repo = ConfigRepository(baseDirOverride: tempDir);
      await repo.init();

      final yamlFile = File(p.join(tempDir.path, 'agent.yaml'));
      await yamlFile.writeAsString(r'''
node_id: "homeserver"
signal: "wss://signal.example.com/ws"
dir: "C:\\Users\\Test\\Files"
stun_servers: "stun:stun.cloudflare.com:3478,stun:stun.qq.com:3478"
max_trunks: 8
''');

      final summary = await repo.importFromFile(yamlFile.path);
      expect(summary['agents'], 1);
      expect(summary['type'], 'upstream_agent');
      final updated = repo.profiles.firstWhere((p) => p.nodeId == 'homeserver');
      expect(updated.id, 'default_home'); // Preserves local profile id on collision
      expect(updated.dirPath, r'C:\Users\Test\Files');
      expect(updated.maxTrunks, 8);

      final emptyFile = File(p.join(tempDir.path, 'empty.yaml'));
      await emptyFile.writeAsString('   ');
      await expectLater(
        repo.importFromFile(emptyFile.path),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('MetricsService Prometheus Parsing & Aggregation Tests', () {
    test('parseAgentMetrics parses labels, scientific notation, and exact names', () {
      const sample = '''
# HELP webrtc_gateway_active_peers Current active peers
# TYPE webrtc_gateway_active_peers gauge
webrtc_gateway_active_peers_extra{node_id="nas"} 999
webrtc_gateway_active_peers{node_id="nas"} 3
webrtc_gateway_active_streams{node_id="nas"} 14
webrtc_gateway_stream_rejections_total{node_id="nas"} 2
webrtc_gateway_traffic_bytes_total{node_id="nas",direction="rx"} 1.5e+06
webrtc_gateway_traffic_bytes_total{node_id="nas",direction="tx"} 250000
''';
      final parsed = MetricsService.parseAgentMetrics(sample);
      expect(parsed.activePeers, 3);
      expect(parsed.activeStreams, 14);
      expect(parsed.streamRejectionsTotal, 2);
      expect(parsed.totalRecvBytes, 1500000);
      expect(parsed.totalSentBytes, 250000);
    });

    test('pollMetrics handles counter reset without negative speed spike', () async {
      var call = 0;
      final mockClient = MockClient((req) async {
        call++;
        final tx = call == 1 ? 100000 : 1000; // Counter reset on restart
        return http.Response(
          'webrtc_gateway_traffic_bytes_total{node_id="a",direction="tx"} $tx\n'
          'webrtc_gateway_traffic_bytes_total{node_id="a",direction="rx"} 0\n',
          200,
        );
      });

      final service = MetricsService(httpClient: mockClient);
      await service.pollMetrics('a', 9091);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final second = await service.pollMetrics('a', 9091);

      expect(second, isNotNull);
      expect(second!.uploadBytesPerSec, 0.0);
      service.dispose();
    });
  });

  group('DiagnosticService STUN Packet & Loopback Probe Tests', () {
    test('buildBindingRequest & parseBindingResponse verify Transaction ID and XOR-MAPPED-ADDRESS', () {
      final txId = Uint8List.fromList(List<int>.generate(12, (i) => i + 1));
      final req = DiagnosticService.buildBindingRequest(fixedTransactionId: txId);
      expect(req.packet.length, 20);
      expect(req.packet.sublist(4, 8), [0x21, 0x12, 0xa4, 0x42]);

      // Construct STUN Binding Response with XOR-MAPPED-ADDRESS (198.51.100.42:54321)
      // Magic cookie = 0x21 0x12 0xA4 0x42
      const port = 54321;
      const xorPort = port ^ 0x2112;
      final resp = <int>[
        0x01, 0x01, // Binding Response
        0x00, 0x0c, // Length = 12
        0x21, 0x12, 0xa4, 0x42, // Magic Cookie
        ...txId,
        0x00, 0x20, // XOR-MAPPED-ADDRESS
        0x00, 0x08, // Attr len
        0x00, 0x01, // Reserved + IPv4
        (xorPort >> 8) & 0xff, xorPort & 0xff,
        198 ^ 0x21, 51 ^ 0x12, 100 ^ 0xa4, 42 ^ 0x42,
      ];

      final parsed = DiagnosticService.parseBindingResponse(resp, txId);
      expect(parsed, isNotNull);
      expect(parsed!.mappedAddress?.ip, '198.51.100.42');
      expect(parsed.mappedAddress?.port, 54321);

      // Wrong Transaction ID must be rejected
      final wrongTxId = Uint8List.fromList(List<int>.filled(12, 9));
      expect(DiagnosticService.parseBindingResponse(resp, wrongTxId), isNull);
    });

    test('pingStunServer succeeds against local loopback UDP mock STUN server', () async {
      final server = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sub = server.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = server.receive();
          if (dg != null && dg.data.length >= 20) {
            final txId = dg.data.sublist(8, 20);
            const xorPort = 12345 ^ 0x2112;
            final reply = Uint8List.fromList([
              0x01, 0x01, 0x00, 0x0c,
              0x21, 0x12, 0xa4, 0x42,
              ...txId,
              0x00, 0x20, 0x00, 0x08,
              0x00, 0x01,
              (xorPort >> 8) & 0xff, xorPort & 0xff,
              127 ^ 0x21, 0 ^ 0x12, 0 ^ 0xa4, 1 ^ 0x42,
            ]);
            server.send(reply, dg.address, dg.port);
          }
        }
      });

      final diag = DiagnosticService();
      final res = await diag.pingStunServer('127.0.0.1:${server.port}');
      expect(res.available, isTrue);
      expect(res.latencyMs, greaterThanOrEqualTo(0));

      await sub.cancel();
      server.close();
    });
  });

  group('AppSettings & UpdateService Tests', () {
    test('AppSettings JSON serialization supports themeMode, fontScale, autoDpi, and mirror', () {
      final settings = AppSettings(
        fontScale: 1.15,
        autoDpi: false,
        customDpiScale: 1.25,
        githubMirror: 'https://mirror.ghproxy.com/',
        themeMode: AppThemePreference.dark,
      );

      final json = settings.toJson();
      final parsed = AppSettings.fromJson(json);
      expect(parsed.fontScale, 1.15);
      expect(parsed.autoDpi, false);
      expect(parsed.customDpiScale, 1.25);
      expect(parsed.githubMirror, 'https://mirror.ghproxy.com/');
      expect(parsed.themeMode, AppThemePreference.dark);
    });

    test('UpdateService parses SHA256SUMS and formats mirror URLs', () {
      const rawUrl =
          'https://github.com/BeingNoAbility/WebRTC-Gateway/releases/download/v3.1.11/webrtc-gateway_v3.1.11_windows_amd64.zip';

      expect(
        UpdateService.formatUrlWithMirror(rawUrl, 'https://ghproxy.net/'),
        'https://ghproxy.net/$rawUrl',
      );
      expect(
        UpdateService.formatUrlWithMirror(rawUrl, '直接访问 (Direct)'),
        rawUrl,
      );

      const sumsText = '''
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  webrtc-gateway_v3.1.11_windows_amd64.zip
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *agent.exe
''';
      final parsed = UpdateService.parseSha256Sums(sumsText);
      expect(
        parsed['webrtc-gateway_v3.1.11_windows_amd64.zip'],
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        parsed['agent.exe'],
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
    });
  });
}
