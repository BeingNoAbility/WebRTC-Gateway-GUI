import 'dart:collection';

enum ProcessStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

class AgentRuntimeState {
  final String profileId;
  ProcessStatus status;
  int? pid;
  int? metricsPort;
  DateTime? startTime;
  String? lastError;
  String? generatedShareLink;
  int generation;
  int logVersion;
  final ListQueue<String> _recentLogs;
  static const int maxLogs = 500;

  AgentRuntimeState({
    required this.profileId,
    this.status = ProcessStatus.stopped,
    this.pid,
    this.metricsPort,
    this.startTime,
    this.lastError,
    this.generatedShareLink,
    this.generation = 0,
    this.logVersion = 0,
    List<String>? logs,
  }) : _recentLogs = ListQueue<String>.from(logs ?? const []);

  List<String> get recentLogs => List<String>.unmodifiable(_recentLogs);

  void addLog(String line) {
    if (_recentLogs.length >= maxLogs) {
      _recentLogs.removeFirst();
    }
    _recentLogs.addLast(line);
    logVersion++;
  }

  void clearLogs() {
    _recentLogs.clear();
    logVersion++;
  }

  Duration? get uptime =>
      startTime != null ? DateTime.now().difference(startTime!) : null;
}
