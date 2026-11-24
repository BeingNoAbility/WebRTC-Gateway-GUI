import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../core/i18n.dart';
import '../models/app_settings.dart';
import '../services/desktop_service.dart';
import '../state/app_state.dart';
import 'agents/agent_list_view.dart';
import 'dashboard/dashboard_view.dart';
import 'diagnostics/diagnostics_view.dart';
import 'logs/log_viewer_view.dart';
import 'settings/settings_view.dart';
import 'signal/signal_server_view.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  @override
  void initState() {
    super.initState();
    DesktopService.onRequestClosePrompt = _showCloseConfirmDialog;
  }

  @override
  void dispose() {
    DesktopService.onRequestClosePrompt = null;
    super.dispose();
  }

  void _showCloseConfirmDialog() {
    if (!mounted) return;
    final state = context.read<AppState>();
    bool remember = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.help_outline_rounded, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('关闭 WebRTC Gateway'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('请选择您希望执行的关闭操作：', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• 最小化到系统托盘：后台保持穿透与信令服务正常运行，通过任务栏托盘小图标可随时唤出。',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• 完全退出程序：立即终止所有运行中的 Agent 和 Signal 进程并彻底退出。',
                        style: TextStyle(fontSize: 12, height: 1.4, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('记住我的选择，下次直接执行', style: TextStyle(fontSize: 13)),
                  value: remember,
                  onChanged: (val) => setDialogState(() => remember = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (remember) {
                  state.setCloseAction(CloseAction.minimizeToTray);
                }
                await windowManager.hide();
              },
              child: const Text('最小化到托盘'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (remember) {
                  state.setCloseAction(CloseAction.exitApp);
                }
                await state.stopAllAgents();
                await state.stopSignalServer();
                await windowManager.destroy();
                exit(0);
              },
              child: const Text('完全退出'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();

    final destinations = [
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard_rounded, color: Colors.blueAccent),
        label: Text(i18n.t('nav_dashboard')),
      ),
      NavigationRailDestination(
        icon: Badge(
          isLabelVisible: state.runningCount > 0,
          label: Text('${state.runningCount}'),
          backgroundColor: Colors.green,
          child: const Icon(Icons.hub_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: state.runningCount > 0,
          label: Text('${state.runningCount}'),
          backgroundColor: Colors.green,
          child: const Icon(Icons.hub_rounded, color: Colors.blueAccent),
        ),
        label: Text(i18n.t('nav_agents')),
      ),
      NavigationRailDestination(
        icon: Badge(
          isLabelVisible: state.isSignalRunning(),
          backgroundColor: Colors.purpleAccent,
          child: const Icon(Icons.dns_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: state.isSignalRunning(),
          backgroundColor: Colors.purpleAccent,
          child: const Icon(Icons.dns_rounded, color: Colors.purpleAccent),
        ),
        label: Text(i18n.t('nav_signal')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.troubleshoot_outlined),
        selectedIcon: const Icon(Icons.troubleshoot_rounded, color: Colors.blueAccent),
        label: Text(i18n.t('nav_diagnostics')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent),
        label: Text(i18n.t('nav_logs')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings_rounded, color: Colors.blueAccent),
        label: Text(i18n.t('nav_settings')),
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Desktop Left Navigation Rail
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            leading: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 24.0, left: 16.0, right: 16.0),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/logo.svg',
                    width: 38,
                    height: 38,
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WebRTC',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.1),
                      ),
                      Text(
                        'Gateway',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        i18n.currentLocale == 'zh' ? '简体中文' : 'EN',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '切换语言 (Switch Language)',
                        icon: const Icon(Icons.translate_rounded, size: 18),
                        onPressed: () => state.toggleLocale(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            selectedIndex: state.selectedTabIndex,
            onDestinationSelected: (idx) => state.setTabIndex(idx),
            destinations: destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // Main View Content
          Expanded(
            child: IndexedStack(
              index: state.selectedTabIndex,
              children: const [
                DashboardView(),
                AgentListView(),
                SignalServerView(),
                DiagnosticsView(),
                LogViewerView(),
                SettingsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
