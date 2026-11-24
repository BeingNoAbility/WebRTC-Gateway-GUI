enum TunnelMode {
  target,
  dir,
  file,
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
    this.allowPublic = true,
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
  }) : stunServers = stunServers ?? [
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
      stunServers: stunServers ?? List.from(this.stunServers),
      turnUrl: turnUrl ?? this.turnUrl,
      turnUser: turnUser ?? this.turnUser,
      turnPass: turnPass ?? this.turnPass,
      insecure: insecure ?? this.insecure,
      insecureTarget: insecureTarget ?? this.insecureTarget,
      proxy: proxy ?? this.proxy,
      sni: sni ?? this.sni,
      customBinaryPath: customBinaryPath ?? this.customBinaryPath,
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

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
      accessSecret: json['access_secret'] as String? ?? '',
      allowPublic: json['allow_public'] as bool? ?? true,
      allowedProxyDomains: json['allowed_proxy_domains'] as String? ?? '',
      portalUrl: json['portal_url'] as String? ?? '',
      signLink: json['sign_link'] as String? ?? '',
      maxTrunks: (json['max_trunks'] as num?)?.toInt() ?? 4,
      maxStreams: (json['max_streams'] as num?)?.toInt() ?? 512,
      stunServers: (json['stun_servers'] as List<dynamic>?)
              ?.map((e) => e.toString())
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

  /// Converts profile to WebRTC-Gateway YAML config compatible with agent.yaml
  String toYamlString({int? metricsPort}) {
    final sb = StringBuffer();
    sb.writeln('# Auto-generated WebRTC Gateway Agent Config');
    sb.writeln('node_id: "$nodeId"');
    sb.writeln('signal: "$signalUrl"');
    if (signalSecret.isNotEmpty) {
      sb.writeln('signal_secret: "$signalSecret"');
    }
    if (accessSecret.isNotEmpty) {
      sb.writeln('access_secret: "$accessSecret"');
    } else {
      sb.writeln('allow_public: true');
    }
    
    switch (mode) {
      case TunnelMode.target:
        sb.writeln('target: "$target"');
        break;
      case TunnelMode.dir:
        sb.writeln('dir: "$dirPath"');
        break;
      case TunnelMode.file:
        sb.writeln('file: "$filePath"');
        break;
    }

    if (allowedProxyDomains.isNotEmpty) {
      sb.writeln('allowed_proxy_domains: "$allowedProxyDomains"');
    }
    if (proxy.isNotEmpty) sb.writeln('proxy: "$proxy"');
    if (sni.isNotEmpty) sb.writeln('sni: "$sni"');
    if (insecure) sb.writeln('insecure: true');
    if (insecureTarget) sb.writeln('insecure_target: true');
    sb.writeln('max_trunks: $maxTrunks');
    sb.writeln('max_streams: $maxStreams');
    
    sb.writeln('stun_servers:');
    for (final s in stunServers) {
      sb.writeln('  - "$s"');
    }

    if (turnUrl.isNotEmpty) {
      sb.writeln('turn_url: "$turnUrl"');
      sb.writeln('turn_user: "$turnUser"');
      sb.writeln('turn_pass: "$turnPass"');
    }

    if (metricsPort != null) {
      sb.writeln('metrics_addr: ":$metricsPort"');
    }

    if (portalUrl.isNotEmpty) {
      sb.writeln('portal_url: "$portalUrl"');
    }

    return sb.toString();
  }

  /// Computes the direct Web Portal visit link
  String get directPortalUrl {
    if (portalUrl.isNotEmpty) {
      final base = portalUrl.endsWith('/') ? portalUrl.substring(0, portalUrl.length - 1) : portalUrl;
      return '$base/#$nodeId';
    }
    try {
      final uri = Uri.parse(signalUrl);
      final scheme = uri.scheme == 'wss' ? 'https' : 'http';
      final portStr = (uri.port != 80 && uri.port != 443 && uri.port != 0) ? ':${uri.port}' : '';
      return '$scheme://${uri.host}$portStr/#$nodeId';
    } catch (_) {
      return 'http://127.0.0.1:8888/#$nodeId';
    }
  }

  /// Generates human-friendly formatted share card for clipboard
  String formatShareCard({int? expireHours}) {
    final sb = StringBuffer();
    sb.writeln('🌐 【WebRTC Gateway 直连穿透服务】');
    sb.writeln('----------------------------------------');
    sb.writeln('📌 节点名称: $name ($nodeId)');
    sb.writeln('🔗 访问地址: $directPortalUrl');
    if (accessSecret.isNotEmpty) {
      sb.writeln('🔑 访问密码: $accessSecret');
    } else {
      sb.writeln('🔑 访问密码: (公开访问，无需密码)');
    }
    if (expireHours != null) {
      sb.writeln('⏳ 有效时限: $expireHours 小时内有效');
    }
    sb.writeln('💡 提示: 无需安装任何客户端，使用现代浏览器 (Chrome/Edge/Safari/Firefox) 打开链接即可高速直连访问。');
    sb.writeln('----------------------------------------');
    return sb.toString();
  }
}
