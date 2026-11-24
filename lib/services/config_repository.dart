import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import '../models/agent_profile.dart';
import '../models/app_settings.dart';
import '../models/signal_profile.dart';

class ResolvedDataDir {
  final Directory directory;
  final bool isPortable;

  const ResolvedDataDir(this.directory, this.isPortable);
}

class ConfigRepository {
  final Directory? baseDirOverride;
  final bool inMemory;

  List<AgentProfile> _profiles = [];
  SignalServerConfig _signalConfig = SignalServerConfig();
  AppSettings _settings = AppSettings();
  bool _isPortable = false;
  String? _lastSaveError;
  Future<void>? _activeSave;
  bool _savePending = false;
  Completer<void>? _flushCompleter;

  ConfigRepository({this.baseDirOverride, this.inMemory = false});

  List<AgentProfile> get profiles => List<AgentProfile>.unmodifiable(_profiles);
  SignalServerConfig get signalConfig => _signalConfig;
  AppSettings get settings => _settings;
  bool get isPortable => _isPortable;
  String? get lastSaveError => _lastSaveError;

  /// Resolves portable data directory next to executable, or falls back to app support dir.
  static Future<ResolvedDataDir> resolveDataDir() async {
    try {
      final exe = Platform.resolvedExecutable;
      final exeDir = File(exe).parent;
      final portableData = Directory(p.join(exeDir.path, 'data'));

      if (!await portableData.exists()) {
        await portableData.create(recursive: true);
      }
      final testFile = File(p.join(portableData.path, '.test_perm'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return ResolvedDataDir(portableData, true);
    } catch (_) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        if (!await supportDir.exists()) {
          await supportDir.create(recursive: true);
        }
        return ResolvedDataDir(supportDir, false);
      } catch (_) {
        return ResolvedDataDir(Directory.current, false);
      }
    }
  }

  Future<File> _getConfigFile() async {
    if (baseDirOverride != null) {
      _isPortable = true;
      return File(p.join(baseDirOverride!.path, 'webrtc_gateway_config.json'));
    }
    final resolved = await resolveDataDir();
    _isPortable = resolved.isPortable;
    return File(p.join(resolved.directory.path, 'webrtc_gateway_config.json'));
  }

  /// Initializes and loads saved full configurations, or seeds with defaults.
  Future<void> init() async {
    if (!inMemory) {
      try {
        final file = await _getConfigFile();
        if (await file.exists()) {
          final content = await file.readAsString();
          final dynamic decoded = jsonDecode(content);

          if (decoded is Map<String, dynamic>) {
            if (decoded['settings'] is Map<String, dynamic>) {
              _settings = AppSettings.fromJson(
                decoded['settings'] as Map<String, dynamic>,
              );
            }
            if (decoded['signal'] is Map<String, dynamic>) {
              _signalConfig = SignalServerConfig.fromJson(
                decoded['signal'] as Map<String, dynamic>,
              );
            }
            if (decoded['agents'] is List<dynamic>) {
              final list = decoded['agents'] as List<dynamic>;
              _profiles = list
                  .whereType<Map<String, dynamic>>()
                  .map(AgentProfile.fromJson)
                  .toList();
            }
          } else if (decoded is List<dynamic>) {
            _profiles = decoded
                .whereType<Map<String, dynamic>>()
                .map(AgentProfile.fromJson)
                .toList();
          }
        }
      } catch (_) {
        // Keep defaults if config is corrupted or unreadable
      }
    }

    if (_profiles.isEmpty) {
      _seedDefaultProfiles();
      if (!inMemory) {
        await save();
      }
    }
  }

  void _seedDefaultProfiles() {
    _profiles = [
      AgentProfile(
        id: 'default_home',
        name: '本地应用反代 (Home NAS / Web)',
        nodeId: 'homeserver',
        mode: TunnelMode.target,
        target: 'http://127.0.0.1:8080',
        signalUrl: 'ws://127.0.0.1:8888/ws',
        allowPublic: false,
        maxTrunks: 4,
      ),
    ];
  }

  /// Coalesces concurrent save requests and writes atomically in sequence.
  Future<void> save() {
    if (inMemory) return Future<void>.value();
    if (_activeSave != null) {
      _savePending = true;
      return _activeSave!;
    }
    final completer = _flushCompleter ??= Completer<void>();
    _activeSave = _drainSaveQueue().whenComplete(() {
      _activeSave = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (_flushCompleter == completer) {
        _flushCompleter = null;
      }
    });
    return _activeSave!;
  }

  Future<void> _drainSaveQueue() async {
    do {
      _savePending = false;
      await _performAtomicSave();
    } while (_savePending);
  }

  /// Waits for all queued writes to finish.
  Future<void> flush() async {
    while (_activeSave != null) {
      await _activeSave;
    }
  }

  Future<void> _performAtomicSave() async {
    try {
      final file = await _getConfigFile();
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      final bundle = {
        'version': 1,
        'portable': _isPortable,
        'settings': _settings.toJson(),
        'signal': _signalConfig.toJson(),
        'agents': _profiles.map((p) => p.toJson()).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle);
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonStr, flush: true);
      if (await file.exists()) {
        try {
          await tempFile.rename(file.path);
        } catch (_) {
          // Some filesystems do not overwrite on rename; fallback to write directly
          await file.writeAsString(jsonStr, flush: true);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      } else {
        await tempFile.rename(file.path);
      }
      _lastSaveError = null;
    } catch (e) {
      _lastSaveError = e.toString();
    }
  }

  void addProfile(AgentProfile profile) {
    _profiles.add(profile);
    unawaited(save());
  }

  void updateProfile(AgentProfile profile) {
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx != -1) {
      _profiles[idx] = profile;
      unawaited(save());
    }
  }

  void removeProfile(String id) {
    _profiles.removeWhere((p) => p.id == id);
    unawaited(save());
  }

  AgentProfile? getById(String id) {
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  void updateSignalConfig(SignalServerConfig config) {
    _signalConfig = config;
    unawaited(save());
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
    unawaited(save());
  }

  /// Exports all configuration (agents, signal, settings).
  Future<void> exportAllToFile(String targetPath) async {
    final file = File(targetPath);
    final bundle = {
      'version': 1,
      'settings': _settings.toJson(),
      'signal': _signalConfig.toJson(),
      'agents': _profiles.map((p) => p.toJson()).toList(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(bundle));
  }

  /// Exports only agent profiles.
  Future<void> exportAgentsToFile(String targetPath) async {
    final file = File(targetPath);
    final jsonList = _profiles.map((p) => p.toJson()).toList();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
  }

  /// Exports only signal server config.
  Future<void> exportSignalToFile(String targetPath) async {
    final file = File(targetPath);
    final jsonMap = _signalConfig.toJson();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonMap),
    );
  }

  /// Exports profile in standard upstream agent.yaml format.
  Future<void> exportUpstreamAgentYaml(
    String profileId,
    String targetPath,
  ) async {
    final profile = getById(profileId);
    if (profile == null) return;
    final file = File(targetPath);
    await file.writeAsString(profile.toYamlString());
  }

  /// Exports signal config in standard upstream server.yaml format.
  Future<void> exportUpstreamSignalYaml(String targetPath) async {
    final file = File(targetPath);
    await file.writeAsString(_signalConfig.toYamlString());
  }

  dynamic _toPlainDart(dynamic value) {
    if (value is YamlMap || value is Map) {
      final result = <String, dynamic>{};
      final map = value as Map<dynamic, dynamic>;
      map.forEach((k, v) {
        result[k.toString()] = _toPlainDart(v);
      });
      return result;
    }
    if (value is YamlList || value is List) {
      return (value as List<dynamic>).map(_toPlainDart).toList();
    }
    return value;
  }

  /// Imports from file and returns summary (supports upstream agent.yaml / server.yaml and JSON).
  ///
  /// Throws [FormatException] if the file is empty or cannot be parsed.
  Future<Map<String, dynamic>> importFromFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      throw const FormatException('配置文件内容为空');
    }

    final dynamic rawDecoded = loadYaml(content);
    final dynamic decoded = _toPlainDart(rawDecoded);

    var agentCount = 0;
    var signalImported = false;
    var settingsImported = false;
    var detectedType = 'unknown';

    if (decoded is Map<String, dynamic>) {
      // 1. Upstream Agent config (e.g. agent.example.yaml or agent.yaml)
      if (decoded.containsKey('signal') &&
          decoded['signal'] is! Map &&
          (decoded.containsKey('target') ||
              decoded.containsKey('dir') ||
              decoded.containsKey('file') ||
              decoded.containsKey('node_id'))) {
        final imported = AgentProfile.fromUpstreamMap(decoded);
        final idx = _profiles.indexWhere((p) => p.nodeId == imported.nodeId);
        if (idx != -1) {
          final existing = _profiles[idx];
          _profiles[idx] = imported.copyWith(
            id: existing.id,
            name: existing.name,
            autoStart: existing.autoStart,
            customBinaryPath: existing.customBinaryPath,
          );
        } else {
          _profiles.add(imported);
        }
        agentCount++;
        detectedType = 'upstream_agent';
      }
      // 2. Upstream Signal Server config (e.g. server.example.yaml or server.yaml)
      else if (decoded.containsKey('addr') &&
          (decoded.containsKey('static') ||
              decoded.containsKey('portal_domain') ||
              decoded.containsKey('signal_secret') ||
              decoded.containsKey('tls_auto') ||
              decoded.containsKey('max_ip_conns'))) {
        _signalConfig = SignalServerConfig.fromUpstreamMap(decoded);
        signalImported = true;
        detectedType = 'upstream_signal';
      }
      // 3. Modern GUI configuration bundle
      else {
        if (decoded['agents'] is List) {
          final list = decoded['agents'] as List<dynamic>;
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              final profile = AgentProfile.fromJson(item);
              final idx = _profiles.indexWhere(
                (p) => p.id == profile.id || p.nodeId == profile.nodeId,
              );
              if (idx != -1) {
                _profiles[idx] = profile;
              } else {
                _profiles.add(profile);
              }
              agentCount++;
            }
          }
          detectedType = 'bundle';
        }

        if (decoded['signal'] is Map<String, dynamic>) {
          _signalConfig = SignalServerConfig.fromJson(
            decoded['signal'] as Map<String, dynamic>,
          );
          signalImported = true;
        }

        if (decoded['settings'] is Map<String, dynamic>) {
          _settings = AppSettings.fromJson(
            decoded['settings'] as Map<String, dynamic>,
          );
          settingsImported = true;
        }
      }
    } else if (decoded is List<dynamic>) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final profile = AgentProfile.fromJson(item);
          final idx = _profiles.indexWhere(
            (p) => p.id == profile.id || p.nodeId == profile.nodeId,
          );
          if (idx != -1) {
            _profiles[idx] = profile;
          } else {
            _profiles.add(profile);
          }
          agentCount++;
        }
      }
      detectedType = 'agent_list';
    } else {
      throw const FormatException('无法识别的配置文件结构，仅支持 YAML/JSON 格式');
    }

    await save();
    return {
      'agents': agentCount,
      'signal': signalImported,
      'settings': settingsImported,
      'type': detectedType,
    };
  }
}
