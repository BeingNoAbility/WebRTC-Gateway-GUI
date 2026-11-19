enum LogLevel {
  info,
  warning,
  error,
  success,
  debug;

  String get label {
    switch (this) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.success:
        return 'SUCCESS';
      case LogLevel.debug:
        return 'DEBUG';
    }
  }
}

enum LogSource {
  agent,
  signal,
  system,
  diagnostic;

  String get displayName {
    switch (this) {
      case LogSource.agent:
        return 'Agent';
      case LogSource.signal:
        return 'Signal';
      case LogSource.system:
        return 'System';
      case LogSource.diagnostic:
        return 'Diag';
    }
  }
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogSource source;
  final String message;

  LogEntry({
    DateTime? timestamp,
    this.level = LogLevel.info,
    required this.source,
    required this.message,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  factory LogEntry.fromRawLine(String line, LogSource source) {
    LogLevel level = LogLevel.info;
    final lower = line.toLowerCase();
    if (lower.contains('error') ||
        lower.contains('fatal') ||
        lower.contains('fail')) {
      level = LogLevel.error;
    } else if (lower.contains('warn') || lower.contains('warning')) {
      level = LogLevel.warning;
    } else if (lower.contains('success') ||
        lower.contains('connected') ||
        lower.contains('ready')) {
      level = LogLevel.success;
    }

    return LogEntry(level: level, source: source, message: line);
  }
}
