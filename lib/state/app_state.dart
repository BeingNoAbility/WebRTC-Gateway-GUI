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

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  String? _selectedLogProfileId;
  String? get selectedLogProfileId => _selectedLogProfileId;

  late SignalServerConfig signalConfig;
  late AppSettings appSettings;

  Timer? _metricsTimer;
  StreamSubscription? _stateSub;
  StreamSubscription? _logSub;

  AppState({
    required this.configRepo,
    required this.binaryManager,
    required this.supervisor,
    required this.metricsService,
    required this.diagnosticService,
  }) {
    signalConfig = configRepo.signalConfig;
    appSettings = configRepo.settings;

    _stateSub = supervisor.onStateChange.listen((_) {
      notifyListeners();
    });

    _logSub = supervisor.onLog.listen((_) {
      notifyListeners();
    });

    _startMetricsPolling();
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

  AgentRuntimeState getRuntimeState(String profileId) => supervisor.getOrCreateState(profileId);

  bool isRunning(String profileId) => supervisor.isRunning(profileId);

  int get runningCount => profiles.where((p) => isRunning(p.id)).length;

  CloseAction get closeAction => appSettings.closeAction;
  void setCloseAction(CloseAction action) {
    appSettings.closeAction = action;
    configRepo.updateSettings(appSettings);
    notifyListeners();
  }

  bool get startOnBoot => appSettings.startOnBoot;
  Future<void> setStartOnBoot(bool enable) async {
    final ok = await autostartService.setEnabled(enable);
    if (ok) {
      appSettings.startOnBoot = enable;
      configRepo.updateSettings(appSettings);
      notifyListeners();
    }
  }

  Future<void> startAgent(AgentProfile profile) async {
    await supervisor.startAgent(profile);
    notifyListeners();
  }

  Future<void> stopAgent(String profileId) async {
    await supervisor.stopAgent(profileId);
    metricsService.clearProfile(profileId);
    notifyListeners();
  }

  Future<void> startAllAgents() async {
    for (final profile in profiles) {
      if (!isRunning(profile.id)) {
        await supervisor.startAgent(profile);
      }
    }
    notifyListeners();
  }

  Future<void> stopAllAgents() async {
    for (final profile in profiles) {
      if (isRunning(profile.id)) {
        await supervisor.stopAgent(profile.id);
      }
    }
    notifyListeners();
  }

  Future<void> addProfile(AgentProfile profile) async {
    configRepo.addProfile(profile);
    notifyListeners();
  }

  Future<void> updateProfile(AgentProfile profile) async {
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

  Future<void> startSignalServer() async {
    configRepo.updateSignalConfig(signalConfig);
    await supervisor.startSignalServer(signalConfig);
    notifyListeners();
  }

  Future<void> stopSignalServer() async {
    await supervisor.stopSignalServer();
    metricsService.clearSignal();
    notifyListeners();
  }

  Future<bool> probeSignalHealth() async {
    return await supervisor.probeSignalHealth();
  }

  bool isSignalRunning() => supervisor.isSignalRunning();

  AgentRuntimeState get signalState => supervisor.getSignalState();

  void syncSignalConfig() {
    configRepo.updateSignalConfig(signalConfig);
    notifyListeners();
  }

  void clearLogs([String? profileId]) {
    supervisor.clearLogs(profileId);
    notifyListeners();
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

  Future<void> exportUpstreamAgentYaml(String profileId, String targetPath) async {
    await configRepo.exportUpstreamAgentYaml(profileId, targetPath);
  }

  Future<void> exportUpstreamSignalYaml(String targetPath) async {
    await configRepo.exportUpstreamSignalYaml(targetPath);
  }

  Future<Map<String, dynamic>> importConfigFile(String filePath) async {
    final res = await configRepo.importFromFile(filePath);
    signalConfig = configRepo.signalConfig;
    appSettings = configRepo.settings;
    notifyListeners();
    return res;
  }

  void _startMetricsPolling() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      bool updated = false;

      // 1. Poll running agents
      for (final profile in profiles) {
        final state = getRuntimeState(profile.id);
        if (state.status == ProcessStatus.running && state.metricsPort != null) {
          final res = await metricsService.pollMetrics(profile.id, state.metricsPort!);
          if (res != null) updated = true;
        }
      }

      // 2. Poll running Signal server
      if (isSignalRunning()) {
        final sigRes = await metricsService.pollSignalMetrics(signalConfig.addr, signalConfig.metricsAddr);
        if (sigRes != null) updated = true;
      }

      if (updated) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _stateSub?.cancel();
    _logSub?.cancel();
    supervisor.dispose();
    super.dispose();
  }
}
