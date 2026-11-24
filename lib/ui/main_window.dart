import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'agents/agent_list_view.dart';
import 'dashboard/dashboard_view.dart';
import 'diagnostics/diagnostics_view.dart';
import 'logs/log_viewer_view.dart';
import 'settings/settings_view.dart';

class MainWindow extends StatelessWidget {
  const MainWindow({super.key});

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
                        i18n.currentLocale == 'zh' ? '中文' : 'EN',
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
