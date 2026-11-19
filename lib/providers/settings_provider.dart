import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

import '../core/models/agent_config.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  ThemeMode _themeMode = ThemeMode.dark;
  String? _customAgentPath;
  String? _customSignalPath;
  bool _closeToTray = true;

  SettingsProvider(this._storageService) {
    final modeStr = _storageService.loadThemeMode();
    if (modeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (modeStr == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark;
    }
    _customAgentPath = _storageService.loadCustomAgentPath();
    _customSignalPath = _storageService.loadCustomSignalPath();
    _closeToTray = _storageService.loadCloseToTray();
  }

  ThemeMode get themeMode => _themeMode;
  String? get customAgentPath => _customAgentPath;
  String? get customSignalPath => _customSignalPath;
  bool get closeToTray => _closeToTray;

  void setCloseToTray(bool value) {
    _closeToTray = value;
    _storageService.saveCloseToTray(value);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    String modeStr = 'dark';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.system) modeStr = 'system';
    _storageService.saveThemeMode(modeStr);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  void setCustomAgentPath(String path) {
    _customAgentPath = path.trim().isEmpty ? null : path.trim();
    _storageService.saveCustomAgentPath(_customAgentPath ?? '');
    notifyListeners();
  }

  void setCustomSignalPath(String path) {
    _customSignalPath = path.trim().isEmpty ? null : path.trim();
    _storageService.saveCustomSignalPath(_customSignalPath ?? '');
    notifyListeners();
  }

  /// Parses YAML text into an AgentConfig.
  AgentConfig? importAgentYaml(String yamlContent) {
    try {
      final doc = loadYaml(yamlContent);
      if (doc is! Map) return null;

      final Map<String, dynamic> jsonMap = {};
      doc.forEach((key, value) {
        if (value is YamlList) {
          jsonMap[key.toString()] = value.map((e) => e.toString()).toList();
        } else {
          jsonMap[key.toString()] = value;
        }
      });

      return AgentConfig.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }
}
