import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../models/agent_profile.dart';
import '../../models/metrics_data.dart';
import '../../state/app_state.dart';

class StreamInspectorView extends StatelessWidget {
  const StreamInspectorView({super.key});

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
  }

  void _resetAgentStreams(BuildContext context, AppState state, AgentProfile profile) async {
    await state.stopAgent(profile.id);
    await Future.delayed(const Duration(milliseconds: 300));
    await state.startAgent(profile);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已向节点 "${profile.name}" 发送复位指令，已重置所有 P2PMux 数据流通道'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();

    final runningProfiles = state.profiles.where((p) => state.isRunning(p.id)).toList();

    int totalActiveStreams = 0;
    for (final p in runningProfiles) {
      final history = state.metricsService.getHistory(p.id);
      if (history.isNotEmpty) {
        totalActiveStreams += history.last.activeStreams;
      }
    }

    return Card(
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on_rounded, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Text(
                      i18n.t('stream_inspector_title'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$totalActiveStreams 条实时活跃流',
                        style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Text('实时监控各节点 P2PMux 多路复用数据通道与网络状态', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            if (runningProfiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.waves_rounded, size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text(
                        '暂无在线节点，请在 "穿透节点" 页面启动节点以开始传输监控',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: runningProfiles.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final p = runningProfiles[i];
                  final history = state.metricsService.getHistory(p.id);
                  final MetricsSnapshot? latest = history.isNotEmpty ? history.last : null;
                  final streams = latest?.activeStreams ?? 0;
                  final peers = latest?.totalConnections ?? 0;
                  final upSpeed = latest?.uploadBytesPerSec ?? 0.0;
                  final downSpeed = latest?.downloadBytesPerSec ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.nodeId,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.mode.name.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '上游目标: ${p.mode == TunnelMode.target ? p.target : (p.mode == TunnelMode.dir ? p.dirPath : p.filePath)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '↑ ${_formatSpeed(upSpeed)}  ↓ ${_formatSpeed(downSpeed)}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$peers PeerConnection | 聚合上限: ${p.maxTrunks} 路',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            streams > 0 ? '$streams 活跃流' : '待机就绪',
                            style: TextStyle(
                              fontSize: 11,
                              color: streams > 0 ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: (streams > 0 ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orangeAccent,
                            side: const BorderSide(color: Colors.orangeAccent),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _resetAgentStreams(context, state, p),
                          icon: const Icon(Icons.restart_alt_rounded, size: 14),
                          label: const Text('重置通道', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
