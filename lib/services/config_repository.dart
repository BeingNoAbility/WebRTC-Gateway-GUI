import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/agent_profile.dart';

class ConfigRepository {
  List<AgentProfile> _profiles = [];

  List<AgentProfile> get profiles => List.unmodifiable(_profiles);

  Future<File> _getConfigFile() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      return File(p.join(appDir.path, 'webrtc_gateway_profiles.json'));
    } catch (_) {
      // Fallback to current working directory
      return File(p.join(Directory.current.path, 'webrtc_gateway_profiles.json'));
    }
  }

  /// Initializes and loads saved profiles, or seeds with defaults if empty
  Future<void> init() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
        _profiles = jsonList
            .map((e) => AgentProfile.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Log and fallback
    }

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

  Future<void> save() async {
    try {
      final file = await _getConfigFile();
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final jsonList = _profiles.map((p) => p.toJson()).toList();
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
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

  /// Exports all profiles to a target JSON file
  Future<void> exportToFile(String targetPath) async {
    final file = File(targetPath);
    final jsonList = _profiles.map((p) => p.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
  }

  /// Imports profiles from a JSON file (merges or replaces)
  Future<int> importFromFile(String sourcePath, {bool replaceAll = false}) async {
    final file = File(sourcePath);
    if (!await file.exists()) return 0;

    final content = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
    final imported = jsonList
        .map((e) => AgentProfile.fromJson(e as Map<String, dynamic>))
        .toList();

    if (replaceAll) {
      _profiles = imported;
    } else {
      for (final p in imported) {
        final existingIdx = _profiles.indexWhere((x) => x.id == p.id);
        if (existingIdx != -1) {
          _profiles[existingIdx] = p;
        } else {
          _profiles.add(p);
        }
      }
    }

    await save();
    return imported.length;
  }
}
