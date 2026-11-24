enum CloseAction {
  minimizeToTray,
  exitApp,
  prompt,
}

enum AppThemePreference {
  system,
  light,
  dark,
}

class AppSettings {
  CloseAction closeAction;
  bool startOnBoot;
  String locale;
  double fontScale;
  bool autoDpi;
  double customDpiScale;
  String githubMirror;
  AppThemePreference themeMode;

  AppSettings({
    this.closeAction = CloseAction.prompt,
    this.startOnBoot = false,
    this.locale = 'zh',
    this.fontScale = 1.0,
    this.autoDpi = true,
    this.customDpiScale = 1.0,
    this.githubMirror = 'https://ghproxy.net/',
    this.themeMode = AppThemePreference.system,
  });

  Map<String, dynamic> toJson() => {
        'close_action': closeAction.name,
        'start_on_boot': startOnBoot,
        'locale': locale,
        'font_scale': fontScale,
        'auto_dpi': autoDpi,
        'custom_dpi_scale': customDpiScale,
        'github_mirror': githubMirror,
        'theme_mode': themeMode.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      closeAction: CloseAction.values.firstWhere(
        (e) => e.name == json['close_action'],
        orElse: () => CloseAction.prompt,
      ),
      startOnBoot: json['start_on_boot'] as bool? ?? false,
      locale: json['locale'] as String? ?? 'zh',
      fontScale: ((json['font_scale'] as num?)?.toDouble() ?? 1.0).clamp(0.80, 1.40),
      autoDpi: json['auto_dpi'] as bool? ?? true,
      customDpiScale: ((json['custom_dpi_scale'] as num?)?.toDouble() ?? 1.0).clamp(0.75, 2.0),
      githubMirror: json['github_mirror'] as String? ?? 'https://ghproxy.net/',
      themeMode: AppThemePreference.values.firstWhere(
        (e) => e.name == json['theme_mode'],
        orElse: () => AppThemePreference.system,
      ),
    );
  }
}
