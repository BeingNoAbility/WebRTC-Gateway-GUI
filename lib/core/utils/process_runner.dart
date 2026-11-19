import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class ManagedProcess {
  final Process process;
  final int pid;
  final Completer<int> exitCompleter = Completer<int>();

  ManagedProcess(this.process) : pid = process.pid;

  Future<void> kill() async {
    try {
      if (Platform.isWindows) {
        // Force kill process tree on Windows to prevent orphaned WebRTC sockets
        await Process.run('taskkill', ['/F', '/T', '/PID', pid.toString()]);
      } else {
        process.kill(ProcessSignal.sigterm);
      }
    } catch (_) {
      process.kill();
    }
  }
}

class ProcessRunner {
  /// Synchronously checks common candidate locations on the filesystem.
  static String? findBinary(String binaryName, {String? customPath}) {
    if (customPath != null && customPath.trim().isNotEmpty) {
      final file = File(customPath.trim());
      if (file.existsSync()) {
        return file.absolute.path;
      }
    }

    final exeName = Platform.isWindows ? '$binaryName.exe' : binaryName;

    // Search candidate locations in order
    final candidates = [
      // 1. Current working directory + assets/bin
      '${Directory.current.path}\\assets\\bin\\$exeName',
      '${Directory.current.path}/assets/bin/$exeName',
      // 2. Current working directory + WebRTC-Gateway
      '${Directory.current.path}\\WebRTC-Gateway\\$exeName',
      '${Directory.current.path}/WebRTC-Gateway/$exeName',
      // 3. Current working directory directly
      '${Directory.current.path}\\$exeName',
      '${Directory.current.path}/$exeName',
      // 4. Alongside the app's resolved executable
      '${File(Platform.resolvedExecutable).parent.path}\\$exeName',
      '${File(Platform.resolvedExecutable).parent.path}\\data\\flutter_assets\\assets\\bin\\$exeName',
      // 5. Local AppData cache directory
      if (Platform.isWindows &&
          Platform.environment.containsKey('LOCALAPPDATA'))
        '${Platform.environment['LOCALAPPDATA']}\\WebRTC-Gateway\\bin\\$exeName',
    ];

    for (final c in candidates) {
      if (File(c).existsSync()) {
        return File(c).absolute.path;
      }
    }

    return null;
  }

  /// Ensures the binary exists. If not found on disk, auto-extracts it from Flutter bundled assets.
  static Future<String?> ensureBinary(
    String binaryName, {
    String? customPath,
  }) async {
    final existing = findBinary(binaryName, customPath: customPath);
    if (existing != null) {
      return existing;
    }

    final exeName = Platform.isWindows ? '$binaryName.exe' : binaryName;

    // Try extracting from Flutter assets bundle
    try {
      final assetPath = 'assets/bin/$exeName';
      final byteData = await rootBundle.load(assetPath);

      // Determine extraction target
      String targetDir;
      if (Platform.isWindows &&
          Platform.environment.containsKey('LOCALAPPDATA')) {
        targetDir =
            '${Platform.environment['LOCALAPPDATA']}\\WebRTC-Gateway\\bin';
      } else {
        targetDir = '${Directory.systemTemp.path}/WebRTC-Gateway/bin';
      }

      final dir = Directory(targetDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final targetFile = File('$targetDir/$exeName');
      final buffer = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await targetFile.writeAsBytes(buffer, flush: true);

      if (targetFile.existsSync()) {
        return targetFile.absolute.path;
      }
    } catch (_) {
      // Asset loading fallback ignored if asset not bundled
    }

    return null;
  }

  /// Starts the process and pipes stdout and stderr line-by-line.
  static Future<ManagedProcess> start({
    required String executable,
    required List<String> arguments,
    String? workingDirectory,
    required void Function(String line) onStdout,
    required void Function(String line) onStderr,
    required void Function(int exitCode) onExit,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
    );

    final managed = ManagedProcess(process);

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => onStdout(line),
          onError: (err) => onStderr('Stdout stream error: $err'),
        );

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => onStderr(line),
          onError: (err) => onStderr('Stderr stream error: $err'),
        );

    process.exitCode.then((code) {
      if (!managed.exitCompleter.isCompleted) {
        managed.exitCompleter.complete(code);
      }
      onExit(code);
    });

    return managed;
  }
}
