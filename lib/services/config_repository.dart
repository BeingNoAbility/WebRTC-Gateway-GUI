import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import '../models/agent_profile.dart';
import '../models/app_settings.dart';
import '../models/signal_profile.dart';

class ConfigRepository {
  List<AgentProfile> _profiles = [];
  SignalServerConfig _signalConfig = SignalServerConfig();
  AppSettings _settings = AppSettings();
  bool _isPortable = false;

  List<AgentProfile> get profiles => List.unmodifiable(_profiles);
  SignalServerConfig get signalConfig => _signalConfig;
  AppSettings get settings => _settings;
  bool get isPortable => _isPortable;

  /// Resolves portable data directory next to executable, or fallback
  static Future<Directory> resolveDataDir() async {
    try {
      final exe = Platform.resolvedExecutable;
      final exeDir = File(exe).parent;
      final portableData = Directory(p.join(exeDir.path, 'data'));

      // Check if writable
      if (!await portableData.exists()) {
        await portableData.create(recursive: true);
      }
      final testFile = File(p.join(portableData.path, '.test_perm'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return portableData;
    } catch (_) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        return supportDir;
      } catch (_) {
        return Directory.current;
      }
    }
  }

  Future<File> _getConfigFile() async {
    final dir = await resolveDataDir();
    _isPortable = !dir.path.contains('AppData') && !dir.path.contains('.config');
    return File(p.join(dir.path, 'webrtc_gateway_config.json'));
  }

  /// Initializes and loads saved full configurations, or seeds with defaults
  Future<void> init() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final dynamic decoded = jsonDecode(content);

        if (decoded is Map<String, dynamic>) {
          // Modern full configuration bundle
          if (decoded.containsKey('settings')) {
            _settings = AppSettings.fromJson(decoded['settings'] as Map<String, dynamic>);
          }
          if (decoded.containsKey('signal')) {
            _signalConfig = SignalServerConfig.fromJson(decoded['signal'] as Map<String, dynamic>);
          }
          if (decoded.containsKey('agents')) {
            final List<dynamic> list = decoded['agents'] as List<dynamic>;
            _profiles = list.map((e) => AgentProfile.fromJson(e as Map<String, dynamic>)).toList();
          }
        } else if (decoded is List<dynamic>) {
          // Legacy profiles array compatibility
          _profiles = decoded.map((e) => AgentProfile.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    if (_profiles.isEmpty) {
      _seedDefaultProfiles();
      await save();
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
        maxTrunks: 4,
      ),
    ];
  }

  /// Saves the complete bundle into portable config file
  Future<void> save() async {
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

      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(bundle));
    } catch (_) {}
  }

  void addProfile(AgentProfile profile) {
    _profiles.add(profile);
    save();
  }

  void updateProfile(AgentProfile profile) {
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx != -1) {
      _profiles[idx] = profile;
      save();
    }
  }

  void removeProfile(String id) {
    _profiles.removeWhere((p) => p.id == id);
    save();
  }

  AgentProfile? getById(String id) {
    try {
      return _profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void updateSignalConfig(SignalServerConfig config) {
    _signalConfig = config;
    save();
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
    save();
  }

  /// Exports all configuration (agents, signal, settings)
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

  /// Exports only agent profiles
  Future<void> exportAgentsToFile(String targetPath) async {
    final file = File(targetPath);
    final jsonList = _profiles.map((p) => p.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
  }

  /// Exports only signal server config
  Future<void> exportSignalToFile(String targetPath) async {
    final file = File(targetPath);
    final jsonMap = _signalConfig.toJson();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonMap));
  }

  /// Exports profile in standard upstream agent.yaml format
  Future<void> exportUpstreamAgentYaml(String profileId, String targetPath) async {
    final profile = getById(profileId);
    if (profile == null) return;
    final file = File(targetPath);
    await file.writeAsString(profile.toYamlString());
  }

  /// Exports signal config in standard upstream server.yaml format
  Future<void> exportUpstreamSignalYaml(String targetPath) async {
    final file = File(targetPath);
    await file.writeAsString(_signalConfig.toYamlString());
  }

  /// Imports from file and returns summary (supports upstream agent.yaml / server.yaml and JSON)
  Future<Map<String, dynamic>> importFromFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final dynamic decoded = loadYaml(content);

    int agentCount = 0;
    bool signalImported = false;
    bool settingsImported = false;
    String detectedType = 'unknown';

    if (decoded is Map) {
      // 1. Upstream Agent config (e.g. agent.example.yaml or agent.yaml)
      if (decoded.containsKey('signal') &&
          (decoded.containsKey('target') ||
              decoded.containsKey('dir') ||
              decoded.containsKey('file') ||
              decoded.containsKey('node_id'))) {
        final profile = AgentProfile.fromUpstreamMap(decoded);
        final idx = _profiles.indexWhere((p) => p.nodeId == profile.nodeId);
        if (idx != -1) {
          _profiles[idx] = profile;
        } else {
          _profiles.add(profile);
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
        if (decoded.containsKey('agents') && decoded['agents'] is List) {
          final List<dynamic> list = decoded['agents'] as List<dynamic>;
          for (final item in list) {
            if (item is Map) {
              final profile = AgentProfile.fromJson(Map<String, dynamic>.from(item));
              final idx = _profiles.indexWhere((p) => p.id == profile.id || p.nodeId == profile.nodeId);
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

        if (decoded.containsKey('signal') && decoded['signal'] is Map) {
          _signalConfig = SignalServerConfig.fromJson(Map<String, dynamic>.from(decoded['signal'] as Map));
          signalImported = true;
        }

        if (decoded.containsKey('settings') && decoded['settings'] is Map) {
          _settings = AppSettings.fromJson(Map<String, dynamic>.from(decoded['settings'] as Map));
          settingsImported = true;
        }
      }
    } else if (decoded is List) {
      // Agent profiles list
      for (final item in decoded) {
        if (item is Map) {
          final profile = AgentProfile.fromJson(Map<String, dynamic>.from(item));
          final idx = _profiles.indexWhere((p) => p.id == profile.id || p.nodeId == profile.nodeId);
          if (idx != -1) {
            _profiles[idx] = profile;
          } else {
            _profiles.add(profile);
          }
          agentCount++;
        }
      }
      detectedType = 'agent_list';
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
