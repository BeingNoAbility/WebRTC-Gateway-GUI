import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/models/agent_config.dart';
import '../core/models/agent_metrics.dart';
import '../core/models/log_entry.dart';
import '../core/utils/process_runner.dart';

enum AgentStatus {
  stopped,
  starting,
  online,
  stopping,
  error;

  String get label {
    switch (this) {
      case AgentStatus.stopped:
        return '已停止';
      case AgentStatus.starting:
        return '正在启动并撮合信令...';
      case AgentStatus.online:
        return '服务在线 (P2P 就绪)';
      case AgentStatus.stopping:
        return '正在停止...';
      case AgentStatus.error:
        return '运行异常';
    }
  }
}

class AgentService extends ChangeNotifier {
  AgentStatus _status = AgentStatus.stopped;
  String? _errorMessage;
  ManagedProcess? _process;
  Timer? _metricsTimer;
  AgentMetrics _metrics = AgentMetrics.initial();
  final List<LogEntry> _logs = [];
  String? _customBinaryPath;

  AgentStatus get status => _status;
  bool get isRunning =>
      _status == AgentStatus.online || _status == AgentStatus.starting;
  String? get errorMessage => _errorMessage;
  AgentMetrics get metrics => _metrics;
  List<LogEntry> get logs => List.unmodifiable(_logs);
  String? get customBinaryPath => _customBinaryPath;

  void setCustomBinaryPath(String? path) {
    _customBinaryPath = path;
    notifyListeners();
  }

  void addLog(
    String message, {
    LogLevel level = LogLevel.info,
    LogSource source = LogSource.agent,
  }) {
    _logs.add(LogEntry(level: level, source: source, message: message));
    if (_logs.length > 1000) {
      _logs.removeRange(0, 100);
    }
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<bool> start(AgentConfig config) async {
    if (isRunning) return false;

    _status = AgentStatus.starting;
    _errorMessage = null;
    notifyListeners();

    addLog(
      '准备启动 WebRTC Gateway Agent (Node: ${config.nodeId})...',
      level: LogLevel.info,
      source: LogSource.system,
    );

    if (Platform.isWindows) {
      final binary = ProcessRunner.findBinary(
        'agent',
        customPath: _customBinaryPath,
      );
      if (binary == null) {
        _status = AgentStatus.error;
        _errorMessage = '未找到 agent.exe 二进制文件，请确认放置于 assets/bin 或设置自定义路径';
        addLog(
          '错误: $_errorMessage',
          level: LogLevel.error,
          source: LogSource.system,
        );
        notifyListeners();
        return false;
      }

      final args = config.toCliArgs();
      addLog(
        '执行命令: $binary ${args.join(" ")}',
        level: LogLevel.debug,
        source: LogSource.system,
      );

      try {
        _process = await ProcessRunner.start(
          executable: binary,
          arguments: args,
          onStdout: (line) {
            _handleOutputLine(line);
          },
          onStderr: (line) {
            _handleOutputLine(line);
          },
          onExit: (code) {
            _handleProcessExit(code);
          },
        );

        await Future.delayed(const Duration(milliseconds: 600));
        if (_status == AgentStatus.starting) {
          _status = AgentStatus.online;
          addLog(
            'Agent 进程已成功创建 (PID: ${_process!.pid})',
            level: LogLevel.success,
            source: LogSource.system,
          );
          notifyListeners();
        }

        _startMetricsPolling(config.metricsAddr);
        return true;
      } catch (e) {
        _status = AgentStatus.error;
        _errorMessage = '启动进程失败: $e';
        addLog(_errorMessage!, level: LogLevel.error, source: LogSource.system);
        notifyListeners();
        return false;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      _status = AgentStatus.online;
      addLog(
        'Android 环境：Agent 控制器已连接就绪 (Node: ${config.nodeId})',
        level: LogLevel.success,
        source: LogSource.system,
      );
      _startMetricsPolling(config.metricsAddr);
      notifyListeners();
      return true;
    }
  }

  void _handleOutputLine(String line) {
    final entry = LogEntry.fromRawLine(line, LogSource.agent);
    _logs.add(entry);
    if (_logs.length > 1000) {
      _logs.removeRange(0, 100);
    }

    final lower = line.toLowerCase();
    if (lower.contains('fatal') || lower.contains('failed to init')) {
      _status = AgentStatus.error;
      _errorMessage = line;
    } else if (lower.contains('connected') ||
        lower.contains('webrtc gateway agent')) {
      _status = AgentStatus.online;
    }
    notifyListeners();
  }

  void _handleProcessExit(int code) {
    addLog(
      'Agent 进程退出 (退出码: $code)',
      level: code == 0 ? LogLevel.info : LogLevel.warning,
      source: LogSource.system,
    );
    _metricsTimer?.cancel();
    _status = AgentStatus.stopped;
    _process = null;
    notifyListeners();
  }

  void _startMetricsPolling(String metricsAddr) {
    _metricsTimer?.cancel();
    String target = metricsAddr;
    if (target.startsWith(':')) {
      target = '127.0.0.1$target';
    }
    final url = Uri.parse('http://$target/metrics');

    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!isRunning) {
        timer.cancel();
        return;
      }
      try {
        final resp = await http
            .get(url)
            .timeout(const Duration(milliseconds: 800));
        if (resp.statusCode == 200) {
          _metrics = AgentMetrics.parsePrometheus(
            resp.body,
            previousMetrics: _metrics,
          );
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    if (!isRunning) return;

    _status = AgentStatus.stopping;
    notifyListeners();

    _metricsTimer?.cancel();
    addLog('正在停止 Agent 进程...', level: LogLevel.info, source: LogSource.system);

    if (_process != null) {
      await _process!.kill();
      _process = null;
    }

    _status = AgentStatus.stopped;
    _metrics = AgentMetrics.initial();
    addLog('Agent 已停止', level: LogLevel.info, source: LogSource.system);
    notifyListeners();
  }
}
