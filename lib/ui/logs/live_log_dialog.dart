import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';

class LiveLogDialog extends StatefulWidget {
  final String title;
  final String? profileId;
  final bool isSignal;

  const LiveLogDialog({
    super.key,
    required this.title,
    this.profileId,
    this.isSignal = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? profileId,
    bool isSignal = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LiveLogDialog(
        title: title,
        profileId: profileId,
        isSignal: isSignal,
      ),
    );
  }

  @override
  State<LiveLogDialog> createState() => _LiveLogDialogState();
}

class _LiveLogDialogState extends State<LiveLogDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _autoScroll = true;
  int _lastLogCount = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!mounted || !_autoScroll || !_scrollCtrl.hasClients) return;
    try {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    List<String> logs;
    if (widget.isSignal || widget.profileId == '__signal__') {
      logs = state.supervisor.getSignalState().recentLogs;
    } else if (widget.profileId != null) {
      logs = state.getRuntimeState(widget.profileId!).recentLogs;
    } else {
      logs = [];
    }

    // Filter by search keyword
    final query = _searchCtrl.text.trim().toLowerCase();
    final displayLogs = query.isEmpty
        ? logs
        : logs.where((l) => l.toLowerCase().contains(query)).toList();

    if (displayLogs.length != _lastLogCount) {
      _lastLogCount = displayLogs.length;
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 650,
          minWidth: 600,
          minHeight: 450,
        ),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isSignal ? Icons.dns_rounded : Icons.terminal_rounded,
                    color: widget.isSignal ? Colors.purpleAccent : Colors.blueAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Search Input
                  SizedBox(
                    width: 180,
                    height: 36,
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '过滤关键字...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Pause / Resume Auto Scroll
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _autoScroll ? Colors.green : Colors.orangeAccent,
                      side: BorderSide(
                        color: _autoScroll ? Colors.green.withValues(alpha: 0.5) : Colors.orangeAccent,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => setState(() => _autoScroll = !_autoScroll),
                    icon: Icon(_autoScroll ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 16),
                    label: Text(
                      _autoScroll ? '暂停滚动' : '恢复滚动',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Copy Button
                  IconButton(
                    tooltip: '复制所有日志',
                    icon: const Icon(Icons.copy_all_rounded, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: logs.join('\n')));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制日志到剪贴板'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                  // Clear Button
                  IconButton(
                    tooltip: '清空显示',
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                    onPressed: () {
                      state.clearLogs(widget.profileId);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已清空当前日志'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  // Close Dialog Button
                  IconButton(
                    tooltip: '关闭',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Notice badge when auto scroll is paused
            if (!_autoScroll)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                color: Colors.orange.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    const Icon(Icons.pause_circle_filled_rounded, size: 14, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    const Text(
                      '已暂停自动滚动：新日志到达不会强制跳至底部，可自由查看与选中文本。',
                      style: TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() => _autoScroll = true),
                      child: const Text('恢复', style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Terminal Log Viewer
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFF1E1E1E),
                padding: const EdgeInsets.all(16),
                child: displayLogs.isEmpty
                    ? Center(
                        child: Text(
                          query.isNotEmpty ? '未匹配到包含 "$query" 的日志条目' : '暂无日志输出...',
                          style: const TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 13),
                        ),
                      )
                    : SelectionArea(
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          itemCount: displayLogs.length,
                          itemBuilder: (context, index) {
                            final line = displayLogs[index];
                            Color textColor = const Color(0xFFCCCCCC);
                            if (line.contains('[ERR]') || line.contains('Error') || line.contains('error')) {
                              textColor = const Color(0xFFF87171); // Red
                            } else if (line.contains('[WRN]') || line.contains('warning')) {
                              textColor = const Color(0xFFFBBF24); // Amber
                            } else if (line.contains('[INF]') || line.contains('listening') || line.contains('ready')) {
                              textColor = const Color(0xFF34D399); // Green
                            } else if (line.contains('[DBG]')) {
                              textColor = const Color(0xFF60A5FA); // Blue
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                line,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: textColor,
                                  height: 1.4,
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
      ),
    );
  }
}
