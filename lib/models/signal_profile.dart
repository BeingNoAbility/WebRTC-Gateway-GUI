class SignalServerConfig {
  String addr;
  bool tlsAuto;
  String tlsCert;
  String tlsKey;
  String signalSecret;
  String portalDomain;
  bool allowAllOrigins;
  int metricsPort;

  SignalServerConfig({
    this.addr = ':8888',
    this.tlsAuto = true,
    this.tlsCert = '',
    this.tlsKey = '',
    this.signalSecret = '',
    this.portalDomain = '',
    this.allowAllOrigins = true,
    this.metricsPort = 9090,
  });

  Map<String, dynamic> toJson() => {
        'addr': addr,
        'tls_auto': tlsAuto,
        'tls_cert': tlsCert,
        'tls_key': tlsKey,
        'signal_secret': signalSecret,
        'portal_domain': portalDomain,
        'allow_all_origins': allowAllOrigins,
        'metrics_port': metricsPort,
      };

  factory SignalServerConfig.fromJson(Map<String, dynamic> json) => SignalServerConfig(
        addr: json['addr'] as String? ?? ':8888',
        tlsAuto: json['tls_auto'] as bool? ?? true,
        tlsCert: json['tls_cert'] as String? ?? '',
        tlsKey: json['tls_key'] as String? ?? '',
        signalSecret: json['signal_secret'] as String? ?? '',
        portalDomain: json['portal_domain'] as String? ?? '',
        allowAllOrigins: json['allow_all_origins'] as bool? ?? true,
        metricsPort: (json['metrics_port'] as num?)?.toInt() ?? 9090,
      );

  String toYamlString() {
    final sb = StringBuffer();
    sb.writeln('addr: "$addr"');
    if (tlsAuto) {
      sb.writeln('tls_auto: true');
    } else {
      if (tlsCert.isNotEmpty) sb.writeln('tls_cert: "$tlsCert"');
      if (tlsKey.isNotEmpty) sb.writeln('tls_key: "$tlsKey"');
    }
    if (signalSecret.isNotEmpty) sb.writeln('signal_secret: "$signalSecret"');
    if (portalDomain.isNotEmpty) sb.writeln('portal_domain: "$portalDomain"');
    if (allowAllOrigins) sb.writeln('allow_all_origins: true');
    sb.writeln('metrics_addr: ":$metricsPort"');
    return sb.toString();
  }
}
