import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/i18n.dart';
import '../models/agent_profile.dart';
import '../models/runtime_state.dart';
import '../models/signal_profile.dart';
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

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  String? _selectedLogProfileId;
  String? get selectedLogProfileId => _selectedLogProfileId;

  SignalServerConfig signalConfig = SignalServerConfig();

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
    await supervisor.startSignalServer(signalConfig);
    notifyListeners();
  }

  Future<void> stopSignalServer() async {
    await supervisor.stopSignalServer();
    notifyListeners();
  }

  bool isSignalRunning() => supervisor.isSignalRunning();

  void toggleLocale() {
    final current = AppI18n().currentLocale;
    AppI18n().setLocale(current == 'zh' ? 'en' : 'zh');
    notifyListeners();
  }

  void _startMetricsPolling() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      bool updated = false;
      for (final profile in profiles) {
        final state = getRuntimeState(profile.id);
        if (state.status == ProcessStatus.running && state.metricsPort != null) {
          final res = await metricsService.pollMetrics(profile.id, state.metricsPort!);
          if (res != null) updated = true;
        }
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
