import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/models/agent_config.dart';
import '../core/models/agent_instance.dart';
import '../core/models/signal_config.dart';
import '../core/models/remote_node.dart';

class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Multi-Agent Instances
  Future<void> saveAgentInstances(List<AgentInstance> instances) async {
    final list = instances.map((inst) => inst.toJson()).toList();
    await _prefs.setString('webrtc_agent_instances', jsonEncode(list));
  }

  List<AgentInstance> loadAgentInstances() {
    final jsonStr = _prefs.getString('webrtc_agent_instances');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list
            .map((item) => AgentInstance.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Fallback: Check if there is an existing legacy single agent config
    final legacyConfig = loadAgentConfig();
    return [
      AgentInstance(id: 'agent-primary', name: '默认主穿透节点', config: legacyConfig),
    ];
  }

  // Agent Config (Legacy single config compatibility)
  Future<void> saveAgentConfig(AgentConfig config) async {
    final jsonStr = jsonEncode(config.toJson());
    await _prefs.setString(AppConstants.keyAgentConfig, jsonStr);
  }

  AgentConfig loadAgentConfig() {
    final jsonStr = _prefs.getString(AppConstants.keyAgentConfig);
    if (jsonStr == null || jsonStr.isEmpty) {
      return AgentConfig();
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AgentConfig.fromJson(map);
    } catch (_) {
      return AgentConfig();
    }
  }

  // Signal Server Config
  Future<void> saveSignalConfig(SignalConfig config) async {
    final jsonStr = jsonEncode(config.toJson());
    await _prefs.setString(AppConstants.keySignalConfig, jsonStr);
  }

  SignalConfig loadSignalConfig() {
    final jsonStr = _prefs.getString(AppConstants.keySignalConfig);
    if (jsonStr == null || jsonStr.isEmpty) {
      return SignalConfig();
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SignalConfig.fromJson(map);
    } catch (_) {
      return SignalConfig();
    }
  }

  // Saved Remote Nodes
  Future<void> saveRemoteNodes(List<RemoteNode> nodes) async {
    final list = nodes.map((n) => n.toJson()).toList();
    await _prefs.setString(AppConstants.keySavedNodes, jsonEncode(list));
  }

  List<RemoteNode> loadRemoteNodes() {
    final jsonStr = _prefs.getString(AppConstants.keySavedNodes);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [
        RemoteNode(
          id: 'demo-1',
          title: '官方公共演示节点 (Official Demo)',
          nodeId: 'demo',
          portalUrl: 'http://127.0.0.1:8888',
          lastConnected: DateTime.now().subtract(const Duration(hours: 2)),
          tags: ['演示', 'Web'],
        ),
      ];
    }
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((item) => RemoteNode.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Theme Mode (dark, light, system)
  Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(AppConstants.keyThemeMode, mode);
  }

  String loadThemeMode() {
    return _prefs.getString(AppConstants.keyThemeMode) ?? 'dark';
  }

  // Custom Binary Paths
  Future<void> saveCustomAgentPath(String path) async {
    await _prefs.setString('custom_agent_path', path);
  }

  String? loadCustomAgentPath() {
    return _prefs.getString('custom_agent_path');
  }

  Future<void> saveCustomSignalPath(String path) async {
    await _prefs.setString('custom_signal_path', path);
  }

  String? loadCustomSignalPath() {
    return _prefs.getString('custom_signal_path');
  }

  // System Tray Close Behavior
  Future<void> saveCloseToTray(bool value) async {
    await _prefs.setBool('webrtc_close_to_tray', value);
  }

  bool loadCloseToTray() {
    return _prefs.getBool('webrtc_close_to_tray') ?? true;
  }
}
