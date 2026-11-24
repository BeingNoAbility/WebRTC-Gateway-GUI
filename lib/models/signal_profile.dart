String _yamlEscapeSignal(String value) {
  return value
      .replaceAll('\\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');
}

class SignalServerConfig {
  String addr;
  String staticDir;
  bool tlsAuto;
  String tlsCert;
  String tlsKey;
  String allowedOrigins;
  String portalDomain;
  String signalSecret;
  String trustedProxies;
  int maxIpConns;
  String metricsAddr;
  bool autoStart;

  SignalServerConfig({
    this.addr = ':8888',
    this.staticDir = '',
    this.tlsAuto = true,
    this.tlsCert = '',
    this.tlsKey = '',
    this.allowedOrigins = '',
    this.portalDomain = '',
    this.signalSecret = '',
    this.trustedProxies =
        '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128',
    this.maxIpConns = 64,
    this.metricsAddr = ':9090',
    this.autoStart = false,
  });

  Map<String, dynamic> toJson() => {
        'addr': addr,
        'static_dir': staticDir,
        'tls_auto': tlsAuto,
        'tls_cert': tlsCert,
        'tls_key': tlsKey,
        'allowed_origins': allowedOrigins,
        'portal_domain': portalDomain,
        'signal_secret': signalSecret,
        'trusted_proxies': trustedProxies,
        'max_ip_conns': maxIpConns,
        'metrics_addr': metricsAddr,
        'auto_start': autoStart,
      };

  factory SignalServerConfig.fromUpstreamMap(Map<dynamic, dynamic> map) =>
      SignalServerConfig(
        addr: (map['addr'] ?? ':8888').toString(),
        staticDir: (map['static'] ?? map['static_dir'] ?? '').toString(),
        tlsAuto: map['tls_auto'] == true,
        tlsCert: (map['tls_cert'] ?? '').toString(),
        tlsKey: (map['tls_key'] ?? '').toString(),
        allowedOrigins: (map['allowed_origins'] ??
                (map['allow_all_origins'] == true ? '*' : ''))
            .toString(),
        portalDomain: (map['portal_domain'] ?? '').toString(),
        signalSecret: (map['signal_secret'] ?? '').toString(),
        trustedProxies: (map['trusted_proxies'] ??
                '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128')
            .toString(),
        maxIpConns: ((map['max_ip_conns'] as num?)?.toInt() ?? 64).clamp(1, 65535),
        metricsAddr: (map['metrics_addr'] ?? ':9090').toString(),
      );

  factory SignalServerConfig.fromJson(Map<String, dynamic> json) =>
      SignalServerConfig(
        addr: json['addr'] as String? ?? ':8888',
        staticDir: json['static_dir'] as String? ?? '',
        tlsAuto: json['tls_auto'] as bool? ?? true,
        tlsCert: json['tls_cert'] as String? ?? '',
        tlsKey: json['tls_key'] as String? ?? '',
        allowedOrigins: json['allowed_origins'] as String? ?? '',
        portalDomain: json['portal_domain'] as String? ?? '',
        signalSecret: json['signal_secret'] as String? ?? '',
        trustedProxies: json['trusted_proxies'] as String? ??
            '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128',
        maxIpConns: ((json['max_ip_conns'] as num?)?.toInt() ?? 64).clamp(1, 65535),
        metricsAddr: json['metrics_addr'] as String? ?? ':9090',
        autoStart: json['auto_start'] as bool? ?? false,
      );

  String toYamlString() {
    final sb = StringBuffer();
    sb.writeln('addr: "${_yamlEscapeSignal(addr)}"');
    if (staticDir.isNotEmpty) {
      sb.writeln('static: "${_yamlEscapeSignal(staticDir)}"');
    }
    if (tlsAuto) {
      sb.writeln('tls_auto: true');
    } else {
      if (tlsCert.isNotEmpty) {
        sb.writeln('tls_cert: "${_yamlEscapeSignal(tlsCert)}"');
      }
      if (tlsKey.isNotEmpty) {
        sb.writeln('tls_key: "${_yamlEscapeSignal(tlsKey)}"');
      }
    }
    if (allowedOrigins.isNotEmpty) {
      sb.writeln('allowed_origins: "${_yamlEscapeSignal(allowedOrigins)}"');
    }
    if (portalDomain.isNotEmpty) {
      sb.writeln('portal_domain: "${_yamlEscapeSignal(portalDomain)}"');
    }
    if (signalSecret.isNotEmpty) {
      sb.writeln('signal_secret: "${_yamlEscapeSignal(signalSecret)}"');
    }
    if (trustedProxies.isNotEmpty) {
      sb.writeln('trusted_proxies: "${_yamlEscapeSignal(trustedProxies)}"');
    }
    sb.writeln('max_ip_conns: $maxIpConns');
    if (metricsAddr.isNotEmpty) {
      sb.writeln('metrics_addr: "${_yamlEscapeSignal(metricsAddr)}"');
    }
    return sb.toString();
  }

  /// Whether TLS is active on the main HTTP/WS listener.
  bool get usesTls =>
      tlsAuto || (tlsCert.trim().isNotEmpty && tlsKey.trim().isNotEmpty);

  /// Normalizes bind addresses like `:8888`, `0.0.0.0:8888`, `[::]:8888` to loopback-reachable host:port.
  static String normalizeLoopbackHostPort(String rawAddr) {
    final trimmed = rawAddr.trim();
    if (trimmed.isEmpty) return '127.0.0.1:8888';
    if (trimmed.startsWith(':')) return '127.0.0.1$trimmed';

    // Handle bracketed IPv6 like [::]:8888
    final ipv6Match = RegExp(r'^\[([^\]]+)\](:\d+)?$').firstMatch(trimmed);
    if (ipv6Match != null) {
      final host = ipv6Match.group(1) ?? '';
      final port = ipv6Match.group(2) ?? ':8888';
      if (host == '::' || host == '0:0:0:0:0:0:0:0') {
        return '127.0.0.1$port';
      }
      return '[$host]$port';
    }

    final colonIdx = trimmed.lastIndexOf(':');
    if (colonIdx > 0) {
      final host = trimmed.substring(0, colonIdx);
      final port = trimmed.substring(colonIdx);
      if (host == '0.0.0.0' || host == '::') {
        return '127.0.0.1$port';
      }
      return trimmed;
    }

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return '127.0.0.1:$trimmed';
    }
    return trimmed;
  }

  /// Calculates URL for browser portal access.
  String get portalWebUrl {
    final hostPort = normalizeLoopbackHostPort(addr);
    final scheme = usesTls ? 'https' : 'http';
    return '$scheme://$hostPort';
  }
}
