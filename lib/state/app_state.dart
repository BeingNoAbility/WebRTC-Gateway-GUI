import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/i18n.dart';
import '../models/agent_profile.dart';
import '../models/app_settings.dart';
import '../models/runtime_state.dart';
import '../models/signal_profile.dart';
import '../services/autostart_service.dart';
import '../services/binary_manager.dart';
import '../services/config_repository.dart';
import '../services/diagnostic_service.dart';
import '../services/metrics_service.dart';
import '../services/process_supervisor.dart';

class AppState extends ChangeNotifier {
  final ConfigRepository configRepo;
  final BinaryManager binaryManager;
  final ProcessSupervisor supervisor;
  final MetricsService metricsService;
  final DiagnosticService diagnosticService;
  final AutostartService autostartService = AutostartService();

  /// Dedicated notifier for high-frequency stdout/stderr logs so log bursts do not
  /// rebuild unrelated screens or the root `MaterialApp`.
  final ChangeNotifier logNotifier = ChangeNotifier();

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  String? _selectedLogProfileId;
  String? get selectedLogProfileId => _selectedLogProfileId;

  late SignalServerConfig signalConfig;
  late AppSettings appSettings;

  Timer? _metricsTimer;
  Timer? _logThrottleTimer;
  bool _pendingLogNotify = false;
  bool _isPollingMetrics = false;
  bool _isDisposed = false;

  StreamSubscription<String>? _stateSub;
  StreamSubscription<MapEntry<String, String>>? _logSub;

  AppState({
    required this.configRepo,
    required this.binaryManager,
    required this.supervisor,
    required this.metricsService,
    required this.diagnosticService,
  }) {
    signalConfig = configRepo.signalConfig;
    appSettings = configRepo.settings;
    AppI18n().setLocale(appSettings.locale);

    _stateSub = supervisor.onStateChange.listen((_) {
      if (!_isDisposed) notifyListeners();
    });

    _logSub = supervisor.onLog.listen((_) {
      _scheduleThrottledLogNotify();
    });

    _startMetricsPolling();
  }

  void _scheduleThrottledLogNotify() {
    _pendingLogNotify = true;
    if (_logThrottleTimer != null && _logThrottleTimer!.isActive) {
      return;
    }
    _logThrottleTimer = Timer(const Duration(milliseconds: 100), () {
      if (_isDisposed) return;
      if (_pendingLogNotify) {
        _pendingLogNotify = false;
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        logNotifier.notifyListeners();
      }
    });
  }

  void setTabIndex(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  void setSelectedLogProfileId(String? id) {
    _selectedLogProfileId = id;
    notifyListeners();
  }

  List<AgentProfile> get profiles => configRepo.profiles;

  AgentRuntimeState getRuntimeState(String profileId) =>
      supervisor.getOrCreateState(profileId);

  bool isRunning(String profileId) => supervisor.isRunning(profileId);

  int get runningCount => profiles.where((p) => isRunning(p.id)).length;

  CloseAction get closeAction => appSettings.closeAction;
  void setCloseAction(CloseAction action) {
    appSettings.closeAction = action;
    configRepo.updateSettings(appSettings);
    notifyListeners();
  }

  AppThemePreference get themePreference => appSettings.themeMode;
  void setThemePreference(AppThemePreference preference) {
    appSettings.themeMode = preference;
    configRepo.updateSettings(appSettings);
    notifyListeners();
  }

  bool get startOnBoot => appSettings.startOnBoot;
  Future<bool> setStartOnBoot(bool enable) async {
    final ok = await autostartService.setEnabled(enable);
    if (ok) {
      appSettings.startOnBoot = enable;
      configRepo.updateSettings(appSettings);
      notifyListeners();
    }
    return ok;
  }

  double get fontScale => appSettings.fontScale;
  bool get autoDpi => appSettings.autoDpi;
  double get customDpiScale => appSettings.customDpiScale;
  String get githubMirror => appSettings.githubMirror;

  void setFontScale(double scale) {
    appSettings.fontScale = scale.clamp(0.80, 1.40);
    configRepo.updateSettings(appSettings);
    notifyListeners();
  }

  void setAutoDpi(bool auto) {
    appSettings.autoDpi = auto;
    configRepo.updateSettings(appSettings);
    notifyListeners();
  }

  void setCustomDpiScale(double scale) {
    appSettings.customDpiScale = scale.clamp(0.75, 2.0);
    configRepo.updateSettings(appSettings);
    notifyListeners();
  }

  void setGithubMirror(String mirror) {
    appSettings.githubMirror = mirror.trim();
    configRepo.updateSettings(appSettings);
    notifyListeners();
  }

  void resetDisplayScaling() {
    appSettings.fontScale = 1.0;
    appSettings.autoDpi = true;
    appSettings.customDpiScale = 1.0;
    configRepo.updateSettings(appSettings);
    notifyListeners();
  }

  Future<bool> startAgent(AgentProfile profile) async {
    final ok = await supervisor.startAgent(profile);
    notifyListeners();
    return ok;
  }

  Future<void> stopAgent(String profileId) async {
    await supervisor.stopAgent(profileId);
    metricsService.clearProfile(profileId);
    notifyListeners();
  }

  Future<void> startAllAgents() async {
    final targets = profiles.where((p) => !isRunning(p.id)).toList();
    await Future.wait(targets.map((p) => supervisor.startAgent(p)));
    notifyListeners();
  }

  Future<void> stopAllAgents() async {
    final targets = profiles.where((p) => isRunning(p.id)).toList();
    await Future.wait(
      targets.map((p) async {
        await supervisor.stopAgent(p.id);
        metricsService.clearProfile(p.id);
      }),
    );
    notifyListeners();
  }

  /// Automatically launches Signal Server and Agent profiles marked with `autoStart`.
  Future<void> runAutoStarts() async {
    if (signalConfig.autoStart && !isSignalRunning()) {
      await startSignalServer();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    for (final profile in profiles) {
      if (profile.autoStart &&
          !isRunning(profile.id) &&
          (profile.accessSecret.isNotEmpty || profile.allowPublic)) {
        await startAgent(profile);
      }
    }
  }

  void addProfile(AgentProfile profile) {
    configRepo.addProfile(profile);
    notifyListeners();
  }

  void updateProfile(AgentProfile profile) {
    configRepo.updateProfile(profile);
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    if (isRunning(id)) {
      await stopAgent(id);
    }
    configRepo.removeProfile(id);
    notifyListeners();
  }

  void applyBestStunServers(List<String> stunServers) {
    if (stunServers.isEmpty) return;
    for (final profile in profiles) {
      configRepo.updateProfile(profile.copyWith(stunServers: stunServers));
    }
    notifyListeners();
  }

  Future<bool> startSignalServer() async {
    configRepo.updateSignalConfig(signalConfig);
    final ok = await supervisor.startSignalServer(signalConfig);
    notifyListeners();
    return ok;
  }

  Future<void> stopSignalServer() async {
    await supervisor.stopSignalServer();
    metricsService.clearSignal();
    notifyListeners();
  }

  Future<bool> probeSignalHealth() async {
    return supervisor.probeSignalHealth(signalConfig);
  }

  bool isSignalRunning() => supervisor.isSignalRunning();

  AgentRuntimeState get signalState => supervisor.getSignalState();

  void syncSignalConfig() {
    configRepo.updateSignalConfig(signalConfig);
    notifyListeners();
  }

  void clearLogs([String? profileId]) {
    supervisor.clearLogs(profileId);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    logNotifier.notifyListeners();
  }

  void toggleLocale() {
    final current = AppI18n().currentLocale;
    final next = current == 'zh' ? 'en' : 'zh';
    AppI18n().setLocale(next);
    appSettings.locale = next;
    configRepo.updateSettings(appSettings);
    notifyListeners();
  }

  Future<void> exportAllConfig(String targetPath) async {
    await configRepo.exportAllToFile(targetPath);
  }

  Future<void> exportAgentsConfig(String targetPath) async {
    await configRepo.exportAgentsToFile(targetPath);
  }

  Future<void> exportSignalConfig(String targetPath) async {
    await configRepo.exportSignalToFile(targetPath);
  }

  Future<void> exportUpstreamAgentYaml(
    String profileId,
    String targetPath,
  ) async {
    await configRepo.exportUpstreamAgentYaml(profileId, targetPath);
  }

  Future<void> exportUpstreamSignalYaml(String targetPath) async {
    await configRepo.exportUpstreamSignalYaml(targetPath);
  }

  Future<Map<String, dynamic>> importConfigFile(String filePath) async {
    final res = await configRepo.importFromFile(filePath);
    signalConfig = configRepo.signalConfig;
    appSettings = configRepo.settings;
    AppI18n().setLocale(appSettings.locale);
    notifyListeners();
    return res;
  }

  void _startMetricsPolling() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_isPollingMetrics || _isDisposed) return;
      _isPollingMetrics = true;

      try {
        final futures = <Future<bool>>[];
        for (final profile in profiles) {
          final state = getRuntimeState(profile.id);
          if (state.status == ProcessStatus.running &&
              state.metricsPort != null) {
            futures.add(
              metricsService
                  .pollMetrics(profile.id, state.metricsPort!)
                  .then((snap) => snap != null),
            );
          }
        }

        if (isSignalRunning()) {
          futures.add(
            metricsService
                .pollSignalMetrics(signalConfig)
                .then((snap) => snap != null),
          );
        }

        if (futures.isEmpty) return;
        final results = await Future.wait(futures);
        if (!_isDisposed && results.any((updated) => updated)) {
          notifyListeners();
        }
      } finally {
        _isPollingMetrics = false;
      }
    });
  }

  Future<void> shutdownForExit() async {
    _metricsTimer?.cancel();
    _logThrottleTimer?.cancel();
    await stopAllAgents();
    await stopSignalServer();
    await configRepo.flush();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _metricsTimer?.cancel();
    _logThrottleTimer?.cancel();
    unawaited(_stateSub?.cancel());
    unawaited(_logSub?.cancel());
    metricsService.dispose();
    unawaited(supervisor.dispose());
    logNotifier.dispose();
    super.dispose();
  }
}
