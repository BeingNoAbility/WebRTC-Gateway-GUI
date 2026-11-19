class SignalConfig {
  String addr;
  String signalSecret;
  String allowedOrigins;
  bool allowAllOrigins;
  String staticDir;
  String tlsCert;
  String tlsKey;
  bool tlsAuto;
  int maxIpConns;
  String trustedProxies;
  String metricsAddr;

  SignalConfig({
    this.addr = ':8888',
    this.signalSecret = '',
    this.allowedOrigins = '',
    this.allowAllOrigins = false,
    this.staticDir = '',
    this.tlsCert = '',
    this.tlsKey = '',
    this.tlsAuto = false,
    this.maxIpConns = 64,
    this.trustedProxies =
        '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128',
    this.metricsAddr = ':9090',
  });

  SignalConfig copyWith({
    String? addr,
    String? signalSecret,
    String? allowedOrigins,
    bool? allowAllOrigins,
    String? staticDir,
    String? tlsCert,
    String? tlsKey,
    bool? tlsAuto,
    int? maxIpConns,
    String? trustedProxies,
    String? metricsAddr,
  }) {
    return SignalConfig(
      addr: addr ?? this.addr,
      signalSecret: signalSecret ?? this.signalSecret,
      allowedOrigins: allowedOrigins ?? this.allowedOrigins,
      allowAllOrigins: allowAllOrigins ?? this.allowAllOrigins,
      staticDir: staticDir ?? this.staticDir,
      tlsCert: tlsCert ?? this.tlsCert,
      tlsKey: tlsKey ?? this.tlsKey,
      tlsAuto: tlsAuto ?? this.tlsAuto,
      maxIpConns: maxIpConns ?? this.maxIpConns,
      trustedProxies: trustedProxies ?? this.trustedProxies,
      metricsAddr: metricsAddr ?? this.metricsAddr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addr': addr,
      'signal_secret': signalSecret,
      'allowed_origins': allowedOrigins,
      'allow_all_origins': allowAllOrigins,
      'static_dir': staticDir,
      'tls_cert': tlsCert,
      'tls_key': tlsKey,
      'tls_auto': tlsAuto,
      'max_ip_conns': maxIpConns,
      'trusted_proxies': trustedProxies,
      'metrics_addr': metricsAddr,
    };
  }

  factory SignalConfig.fromJson(Map<String, dynamic> json) {
    return SignalConfig(
      addr: json['addr'] as String? ?? ':8888',
      signalSecret: json['signal_secret'] as String? ?? '',
      allowedOrigins: json['allowed_origins'] as String? ?? '',
      allowAllOrigins: json['allow_all_origins'] as bool? ?? false,
      staticDir: json['static_dir'] as String? ?? '',
      tlsCert: json['tls_cert'] as String? ?? '',
      tlsKey: json['tls_key'] as String? ?? '',
      tlsAuto: json['tls_auto'] as bool? ?? false,
      maxIpConns: json['max_ip_conns'] as int? ?? 64,
      trustedProxies:
          json['trusted_proxies'] as String? ??
          '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128',
      metricsAddr: json['metrics_addr'] as String? ?? ':9090',
    );
  }

  List<String> toCliArgs() {
    final args = <String>['-addr', addr.trim()];
    if (signalSecret.trim().isNotEmpty) {
      args.addAll(['-signal-secret', signalSecret.trim()]);
    }
    if (allowAllOrigins) {
      args.add('-allow-all-origins');
    } else if (allowedOrigins.trim().isNotEmpty) {
      args.addAll(['-allowed-origins', allowedOrigins.trim()]);
    }
    if (staticDir.trim().isNotEmpty) {
      args.addAll(['-static', staticDir.trim()]);
    }
    if (tlsAuto) {
      args.add('-tls-auto');
    } else if (tlsCert.trim().isNotEmpty && tlsKey.trim().isNotEmpty) {
      args.addAll(['-tls-cert', tlsCert.trim(), '-tls-key', tlsKey.trim()]);
    }
    if (maxIpConns > 0 && maxIpConns != 64) {
      args.addAll(['-max-ip-conns', maxIpConns.toString()]);
    }
    if (metricsAddr.trim().isNotEmpty) {
      args.addAll(['-metrics-addr', metricsAddr.trim()]);
    }
    return args;
  }
}
