import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/agent_profile.dart';
import '../models/runtime_state.dart';
import '../models/signal_profile.dart';
import 'binary_manager.dart';

class ProcessSupervisor {
  final BinaryManager _binaryManager;

  // Running processes map: profileId -> Process
  final Map<String, Process> _runningProcesses = {};
  
  // Runtime states: profileId -> AgentRuntimeState
  final Map<String, AgentRuntimeState> _runtimeStates = {};

  // Signal server process & state
  Process? _signalProcess;
  final AgentRuntimeState _signalState = AgentRuntimeState(profileId: '__signal__');

  // Broadcast stream controller for state changes
  final _stateChangeController = StreamController<String>.broadcast();
  Stream<String> get onStateChange => _stateChangeController.stream;

  // Broadcast stream controller for log lines: (profileId, logLine)
  final _logController = StreamController<MapEntry<String, String>>.broadcast();
  Stream<MapEntry<String, String>> get onLog => _logController.stream;

  ProcessSupervisor(this._binaryManager);

  AgentRuntimeState getOrCreateState(String profileId) {
    if (profileId == '__signal__') {
      return _signalState;
    }
    return _runtimeStates.putIfAbsent(
      profileId,
      () => AgentRuntimeState(profileId: profileId),
    );
  }

  AgentRuntimeState getSignalState() => _signalState;

  bool isRunning(String profileId) {
    if (profileId == '__signal__') {
      return isSignalRunning();
    }
    final state = _runtimeStates[profileId];
    return state != null && state.status == ProcessStatus.running;
  }

  bool isSignalRunning() {
    return _signalState.status == ProcessStatus.running && _signalProcess != null;
  }

  /// Clears logs for all nodes or a specific node
  void clearLogs([String? profileId]) {
    if (profileId == null) {
      _signalState.clearLogs();
      for (final state in _runtimeStates.values) {
        state.clearLogs();
      }
    } else if (profileId == '__signal__') {
      _signalState.clearLogs();
    } else {
      _runtimeStates[profileId]?.clearLogs();
    }
  }

  /// Finds an available TCP port for Prometheus metrics
  Future<int> _findAvailablePort([int startPort = 9091]) async {
    for (int port = startPort; port < startPort + 200; port++) {
      bool alreadyAllocated = _runtimeStates.values.any((s) => s.metricsPort == port);
      if (alreadyAllocated) continue;

      try {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
        await server.close();
        return port;
      } catch (_) {}
    }
    return startPort;
  }

  /// Starts a specific Agent profile as a managed background process
  Future<bool> startAgent(AgentProfile profile) async {
    final state = getOrCreateState(profile.id);
    if (state.status == ProcessStatus.running || state.status == ProcessStatus.starting) {
      return false;
    }

    state.status = ProcessStatus.starting;
    state.lastError = null;
    _stateChangeController.add(profile.id);

    try {
      final binPath = await _binaryManager.resolveAgentPath(profile.customBinaryPath);
      final binInfo = await _binaryManager.inspectBinary(binPath);
      if (!binInfo.exists) {
        state.status = ProcessStatus.error;
        state.lastError = '底层 Agent 核心未找到: $binPath';
        _stateChangeController.add(profile.id);
        return false;
      }

      // Allocate unique metrics port for this instance
      final metricsPort = await _findAvailablePort(9091);
      state.metricsPort = metricsPort;

      // Construct CLI arguments with exact official flag names
      final args = <String>[
        '-node-id', profile.nodeId,
        '-signal', profile.signalUrl,
        '-metrics-addr', ':$metricsPort',
        '-max-trunks', profile.maxTrunks.toString(),
        '-max-streams', profile.maxStreams.toString(),
      ];

      // Operating Mode
      switch (profile.mode) {
        case TunnelMode.target:
          args.addAll(['-target', profile.target]);
          break;
        case TunnelMode.dir:
          args.addAll(['-dir', profile.dirPath]);
          break;
        case TunnelMode.file:
          args.addAll(['-file', profile.filePath]);
          break;
      }

      if (profile.signalSecret.isNotEmpty) {
        args.addAll(['-signal-secret', profile.signalSecret]);
      }

      // In WebRTC Gateway Agent v3.1+, empty password strictly requires -allow-public flag!
      if (profile.accessSecret.isNotEmpty) {
        args.addAll(['-access-secret', profile.accessSecret]);
      } else {
        args.add('-allow-public');
      }

      if (profile.allowedProxyDomains.isNotEmpty) {
        args.addAll(['-allowed-proxy-domains', profile.allowedProxyDomains]);
      }
      if (profile.portalUrl.isNotEmpty) {
        args.addAll(['-portal-url', profile.portalUrl]);
      }
      if (profile.signLink.isNotEmpty) {
        args.addAll(['-sign-link', profile.signLink]);
      }
      if (profile.insecure) {
        args.add('-insecure');
      }
      if (profile.insecureTarget) {
        args.add('-insecure-target');
      }
      if (profile.proxy.isNotEmpty) {
        args.addAll(['-proxy', profile.proxy]);
      }
      if (profile.sni.isNotEmpty) {
        args.addAll(['-sni', profile.sni]);
      }
      if (profile.stunServers.isNotEmpty) {
        args.addAll(['-stun-servers', profile.stunServers.join(',')]);
      }
      if (profile.turnUrl.isNotEmpty) {
        args.addAll(['-turn-url', profile.turnUrl]);
        if (profile.turnUser.isNotEmpty) args.addAll(['-turn-user', profile.turnUser]);
        if (profile.turnPass.isNotEmpty) args.addAll(['-turn-pass', profile.turnPass]);
      }

      final process = await Process.start(
        binPath,
        args,
        runInShell: false,
      );

      _runningProcesses[profile.id] = process;
      state.pid = process.pid;
      state.startTime = DateTime.now();
      state.status = ProcessStatus.running;
      _stateChangeController.add(profile.id);

      // Listen to stdout and stderr
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        state.addLog(line);
        _logController.add(MapEntry(profile.id, line));
      });

      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        state.addLog(line);
        _logController.add(MapEntry(profile.id, line));
      });

      // Handle process exit
      process.exitCode.then((code) {
        _runningProcesses.remove(profile.id);
        if (state.status == ProcessStatus.running || state.status == ProcessStatus.stopping) {
          state.status = ProcessStatus.stopped;
        }
        if (code != 0 && state.status != ProcessStatus.stopped) {
          state.status = ProcessStatus.error;
          state.lastError = '进程退出，退出码: $code';
        }
        state.pid = null;
        _stateChangeController.add(profile.id);
      });

      return true;
    } catch (e) {
      state.status = ProcessStatus.error;
      state.lastError = '启动失败: $e';
      _stateChangeController.add(profile.id);
      return false;
    }
  }

  /// Stops a running Agent profile
  Future<bool> stopAgent(String profileId) async {
    final state = _runtimeStates[profileId];
    final process = _runningProcesses[profileId];

    if (state == null || process == null) {
      if (state != null) {
        state.status = ProcessStatus.stopped;
        state.pid = null;
        _stateChangeController.add(profileId);
      }
      return true;
    }

    state.status = ProcessStatus.stopping;
    _stateChangeController.add(profileId);

    bool killed = process.kill(ProcessSignal.sigint);
    if (!killed) {
      killed = process.kill();
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (_runningProcesses.containsKey(profileId)) {
        process.kill(ProcessSignal.sigkill);
      }
    });

    return true;
  }

  /// Starts the local Signal server
  Future<bool> startSignalServer(SignalServerConfig config) async {
    if (isSignalRunning()) return false;

    _signalState.status = ProcessStatus.starting;
    _signalState.lastError = null;
    _stateChangeController.add('__signal__');

    try {
      final binPath = await _binaryManager.resolveSignalPath();
      final binInfo = await _binaryManager.inspectBinary(binPath);
      if (!binInfo.exists) {
        _signalState.status = ProcessStatus.error;
        _signalState.lastError = '底层 Signal 核心未找到: $binPath';
        _stateChangeController.add('__signal__');
        return false;
      }

      final args = <String>[
        '-addr', config.addr,
      ];

      if (config.metricsAddr.isNotEmpty) {
        args.addAll(['-metrics-addr', config.metricsAddr]);
      }
      if (config.staticDir.isNotEmpty) {
        args.addAll(['-static', config.staticDir]);
      }
      if (config.tlsAuto) {
        args.add('-tls-auto');
      } else {
        if (config.tlsCert.isNotEmpty) args.addAll(['-tls-cert', config.tlsCert]);
        if (config.tlsKey.isNotEmpty) args.addAll(['-tls-key', config.tlsKey]);
      }
      if (config.allowedOrigins.isNotEmpty) {
        args.addAll(['-allowed-origins', config.allowedOrigins]);
      }
      if (config.portalDomain.isNotEmpty) {
        args.addAll(['-portal-domain', config.portalDomain]);
      }
      if (config.signalSecret.isNotEmpty) {
        args.addAll(['-signal-secret', config.signalSecret]);
      }
      if (config.trustedProxies.isNotEmpty) {
        args.addAll(['-trusted-proxies', config.trustedProxies]);
      }
      args.addAll(['-max-ip-conns', config.maxIpConns.toString()]);

      final process = await Process.start(
        binPath,
        args,
        runInShell: false,
      );

      _signalProcess = process;
      _signalState.pid = process.pid;
      _signalState.startTime = DateTime.now();
      _signalState.status = ProcessStatus.running;
      _stateChangeController.add('__signal__');

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        _signalState.addLog(line);
        _logController.add(MapEntry('__signal__', line));
      });

      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        _signalState.addLog(line);
        _logController.add(MapEntry('__signal__', line));
      });

      process.exitCode.then((code) {
        _signalProcess = null;
        _signalState.status = ProcessStatus.stopped;
        _signalState.pid = null;
        if (code != 0) {
          _signalState.status = ProcessStatus.error;
          _signalState.lastError = 'Signal 服务异常退出: $code';
        }
        _stateChangeController.add('__signal__');
      });

      return true;
    } catch (e) {
      _signalState.status = ProcessStatus.error;
      _signalState.lastError = 'Signal 启动失败: $e';
      _stateChangeController.add('__signal__');
      return false;
    }
  }

  /// Stops local Signal server
  Future<bool> stopSignalServer() async {
    if (_signalProcess != null) {
      _signalState.status = ProcessStatus.stopping;
      _stateChangeController.add('__signal__');

      _signalProcess?.kill(ProcessSignal.sigint);
      _signalProcess?.kill();
      _signalProcess = null;
    }
    _signalState.status = ProcessStatus.stopped;
    _signalState.pid = null;
    _stateChangeController.add('__signal__');
    return true;
  }

  /// Executes health check probe for Signal server
  Future<bool> probeSignalHealth([String? customUrl]) async {
    try {
      final binPath = await _binaryManager.resolveSignalPath();
      final args = ['-health'];
      if (customUrl != null && customUrl.isNotEmpty) {
        args.addAll(['-health-url', customUrl]);
      }
      final result = await Process.run(binPath, args);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Stops all running Agent processes and Signal server
  Future<void> stopAll() async {
    for (final id in List<String>.from(_runningProcesses.keys)) {
      await stopAgent(id);
    }
    await stopSignalServer();
  }

  void dispose() {
    stopAll();
    _stateChangeController.close();
    _logController.close();
  }
}
