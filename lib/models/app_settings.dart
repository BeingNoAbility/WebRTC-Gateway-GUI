enum CloseAction {
  minimizeToTray,
  exitApp,
  prompt,
}

class AppSettings {
  CloseAction closeAction;
  bool startOnBoot;
  String locale;

  AppSettings({
    this.closeAction = CloseAction.prompt,
    this.startOnBoot = false,
    this.locale = 'zh',
  });

  Map<String, dynamic> toJson() => {
        'close_action': closeAction.name,
        'start_on_boot': startOnBoot,
        'locale': locale,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      closeAction: CloseAction.values.firstWhere(
        (e) => e.name == json['close_action'],
        orElse: () => CloseAction.prompt,
      ),
      startOnBoot: json['start_on_boot'] as bool? ?? false,
      locale: json['locale'] as String? ?? 'zh',
    );
  }
}
