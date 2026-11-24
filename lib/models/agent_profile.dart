import 'dart:convert';
import 'package:crypto/crypto.dart';

enum TunnelMode {
  target,
  dir,
  file,
}

String _yamlDoubleQuoteEscape(String value) {
  return value
      .replaceAll('\\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');
}

class AgentProfile {
  final String id;
  String name;
  String nodeId;
  TunnelMode mode;
  String target;
  String dirPath;
  String filePath;
  String signalUrl;
  String signalSecret;
  String accessSecret;
  bool allowPublic;
  String allowedProxyDomains;
  String portalUrl;
  String signLink;
  int maxTrunks;
  int maxStreams;
  List<String> stunServers;
  String turnUrl;
  String turnUser;
  String turnPass;
  bool insecure;
  bool insecureTarget;
  String proxy;
  String sni;
  String? customBinaryPath;
  bool autoStart;

  AgentProfile({
    required this.id,
    required this.name,
    this.nodeId = 'homeserver',
    this.mode = TunnelMode.target,
    this.target = 'http://127.0.0.1:8080',
    this.dirPath = '',
    this.filePath = '',
    this.signalUrl = 'ws://127.0.0.1:8888/ws',
    this.signalSecret = '',
    this.accessSecret = '',
    this.allowPublic = false,
    this.allowedProxyDomains = '',
    this.portalUrl = '',
    this.signLink = '',
    this.maxTrunks = 4,
    this.maxStreams = 512,
    List<String>? stunServers,
    this.turnUrl = '',
    this.turnUser = '',
    this.turnPass = '',
    this.insecure = false,
    this.insecureTarget = false,
    this.proxy = '',
    this.sni = '',
    this.customBinaryPath,
    this.autoStart = false,
  }) : stunServers = stunServers ??
            [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
            ];

  AgentProfile copyWith({
    String? id,
    String? name,
    String? nodeId,
    TunnelMode? mode,
    String? target,
    String? dirPath,
    String? filePath,
    String? signalUrl,
    String? signalSecret,
    String? accessSecret,
    bool? allowPublic,
    String? allowedProxyDomains,
    String? portalUrl,
    String? signLink,
    int? maxTrunks,
    int? maxStreams,
    List<String>? stunServers,
    String? turnUrl,
    String? turnUser,
    String? turnPass,
    bool? insecure,
    bool? insecureTarget,
    String? proxy,
    String? sni,
    String? customBinaryPath,
    bool clearCustomBinaryPath = false,
    bool? autoStart,
  }) {
    return AgentProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      nodeId: nodeId ?? this.nodeId,
      mode: mode ?? this.mode,
      target: target ?? this.target,
      dirPath: dirPath ?? this.dirPath,
      filePath: filePath ?? this.filePath,
      signalUrl: signalUrl ?? this.signalUrl,
      signalSecret: signalSecret ?? this.signalSecret,
      accessSecret: accessSecret ?? this.accessSecret,
      allowPublic: allowPublic ?? this.allowPublic,
      allowedProxyDomains: allowedProxyDomains ?? this.allowedProxyDomains,
      portalUrl: portalUrl ?? this.portalUrl,
      signLink: signLink ?? this.signLink,
      maxTrunks: maxTrunks ?? this.maxTrunks,
      maxStreams: maxStreams ?? this.maxStreams,
      stunServers: stunServers ?? List<String>.from(this.stunServers),
      turnUrl: turnUrl ?? this.turnUrl,
      turnUser: turnUser ?? this.turnUser,
      turnPass: turnPass ?? this.turnPass,
      insecure: insecure ?? this.insecure,
      insecureTarget: insecureTarget ?? this.insecureTarget,
      proxy: proxy ?? this.proxy,
      sni: sni ?? this.sni,
      customBinaryPath: clearCustomBinaryPath
          ? null
          : (customBinaryPath ?? this.customBinaryPath),
      autoStart: autoStart ?? this.autoStart,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'node_id': nodeId,
        'mode': mode.name,
        'target': target,
        'dir_path': dirPath,
        'file_path': filePath,
        'signal': signalUrl,
        'signal_secret': signalSecret,
        'access_secret': accessSecret,
        'allow_public': allowPublic,
        'allowed_proxy_domains': allowedProxyDomains,
        'portal_url': portalUrl,
        'sign_link': signLink,
        'max_trunks': maxTrunks,
        'max_streams': maxStreams,
        'stun_servers': stunServers,
        'turn_url': turnUrl,
        'turn_user': turnUser,
        'turn_pass': turnPass,
        'insecure': insecure,
        'insecure_target': insecureTarget,
        'proxy': proxy,
        'sni': sni,
        'custom_binary_path': customBinaryPath,
        'auto_start': autoStart,
      };

  factory AgentProfile.fromUpstreamMap(
    Map<dynamic, dynamic> map, {
    String? defaultName,
  }) {
    final nodeId = (map['node_id'] ?? 'homeserver').toString();
    final signal = (map['signal'] ?? 'ws://127.0.0.1:8888/ws').toString();
    final signalSecret = (map['signal_secret'] ?? '').toString();
    final accessSecret = (map['access_secret'] ?? '').toString();

    var mode = TunnelMode.target;
    var target = 'http://127.0.0.1:8080';
    var dirPath = '';
    var filePath = '';

    if (map.containsKey('dir') &&
        map['dir'] != null &&
        map['dir'].toString().isNotEmpty) {
      mode = TunnelMode.dir;
      dirPath = map['dir'].toString();
    } else if (map.containsKey('file') &&
        map['file'] != null &&
        map['file'].toString().isNotEmpty) {
      mode = TunnelMode.file;
      filePath = map['file'].toString();
    } else if (map.containsKey('target') && map['target'] != null) {
      mode = TunnelMode.target;
      target = map['target'].toString();
    }

    final proxy = (map['proxy'] ?? '').toString();
    final sni = (map['sni'] ?? '').toString();
    final insecure = map['insecure'] == true;
    final insecureTarget = map['insecure_target'] == true;

    var stunList = <String>[
      'stun:stun.l.google.com:19302',
      'stun:stun1.l.google.com:19302',
    ];
    if (map['stun_servers'] != null) {
      if (map['stun_servers'] is List) {
        stunList = (map['stun_servers'] as List<dynamic>)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList();
      } else if (map['stun_servers'] is String) {
        stunList = map['stun_servers']
            .toString()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    final turnUrl = (map['turn_url'] ?? '').toString();
    final turnUser = (map['turn_user'] ?? '').toString();
    final turnPass = (map['turn_pass'] ?? '').toString();
    final maxStreams = ((map['max_streams'] as num?)?.toInt() ?? 512).clamp(1, 65535);
    final maxTrunks = ((map['max_trunks'] as num?)?.toInt() ?? 4).clamp(1, 8);
    final portalUrl = (map['portal_url'] ?? '').toString();

    var allowedProxyDomains = '';
    if (map['allowed_proxy_domains'] != null) {
      if (map['allowed_proxy_domains'] is List) {
        allowedProxyDomains = (map['allowed_proxy_domains'] as List<dynamic>)
            .map((e) => e.toString())
            .join(',');
      } else {
        allowedProxyDomains = map['allowed_proxy_domains'].toString();
      }
    }

    return AgentProfile(
      id: 'agent_${DateTime.now().millisecondsSinceEpoch}_${nodeId.replaceAll(RegExp(r'\W'), '_')}',
      name: defaultName ?? '节点 ($nodeId)',
      nodeId: nodeId,
      mode: mode,
      target: target,
      dirPath: dirPath,
      filePath: filePath,
      signalUrl: signal,
      signalSecret: signalSecret,
      accessSecret: accessSecret,
      allowPublic: accessSecret.isEmpty,
      allowedProxyDomains: allowedProxyDomains,
      portalUrl: portalUrl,
      maxTrunks: maxTrunks,
      maxStreams: maxStreams,
      stunServers: stunList,
      turnUrl: turnUrl,
      turnUser: turnUser,
      turnPass: turnPass,
      insecure: insecure,
      insecureTarget: insecureTarget,
      proxy: proxy,
      sni: sni,
    );
  }

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    final accessSecret = json['access_secret'] as String? ?? '';
    final hasAllowPublic = json.containsKey('allow_public');
    return AgentProfile(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Agent',
      nodeId: json['node_id'] as String? ?? 'homeserver',
      mode: TunnelMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => TunnelMode.target,
      ),
      target: json['target'] as String? ?? 'http://127.0.0.1:8080',
      dirPath: json['dir_path'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      signalUrl: json['signal'] as String? ?? 'ws://127.0.0.1:8888/ws',
      signalSecret: json['signal_secret'] as String? ?? '',
      accessSecret: accessSecret,
      allowPublic: hasAllowPublic
          ? (json['allow_public'] as bool? ?? false)
          : accessSecret.isEmpty,
      allowedProxyDomains: json['allowed_proxy_domains'] as String? ?? '',
      portalUrl: json['portal_url'] as String? ?? '',
      signLink: json['sign_link'] as String? ?? '',
      maxTrunks: ((json['max_trunks'] as num?)?.toInt() ?? 4).clamp(1, 8),
      maxStreams: ((json['max_streams'] as num?)?.toInt() ?? 512).clamp(1, 65535),
      stunServers: (json['stun_servers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
      turnUrl: json['turn_url'] as String? ?? '',
      turnUser: json['turn_user'] as String? ?? '',
      turnPass: json['turn_pass'] as String? ?? '',
      insecure: json['insecure'] as bool? ?? false,
      insecureTarget: json['insecure_target'] as bool? ?? false,
      proxy: json['proxy'] as String? ?? '',
      sni: json['sni'] as String? ?? '',
      customBinaryPath: json['custom_binary_path'] as String?,
      autoStart: json['auto_start'] as bool? ?? false,
    );
  }

  /// Validates whether [input] conforms to Go `time.ParseDuration` syntax (positive).
  static bool isValidGoDuration(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return true;
    final regex = RegExp(r'^(?:\d+(?:\.\d+)?(?:ns|us|µs|μs|ms|s|m|h))+$');
    return regex.hasMatch(trimmed);
  }

  /// Converts profile to WebRTC-Gateway YAML config compatible with agent.yaml.
  String toYamlString({int? metricsPort}) {
    final sb = StringBuffer();
    sb.writeln('# Auto-generated WebRTC Gateway Agent Config');
    sb.writeln('node_id: "${_yamlDoubleQuoteEscape(nodeId)}"');
    sb.writeln('signal: "${_yamlDoubleQuoteEscape(signalUrl)}"');
    if (signalSecret.isNotEmpty) {
      sb.writeln('signal_secret: "${_yamlDoubleQuoteEscape(signalSecret)}"');
    }
    sb.writeln('access_secret: "${_yamlDoubleQuoteEscape(accessSecret)}"');

    switch (mode) {
      case TunnelMode.target:
        sb.writeln('target: "${_yamlDoubleQuoteEscape(target)}"');
      case TunnelMode.dir:
        sb.writeln('dir: "${_yamlDoubleQuoteEscape(dirPath)}"');
      case TunnelMode.file:
        sb.writeln('file: "${_yamlDoubleQuoteEscape(filePath)}"');
    }

    if (allowedProxyDomains.isNotEmpty) {
      sb.writeln(
        'allowed_proxy_domains: "${_yamlDoubleQuoteEscape(allowedProxyDomains)}"',
      );
    }
    if (proxy.isNotEmpty) {
      sb.writeln('proxy: "${_yamlDoubleQuoteEscape(proxy)}"');
    }
    if (sni.isNotEmpty) {
      sb.writeln('sni: "${_yamlDoubleQuoteEscape(sni)}"');
    }
    if (insecure) sb.writeln('insecure: true');
    if (insecureTarget) sb.writeln('insecure_target: true');
    sb.writeln('max_trunks: $maxTrunks');
    sb.writeln('max_streams: $maxStreams');

    sb.writeln('stun_servers:');
    for (final s in stunServers) {
      sb.writeln('  - "${_yamlDoubleQuoteEscape(s)}"');
    }

    if (turnUrl.isNotEmpty) {
      sb.writeln('turn_url: "${_yamlDoubleQuoteEscape(turnUrl)}"');
      sb.writeln('turn_user: "${_yamlDoubleQuoteEscape(turnUser)}"');
      sb.writeln('turn_pass: "${_yamlDoubleQuoteEscape(turnPass)}"');
    }

    if (metricsPort != null) {
      sb.writeln('metrics_addr: ":$metricsPort"');
    }

    if (portalUrl.isNotEmpty) {
      sb.writeln('portal_url: "${_yamlDoubleQuoteEscape(portalUrl)}"');
    }

    return sb.toString();
  }

  /// Resolves base Web Portal URL (without `#nodeId`), normalizing wildcard bind hosts.
  String get resolvedPortalBaseUrl {
    if (portalUrl.trim().isNotEmpty) {
      final raw = portalUrl.trim();
      return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    }
    try {
      final uri = Uri.parse(signalUrl);
      final scheme =
          (uri.scheme == 'wss' || uri.scheme == 'https') ? 'https' : 'http';
      var host = uri.host;
      if (host.isEmpty || host == '0.0.0.0' || host == '::' || host == '[::]') {
        host = '127.0.0.1';
      } else if (host.contains(':') && !host.startsWith('[')) {
        host = '[$host]';
      }
      final portStr =
          (uri.hasPort && uri.port != 80 && uri.port != 443 && uri.port != 0)
              ? ':${uri.port}'
              : '';
      return '$scheme://$host$portStr';
    } catch (_) {
      return 'http://127.0.0.1:8888';
    }
  }

  /// Computes the direct Web Portal visit link.
  String get directPortalUrl => '$resolvedPortalBaseUrl/#$nodeId';

  /// Generates an upstream-compatible HMAC-SHA256 signed share link (matching `pkg/agent/auth.go`).
  ///
  /// When [accessSecret] is empty and [overrideSecret] is not provided, returns [directPortalUrl]
  /// because no visitor authentication secret is configured on the node.
  String generateSignedShareUrl({
    required Duration duration,
    String? overrideSecret,
    DateTime? now,
  }) {
    final effectiveSecret =
        (overrideSecret != null && overrideSecret.isNotEmpty)
            ? overrideSecret
            : accessSecret;
    if (effectiveSecret.isEmpty) {
      return directPortalUrl;
    }
    final current = now ?? DateTime.now();
    final exp = current.add(duration).millisecondsSinceEpoch ~/ 1000;
    final sign = computeShareSignature(
      nodeId: nodeId,
      exp: exp,
      secret: effectiveSecret,
    );
    return '$resolvedPortalBaseUrl/#$nodeId?exp=$exp&sign=$sign';
  }

  /// Computes HMAC-SHA256 hex signature over `"$nodeId:$exp"` using [secret].
  static String computeShareSignature({
    required String nodeId,
    required int exp,
    required String secret,
  }) {
    final hmacSha256 = Hmac(sha256, utf8.encode(secret));
    final digest = hmacSha256.convert(utf8.encode('$nodeId:$exp'));
    return digest.toString();
  }

  bool get isPublicMode => accessSecret.isEmpty;

  /// Generates human-friendly formatted share card for clipboard.
  String formatShareCard({
    int? expireHours,
    String? shareUrl,
    bool includePassword = false,
    bool isEnglish = false,
  }) {
    final resolvedUrl = shareUrl ??
        ((expireHours != null && accessSecret.isNotEmpty)
            ? generateSignedShareUrl(duration: Duration(hours: expireHours))
            : directPortalUrl);

    final sb = StringBuffer();
    if (isEnglish) {
      sb.writeln('🌐 [WebRTC Gateway Direct Tunnel]');
      sb.writeln('----------------------------------------');
      sb.writeln('📌 Node: $name ($nodeId)');
      sb.writeln('🔗 Access URL: $resolvedUrl');
      if (accessSecret.isNotEmpty) {
        if (includePassword) {
          sb.writeln('🔑 Access Password: $accessSecret');
        } else if (expireHours != null || resolvedUrl.contains('sign=')) {
          sb.writeln('🔐 Auth: Pre-authorized signed link (no password input needed)');
        } else {
          sb.writeln('🔐 Auth: Password protected (ask owner for password)');
        }
      } else {
        sb.writeln('⚠️ Access Mode: Public (no password required)');
      }
      if (expireHours != null && (accessSecret.isNotEmpty || resolvedUrl.contains('sign='))) {
        sb.writeln('⏳ Valid For: $expireHours hours');
      }
      sb.writeln(
        '💡 Tip: No client needed. Open the link in any modern browser (Chrome/Edge/Safari/Firefox).',
      );
      sb.writeln('----------------------------------------');
    } else {
      sb.writeln('🌐 【WebRTC Gateway 直连穿透服务】');
      sb.writeln('----------------------------------------');
      sb.writeln('📌 节点名称: $name ($nodeId)');
      sb.writeln('🔗 访问地址: $resolvedUrl');
      if (accessSecret.isNotEmpty) {
        if (includePassword) {
          sb.writeln('🔑 访问密码: $accessSecret');
        } else if (expireHours != null || resolvedUrl.contains('sign=')) {
          sb.writeln('🔐 访问鉴权: 已内嵌时效数字签名，免输密码直接连通');
        } else {
          sb.writeln('🔐 访问鉴权: 已启用密码保护（请向分享者获取访问密码）');
        }
      } else {
        sb.writeln('⚠️ 访问方式: 公开免密访问（请注意访问风险）');
      }
      if (expireHours != null && (accessSecret.isNotEmpty || resolvedUrl.contains('sign='))) {
        sb.writeln('⏳ 有效时限: $expireHours 小时内有效');
      }
      sb.writeln(
        '💡 提示: 无需安装任何客户端，使用现代浏览器 (Chrome/Edge/Safari/Firefox) 打开链接即可高速直连访问。',
      );
      sb.writeln('----------------------------------------');
    }
    return sb.toString();
  }
}
