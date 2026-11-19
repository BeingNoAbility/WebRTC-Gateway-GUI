import '../constants/app_constants.dart';

enum AgentMode {
  reverseProxy,
  directory,
  singleFile;

  String get displayName {
    switch (this) {
      case AgentMode.reverseProxy:
        return 'Web应用反代 (HTTP/WS)';
      case AgentMode.directory:
        return '本地静态目录托管';
      case AgentMode.singleFile:
        return '单文件极速分发';
    }
  }

  String get description {
    switch (this) {
      case AgentMode.reverseProxy:
        return '反向代理本地 HTTP/HTTPS/WebSocket 网站或服务 (如 127.0.0.1:8080)';
      case AgentMode.directory:
        return '指定本地目录，自动生成暗黑极简文件浏览器并支持只读下载';
      case AgentMode.singleFile:
        return '零端口监听极速分发单个大文件 (ISO、安装包、视频等)';
    }
  }
}

class AgentConfig {
  String nodeId;
  AgentMode mode;
  String target;
  String dir;
  String file;
  String signal;
  String signalSecret;
  String accessSecret;
  String proxy;
  String sni;
  bool insecure;
  List<String> stunServers;
  String turnUrl;
  String turnUser;
  String turnPass;
  int maxStreams;
  String metricsAddr;
  String portalUrl;
  List<String> allowedProxyDomains;

  AgentConfig({
    this.nodeId = AppConstants.defaultNodeId,
    this.mode = AgentMode.reverseProxy,
    this.target = AppConstants.defaultTarget,
    this.dir = '',
    this.file = '',
    this.signal = AppConstants.defaultSignalUrl,
    this.signalSecret = '',
    this.accessSecret = '',
    this.proxy = '',
    this.sni = '',
    this.insecure = false,
    List<String>? stunServers,
    this.turnUrl = '',
    this.turnUser = '',
    this.turnPass = '',
    this.maxStreams = 512,
    this.metricsAddr = AppConstants.defaultMetricsAddr,
    this.portalUrl = AppConstants.defaultPortalUrl,
    List<String>? allowedProxyDomains,
  })  : stunServers = stunServers ?? List.from(AppConstants.defaultStunServers),
        allowedProxyDomains = allowedProxyDomains ?? [];

  AgentConfig copyWith({
    String? nodeId,
    AgentMode? mode,
    String? target,
    String? dir,
    String? file,
    String? signal,
    String? signalSecret,
    String? accessSecret,
    String? proxy,
    String? sni,
    bool? insecure,
    List<String>? stunServers,
    String? turnUrl,
    String? turnUser,
    String? turnPass,
    int? maxStreams,
    String? metricsAddr,
    String? portalUrl,
    List<String>? allowedProxyDomains,
  }) {
    return AgentConfig(
      nodeId: nodeId ?? this.nodeId,
      mode: mode ?? this.mode,
      target: target ?? this.target,
      dir: dir ?? this.dir,
      file: file ?? this.file,
      signal: signal ?? this.signal,
      signalSecret: signalSecret ?? this.signalSecret,
      accessSecret: accessSecret ?? this.accessSecret,
      proxy: proxy ?? this.proxy,
      sni: sni ?? this.sni,
      insecure: insecure ?? this.insecure,
      stunServers: stunServers ?? List.from(this.stunServers),
      turnUrl: turnUrl ?? this.turnUrl,
      turnUser: turnUser ?? this.turnUser,
      turnPass: turnPass ?? this.turnPass,
      maxStreams: maxStreams ?? this.maxStreams,
      metricsAddr: metricsAddr ?? this.metricsAddr,
      portalUrl: portalUrl ?? this.portalUrl,
      allowedProxyDomains: allowedProxyDomains ?? List.from(this.allowedProxyDomains),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_id': nodeId,
      'mode': mode.name,
      'target': target,
      'dir': dir,
      'file': file,
      'signal': signal,
      'signal_secret': signalSecret,
      'access_secret': accessSecret,
      'proxy': proxy,
      'sni': sni,
      'insecure': insecure,
      'stun_servers': stunServers,
      'turn_url': turnUrl,
      'turn_user': turnUser,
      'turn_pass': turnPass,
      'max_streams': maxStreams,
      'metrics_addr': metricsAddr,
      'portal_url': portalUrl,
      'allowed_proxy_domains': allowedProxyDomains,
    };
  }

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    AgentMode parsedMode = AgentMode.reverseProxy;
    final modeStr = json['mode'] as String?;
    if (modeStr != null) {
      parsedMode = AgentMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => AgentMode.reverseProxy,
      );
    } else if (json['dir'] != null && (json['dir'] as String).isNotEmpty) {
      parsedMode = AgentMode.directory;
    } else if (json['file'] != null && (json['file'] as String).isNotEmpty) {
      parsedMode = AgentMode.singleFile;
    }

    return AgentConfig(
      nodeId: json['node_id'] as String? ?? AppConstants.defaultNodeId,
      mode: parsedMode,
      target: json['target'] as String? ?? AppConstants.defaultTarget,
      dir: json['dir'] as String? ?? '',
      file: json['file'] as String? ?? '',
      signal: json['signal'] as String? ?? AppConstants.defaultSignalUrl,
      signalSecret: json['signal_secret'] as String? ?? '',
      accessSecret: json['access_secret'] as String? ?? '',
      proxy: json['proxy'] as String? ?? '',
      sni: json['sni'] as String? ?? '',
      insecure: json['insecure'] as bool? ?? false,
      stunServers: (json['stun_servers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          List.from(AppConstants.defaultStunServers),
      turnUrl: json['turn_url'] as String? ?? '',
      turnUser: json['turn_user'] as String? ?? '',
      turnPass: json['turn_pass'] as String? ?? '',
      maxStreams: json['max_streams'] as int? ?? 512,
      metricsAddr: json['metrics_addr'] as String? ?? AppConstants.defaultMetricsAddr,
      portalUrl: json['portal_url'] as String? ?? AppConstants.defaultPortalUrl,
      allowedProxyDomains: (json['allowed_proxy_domains'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  List<String> toCliArgs() {
    final args = <String>[
      '-node-id',
      nodeId.trim(),
      '-signal',
      signal.trim(),
    ];

    switch (mode) {
      case AgentMode.reverseProxy:
        if (target.trim().isNotEmpty) {
          args.addAll(['-target', target.trim()]);
        }
        break;
      case AgentMode.directory:
        if (dir.trim().isNotEmpty) {
          args.addAll(['-dir', dir.trim()]);
        }
        break;
      case AgentMode.singleFile:
        if (file.trim().isNotEmpty) {
          args.addAll(['-file', file.trim()]);
        }
        break;
    }

    if (signalSecret.trim().isNotEmpty) {
      args.addAll(['-signal-secret', signalSecret.trim()]);
    }
    if (accessSecret.trim().isNotEmpty) {
      args.addAll(['-access-secret', accessSecret.trim()]);
    }
    if (proxy.trim().isNotEmpty) {
      args.addAll(['-proxy', proxy.trim()]);
    }
    if (sni.trim().isNotEmpty) {
      args.addAll(['-sni', sni.trim()]);
    }
    if (insecure) {
      args.add('-insecure');
    }
    if (stunServers.isNotEmpty) {
      args.addAll(['-stun-servers', stunServers.join(',')]);
    }
    if (turnUrl.trim().isNotEmpty) {
      args.addAll(['-turn-url', turnUrl.trim()]);
      if (turnUser.trim().isNotEmpty) {
        args.addAll(['-turn-user', turnUser.trim()]);
      }
      if (turnPass.trim().isNotEmpty) {
        args.addAll(['-turn-pass', turnPass.trim()]);
      }
    }
    if (maxStreams > 0 && maxStreams != 512) {
      args.addAll(['-max-streams', maxStreams.toString()]);
    }
    if (metricsAddr.trim().isNotEmpty) {
      args.addAll(['-metrics-addr', metricsAddr.trim()]);
    }
    if (portalUrl.trim().isNotEmpty) {
      args.addAll(['-portal-url', portalUrl.trim()]);
    }
    if (allowedProxyDomains.isNotEmpty) {
      args.addAll(['-allowed-proxy-domains', allowedProxyDomains.join(',')]);
    }

    return args;
  }

  String toYamlString() {
    final buffer = StringBuffer();
    buffer.writeln('# WebRTC Gateway Agent Configuration');
    buffer.writeln('node_id: "$nodeId"');
    buffer.writeln('signal: "$signal"');
    if (signalSecret.isNotEmpty) buffer.writeln('signal_secret: "$signalSecret"');
    if (accessSecret.isNotEmpty) buffer.writeln('access_secret: "$accessSecret"');

    switch (mode) {
      case AgentMode.reverseProxy:
        buffer.writeln('target: "$target"');
        break;
      case AgentMode.directory:
        buffer.writeln('dir: "$dir"');
        break;
      case AgentMode.singleFile:
        buffer.writeln('file: "$file"');
        break;
    }

    if (proxy.isNotEmpty) buffer.writeln('proxy: "$proxy"');
    if (sni.isNotEmpty) buffer.writeln('sni: "$sni"');
    buffer.writeln('insecure: $insecure');

    buffer.writeln('stun_servers:');
    for (final s in stunServers) {
      buffer.writeln('  - "$s"');
    }

    if (turnUrl.isNotEmpty) {
      buffer.writeln('turn_url: "$turnUrl"');
      buffer.writeln('turn_user: "$turnUser"');
      buffer.writeln('turn_pass: "$turnPass"');
    }

    buffer.writeln('max_streams: $maxStreams');
    buffer.writeln('metrics_addr: "$metricsAddr"');
    buffer.writeln('portal_url: "$portalUrl"');

    if (allowedProxyDomains.isNotEmpty) {
      buffer.writeln('allowed_proxy_domains:');
      for (final d in allowedProxyDomains) {
        buffer.writeln('  - "$d"');
      }
    }

    return buffer.toString();
  }
}
