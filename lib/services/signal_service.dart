import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/models/signal_config.dart';
import '../core/models/log_entry.dart';
import '../core/utils/process_runner.dart';

enum SignalStatus {
  stopped,
  starting,
  running,
  stopping,
  error;

  String get label {
    switch (this) {
      case SignalStatus.stopped:
        return '信令服务已停止';
      case SignalStatus.starting:
        return '正在启动信令服务...';
      case SignalStatus.running:
        return '信令服务运行中';
      case SignalStatus.stopping:
        return '正在停止...';
      case SignalStatus.error:
        return '运行异常';
    }
  }
}

class SignalService extends ChangeNotifier {
  SignalStatus _status = SignalStatus.stopped;
  String? _errorMessage;
  ManagedProcess? _process;
  Timer? _metricsTimer;
  int _registeredNodes = 0;
  final List<LogEntry> _logs = [];
  String? _customBinaryPath;

  SignalStatus get status => _status;
  bool get isRunning => _status == SignalStatus.running || _status == SignalStatus.starting;
  String? get errorMessage => _errorMessage;
  int get registeredNodes => _registeredNodes;
  List<LogEntry> get logs => List.unmodifiable(_logs);
  String? get customBinaryPath => _customBinaryPath;

  void setCustomBinaryPath(String? path) {
    _customBinaryPath = path;
    notifyListeners();
  }

  void addLog(String message, {LogLevel level = LogLevel.info, LogSource source = LogSource.signal}) {
    _logs.add(LogEntry(
      level: level,
      source: source,
      message: message,
    ));
    if (_logs.length > 1000) {
      _logs.removeRange(0, 100);
    }
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<bool> start(SignalConfig config) async {
    if (isRunning) return false;

    _status = SignalStatus.starting;
    _errorMessage = null;
    notifyListeners();

    addLog('准备启动 WebRTC Gateway 信令服务端 (${config.addr})...', level: LogLevel.info, source: LogSource.system);

    if (Platform.isWindows) {
      final binary = ProcessRunner.findBinary('signal', customPath: _customBinaryPath);
      if (binary == null) {
        _status = SignalStatus.error;
        _errorMessage = '未找到 signal.exe 二进制文件，请确认放置于 assets/bin 或设置自定义路径';
        addLog('错误: $_errorMessage', level: LogLevel.error, source: LogSource.system);
        notifyListeners();
        return false;
      }

      final args = config.toCliArgs();
      addLog('执行命令: $binary ${args.join(" ")}', level: LogLevel.debug, source: LogSource.system);

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
        if (_status == SignalStatus.starting) {
          _status = SignalStatus.running;
          addLog('Signal 服务已成功创建 (PID: ${_process!.pid})', level: LogLevel.success, source: LogSource.system);
          notifyListeners();
        }

        _startMetricsPolling(config.addr, config.metricsAddr);
        return true;
      } catch (e) {
        _status = SignalStatus.error;
        _errorMessage = '启动信令服务失败: $e';
        addLog(_errorMessage!, level: LogLevel.error, source: LogSource.system);
        notifyListeners();
        return false;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      _status = SignalStatus.running;
      addLog('Android 环境：信令服务端控制已启动', level: LogLevel.success, source: LogSource.system);
      notifyListeners();
      return true;
    }
  }

  void _handleOutputLine(String line) {
    final entry = LogEntry.fromRawLine(line, LogSource.signal);
    _logs.add(entry);
    if (_logs.length > 1000) {
      _logs.removeRange(0, 100);
    }

    final lower = line.toLowerCase();
    if (lower.contains('fatal') || lower.contains('address already in use')) {
      _status = SignalStatus.error;
      _errorMessage = line;
    } else if (lower.contains('webrtc gateway signaling server') || lower.contains('listening on')) {
      _status = SignalStatus.running;
    }
    notifyListeners();
  }

  void _handleProcessExit(int code) {
    addLog('Signal 进程退出 (退出码: $code)', level: code == 0 ? LogLevel.info : LogLevel.warning, source: LogSource.system);
    _metricsTimer?.cancel();
    _status = SignalStatus.stopped;
    _process = null;
    _registeredNodes = 0;
    notifyListeners();
  }

  void _startMetricsPolling(String addr, String metricsAddr) {
    _metricsTimer?.cancel();
    String target = metricsAddr.isNotEmpty ? metricsAddr : addr;
    if (target.startsWith(':')) {
      target = '127.0.0.1$target';
    }
    final url = Uri.parse('http://$target/metrics');

    _metricsTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!isRunning) {
        timer.cancel();
        return;
      }
      try {
        final resp = await http.get(url).timeout(const Duration(milliseconds: 800));
        if (resp.statusCode == 200) {
          final lines = resp.body.split('\n');
          for (final raw in lines) {
            final line = raw.trim();
            if (line.startsWith('webrtc_gateway_registered_nodes')) {
              final parts = line.split(RegExp(r'\s+'));
              if (parts.length >= 2) {
                _registeredNodes = int.tryParse(parts.last) ?? 0;
                notifyListeners();
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    if (!isRunning) return;

    _status = SignalStatus.stopping;
    notifyListeners();

    _metricsTimer?.cancel();
    addLog('正在停止信令服务...', level: LogLevel.info, source: LogSource.system);

    if (_process != null) {
      await _process!.kill();
      _process = null;
    }

    _status = SignalStatus.stopped;
    _registeredNodes = 0;
    addLog('信令服务已停止', level: LogLevel.info, source: LogSource.system);
    notifyListeners();
  }
}
