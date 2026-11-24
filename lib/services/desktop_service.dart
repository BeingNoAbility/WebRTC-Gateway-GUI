import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../models/app_settings.dart';
import '../state/app_state.dart';

class DesktopService with TrayListener, WindowListener {
  final AppState appState;
  final Connectivity _connectivity = Connectivity();

  static VoidCallback? onRequestClosePrompt;

  DesktopService(this.appState);

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    // Window Manager setup
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1220, 780),
        minimumSize: Size(1024, 640),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        title: 'WebRTC Gateway',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      });

      windowManager.addListener(this);
    } catch (_) {}

    // System Tray setup
    try {
      trayManager.addListener(this);
      await _updateTray();
      appState.addListener(_onAppStateChanged);
    } catch (_) {}

    // Network Change Auto-Heal
    _setupNetworkWatcher();
  }

  void _onAppStateChanged() {
    _updateTray();
  }

  Future<String> _resolveTrayIconPath() async {
    if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final candidates = [
        p.join(exeDir, 'data', 'flutter_assets', 'assets', 'icons', 'app_icon.ico'),
        p.join(exeDir, 'app_icon.ico'),
        p.join(Directory.current.path, 'assets', 'icons', 'app_icon.ico'),
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) {
          return path;
        }
      }

      // If not found in standard paths, extract asset to temporary or app data file
      try {
        final byteData = await rootBundle.load('assets/icons/app_icon.ico');
        final tempDir = await getTemporaryDirectory();
        final file = File(p.join(tempDir.path, 'webrtc_gateway_tray.ico'));
        await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        return file.path;
      } catch (_) {}
      return p.join(exeDir, 'app_icon.ico');
    } else {
      return 'assets/icons/tray_icon.png';
    }
  }

  Future<void> _updateTray() async {
    try {
      final iconPath = await _resolveTrayIconPath();
      await trayManager.setIcon(iconPath);

      final isSignalRunning = appState.isSignalRunning();
      final runningNodes = appState.runningCount;
      final tooltip = isSignalRunning
          ? 'WebRTC Gateway ($runningNodes 节点运行中 | 信令服务在线)'
          : 'WebRTC Gateway ($runningNodes 节点运行中)';
      await trayManager.setToolTip(tooltip);

      final menuItems = <MenuItem>[
        MenuItem(key: 'show', label: '显示主窗口 (Show Window)'),
        MenuItem(key: 'hide', label: '隐藏到托盘 (Hide to Tray)'),
        MenuItem.separator(),
        MenuItem(
          key: 'start_all',
          label: '启动全部穿透节点 (${appState.profiles.length} 个)',
          disabled: appState.profiles.isEmpty || runningNodes == appState.profiles.length,
        ),
        MenuItem(
          key: 'stop_all',
          label: '停止全部穿透节点',
          disabled: runningNodes == 0,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle_signal',
          label: isSignalRunning ? '停止信令服务 (Stop Signal)' : '启动信令服务 (Start Signal)',
        ),
      ];

      if (isSignalRunning) {
        menuItems.add(
          MenuItem(key: 'open_web', label: '打开 Web 门户控制台'),
        );
      }

      menuItems.addAll([
        MenuItem.separator(),
        MenuItem(key: 'exit', label: '退出程序 (Exit)'),
      ]);

      final menu = Menu(items: menuItems);
      await trayManager.setContextMenu(menu);
    } catch (_) {}
  }

  void _setupNetworkWatcher() {
    _connectivity.onConnectivityChanged.listen((results) async {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        // Trigger auto-heal reconnect for agents
        for (final p in appState.profiles) {
          if (appState.isRunning(p.id)) {
            // Hot reload or restart if connection was dropped
            await appState.stopAgent(p.id);
            await Future.delayed(const Duration(milliseconds: 500));
            await appState.startAgent(p);
          }
        }
      }
    });
  }

  @override
  void onTrayIconMouseDown() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    // Windows: Show context menu on right click
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'hide':
        await windowManager.hide();
        break;
      case 'start_all':
        await appState.startAllAgents();
        break;
      case 'stop_all':
        await appState.stopAllAgents();
        break;
      case 'toggle_signal':
        if (appState.isSignalRunning()) {
          await appState.stopSignalServer();
        } else {
          await appState.startSignalServer();
        }
        break;
      case 'open_web':
        final url = appState.signalConfig.portalWebUrl;
        if (Platform.isWindows) {
          Process.run('cmd', ['/c', 'start', url]);
        } else if (Platform.isMacOS) {
          Process.run('open', [url]);
        } else {
          Process.run('xdg-open', [url]);
        }
        break;
      case 'exit':
        await appState.stopAllAgents();
        await appState.stopSignalServer();
        await windowManager.destroy();
        exit(0);
    }
  }

  @override
  void onWindowClose() async {
    final action = appState.closeAction;
    if (action == CloseAction.minimizeToTray) {
      await windowManager.hide();
    } else if (action == CloseAction.exitApp) {
      await appState.stopAllAgents();
      await appState.stopSignalServer();
      await windowManager.destroy();
      exit(0);
    } else {
      if (onRequestClosePrompt != null) {
        onRequestClosePrompt!();
      } else {
        await windowManager.hide();
      }
    }
  }

  void dispose() {
    appState.removeListener(_onAppStateChanged);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }
}
