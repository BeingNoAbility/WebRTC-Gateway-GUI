import 'dart:async';
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

  Future<void> _confirmAndRestartAgent(
    BuildContext context,
    AppState state,
    AgentProfile profile,
  ) async {
    final i18n = AppI18n();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.pick('确认重启节点通道', 'Restart Agent Process')),
        content: Text(
          i18n.pick(
            '重启节点 "${profile.name}" 将重置其全部 WebRTC PeerConnection 与复用通道，当前正在访问的访客会短暂断开并重连。\n\n（如需仅强杀单个卡死请求，可在访客浏览器右下角 HUD 悬浮球内操作。）',
            'Restarting "${profile.name}" resets all PeerConnections and mux streams for this node. Connected visitors will briefly reconnect.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(i18n.t('common_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(i18n.t('stream_reset_btn')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await state.stopAgent(profile.id);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await state.startAgent(profile);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.pick(
              '已重启节点 "${profile.name}"，正在重新建立信令与通道',
              'Restarted "${profile.name}" and re-registering signaling session.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final runningProfiles =
        state.profiles.where((p) => state.isRunning(p.id)).toList();

    var totalActiveStreams = 0;
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
                    const Icon(
                      Icons.flash_on_rounded,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      i18n.t('stream_inspector_title'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$totalActiveStreams ${i18n.pick("条活跃逻辑流", "active streams")}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  i18n.pick(
                    '节点级 Prometheus 聚合指标（单流级 RST 控制在浏览器端 HUD 悬浮球内提供）',
                    'Node-level Prometheus telemetry (per-stream RST is available in Web Portal HUD)',
                  ),
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (runningProfiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.waves_rounded, size: 40, color: muted),
                      const SizedBox(height: 8),
                      Text(
                        i18n.t('stream_no_active'),
                        style: TextStyle(color: muted, fontSize: 13),
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
                  final MetricsSnapshot? latest =
                      history.isNotEmpty ? history.last : null;
                  final streams = latest?.activeStreams ?? 0;
                  final peers = latest?.totalConnections ?? 0;
                  final rejections = latest?.streamRejectionsTotal ?? 0;
                  final upSpeed = latest?.uploadBytesPerSec ?? 0.0;
                  final downSpeed = latest?.downloadBytesPerSec ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.nodeId,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.mode.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${i18n.pick("目标", "Target")}: ${p.mode == TunnelMode.target ? p.target : (p.mode == TunnelMode.dir ? p.dirPath : p.filePath)}',
                                style: TextStyle(fontSize: 11, color: muted),
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
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontFamilyFallback: ['Courier New', 'monospace'],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$peers PeerConnection | ${i18n.pick("聚合上限", "Trunks")}: ${p.maxTrunks}'
                              '${rejections > 0 ? " | ${i18n.pick("背压拒绝", "Rejected")}: $rejections" : ""}',
                              style: TextStyle(
                                fontSize: 11,
                                color: rejections > 0 ? Colors.redAccent : muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            streams > 0
                                ? '$streams ${i18n.pick("活跃流", "streams")}'
                                : i18n.pick('待机就绪', 'Idle'),
                            style: TextStyle(
                              fontSize: 11,
                              color: streams > 0 ? Colors.green : muted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor:
                              (streams > 0 ? Colors.green : muted)
                                  .withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orangeAccent,
                            side: const BorderSide(color: Colors.orangeAccent),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              unawaited(_confirmAndRestartAgent(context, state, p)),
                          icon: const Icon(Icons.restart_alt_rounded, size: 14),
                          label: Text(
                            i18n.t('stream_reset_btn'),
                            style: const TextStyle(fontSize: 11),
                          ),
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
