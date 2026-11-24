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
  final List<String> recentLogs;
  static const int maxLogs = 500;

  AgentRuntimeState({
    required this.profileId,
    this.status = ProcessStatus.stopped,
    this.pid,
    this.metricsPort,
    this.startTime,
    this.lastError,
    List<String>? logs,
  }) : recentLogs = logs ?? [];

  void addLog(String line) {
    if (recentLogs.length >= maxLogs) {
      recentLogs.removeAt(0);
    }
    recentLogs.add(line);
  }

  void clearLogs() {
    recentLogs.clear();
  }

  Duration? get uptime => startTime != null ? DateTime.now().difference(startTime!) : null;
}
