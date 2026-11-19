// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/legacy.dart';

import '../providers/agent_provider.dart';
import '../providers/settings_provider.dart';

class TrayService with WindowListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();
  BuildContext? _context;
  bool _initialized = false;

  Future<void> init(BuildContext context) async {
    if (kIsWeb || !Platform.isWindows) return;
    if (_initialized) {
      _context = context;
      return;
    }

    _context = context;
    _initialized = true;

    try {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1120, 740),
        minimumSize: Size(820, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'WebRTC Gateway Manager',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      // Prevent closing directly, minimize to tray instead
      await windowManager.setPreventClose(true);
      windowManager.addListener(this);

      // Initialize SystemTray
      await _systemTray.initSystemTray(
        title: "WebRTC Gateway Manager",
        iconPath: 'assets/images/logo_32.png',
        toolTip: "WebRTC Gateway Manager (后台运行中)",
      );

      final Menu menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: '显示主面板 (Show Window)',
          onClicked: (menuItem) async {
            await _appWindow.show();
            await windowManager.focus();
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '启动全部 Agent (Start All)',
          onClicked: (menuItem) {
            _context?.read<AgentProvider>().startAll();
          },
        ),
        MenuItemLabel(
          label: '停止全部 Agent (Stop All)',
          onClicked: (menuItem) {
            _context?.read<AgentProvider>().stopAll();
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '彻底退出程序 (Exit)',
          onClicked: (menuItem) async {
            windowManager.removeListener(this);
            await windowManager.destroy();
            exit(0);
          },
        ),
      ]);

      await _systemTray.setContextMenu(menu);

      // Handle tray left click
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _appWindow.show();
          windowManager.focus();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e) {
      debugPrint('TrayService init failed: $e');
    }
  }

  @override
  void onWindowClose() async {
    if (!Platform.isWindows || _context == null) return;

    final settings = _context!.read<SettingsProvider>();
    if (settings.closeToTray) {
      await _appWindow.hide();
    } else {
      windowManager.removeListener(this);
      await windowManager.destroy();
      exit(0);
    }
  }

  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      _systemTray.destroy();
    }
  }
}
