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
  final Set<String> _stoppingAgents = {};
  final Map<String, Completer<void>> _agentExitCompleters = {};

  Process? _signalProcess;
  bool _stoppingSignal = false;
  Completer<void>? _signalExitCompleter;

  // Runtime states: profileId -> AgentRuntimeState
  final Map<String, AgentRuntimeState> _runtimeStates = {};
  final AgentRuntimeState _signalState =
      AgentRuntimeState(profileId: '__signal__');

  // Broadcast stream controller for state changes
  final _stateChangeController = StreamController<String>.broadcast();
  Stream<String> get onStateChange => _stateChangeController.stream;

  // Broadcast stream controller for log lines: (profileId, logLine)
  final _logController =
      StreamController<MapEntry<String, String>>.broadcast();
  Stream<MapEntry<String, String>> get onLog => _logController.stream;

  static final RegExp _signLinkRegex = RegExp(
    r'(?:Link:\s*|)(https?://\S+#[a-zA-Z0-9._-]+\?exp=\d+&sign=[0-9a-fA-F]+)',
  );

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
    return _signalState.status == ProcessStatus.running &&
        _signalProcess != null;
  }

  /// Clears logs for all nodes or a specific node.
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

  /// Builds exact official CLI flags for `agent[.exe]`.
  static List<String> buildAgentArgs(
    AgentProfile profile, {
    required int metricsPort,
  }) {
    final args = <String>[
      '-node-id',
      profile.nodeId,
      '-signal',
      profile.signalUrl,
      '-metrics-addr',
      ':$metricsPort',
      '-max-trunks',
      profile.maxTrunks.clamp(1, 8).toString(),
      '-max-streams',
      profile.maxStreams.clamp(1, 65535).toString(),
    ];

    switch (profile.mode) {
      case TunnelMode.target:
        args.addAll(['-target', profile.target]);
      case TunnelMode.dir:
        args.addAll(['-dir', profile.dirPath]);
      case TunnelMode.file:
        args.addAll(['-file', profile.filePath]);
    }

    if (profile.signalSecret.isNotEmpty) {
      args.addAll(['-signal-secret', profile.signalSecret]);
    }

    if (profile.accessSecret.isNotEmpty) {
      args.addAll(['-access-secret', profile.accessSecret]);
    } else if (profile.signLink.trim().isEmpty) {
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
      if (profile.turnUser.isNotEmpty) {
        args.addAll(['-turn-user', profile.turnUser]);
      }
      if (profile.turnPass.isNotEmpty) {
        args.addAll(['-turn-pass', profile.turnPass]);
      }
    }

    return args;
  }

  /// Builds exact official CLI flags for `signal[.exe]`.
  static List<String> buildSignalArgs(SignalServerConfig config) {
    final args = <String>[
      '-addr',
      config.addr,
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
      if (config.tlsCert.isNotEmpty) {
        args.addAll(['-tls-cert', config.tlsCert]);
      }
      if (config.tlsKey.isNotEmpty) {
        args.addAll(['-tls-key', config.tlsKey]);
      }
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
    args.addAll(['-max-ip-conns', config.maxIpConns.clamp(1, 65535).toString()]);
    return args;
  }

  /// Finds an available TCP port for Prometheus metrics.
  Future<int> _findAvailablePort([int startPort = 9091]) async {
    for (var port = startPort; port < startPort + 200; port++) {
      final alreadyAllocated =
          _runtimeStates.values.any((s) => s.metricsPort == port);
      if (alreadyAllocated) continue;

      try {
        final server =
            await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
        await server.close();
        return port;
      } catch (_) {}
    }
    return startPort;
  }

  String? _validateProfileBeforeStart(AgentProfile profile) {
    if (!RegExp(r'^[a-zA-Z0-9._-]{1,64}$').hasMatch(profile.nodeId)) {
      return 'Node ID 无效：仅支持 1~64 位字母、数字、点(.)、下划线(_)或短横线(-)';
    }
    if (profile.signalUrl.trim().isEmpty) {
      return '信令地址 (-signal) 不能为空';
    }
    switch (profile.mode) {
      case TunnelMode.target:
        if (profile.target.trim().isEmpty) {
          return '本地目标服务 URL (-target) 不能为空';
        }
      case TunnelMode.dir:
        if (profile.dirPath.trim().isEmpty ||
            !Directory(profile.dirPath).existsSync()) {
          return '静态目录不存在: ${profile.dirPath}';
        }
      case TunnelMode.file:
        if (profile.filePath.trim().isEmpty ||
            !File(profile.filePath).existsSync()) {
          return '目标文件不存在: ${profile.filePath}';
        }
    }
    if (!AgentProfile.isValidGoDuration(profile.signLink)) {
      return '临时签名时长格式无效 ("${profile.signLink}")，请使用如 1h、24h、168h（Go 不支持 d 单位）';
    }
    return null;
  }

  /// Starts a specific Agent profile as a managed background process.
  Future<bool> startAgent(AgentProfile profile) async {
    final state = getOrCreateState(profile.id);
    if (state.status == ProcessStatus.running ||
        state.status == ProcessStatus.starting) {
      return false;
    }

    // If a stop is still draining, wait briefly before starting replacement
    final pendingStop = _agentExitCompleters[profile.id];
    if (pendingStop != null && !pendingStop.isCompleted) {
      await pendingStop.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    }

    final validationError = _validateProfileBeforeStart(profile);
    if (validationError != null) {
      state.status = ProcessStatus.error;
      state.lastError = validationError;
      _stateChangeController.add(profile.id);
      return false;
    }

    final myGen = ++state.generation;
    state.status = ProcessStatus.starting;
    state.lastError = null;
    state.generatedShareLink = null;
    _stateChangeController.add(profile.id);

    try {
      final binPath =
          await _binaryManager.resolveAgentPath(profile.customBinaryPath);
      final binInfo = await _binaryManager.inspectBinary(binPath);
      if (!binInfo.exists) {
        if (state.generation != myGen) return false;
        state.status = ProcessStatus.error;
        state.lastError = binInfo.error ?? '底层 Agent 核心未找到: $binPath';
        _stateChangeController.add(profile.id);
        return false;
      }

      final metricsPort = await _findAvailablePort(9091);
      if (state.generation != myGen) return false;
      state.metricsPort = metricsPort;

      final args = buildAgentArgs(profile, metricsPort: metricsPort);
      final process = await Process.start(
        binPath,
        args,
        runInShell: false,
      );

      final exitCompleter = Completer<void>();
      _agentExitCompleters[profile.id] = exitCompleter;
      _runningProcesses[profile.id] = process;
      state.pid = process.pid;
      state.startTime = DateTime.now();
      state.status = ProcessStatus.running;
      _stateChangeController.add(profile.id);

      void handleLine(String line) {
        if (state.generation != myGen) return;
        state.addLog(line);
        _logController.add(MapEntry(profile.id, line));

        final linkMatch = _signLinkRegex.firstMatch(line);
        if (linkMatch != null) {
          final captured = linkMatch.group(1);
          if (captured != null && captured != state.generatedShareLink) {
            state.generatedShareLink = captured;
            _stateChangeController.add(profile.id);
          }
        }
      }

      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(handleLine);

      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(handleLine);

      unawaited(
        process.exitCode.then((code) {
          if (!exitCompleter.isCompleted) {
            exitCompleter.complete();
          }
          if (state.generation != myGen) return;

          final wasStopping = _stoppingAgents.remove(profile.id) ||
              state.status == ProcessStatus.stopping;
          _runningProcesses.remove(profile.id);
          state.status = ProcessStatus.stopped;
          state.pid = null;
          if (!wasStopping && code != 0) {
            state.status = ProcessStatus.error;
            state.lastError = '进程异常退出，退出码: $code';
          }
          _stateChangeController.add(profile.id);
        }),
      );

      return true;
    } catch (e) {
      if (state.generation != myGen) return false;
      state.status = ProcessStatus.error;
      state.lastError = '启动失败: $e';
      _stateChangeController.add(profile.id);
      return false;
    }
  }

  /// Stops a running Agent profile gracefully, escalating only if needed.
  Future<bool> stopAgent(String profileId) async {
    final state = _runtimeStates[profileId];
    final process = _runningProcesses[profileId];
    final completer = _agentExitCompleters[profileId];

    if (state == null || process == null) {
      if (state != null) {
        state.status = ProcessStatus.stopped;
        state.pid = null;
        _stateChangeController.add(profileId);
      }
      return true;
    }

    _stoppingAgents.add(profileId);
    state.status = ProcessStatus.stopping;
    _stateChangeController.add(profileId);

    final pid = process.pid;
    if (!Platform.isWindows) {
      process.kill(ProcessSignal.sigint);
    } else {
      process.kill();
    }

    if (completer != null) {
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () async {
          if (_runningProcesses[profileId] == process) {
            if (Platform.isWindows) {
              try {
                await Process.run('taskkill', ['/F', '/T', '/PID', '$pid']);
              } catch (_) {}
            } else {
              process.kill(ProcessSignal.sigkill);
            }
            await completer.future.timeout(
              const Duration(seconds: 2),
              onTimeout: () {},
            );
          }
        },
      );
    }

    return true;
  }

  /// Starts the local Signal server.
  Future<bool> startSignalServer(SignalServerConfig config) async {
    if (isSignalRunning() || _signalState.status == ProcessStatus.starting) {
      return false;
    }

    if (_signalExitCompleter != null && !_signalExitCompleter!.isCompleted) {
      await _signalExitCompleter!.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    }

    if (config.addr.trim().isEmpty) {
      _signalState.status = ProcessStatus.error;
      _signalState.lastError = '监听地址 (-addr) 不能为空';
      _stateChangeController.add('__signal__');
      return false;
    }

    if (!config.tlsAuto &&
        ((config.tlsCert.isNotEmpty && config.tlsKey.isEmpty) ||
            (config.tlsCert.isEmpty && config.tlsKey.isNotEmpty))) {
      _signalState.status = ProcessStatus.error;
      _signalState.lastError = '自定义 TLS 必须同时提供证书和私钥文件';
      _stateChangeController.add('__signal__');
      return false;
    }

    final myGen = ++_signalState.generation;
    _signalState.status = ProcessStatus.starting;
    _signalState.lastError = null;
    _stateChangeController.add('__signal__');

    try {
      final binPath = await _binaryManager.resolveSignalPath();
      final binInfo = await _binaryManager.inspectBinary(binPath);
      if (!binInfo.exists) {
        if (_signalState.generation != myGen) return false;
        _signalState.status = ProcessStatus.error;
        _signalState.lastError = binInfo.error ?? '底层 Signal 核心未找到: $binPath';
        _stateChangeController.add('__signal__');
        return false;
      }

      final args = buildSignalArgs(config);
      final process = await Process.start(
        binPath,
        args,
        runInShell: false,
      );

      final exitCompleter = Completer<void>();
      _signalExitCompleter = exitCompleter;
      _signalProcess = process;
      _signalState.pid = process.pid;
      _signalState.startTime = DateTime.now();
      _signalState.status = ProcessStatus.running;
      _stateChangeController.add('__signal__');

      void handleLine(String line) {
        if (_signalState.generation != myGen) return;
        _signalState.addLog(line);
        _logController.add(MapEntry('__signal__', line));
      }

      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(handleLine);

      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(handleLine);

      unawaited(
        process.exitCode.then((code) {
          if (!exitCompleter.isCompleted) {
            exitCompleter.complete();
          }
          if (_signalState.generation != myGen) return;

          _signalProcess = null;
          final wasStopping =
              _stoppingSignal || _signalState.status == ProcessStatus.stopping;
          _stoppingSignal = false;
          _signalState.status = ProcessStatus.stopped;
          _signalState.pid = null;
          if (!wasStopping && code != 0) {
            _signalState.status = ProcessStatus.error;
            _signalState.lastError = 'Signal 服务异常退出 (退出码: $code)';
          }
          _stateChangeController.add('__signal__');
        }),
      );

      return true;
    } catch (e) {
      if (_signalState.generation != myGen) return false;
      _signalState.status = ProcessStatus.error;
      _signalState.lastError = 'Signal 启动失败: $e';
      _stateChangeController.add('__signal__');
      return false;
    }
  }

  /// Stops local Signal server cleanly.
  Future<bool> stopSignalServer() async {
    final process = _signalProcess;
    final completer = _signalExitCompleter;
    if (process != null) {
      _stoppingSignal = true;
      final pid = process.pid;
      _signalState.status = ProcessStatus.stopping;
      _stateChangeController.add('__signal__');

      if (!Platform.isWindows) {
        process.kill(ProcessSignal.sigint);
      } else {
        process.kill();
      }

      if (completer != null) {
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () async {
            if (_signalProcess == process) {
              if (Platform.isWindows) {
                try {
                  await Process.run('taskkill', ['/F', '/T', '/PID', '$pid']);
                } catch (_) {}
              } else {
                process.kill(ProcessSignal.sigkill);
              }
              await completer.future.timeout(
                const Duration(seconds: 2),
                onTimeout: () {},
              );
            }
          },
        );
      }
    } else {
      _signalState.status = ProcessStatus.stopped;
      _signalState.pid = null;
      _stateChangeController.add('__signal__');
    }
    return true;
  }

  /// Executes health check probe for Signal server using configured host/TLS.
  Future<bool> probeSignalHealth(
    SignalServerConfig config, [
    String? customUrl,
  ]) async {
    try {
      final binPath = await _binaryManager.resolveSignalPath();
      final healthUrl = (customUrl != null && customUrl.isNotEmpty)
          ? customUrl
          : '${config.portalWebUrl}/healthz';
      final args = ['-health', '-health-url', healthUrl];
      final result = await Process.run(binPath, args)
          .timeout(const Duration(seconds: 5));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Stops all running Agent processes and Signal server concurrently.
  Future<void> stopAll() async {
    final futures = <Future<bool>>[
      for (final id in List<String>.from(_runningProcesses.keys)) stopAgent(id),
      stopSignalServer(),
    ];
    await Future.wait(futures);
  }

  Future<void> dispose() async {
    await stopAll();
    await _stateChangeController.close();
    await _logController.close();
  }
}
