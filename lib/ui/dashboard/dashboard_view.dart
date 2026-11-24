import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../models/metrics_data.dart';
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

    // Aggregate statistics
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Text(
                i18n.t('dashboard_title'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Chip(
                avatar: Icon(
                  state.runningCount > 0 ? Icons.check_circle : Icons.pause_circle_outline,
                  color: state.runningCount > 0 ? Colors.green : Colors.grey,
                  size: 16,
                ),
                label: Text(
                  state.runningCount > 0 ? 'P2P 服务活跃中' : '服务待机中',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stat Cards Grid
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
                  value: '${state.runningCount} / ${state.profiles.length}',
                  icon: Icons.devices_rounded,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 220,
                    child: _BandwidthChart(profiles: state.profiles, metrics: state.metricsService),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // HUD 2.0 Stream Inspector Section
          const StreamInspectorView(),
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

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
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

class _BandwidthChart extends StatelessWidget {
  final List<dynamic> profiles;
  final dynamic metrics;

  const _BandwidthChart({required this.profiles, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final upSpots = <FlSpot>[];
    final downSpots = <FlSpot>[];

    // Build timeline points from the first running profile history
    final history = profiles.isNotEmpty ? metrics.getHistory(profiles.first.id) as List<MetricsSnapshot> : <MetricsSnapshot>[];

    if (history.isEmpty) {
      for (int i = 0; i < 20; i++) {
        upSpots.add(FlSpot(i.toDouble(), 0));
        downSpots.add(FlSpot(i.toDouble(), 0));
      }
    } else {
      for (int i = 0; i < history.length; i++) {
        final snap = history[i];
        upSpots.add(FlSpot(i.toDouble(), (snap.uploadBytesPerSec / 1024.0)));
        downSpots.add(FlSpot(i.toDouble(), (snap.downloadBytesPerSec / 1024.0)));
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(color: Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, meta) {
                return Text('${val.toInt()} KB', style: const TextStyle(fontSize: 10, color: Colors.grey));
              },
            ),
          ),
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
