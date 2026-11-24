import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../state/app_state.dart';

class LogViewerView extends StatefulWidget {
  const LogViewerView({super.key});

  @override
  State<LogViewerView> createState() => _LogViewerViewState();
}

class _LogViewerViewState extends State<LogViewerView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();

    // Determine which logs to display
    final selectedId = state.selectedLogProfileId;
    List<String> logs = [];

    if (selectedId == null) {
      // Aggregate all running profiles logs
      for (final p in state.profiles) {
        final runtime = state.getRuntimeState(p.id);
        logs.addAll(runtime.recentLogs.map((l) => '[${p.nodeId}] $l'));
      }
      final signal = state.supervisor.getSignalState();
      logs.addAll(signal.recentLogs.map((l) => '[SIGNAL] $l'));
    } else if (selectedId == '__signal__') {
      final signal = state.supervisor.getSignalState();
      logs = signal.recentLogs;
    } else {
      final runtime = state.getRuntimeState(selectedId);
      logs = runtime.recentLogs;
    }

    // Filter by search query
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      logs = logs.where((l) => l.toLowerCase().contains(query)).toList();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Toolbar
          Row(
            children: [
              Text(
                i18n.t('nav_logs'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 20),
              // Dropdown
              DropdownButton<String?>(
                value: state.selectedLogProfileId,
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部节点日志 (All)')),
                  const DropdownMenuItem(value: '__signal__', child: Text('本地信令服务 (Signal)')),
                  ...state.profiles.map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (${p.nodeId})'),
                    ),
                  ),
                ],
                onChanged: (val) => state.setSelectedLogProfileId(val),
              ),
              const Spacer(),
              // Search field
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '过滤关键字...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: _autoScroll ? '暂停滚动' : '开启自动滚动',
                icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause),
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
              IconButton(
                tooltip: '复制所有日志',
                icon: const Icon(Icons.copy_all_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: logs.join('\n')));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制全部日志到剪贴板')),
                  );
                },
              ),
              IconButton(
                tooltip: '清空显示',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () {
                  state.clearLogs(selectedId);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已清空日志输出'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Terminal Console Window
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Dark slate blue matching logo background
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
              ),
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无日志输出，启动节点后将在此处实时打印 stdout / stderr',
                        style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                      ),
                    )
                  : SelectionArea(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final line = logs[index];
                          Color textColor = const Color(0xFFE2E8F0);
                          if (line.contains('ERROR') || line.contains('panic') || line.contains('failed')) {
                            textColor = const Color(0xFFF87171); // Red
                          } else if (line.contains('WARN')) {
                            textColor = const Color(0xFFFBBF24); // Yellow
                          } else if (line.contains('P2P') || line.contains('connected') || line.contains('registered')) {
                            textColor = const Color(0xFF38BDF8); // Cyber Cyan
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontFamily: 'Consolas, monospace',
                                fontSize: 12.5,
                                color: textColor,
                                height: 1.3,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
