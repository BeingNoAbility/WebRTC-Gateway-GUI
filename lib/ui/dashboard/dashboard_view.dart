import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../state/app_state.dart';
import 'stream_inspector_view.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final colorScheme = Theme.of(context).colorScheme;

    var totalUpSpeed = 0.0;
    var totalDownSpeed = 0.0;
    var totalStreams = 0;

    final runningPublicNodes = state.profiles
        .where((p) => state.isRunning(p.id) && p.accessSecret.isEmpty)
        .toList();

    for (final p in state.profiles) {
      final history = state.metricsService.getHistory(p.id);
      if (history.isNotEmpty) {
        final latest = history.last;
        totalUpSpeed += latest.uploadBytesPerSec;
        totalDownSpeed += latest.downloadBytesPerSec;
        totalStreams += latest.activeStreams;
      }
    }

    final isSignalRunning = state.isSignalRunning();
    final signalRuntime = state.signalState;
    final sigMetrics = state.metricsService.latestSignalMetrics;
    final signalExposedUnprotected = isSignalRunning &&
        (state.signalConfig.signalSecret.isEmpty ||
            state.signalConfig.allowedOrigins.trim() == '*');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                i18n.t('dashboard_title'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Chip(
                avatar: Icon(
                  state.runningCount > 0 || isSignalRunning
                      ? Icons.check_circle
                      : Icons.pause_circle_outline,
                  color: state.runningCount > 0 || isSignalRunning
                      ? Colors.green
                      : colorScheme.onSurfaceVariant,
                  size: 16,
                ),
                label: Text(
                  state.runningCount > 0 || isSignalRunning
                      ? i18n.t('dashboard_status_active')
                      : i18n.t('dashboard_status_idle'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),

          // Prominent Runtime Security Alerts
          if (runningPublicNodes.isNotEmpty || signalExposedUnprotected) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.shade700.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade800,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.pick(
                            '安全提示：检测到无密码保护的运行服务',
                            'Security Notice: Unprotected Services Running',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (runningPublicNodes.isNotEmpty)
                          Text(
                            i18n.pick(
                              '• ${runningPublicNodes.length} 个穿透节点当前处于“公开免密”模式 (${runningPublicNodes.map((e) => e.nodeId).join(", ")})，任何获取链接的人都可直接访问目标资源。',
                              '• ${runningPublicNodes.length} agent(s) running in public no-password mode (${runningPublicNodes.map((e) => e.nodeId).join(", ")}).',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (signalExposedUnprotected)
                          Text(
                            i18n.pick(
                              '• 本地信令服务未设置集群准入密钥或允许所有来源 (*)，仅建议在受信任局域网调试使用。',
                              '• Local signal server has no cluster secret or allows all origins (*). Use only in trusted LANs.',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // SECTION 1: Agent Nodes
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                i18n.t('dashboard_agent_section'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${state.runningCount} / ${state.profiles.length} ${i18n.pick("在线", "Online")}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => state.setTabIndex(1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(i18n.t('dashboard_manage_nodes')),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _ResponsiveStatGrid(
            cards: [
              _StatCard(
                title: i18n.t('dashboard_total_up'),
                value: _formatSpeed(totalUpSpeed),
                icon: Icons.upload_rounded,
                color: Colors.cyan,
              ),
              _StatCard(
                title: i18n.t('dashboard_total_down'),
                value: _formatSpeed(totalDownSpeed),
                icon: Icons.download_rounded,
                color: Colors.indigo,
              ),
              _StatCard(
                title: i18n.t('dashboard_active_streams'),
                value: '$totalStreams ${i18n.pick("路", "streams")}',
                icon: Icons.alt_route_rounded,
                color: Colors.purpleAccent,
              ),
              _StatCard(
                title: i18n.t('dashboard_total_nodes'),
                value: '${state.runningCount} ${i18n.pick("在线", "online")}',
                icon: Icons.devices_rounded,
                color: Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Real-time Bandwidth Line Chart
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.show_chart_rounded,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            i18n.t('dashboard_throughput_title'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendIndicator(
                            color: Colors.cyan,
                            label: i18n.t('dashboard_up_legend'),
                          ),
                          const SizedBox(width: 16),
                          _LegendIndicator(
                            color: Colors.indigo,
                            label: i18n.t('dashboard_down_legend'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 190,
                    child: _ThroughputChart(state: state),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const StreamInspectorView(),
          const SizedBox(height: 32),

          // SECTION 2: Signal Server
          Row(
            children: [
              const Icon(
                Icons.dns_rounded,
                color: Colors.purpleAccent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                i18n.t('dashboard_signal_section'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isSignalRunning ? Colors.green : colorScheme.outline)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSignalRunning
                      ? '${i18n.t("agent_status_running")} (PID: ${signalRuntime.pid ?? "-"})'
                      : i18n.t('agent_status_stopped'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSignalRunning
                        ? Colors.green
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => state.setTabIndex(2),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(i18n.t('dashboard_signal_workspace')),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _ResponsiveStatGrid(
            cards: [
              _StatCard(
                title: i18n.pick('信令监听地址', 'Signal Listen Addr'),
                value: state.signalConfig.addr,
                icon: Icons.sensors_rounded,
                color: Colors.purpleAccent,
                subtitle: state.signalConfig.tlsAuto
                    ? i18n.pick('自签 ECDSA TLS', 'Self-signed ECDSA TLS')
                    : (state.signalConfig.tlsCert.isNotEmpty
                        ? i18n.pick('自定义 TLS 证书', 'Custom TLS Cert')
                        : i18n.pick('明文 HTTP (仅限本机)', 'Plain HTTP (Localhost)')),
              ),
              _StatCard(
                title: i18n.pick('集群注册节点数', 'Registered Agents'),
                value: isSignalRunning
                    ? '${sigMetrics?.registeredNodes ?? 0}'
                    : '--',
                icon: Icons.hub_outlined,
                color: Colors.deepPurple,
                subtitle: i18n.pick('已在线握手注册的节点', 'Online registered nodes'),
              ),
              _StatCard(
                title: i18n.pick('活跃访客客户端', 'Active Visitors'),
                value: isSignalRunning
                    ? '${sigMetrics?.activeClients ?? 0}'
                    : '--',
                icon: Icons.person_pin_circle_rounded,
                color: Colors.teal,
                subtitle: i18n.pick('正在连接中的访客浏览器', 'Connected browser clients'),
              ),
              _StatCard(
                title: i18n.pick('累计信令消息量', 'Signaling Messages'),
                value: isSignalRunning
                    ? '${sigMetrics?.signalingMessagesTotal ?? 0}'
                    : '--',
                icon: Icons.swap_vert_circle_rounded,
                color: Colors.blueGrey,
                subtitle:
                    '${i18n.pick("限流拦截", "Rate-limited")}: ${sigMetrics?.ratelimitRejectedTotal ?? 0}',
              ),
            ],
          ),
          const SizedBox(height: 16),

          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Icon(
                    isSignalRunning
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSignalRunning
                        ? Colors.green
                        : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSignalRunning
                              ? '${i18n.pick("信令服务正常就绪，Web 访问入口:", "Signal server ready at:")} ${state.signalConfig.portalWebUrl}'
                              : i18n.pick(
                                  '本地信令服务当前处于停止状态，点击右侧开关可即时拉起',
                                  'Local signal server is stopped. Toggle to start.',
                                ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (signalRuntime.lastError != null &&
                            !isSignalRunning) ...[
                          const SizedBox(height: 2),
                          Text(
                            signalRuntime.lastError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: isSignalRunning,
                    activeThumbColor: Colors.purpleAccent,
                    onChanged: (val) {
                      if (val) {
                        state.startSignalServer();
                      } else {
                        state.stopSignalServer();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveStatGrid extends StatelessWidget {
  final List<Widget> cards;

  const _ResponsiveStatGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        if (!isNarrow) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 16),
              ],
            ],
          );
        }
        final itemWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map((c) => SizedBox(width: itemWidth, child: c))
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 10, color: muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: muted)),
      ],
    );
  }
}

class _ThroughputChart extends StatelessWidget {
  final AppState state;

  const _ThroughputChart({required this.state});

  double _niceStep(double maxVal) {
    if (maxVal <= 10) return 5;
    final raw = maxVal / 4.0;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final nice = norm < 1.5
        ? 1.0
        : (norm < 3.5 ? 2.0 : (norm < 7.5 ? 5.0 : 10.0));
    return math.max(1.0, nice * mag);
  }

  String _formatAxis(double kbPerSec) {
    if (kbPerSec >= 1024) {
      final mb = kbPerSec / 1024.0;
      return mb >= 10 ? '${mb.toInt()}M' : '${mb.toStringAsFixed(1)}M';
    }
    return '${kbPerSec.toInt()}K';
  }

  @override
  Widget build(BuildContext context) {
    final series = state.metricsService.getAggregatedTimeSeries(
      state.profiles.map((p) => p.id),
    );

    final upSpots = <FlSpot>[];
    final downSpots = <FlSpot>[];
    var peakKb = 0.0;

    if (series.isEmpty) {
      for (var i = 0; i < 20; i++) {
        upSpots.add(FlSpot(i.toDouble(), 0));
        downSpots.add(FlSpot(i.toDouble(), 0));
      }
      peakKb = 100;
    } else {
      for (var i = 0; i < series.length; i++) {
        final upKb = series[i].uploadBytesPerSec / 1024.0;
        final downKb = series[i].downloadBytesPerSec / 1024.0;
        if (upKb > peakKb) peakKb = upKb;
        if (downKb > peakKb) peakKb = downKb;
        upSpots.add(FlSpot(i.toDouble(), upKb));
        downSpots.add(FlSpot(i.toDouble(), downKb));
      }
    }

    final safePeak = math.max(50.0, peakKb * 1.15);
    final interval = _niceStep(safePeak);
    final maxY = (safePeak / interval).ceilToDouble() * interval;
    final gridColor = Theme.of(context).colorScheme.outlineVariant;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (v) => FlLine(
            color: gridColor.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: interval,
              getTitlesWidget: (val, meta) => Text(
                _formatAxis(val),
                style: TextStyle(fontSize: 10, color: labelColor),
              ),
            ),
          ),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: upSpots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: Colors.cyan,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.cyan.withValues(alpha: 0.12),
            ),
          ),
          LineChartBarData(
            spots: downSpots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: Colors.indigo,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.indigo.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
