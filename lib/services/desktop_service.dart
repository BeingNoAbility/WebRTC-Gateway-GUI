import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import '../core/i18n.dart';
import '../models/app_settings.dart';
import '../state/app_state.dart';

class DesktopService with TrayListener, WindowListener {
  final AppState appState;
  final Connectivity _connectivity = Connectivity();

  static VoidCallback? onRequestClosePrompt;
  static DesktopService? instance;

  int _lastRunningCount = -1;
  bool _lastSignalRunning = false;
  int _lastProfilesCount = -1;
  String _lastLocale = '';
  bool _isUpdatingTray = false;
  bool _trayIconInitialized = false;
  String? _cachedTrayIconPath;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _networkHealTimer;
  bool _wasOffline = false;
  bool _hasSeenConnectivityEvent = false;

  DesktopService(this.appState) {
    instance = this;
  }

  Future<void> init({bool startMinimized = false}) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

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
        if (startMinimized) {
          await windowManager.hide();
        } else {
          await windowManager.show();
          await windowManager.focus();
        }
      });

      windowManager.addListener(this);
    } catch (_) {}

    try {
      trayManager.addListener(this);
      await _updateTray();
      appState.addListener(_onAppStateChanged);
    } catch (_) {}

    _setupNetworkWatcher();
  }

  void _onAppStateChanged() {
    final isSignalRunning = appState.isSignalRunning();
    final runningNodes = appState.runningCount;
    final profilesCount = appState.profiles.length;
    final locale = AppI18n().currentLocale;

    if (isSignalRunning == _lastSignalRunning &&
        runningNodes == _lastRunningCount &&
        profilesCount == _lastProfilesCount &&
        locale == _lastLocale) {
      return;
    }

    _lastSignalRunning = isSignalRunning;
    _lastRunningCount = runningNodes;
    _lastProfilesCount = profilesCount;
    _lastLocale = locale;

    unawaited(_updateTray());
  }

  Future<String> _resolveTrayIconPath() async {
    if (_cachedTrayIconPath != null) return _cachedTrayIconPath!;

    if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final candidates = [
        p.join(exeDir, 'app_icon.ico'),
        p.join(
          exeDir,
          'data',
          'flutter_assets',
          'assets',
          'icons',
          'app_icon.ico',
        ),
        p.join(Directory.current.path, 'assets', 'icons', 'app_icon.ico'),
        p.join(
          Directory.current.path,
          'windows',
          'runner',
          'resources',
          'app_icon.ico',
        ),
      ];
      for (final candidate in candidates) {
        if (File(candidate).existsSync()) {
          _cachedTrayIconPath = candidate;
          return candidate;
        }
      }

      try {
        final byteData = await rootBundle.load('assets/icons/app_icon.ico');
        final tempDir = await getTemporaryDirectory();
        final file = File(p.join(tempDir.path, 'webrtc_gateway_tray.ico'));
        await file.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        );
        _cachedTrayIconPath = file.path;
        return file.path;
      } catch (_) {}
      _cachedTrayIconPath = p.join(exeDir, 'app_icon.ico');
      return _cachedTrayIconPath!;
    } else {
      _cachedTrayIconPath = 'assets/icons/tray_icon.png';
      return _cachedTrayIconPath!;
    }
  }

  Future<void> _updateTray() async {
    if (_isUpdatingTray) return;
    _isUpdatingTray = true;

    try {
      if (!_trayIconInitialized) {
        final iconPath = await _resolveTrayIconPath();
        await trayManager.setIcon(iconPath);
        _trayIconInitialized = true;
      }

      final isEn = AppI18n().currentLocale == 'en';
      final isSignalRunning = appState.isSignalRunning();
      final runningNodes = appState.runningCount;
      final tooltip = isEn
          ? (isSignalRunning
              ? 'WebRTC Gateway ($runningNodes agents running | Signal online)'
              : 'WebRTC Gateway ($runningNodes agents running)')
          : (isSignalRunning
              ? 'WebRTC Gateway ($runningNodes 节点运行中 | 信令服务在线)'
              : 'WebRTC Gateway ($runningNodes 节点运行中)');
      await trayManager.setToolTip(tooltip);

      // NOTE: Do NOT attach MenuItem.onClick here because tray_manager invokes BOTH
      // MenuItem.onClick and TrayListener.onTrayMenuItemClick on every click.
      final menuItems = <MenuItem>[
        MenuItem(
          key: 'show',
          label: isEn ? 'Show Window' : '显示主窗口',
        ),
        MenuItem(
          key: 'hide',
          label: isEn ? 'Hide to Tray' : '隐藏到托盘',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'start_all',
          label: isEn
              ? 'Start All Agents (${appState.profiles.length})'
              : '启动全部穿透节点 (${appState.profiles.length} 个)',
          disabled: appState.profiles.isEmpty ||
              runningNodes == appState.profiles.length,
        ),
        MenuItem(
          key: 'stop_all',
          label: isEn ? 'Stop All Agents' : '停止全部穿透节点',
          disabled: runningNodes == 0,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle_signal',
          label: isSignalRunning
              ? (isEn ? 'Stop Signal Server' : '停止信令服务')
              : (isEn ? 'Start Signal Server' : '启动信令服务'),
        ),
      ];

      if (isSignalRunning) {
        menuItems.add(
          MenuItem(
            key: 'open_web',
            label: isEn ? 'Open Web Portal' : '打开 Web 门户控制台',
          ),
        );
      }

      menuItems.addAll([
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: isEn ? 'Exit' : '退出程序',
        ),
      ]);

      final menu = Menu(items: menuItems);
      await trayManager.setContextMenu(menu);
    } catch (_) {
    } finally {
      _isUpdatingTray = false;
    }
  }

  void _setupNetworkWatcher() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (!_hasSeenConnectivityEvent) {
        _hasSeenConnectivityEvent = true;
        _wasOffline = !isOnline;
        return;
      }

      if (!isOnline) {
        _wasOffline = true;
        _networkHealTimer?.cancel();
        return;
      }

      // Only trigger auto-heal when transitioning back from an actual offline state,
      // debounced so virtual/VPN adapters do not cause reconnect storms.
      if (_wasOffline && isOnline) {
        _wasOffline = false;
        _networkHealTimer?.cancel();
        _networkHealTimer = Timer(const Duration(seconds: 2), () async {
          for (final profile in appState.profiles) {
            if (appState.isRunning(profile.id)) {
              appState.supervisor
                  .getOrCreateState(profile.id)
                  .addLog('[GUI] 检测到网络恢复上线，正在自动重连节点...');
              await appState.stopAgent(profile.id);
              await Future<void>.delayed(const Duration(milliseconds: 500));
              await appState.startAgent(profile);
            }
          }
        });
      }
    });
  }

  static Future<bool> openExternalUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> shutdownAndExit() async {
    await appState.shutdownForExit();
    await dispose();
    try {
      await trayManager.destroy();
    } catch (_) {}
    try {
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }

  @override
  Future<void> onTrayIconMouseDown() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  Future<void> onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
      case 'hide':
        await windowManager.hide();
      case 'start_all':
        await appState.startAllAgents();
      case 'stop_all':
        await appState.stopAllAgents();
      case 'toggle_signal':
        if (appState.isSignalRunning()) {
          await appState.stopSignalServer();
        } else {
          await appState.startSignalServer();
        }
      case 'open_web':
        await openExternalUrl(appState.signalConfig.portalWebUrl);
      case 'exit':
        await shutdownAndExit();
    }
  }

  @override
  Future<void> onWindowClose() async {
    final action = appState.closeAction;
    if (action == CloseAction.minimizeToTray) {
      await windowManager.hide();
    } else if (action == CloseAction.exitApp) {
      await shutdownAndExit();
    } else {
      if (onRequestClosePrompt != null) {
        onRequestClosePrompt!();
      } else {
        await windowManager.hide();
      }
    }
  }

  Future<void> dispose() async {
    _networkHealTimer?.cancel();
    await _connectivitySub?.cancel();
    appState.removeListener(_onAppStateChanged);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }
}
