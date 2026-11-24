enum CloseAction {
  minimizeToTray,
  exitApp,
  prompt,
}

class AppSettings {
  CloseAction closeAction;
  bool startOnBoot;
  String locale;
  double fontScale;
  bool autoDpi;
  double customDpiScale;
  String githubMirror;

  AppSettings({
    this.closeAction = CloseAction.prompt,
    this.startOnBoot = false,
    this.locale = 'zh',
    this.fontScale = 1.0,
    this.autoDpi = true,
    this.customDpiScale = 1.0,
    this.githubMirror = 'https://ghproxy.net/',
  });

  Map<String, dynamic> toJson() => {
        'close_action': closeAction.name,
        'start_on_boot': startOnBoot,
        'locale': locale,
        'font_scale': fontScale,
        'auto_dpi': autoDpi,
        'custom_dpi_scale': customDpiScale,
        'github_mirror': githubMirror,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      closeAction: CloseAction.values.firstWhere(
        (e) => e.name == json['close_action'],
        orElse: () => CloseAction.prompt,
      ),
      startOnBoot: json['start_on_boot'] as bool? ?? false,
      locale: json['locale'] as String? ?? 'zh',
      fontScale: (json['font_scale'] as num?)?.toDouble() ?? 1.0,
      autoDpi: json['auto_dpi'] as bool? ?? true,
      customDpiScale: (json['custom_dpi_scale'] as num?)?.toDouble() ?? 1.0,
      githubMirror: json['github_mirror'] as String? ?? 'https://ghproxy.net/',
    );
  }
}
