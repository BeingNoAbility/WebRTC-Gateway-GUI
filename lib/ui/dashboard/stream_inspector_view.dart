import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../models/metrics_data.dart';
import '../../state/app_state.dart';

class StreamInspectorView extends StatefulWidget {
  const StreamInspectorView({super.key});

  @override
  State<StreamInspectorView> createState() => _StreamInspectorViewState();
}

class _StreamInspectorViewState extends State<StreamInspectorView> {
  // Simulated / Polled active streams list
  final List<ActiveStreamInfo> _mockStreams = [
    ActiveStreamInfo(
      id: 102,
      path: '/api/v1/stream',
      method: 'GET',
      status: 'STREAMING',
      bytesTransferred: 4194304,
      duration: const Duration(seconds: 42),
    ),
    ActiveStreamInfo(
      id: 104,
      path: '/assets/app.bundle.js',
      method: 'GET',
      status: 'IDLE',
      bytesTransferred: 1048576,
      duration: const Duration(seconds: 12),
    ),
  ];

  void _resetStream(int id) {
    setState(() {
      _mockStreams.removeWhere((s) => s.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已发送 RST_STREAM 强杀数据流 #$id (Stream Terminated)'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();

    final isAnyRunning = state.runningCount > 0;
    final streams = isAnyRunning ? _mockStreams : <ActiveStreamInfo>[];

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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${streams.length} 条活跃流',
                        style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Text('支持对卡死的大文件或 API 流进行交互式重置', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            if (streams.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.waves_rounded, size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        isAnyRunning ? i18n.t('stream_no_active') : '请先启动任意穿透节点',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: streams.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final s = streams[i];
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
                          child: Text('#${s.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(s.method, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.path,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(s.bytesTransferred / 1024).toStringAsFixed(0)} KB',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(width: 16),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(s.status, style: const TextStyle(fontSize: 10, color: Colors.green)),
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _resetStream(s.id),
                          icon: const Icon(Icons.close_rounded, size: 14),
                          label: Text(i18n.t('stream_reset_btn'), style: const TextStyle(fontSize: 11)),
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
