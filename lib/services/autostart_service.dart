import 'dart:io';
import 'package:path/path.dart' as p;

class AutostartService {
  static const String appKey = 'WebRTCGatewayGUI';

  /// Checks if start-on-boot is currently enabled on the host system.
  Future<bool> isEnabled() async {
    try {
      if (Platform.isWindows) {
        final res = await Process.run('reg', [
          'query',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          appKey,
        ]);
        return res.exitCode == 0;
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        final file = File(
          p.join(home, '.config', 'autostart', 'webrtc-gateway-gui.desktop'),
        );
        return await file.exists();
      } else if (Platform.isMacOS) {
        final exe = Platform.resolvedExecutable.replaceAll('"', r'\"');
        final res = await Process.run('osascript', [
          '-e',
          'tell application "System Events" to get name of every login item whose path contains "$exe"',
        ]);
        return res.exitCode == 0 && (res.stdout as String).trim().isNotEmpty;
      }
    } catch (_) {}
    return false;
  }

  /// Sets start-on-boot state, passing `--minimized` so boot launch stays unobtrusive in tray.
  Future<bool> setEnabled(bool enable) async {
    try {
      final exePath = Platform.resolvedExecutable;

      if (Platform.isWindows) {
        if (enable) {
          final res = await Process.run('reg', [
            'add',
            r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
            '/v',
            appKey,
            '/t',
            'REG_SZ',
            '/d',
            '"$exePath" --minimized',
            '/f',
          ]);
          return res.exitCode == 0;
        } else {
          final res = await Process.run('reg', [
            'delete',
            r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
            '/v',
            appKey,
            '/f',
          ]);
          return res.exitCode == 0 || res.exitCode == 1;
        }
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        final autostartDir = Directory(p.join(home, '.config', 'autostart'));
        final file =
            File(p.join(autostartDir.path, 'webrtc-gateway-gui.desktop'));

        if (enable) {
          if (!await autostartDir.exists()) {
            await autostartDir.create(recursive: true);
          }
          final escapedExe = exePath.replaceAll('"', r'\"');
          final desktopContent = '''[Desktop Entry]
Type=Application
Version=1.0
Name=WebRTC Gateway
Comment=WebRTC Gateway GUI Desktop Client
Exec="$escapedExe" --minimized
Terminal=false
Icon=webrtc-gateway
Categories=Network;Utility;
StartupNotify=false
''';
          await file.writeAsString(desktopContent);
          return true;
        } else {
          if (await file.exists()) {
            await file.delete();
          }
          return true;
        }
      } else if (Platform.isMacOS) {
        final escapedExe = exePath.replaceAll('"', r'\"');
        if (enable) {
          final script =
              'tell application "System Events" to make login item at end with properties {path:"$escapedExe", hidden:true}';
          final res = await Process.run('osascript', ['-e', script]);
          return res.exitCode == 0;
        } else {
          final script =
              'tell application "System Events" to delete (every login item whose path contains "$escapedExe")';
          final res = await Process.run('osascript', ['-e', script]);
          return res.exitCode == 0;
        }
      }
    } catch (_) {}
    return false;
  }
}
