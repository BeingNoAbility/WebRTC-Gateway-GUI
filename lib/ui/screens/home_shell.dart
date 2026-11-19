import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/agent_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/status_indicator_badge.dart';
import '../../services/tray_service.dart';
import 'agent_screen.dart';
import 'diagnostics_screen.dart';
import 'logs_screen.dart';
import 'server_screen.dart';
import 'settings_screen.dart';
import 'visitor_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrayService().init(context);
    });
  }

  void _navigateToIndex(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final agentProvider = context.watch<AgentProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      AgentScreen(onNavigateToLogs: () => _navigateToIndex(4)),
      const VisitorScreen(),
      ServerScreen(onNavigateToLogs: () => _navigateToIndex(4)),
      const DiagnosticsScreen(),
      const LogsScreen(),
      const SettingsScreen(),
    ];

    const navDestinations = [
      NavigationRailDestination(
        icon: Icon(Icons.router_outlined),
        selectedIcon: Icon(Icons.router_rounded),
        label: Text('穿透服务'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.travel_explore_outlined),
        selectedIcon: Icon(Icons.travel_explore_rounded),
        label: Text('访客中心'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.cell_tower_outlined),
        selectedIcon: Icon(Icons.cell_tower_rounded),
        label: Text('信令服务'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.speed_outlined),
        selectedIcon: Icon(Icons.speed_rounded),
        label: Text('网络诊断'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.terminal_outlined),
        selectedIcon: Icon(Icons.terminal_rounded),
        label: Text('运行日志'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings_rounded),
        label: Text('配置设置'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          // Desktop / Tablet Layout with Left NavigationRail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _navigateToIndex,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryCyan.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCyan.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SvgPicture.asset(
                            'assets/images/logo.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'WebRTC',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: isDark ? '切换至亮色模式' : '切换至暗黑模式',
                              icon: Icon(
                                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                size: 20,
                              ),
                              onPressed: () => settingsProvider.toggleTheme(),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                Platform.isWindows ? 'WIN' : 'AND',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  destinations: navDestinations,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Column(
                    children: [
                      // Desktop Top Header
                      Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _getTitleForIndex(_currentIndex),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            StatusIndicatorBadge(status: agentProvider.status),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryCyan.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.shield_outlined, size: 14, color: AppColors.primaryCyan),
                                  const SizedBox(width: 5),
                                  Text(
                                    'DTLS 1.2 / SRTP 端到端加密直连',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.primaryCyan : AppColors.primaryCyanDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: screens,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile Layout (Android / Narrow Screen) with Bottom NavigationBar
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryCyan.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/logo.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getTitleForIndex(_currentIndex),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                StatusIndicatorBadge(status: agentProvider.status),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
                  onPressed: () => settingsProvider.toggleTheme(),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _navigateToIndex,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.router_outlined),
                  selectedIcon: Icon(Icons.router_rounded),
                  label: '穿透端',
                ),
                NavigationDestination(
                  icon: Icon(Icons.travel_explore_outlined),
                  selectedIcon: Icon(Icons.travel_explore_rounded),
                  label: '访客中心',
                ),
                NavigationDestination(
                  icon: Icon(Icons.cell_tower_outlined),
                  selectedIcon: Icon(Icons.cell_tower_rounded),
                  label: '信令端',
                ),
                NavigationDestination(
                  icon: Icon(Icons.speed_outlined),
                  selectedIcon: Icon(Icons.speed_rounded),
                  label: '诊断',
                ),
                NavigationDestination(
                  icon: Icon(Icons.terminal_outlined),
                  selectedIcon: Icon(Icons.terminal_rounded),
                  label: '日志',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: '设置',
                ),
              ],
            ),
          );
        }
      },
    );
  }

  String _getTitleForIndex(int idx) {
    switch (idx) {
      case 0:
        return 'WebRTC 穿透服务管理';
      case 1:
        return '访客远程直连中心';
      case 2:
        return '信令中继服务端';
      case 3:
        return '网络与穿透诊断工具箱';
      case 4:
        return '实时运行控制台日志';
      case 5:
        return '系统与高级设置';
      default:
        return AppConstants.appName;
    }
  }
}
