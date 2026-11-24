import 'dart:async';
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
    if (DesktopService.onRequestClosePrompt == _showCloseConfirmDialog) {
      DesktopService.onRequestClosePrompt = null;
    }
    super.dispose();
  }

  void _showCloseConfirmDialog() {
    if (!mounted) return;
    final state = context.read<AppState>();
    final i18n = AppI18n();
    var remember = false;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Text(i18n.pick('关闭 WebRTC Gateway', 'Close WebRTC Gateway')),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.pick('请选择您希望执行的关闭操作：', 'Choose what happens when closing:'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.pick(
                            '• 最小化到系统托盘：后台保持穿透与信令服务正常运行，通过任务栏托盘小图标可随时唤出。',
                            '• Minimize to Tray: Keep tunnels and signal server running in the background.',
                          ),
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          i18n.pick(
                            '• 完全退出程序：立即终止所有运行中的 Agent 和 Signal 进程并彻底退出。',
                            '• Exit Completely: Stop all running Agent & Signal processes and quit.',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      i18n.pick('记住我的选择，下次直接执行', 'Remember my choice'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    value: remember,
                    onChanged: (val) =>
                        setDialogState(() => remember = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(i18n.t('common_cancel')),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (remember) {
                    state.setCloseAction(CloseAction.minimizeToTray);
                  }
                  await windowManager.hide();
                },
                child: Text(i18n.pick('最小化到托盘', 'Minimize to Tray')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (remember) {
                    state.setCloseAction(CloseAction.exitApp);
                  }
                  final desktop = DesktopService.instance;
                  if (desktop != null) {
                    await desktop.shutdownAndExit();
                  } else {
                    await state.shutdownForExit();
                  }
                },
                child: Text(i18n.pick('完全退出', 'Exit')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.select<
        AppState,
        ({
          int tabIndex,
          int runningCount,
          bool signalRunning,
          String locale,
        })>(
      (s) => (
        tabIndex: s.selectedTabIndex,
        runningCount: s.runningCount,
        signalRunning: s.isSignalRunning(),
        locale: AppI18n().currentLocale,
      ),
    );
    final state = context.read<AppState>();

    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebar(
            selectedIndex: nav.tabIndex,
            runningCount: nav.runningCount,
            signalRunning: nav.signalRunning,
            locale: nav.locale,
            onSelect: state.setTabIndex,
            onToggleLocale: state.toggleLocale,
          ),
          Expanded(
            child: _SmoothTabStack(
              selectedIndex: nav.tabIndex,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarEntry {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color activeColor;
  final int? badgeCount;
  final bool showDotBadge;
  final Color? badgeColor;

  const _SidebarEntry({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.activeColor,
    this.badgeCount,
    this.showDotBadge = false,
    this.badgeColor,
  });
}

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final int runningCount;
  final bool signalRunning;
  final String locale;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleLocale;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.runningCount,
    required this.signalRunning,
    required this.locale,
    required this.onSelect,
    required this.onToggleLocale,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final entries = [
      _SidebarEntry(
        index: 0,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: i18n.t('nav_dashboard'),
        activeColor: Colors.blueAccent,
      ),
      _SidebarEntry(
        index: 1,
        icon: Icons.hub_outlined,
        selectedIcon: Icons.hub_rounded,
        label: i18n.t('nav_agents'),
        activeColor: Colors.blueAccent,
        badgeCount: runningCount,
        badgeColor: Colors.green,
      ),
      _SidebarEntry(
        index: 2,
        icon: Icons.dns_outlined,
        selectedIcon: Icons.dns_rounded,
        label: i18n.t('nav_signal'),
        activeColor: Colors.purpleAccent,
        showDotBadge: signalRunning,
        badgeColor: Colors.purpleAccent,
      ),
      _SidebarEntry(
        index: 3,
        icon: Icons.troubleshoot_outlined,
        selectedIcon: Icons.troubleshoot_rounded,
        label: i18n.t('nav_diagnostics'),
        activeColor: Colors.blueAccent,
      ),
      _SidebarEntry(
        index: 4,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: i18n.t('nav_logs'),
        activeColor: Colors.blueAccent,
      ),
      _SidebarEntry(
        index: 5,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: i18n.t('nav_settings'),
        activeColor: Colors.blueAccent,
      ),
    ];

    return RepaintBoundary(
      child: Container(
        width: 212,
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerLow
              : colorScheme.surfaceContainerLowest,
          border: Border(
            right: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 16, 20),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icons/logo.png',
                    width: 36,
                    height: 36,
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WebRTC',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Gateway',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: entries.length,
                itemBuilder: (context, idx) {
                  final item = entries[idx];
                  return _SidebarNavItem(
                    entry: item,
                    selected: selectedIndex == item.index,
                    onTap: () => onSelect(item.index),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  onPressed: onToggleLocale,
                  icon: const Icon(Icons.translate_rounded, size: 16),
                  label: Text(
                    locale == 'zh' ? '简体中文 · EN' : 'English · 中文',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final _SidebarEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unselectedColor = colorScheme.onSurfaceVariant;
    final activeBg = entry.activeColor.withValues(alpha: 0.14);

    Widget iconWidget = Icon(
      selected ? entry.selectedIcon : entry.icon,
      size: 20,
      color: selected ? entry.activeColor : unselectedColor,
    );

    if (entry.badgeCount != null) {
      iconWidget = Badge(
        isLabelVisible: entry.badgeCount! > 0,
        label: Text('${entry.badgeCount}'),
        backgroundColor: entry.badgeColor ?? Colors.green,
        child: iconWidget,
      );
    } else if (entry.index == 2) {
      iconWidget = Badge(
        isLabelVisible: entry.showDotBadge,
        backgroundColor: entry.badgeColor ?? Colors.purpleAccent,
        child: iconWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: colorScheme.onSurface.withValues(alpha: 0.05),
          splashColor: entry.activeColor.withValues(alpha: 0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: 3,
                  height: selected ? 18 : 0,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: selected ? entry.activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                iconWidget,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color:
                          selected ? colorScheme.onSurface : unselectedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmoothTabStack extends StatefulWidget {
  final int selectedIndex;

  const _SmoothTabStack({required this.selectedIndex});

  @override
  State<_SmoothTabStack> createState() => _SmoothTabStackState();
}

class _SmoothTabStackState extends State<_SmoothTabStack>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 6;
  final List<Widget?> _cachedPages = List<Widget?>.filled(_tabCount, null);

  late final AnimationController _transitionCtrl;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  Widget _createPage(int index) {
    switch (index) {
      case 0:
        return const DashboardView();
      case 1:
        return const AgentListView();
      case 2:
        return const SignalServerView();
      case 3:
        return const DiagnosticsView();
      case 4:
        return const LogViewerView();
      case 5:
        return const SettingsView();
      default:
        return const DashboardView();
    }
  }

  @override
  void initState() {
    super.initState();
    _cachedPages[widget.selectedIndex] = _createPage(widget.selectedIndex);
    _transitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      value: 1.0,
    );
    final curved = CurvedAnimation(
      parent: _transitionCtrl,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(curved);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.014),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didUpdateWidget(covariant _SmoothTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idx = widget.selectedIndex;
    if (_cachedPages[idx] == null) {
      _cachedPages[idx] = _createPage(idx);
    }
    if (idx != oldWidget.selectedIndex) {
      _transitionCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _transitionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only the active tab is kept onstage; inactive tabs stay Offstage with
    // tickers and semantics excluded so views can never bleed/overlap while a
    // single GPU-composited entrance animation glides on tab switch.
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < _tabCount; i++)
              if (_cachedPages[i] != null)
                Offstage(
                  key: ValueKey<int>(i),
                  offstage: widget.selectedIndex != i,
                  child: TickerMode(
                    enabled: widget.selectedIndex == i,
                    child: ExcludeSemantics(
                      excluding: widget.selectedIndex != i,
                      child: RepaintBoundary(
                        child: _cachedPages[i]!,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
