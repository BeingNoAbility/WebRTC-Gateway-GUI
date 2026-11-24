import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
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
    } catch (_) {}

    // Network Change Auto-Heal
    _setupNetworkWatcher();
  }

  Future<void> _updateTray() async {
    try {
      final iconPath = Platform.isWindows ? 'assets/icons/app_icon.ico' : 'assets/icons/tray_icon.png';
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('WebRTC Gateway (${appState.runningCount} 节点在线)');

      final menu = Menu(
        items: [
          MenuItem(key: 'show', label: '显示主窗口'),
          MenuItem.separator(),
          MenuItem(key: 'start_all', label: '启动所有节点'),
          MenuItem(key: 'stop_all', label: '停止所有节点'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: '退出程序'),
        ],
      );
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
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'start_all':
        await appState.startAllAgents();
        await _updateTray();
        break;
      case 'stop_all':
        await appState.stopAllAgents();
        await _updateTray();
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
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }
}
