import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class BinaryInfo {
  final String path;
  final bool exists;
  final String? version;
  final String? error;

  const BinaryInfo({
    required this.path,
    required this.exists,
    this.version,
    this.error,
  });

  bool get isValid => exists && (version != null && version!.isNotEmpty);
}

class _CachedBinaryEntry {
  final DateTime modified;
  final int size;
  final BinaryInfo info;

  const _CachedBinaryEntry(this.modified, this.size, this.info);
}

class BinaryManager {
  static const _keyCustomAgent = 'custom_agent_binary_path';
  static const _keyCustomSignal = 'custom_signal_binary_path';

  final SharedPreferences _prefs;
  final bool disableProcessProbe;
  final Map<String, _CachedBinaryEntry> _inspectCache = {};

  BinaryManager(this._prefs, {this.disableProcessProbe = false});

  static Future<BinaryManager> init() async {
    final prefs = await SharedPreferences.getInstance();
    return BinaryManager(prefs);
  }

  String? get customAgentPath => _prefs.getString(_keyCustomAgent);
  String? get customSignalPath => _prefs.getString(_keyCustomSignal);

  Future<void> setCustomAgentPath(String? path) async {
    _inspectCache.clear();
    if (path == null || path.isEmpty) {
      await _prefs.remove(_keyCustomAgent);
    } else {
      await _prefs.setString(_keyCustomAgent, path);
    }
  }

  Future<void> setCustomSignalPath(String? path) async {
    _inspectCache.clear();
    if (path == null || path.isEmpty) {
      await _prefs.remove(_keyCustomSignal);
    } else {
      await _prefs.setString(_keyCustomSignal, path);
    }
  }

  void clearInspectCache() {
    _inspectCache.clear();
  }

  String _getExecutableExtension() => Platform.isWindows ? '.exe' : '';

  List<String> _candidateBinaryDirs() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return [
      // Prefer binaries bundled alongside the executable first to prevent CWD hijacking
      p.join(exeDir, 'bin'),
      exeDir,
      if (Platform.isMacOS) p.join(p.dirname(exeDir), 'Resources', 'bin'),
      // Development workspace fallbacks
      p.join(Directory.current.path, 'bin'),
      p.join(p.dirname(Directory.current.path), 'WebRTC-Gateway', 'build_output'),
      p.join(p.dirname(Directory.current.path), 'WebRTC-Gateway'),
    ];
  }

  Future<String?> _findInSystemPath(String exeName) async {
    try {
      final locator = Platform.isWindows ? 'where' : 'which';
      final res = await Process.run(locator, [exeName])
          .timeout(const Duration(seconds: 2));
      if (res.exitCode == 0) {
        final lines = (res.stdout as String)
            .split(RegExp(r'\r?\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        for (final candidate in lines) {
          if (await File(candidate).exists()) {
            return candidate;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolves the actual Agent binary path to execute.
  Future<String> resolveAgentPath([String? profileOverride]) async {
    if (profileOverride != null && profileOverride.isNotEmpty) {
      if (await File(profileOverride).exists()) return profileOverride;
    }

    final custom = customAgentPath;
    if (custom != null && custom.isNotEmpty) {
      if (await File(custom).exists()) return custom;
    }

    final ext = _getExecutableExtension();
    final exeName = 'agent$ext';
    for (final dir in _candidateBinaryDirs()) {
      final target = p.join(dir, exeName);
      if (await File(target).exists()) {
        return target;
      }
    }

    final pathResolved = await _findInSystemPath(exeName);
    if (pathResolved != null) {
      return pathResolved;
    }

    return p.join(p.dirname(Platform.resolvedExecutable), 'bin', exeName);
  }

  /// Resolves the actual Signal binary path to execute.
  Future<String> resolveSignalPath() async {
    final custom = customSignalPath;
    if (custom != null && custom.isNotEmpty) {
      if (await File(custom).exists()) return custom;
    }

    final ext = _getExecutableExtension();
    final exeName = 'signal$ext';
    for (final dir in _candidateBinaryDirs()) {
      final target = p.join(dir, exeName);
      if (await File(target).exists()) {
        return target;
      }
    }

    final pathResolved = await _findInSystemPath(exeName);
    if (pathResolved != null) {
      return pathResolved;
    }

    return p.join(p.dirname(Platform.resolvedExecutable), 'bin', exeName);
  }

  /// Inspects a binary file, executes with `-help`, and parses its version string.
  Future<BinaryInfo> inspectBinary(
    String path, {
    bool useCache = true,
  }) async {
    if (disableProcessProbe) {
      return BinaryInfo(
        path: path,
        exists: true,
        version: 'v3.1.11 (Test Stub)',
      );
    }
    final file = File(path);
    if (!await file.exists()) {
      return BinaryInfo(
        path: path,
        exists: false,
        error: '核心程序不存在: $path',
      );
    }

    try {
      final stat = await file.stat();
      if (useCache) {
        final cached = _inspectCache[path];
        if (cached != null &&
            cached.modified == stat.modified &&
            cached.size == stat.size) {
          return cached.info;
        }
      }

      final result = await Process.run(path, ['-help'])
          .timeout(const Duration(seconds: 5));
      final output = '${result.stdout}\n${result.stderr}';

      final versionRegex = RegExp(r'v\d+\.\d+\.\d+(?:-[\w.]+)?');
      final match = versionRegex.firstMatch(output);

      BinaryInfo info;
      if (match != null) {
        info = BinaryInfo(
          path: path,
          exists: true,
          version: match.group(0),
        );
      } else if (output.contains('WebRTC Gateway')) {
        info = BinaryInfo(
          path: path,
          exists: true,
          version: 'WebRTC Gateway Core (Custom)',
        );
      } else {
        info = BinaryInfo(
          path: path,
          exists: true,
          version: null,
          error: '未识别为有效的 WebRTC Gateway 二进制程序',
        );
      }

      _inspectCache[path] = _CachedBinaryEntry(stat.modified, stat.size, info);
      return info;
    } on TimeoutException {
      return BinaryInfo(
        path: path,
        exists: true,
        error: '检测超时: 程序在 5 秒内未响应 -help 参数',
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
