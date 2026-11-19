import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/models/agent_config.dart';
import '../core/models/agent_instance.dart';
import '../core/models/agent_metrics.dart';
import '../core/models/log_entry.dart';
import '../services/storage_service.dart';

class AgentProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<AgentInstance> _agents = [];
  String? _focusedAgentId;
  String? _customBinaryPath;

  AgentProvider(this._storageService) {
    _customBinaryPath = _storageService.loadCustomAgentPath();
    _agents = _storageService.loadAgentInstances();
    for (final agent in _agents) {
      agent.addListener(_onAgentChanged);
    }
    if (_agents.isNotEmpty) {
      _focusedAgentId = _agents.first.id;
    }
  }

  void _onAgentChanged() {
    notifyListeners();
  }

  List<AgentInstance> get agents => List.unmodifiable(_agents);
  String? get focusedAgentId => _focusedAgentId;
  String? get customBinaryPath => _customBinaryPath;

  AgentInstance get focusedAgent {
    if (_agents.isEmpty) {
      final defaultAgent = AgentInstance(
        id: 'agent-${DateTime.now().millisecondsSinceEpoch}',
        name: '主穿透节点',
        config: AgentConfig(),
      );
      _agents.add(defaultAgent);
      defaultAgent.addListener(_onAgentChanged);
      _focusedAgentId = defaultAgent.id;
      return defaultAgent;
    }
    return _agents.firstWhere(
      (a) => a.id == _focusedAgentId,
      orElse: () => _agents.first,
    );
  }

  // Aggregated Statistics across all agents
  int get totalAgents => _agents.length;
  int get runningAgents => _agents.where((a) => a.isRunning).length;
  bool get hasRunningAgents => runningAgents > 0;

  int get totalActivePeers => _agents.fold(
    0,
    (sum, a) => sum + (a.isRunning ? a.metrics.activePeers : 0),
  );

  double get totalRxSpeed => _agents.fold(
    0.0,
    (sum, a) => sum + (a.isRunning ? a.metrics.rxSpeedBytesPerSec : 0.0),
  );

  double get totalTxSpeed => _agents.fold(
    0.0,
    (sum, a) => sum + (a.isRunning ? a.metrics.txSpeedBytesPerSec : 0.0),
  );

  int get totalRxBytes =>
      _agents.fold(0, (sum, a) => sum + a.metrics.rxBytesTotal);
  int get totalTxBytes =>
      _agents.fold(0, (sum, a) => sum + a.metrics.txBytesTotal);

  // Backward compatibility getters for active/focused agent
  AgentConfig get config => focusedAgent.config;
  AgentStatus get status => focusedAgent.status;
  bool get isRunning => focusedAgent.isRunning;
  String? get errorMessage => focusedAgent.errorMessage;
  AgentMetrics get metrics => focusedAgent.metrics;
  List<LogEntry> get logs => focusedAgent.logs;

  List<LogEntry> get allAgentLogs {
    final list = <LogEntry>[];
    for (final a in _agents) {
      list.addAll(a.logs);
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  void setCustomBinaryPath(String? path) {
    _customBinaryPath = path;
    _storageService.saveCustomAgentPath(path ?? '');
    notifyListeners();
  }

  void setFocusedAgentId(String? id) {
    _focusedAgentId = id;
    notifyListeners();
  }

  /// Automatically allocates an unused local metrics port starting from 9091.
  String allocateNextMetricsAddr() {
    final usedPorts = <int>{};
    for (final a in _agents) {
      final addr = a.config.metricsAddr;
      final portStr = addr.contains(':') ? addr.split(':').last : addr;
      final p = int.tryParse(portStr);
      if (p != null) usedPorts.add(p);
    }

    int port = 9091;
    while (usedPorts.contains(port)) {
      port++;
    }
    return '127.0.0.1:$port';
  }

  AgentInstance addAgent({
    required String name,
    required AgentConfig config,
    bool autoStart = false,
  }) {
    // If metricsAddr conflicts, assign unique address
    final assignedConfig = config.copyWith(
      metricsAddr: allocateNextMetricsAddr(),
    );

    final instance = AgentInstance(
      id: 'agent-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Agent ${_agents.length + 1}' : name.trim(),
      config: assignedConfig,
      autoStart: autoStart,
    );

    instance.addListener(_onAgentChanged);
    _agents.add(instance);
    _focusedAgentId = instance.id;
    _storageService.saveAgentInstances(_agents);
    notifyListeners();
    return instance;
  }

  void updateAgent(AgentInstance updated) {
    final idx = _agents.indexWhere((a) => a.id == updated.id);
    if (idx != -1) {
      _agents[idx] = updated;
      _storageService.saveAgentInstances(_agents);
      notifyListeners();
    }
  }

  Future<void> deleteAgent(String id) async {
    final idx = _agents.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final agent = _agents[idx];
      if (agent.isRunning) {
        await agent.stop();
      }
      agent.removeListener(_onAgentChanged);
      _agents.removeAt(idx);

      if (_focusedAgentId == id) {
        _focusedAgentId = _agents.isNotEmpty ? _agents.first.id : null;
      }

      _storageService.saveAgentInstances(_agents);
      notifyListeners();
    }
  }

  void updateConfig(AgentConfig newConfig) {
    focusedAgent.config = newConfig;
    _storageService.saveAgentInstances(_agents);
    _storageService.saveAgentConfig(newConfig);
    notifyListeners();
  }

  void setMode(AgentMode mode) {
    focusedAgent.config.mode = mode;
    _storageService.saveAgentInstances(_agents);
    notifyListeners();
  }

  Future<void> pickDirectory({AgentInstance? target}) async {
    final agent = target ?? focusedAgent;
    // ignore: deprecated_member_use
    final selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null) {
      agent.config.dir = selectedDirectory;
      agent.config.mode = AgentMode.directory;
      _storageService.saveAgentInstances(_agents);
      notifyListeners();
    }
  }

  Future<void> pickFile({AgentInstance? target}) async {
    final agent = target ?? focusedAgent;
    final file = await FilePicker.pickFile();
    if (file != null && file.path != null) {
      agent.config.file = file.path!;
      agent.config.mode = AgentMode.singleFile;
      _storageService.saveAgentInstances(_agents);
      notifyListeners();
    }
  }

  Future<bool> startAgent(String id) async {
    final agent = _agents.firstWhere((a) => a.id == id);
    return await agent.start(customBinaryPath: _customBinaryPath);
  }

  Future<void> stopAgent(String id) async {
    final agent = _agents.firstWhere((a) => a.id == id);
    await agent.stop();
  }

  Future<bool> start() async {
    return await focusedAgent.start(customBinaryPath: _customBinaryPath);
  }

  Future<void> stop() async {
    await focusedAgent.stop();
  }

  Future<void> startAll() async {
    for (final agent in _agents) {
      if (!agent.isRunning) {
        await agent.start(customBinaryPath: _customBinaryPath);
      }
    }
  }

  Future<void> stopAll() async {
    for (final agent in _agents) {
      if (agent.isRunning) {
        await agent.stop();
      }
    }
  }

  void clearLogs() {
    focusedAgent.clearLogs();
  }

  @override
  void dispose() {
    for (final agent in _agents) {
      agent.removeListener(_onAgentChanged);
    }
    super.dispose();
  }
}
