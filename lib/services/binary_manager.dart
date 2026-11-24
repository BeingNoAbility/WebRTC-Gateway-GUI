import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class BinaryInfo {
  final String path;
  final bool exists;
  final String? version;
  final String? error;

  BinaryInfo({
    required this.path,
    required this.exists,
    this.version,
    this.error,
  });

  bool get isValid => exists && (version != null && version!.isNotEmpty);
}

class BinaryManager {
  static const _keyCustomAgent = 'custom_agent_binary_path';
  static const _keyCustomSignal = 'custom_signal_binary_path';

  final SharedPreferences _prefs;

  BinaryManager(this._prefs);

  static Future<BinaryManager> init() async {
    final prefs = await SharedPreferences.getInstance();
    return BinaryManager(prefs);
  }

  String? get customAgentPath => _prefs.getString(_keyCustomAgent);
  String? get customSignalPath => _prefs.getString(_keyCustomSignal);

  Future<void> setCustomAgentPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove(_keyCustomAgent);
    } else {
      await _prefs.setString(_keyCustomAgent, path);
    }
  }

  Future<void> setCustomSignalPath(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove(_keyCustomSignal);
    } else {
      await _prefs.setString(_keyCustomSignal, path);
    }
  }

  String _getExecutableExtension() => Platform.isWindows ? '.exe' : '';

  /// Resolves the actual Agent binary path to execute
  Future<String> resolveAgentPath([String? profileOverride]) async {
    // 1. Profile specific override
    if (profileOverride != null && profileOverride.isNotEmpty) {
      if (await File(profileOverride).exists()) return profileOverride;
    }

    // 2. Custom binary specified in settings
    final custom = customAgentPath;
    if (custom != null && custom.isNotEmpty) {
      if (await File(custom).exists()) return custom;
    }

    // 3. Bundled binary relative to executable or current dir
    final ext = _getExecutableExtension();
    final candidateDirs = [
      p.join(Directory.current.path, 'bin'),
      p.join(p.dirname(Platform.resolvedExecutable), 'bin'),
      p.dirname(Platform.resolvedExecutable),
      // Local dev workspace fallback
      p.join(p.dirname(Directory.current.path), 'WebRTC-Gateway', 'build_output'),
      p.join(p.dirname(Directory.current.path), 'WebRTC-Gateway'),
    ];

    for (final dir in candidateDirs) {
      final target = p.join(dir, 'agent$ext');
      if (await File(target).exists()) {
        return target;
      }
    }

    // Fallback: system PATH or default
    return 'agent$ext';
  }

  /// Resolves the actual Signal binary path to execute
  Future<String> resolveSignalPath() async {
    final custom = customSignalPath;
    if (custom != null && custom.isNotEmpty) {
      if (await File(custom).exists()) return custom;
    }

    final ext = _getExecutableExtension();
    final candidateDirs = [
      p.join(Directory.current.path, 'bin'),
      p.join(p.dirname(Platform.resolvedExecutable), 'bin'),
      p.dirname(Platform.resolvedExecutable),
      p.join(p.dirname(Directory.current.path), 'WebRTC-Gateway', 'build_output'),
      p.join(p.dirname(Directory.current.path), 'WebRTC-Gateway'),
    ];

    for (final dir in candidateDirs) {
      final target = p.join(dir, 'signal$ext');
      if (await File(target).exists()) {
        return target;
      }
    }

    return 'signal$ext';
  }

  /// Inspects a binary file, executes with `-help` or `--version`, and parses version string
  Future<BinaryInfo> inspectBinary(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return BinaryInfo(
        path: path,
        exists: false,
        error: '文件不存在: $path',
      );
    }

    try {
      final result = await Process.run(path, ['-help']);
      final output = '${result.stdout}\n${result.stderr}';
      
      // Match patterns like "WebRTC Gateway Agent (v3.1.11)" or "v3.X.X"
      final versionRegex = RegExp(r'v\d+\.\d+\.\d+(?:-[\w.]+)?');
      final match = versionRegex.firstMatch(output);

      if (match != null) {
        return BinaryInfo(
          path: path,
          exists: true,
          version: match.group(0),
        );
      }

      // Check if it's our binary by header text
      if (output.contains('WebRTC Gateway')) {
        return BinaryInfo(
          path: path,
          exists: true,
          version: 'WebRTC Gateway Core (Custom)',
        );
      }

      return BinaryInfo(
        path: path,
        exists: true,
        version: null,
        error: '未识别为有效的 WebRTC Gateway 二进制程序',
      );
    } catch (e) {
      return BinaryInfo(
        path: path,
        exists: true,
        error: '无法执行程序: $e',
      );
    }
  }
}
