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

  SignalServerConfig({
    this.addr = ':8888',
    this.staticDir = '',
    this.tlsAuto = true,
    this.tlsCert = '',
    this.tlsKey = '',
    this.allowedOrigins = '*',
    this.portalDomain = '',
    this.signalSecret = '',
    this.trustedProxies = '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128',
    this.maxIpConns = 64,
    this.metricsAddr = ':9090',
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
      };

  factory SignalServerConfig.fromUpstreamMap(Map<dynamic, dynamic> map) => SignalServerConfig(
        addr: (map['addr'] ?? ':8888').toString(),
        staticDir: (map['static'] ?? map['static_dir'] ?? '').toString(),
        tlsAuto: map['tls_auto'] == true,
        tlsCert: (map['tls_cert'] ?? '').toString(),
        tlsKey: (map['tls_key'] ?? '').toString(),
        allowedOrigins: (map['allowed_origins'] ?? (map['allow_all_origins'] == true ? '*' : '')).toString(),
        portalDomain: (map['portal_domain'] ?? '').toString(),
        signalSecret: (map['signal_secret'] ?? '').toString(),
        trustedProxies: (map['trusted_proxies'] ??
                '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128')
            .toString(),
        maxIpConns: (map['max_ip_conns'] as num?)?.toInt() ?? 64,
        metricsAddr: (map['metrics_addr'] ?? ':9090').toString(),
      );

  factory SignalServerConfig.fromJson(Map<String, dynamic> json) => SignalServerConfig(
        addr: json['addr'] as String? ?? ':8888',
        staticDir: json['static_dir'] as String? ?? '',
        tlsAuto: json['tls_auto'] as bool? ?? true,
        tlsCert: json['tls_cert'] as String? ?? '',
        tlsKey: json['tls_key'] as String? ?? '',
        allowedOrigins: json['allowed_origins'] as String? ?? '*',
        portalDomain: json['portal_domain'] as String? ?? '',
        signalSecret: json['signal_secret'] as String? ?? '',
        trustedProxies: json['trusted_proxies'] as String? ??
            '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128',
        maxIpConns: (json['max_ip_conns'] as num?)?.toInt() ?? 64,
        metricsAddr: json['metrics_addr'] as String? ?? ':9090',
      );

  String toYamlString() {
    final sb = StringBuffer();
    sb.writeln('addr: "$addr"');
    if (staticDir.isNotEmpty) sb.writeln('static: "$staticDir"');
    if (tlsAuto) {
      sb.writeln('tls_auto: true');
    } else {
      if (tlsCert.isNotEmpty) sb.writeln('tls_cert: "$tlsCert"');
      if (tlsKey.isNotEmpty) sb.writeln('tls_key: "$tlsKey"');
    }
    if (allowedOrigins.isNotEmpty) sb.writeln('allowed_origins: "$allowedOrigins"');
    if (portalDomain.isNotEmpty) sb.writeln('portal_domain: "$portalDomain"');
    if (signalSecret.isNotEmpty) sb.writeln('signal_secret: "$signalSecret"');
    if (trustedProxies.isNotEmpty) sb.writeln('trusted_proxies: "$trustedProxies"');
    sb.writeln('max_ip_conns: $maxIpConns');
    if (metricsAddr.isNotEmpty) sb.writeln('metrics_addr: "$metricsAddr"');
    return sb.toString();
  }

  /// Calculates URL for browser portal access
  String get portalWebUrl {
    final cleanAddr = addr.startsWith(':') ? '127.0.0.1$addr' : addr;
    final scheme = tlsAuto || tlsCert.isNotEmpty ? 'https' : 'http';
    return '$scheme://$cleanAddr';
  }
}
