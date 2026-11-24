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

    // Aggregate statistics for agents
    double totalUpSpeed = 0;
    double totalDownSpeed = 0;
    int totalStreams = 0;

    for (final p in state.profiles) {
      final history = state.metricsService.getHistory(p.id);
      if (history.isNotEmpty) {
        final latest = history.last;
        totalUpSpeed += latest.uploadBytesPerSec;
        totalDownSpeed += latest.downloadBytesPerSec;
        totalStreams += latest.activeStreams;
      }
    }

    // Signal server metrics
    final isSignalRunning = state.isSignalRunning();
    final signalRuntime = state.signalState;
    final sigMetrics = state.metricsService.latestSignalMetrics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                i18n.t('dashboard_title'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Chip(
                avatar: Icon(
                  state.runningCount > 0 || isSignalRunning ? Icons.check_circle : Icons.pause_circle_outline,
                  color: state.runningCount > 0 || isSignalRunning ? Colors.green : Colors.grey,
                  size: 16,
                ),
                label: Text(
                  state.runningCount > 0 || isSignalRunning ? '服务活跃运行中' : '系统空闲待机中',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ==========================================
          // SECTION 1: 穿透节点状态看板 (Agent Section)
          // ==========================================
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 8),
              const Text(
                '穿透节点运行看板 (Agent Nodes)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${state.runningCount} / ${state.profiles.length} 在线',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => state.setTabIndex(1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('管理节点'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Agent Stat Cards Grid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: i18n.t('dashboard_total_up'),
                  value: _formatSpeed(totalUpSpeed),
                  icon: Icons.upload_rounded,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: i18n.t('dashboard_total_down'),
                  value: _formatSpeed(totalDownSpeed),
                  icon: Icons.download_rounded,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: i18n.t('dashboard_active_streams'),
                  value: '$totalStreams 路',
                  icon: Icons.alt_route_rounded,
                  color: Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: i18n.t('dashboard_total_nodes'),
                  value: '${state.runningCount} 在线',
                  icon: Icons.devices_rounded,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Real-time Bandwidth Line Chart
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.show_chart_rounded, color: Colors.blueAccent),
                          SizedBox(width: 8),
                          Text(
                            '实时聚合吞吐速率 (Real-time Throughput)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendIndicator(color: Colors.cyan, label: '上传 (Up)'),
                          const SizedBox(width: 16),
                          _LegendIndicator(color: Colors.indigo, label: '下载 (Down)'),
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

          // Active Stream Inspector HUD
          const StreamInspectorView(),
          const SizedBox(height: 32),

          // ==========================================
          // SECTION 2: 信令服务看板 (Signal Section)
          // ==========================================
          Row(
            children: [
              const Icon(Icons.dns_rounded, color: Colors.purpleAccent, size: 22),
              const SizedBox(width: 8),
              const Text(
                '信令与控制台看板 (Signal Server)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSignalRunning ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSignalRunning ? '运行中 (PID: ${signalRuntime.pid ?? '活跃'})' : '已停止',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSignalRunning ? Colors.green : Colors.grey,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => state.setTabIndex(2),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('信令工作台'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Signal Stat Cards Grid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '信令监听地址',
                  value: state.signalConfig.addr,
                  icon: Icons.sensors_rounded,
                  color: Colors.purpleAccent,
                  subtitle: state.signalConfig.tlsAuto ? '自签 ECDSA TLS' : '明文 / 自定义证书',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: '集群注册 Agent 数',
                  value: isSignalRunning ? '${sigMetrics?.registeredNodes ?? 0} 个' : '--',
                  icon: Icons.hub_outlined,
                  color: Colors.deepPurple,
                  subtitle: '已在线握手注册的节点',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: '活跃访客客户端',
                  value: isSignalRunning ? '${sigMetrics?.activeClients ?? 0} 个' : '--',
                  icon: Icons.person_pin_circle_rounded,
                  color: Colors.teal,
                  subtitle: '正在通过浏览器直连访问',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: '累计信令消息量',
                  value: isSignalRunning ? '${sigMetrics?.signalingMessagesTotal ?? 0}' : '--',
                  icon: Icons.swap_vert_circle_rounded,
                  color: Colors.blueGrey,
                  subtitle: '限流拦截: ${sigMetrics?.ratelimitRejectedTotal ?? 0}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Signal Quick Control Bar
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                children: [
                  Icon(
                    isSignalRunning ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSignalRunning ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSignalRunning
                              ? '信令服务正常就绪，Web 访问入口: ${state.signalConfig.portalWebUrl}'
                              : '本地信令服务当前处于停止状态，点击右侧开关可即时拉起',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if (signalRuntime.lastError != null && !isSignalRunning) ...[
                          const SizedBox(height: 2),
                          Text(
                            signalRuntime.lastError!,
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
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
                    style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _ThroughputChart extends StatelessWidget {
  final AppState state;

  const _ThroughputChart({required this.state});

  @override
  Widget build(BuildContext context) {
    final upSpots = <FlSpot>[];
    final downSpots = <FlSpot>[];

    // Compute aggregate speed history across all running agents
    int maxLength = 0;
    for (final p in state.profiles) {
      final h = state.metricsService.getHistory(p.id);
      if (h.length > maxLength) maxLength = h.length;
    }

    if (maxLength == 0) {
      // Empty baseline
      for (int i = 0; i < 20; i++) {
        upSpots.add(FlSpot(i.toDouble(), 0));
        downSpots.add(FlSpot(i.toDouble(), 0));
      }
    } else {
      for (int i = 0; i < maxLength; i++) {
        double aggUp = 0;
        double aggDown = 0;
        for (final p in state.profiles) {
          final h = state.metricsService.getHistory(p.id);
          if (i < h.length) {
            aggUp += h[i].uploadBytesPerSec;
            aggDown += h[i].downloadBytesPerSec;
          }
        }
        // Convert to KB/s for display scaling
        upSpots.add(FlSpot(i.toDouble(), aggUp / 1024.0));
        downSpots.add(FlSpot(i.toDouble(), aggDown / 1024.0));
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 50,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.grey.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (val, meta) => Text(
                '${val.toInt()}K',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: upSpots,
            isCurved: true,
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
