import 'dart:async';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
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

  static void show(
    BuildContext context, {
    required String title,
    String? profileId,
    bool isSignal = false,
  }) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) => LiveLogDialog(
          title: title,
          profileId: profileId,
          isSignal: isSignal,
        ),
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
  int _lastLogVersion = -1;
  String _lastQuery = '';

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
    final state = context.read<AppState>();
    final i18n = AppI18n();

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
        child: AnimatedBuilder(
          animation: state.logNotifier,
          builder: (context, _) {
            final runtime = (widget.isSignal || widget.profileId == '__signal__')
                ? state.supervisor.getSignalState()
                : (widget.profileId != null
                    ? state.getRuntimeState(widget.profileId!)
                    : null);
            final logs = runtime?.recentLogs ?? const <String>[];
            final logVersion = runtime?.logVersion ?? 0;

            final query = _searchCtrl.text.trim().toLowerCase();
            final displayLogs = query.isEmpty
                ? logs
                : logs.where((l) => l.toLowerCase().contains(query)).toList();

            if (logVersion != _lastLogVersion || query != _lastQuery) {
              _lastLogVersion = logVersion;
              _lastQuery = query;
              if (_autoScroll) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
              }
            }

            return Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isSignal
                            ? Icons.dns_rounded
                            : Icons.terminal_rounded,
                        color: widget.isSignal
                            ? Colors.purpleAccent
                            : Colors.blueAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        height: 36,
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: i18n.t('logs_filter_hint'),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            prefixIcon: const Icon(Icons.search, size: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              _autoScroll ? Colors.green : Colors.orangeAccent,
                          side: BorderSide(
                            color: _autoScroll
                                ? Colors.green.withValues(alpha: 0.5)
                                : Colors.orangeAccent,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        onPressed: () =>
                            setState(() => _autoScroll = !_autoScroll),
                        icon: Icon(
                          _autoScroll
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                          size: 16,
                        ),
                        label: Text(
                          _autoScroll
                              ? i18n.t('logs_pause_scroll')
                              : i18n.t('logs_resume_scroll'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: query.isEmpty
                            ? i18n.pick('复制全部日志', 'Copy All Logs')
                            : i18n.pick('复制筛选后日志', 'Copy Filtered Logs'),
                        icon: const Icon(Icons.copy_all_rounded, size: 20),
                        onPressed: () {
                          unawaited(
                            Clipboard.setData(
                              ClipboardData(text: displayLogs.join('\n')),
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                i18n.pick(
                                  '已复制 ${displayLogs.length} 条日志到剪贴板',
                                  'Copied ${displayLogs.length} log line(s)',
                                ),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: i18n.pick('清空显示', 'Clear Logs'),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                        onPressed: () {
                          state.clearLogs(widget.profileId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(i18n.pick('已清空当前日志', 'Logs cleared')),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: i18n.t('common_close'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                if (!_autoScroll)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    color: Colors.orange.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pause_circle_filled_rounded,
                          size: 14,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          i18n.pick(
                            '已暂停自动滚动：新日志到达不会强制跳至底部，可自由翻阅或点击单行日志复制。',
                            'Auto-scroll paused. Scroll freely or click any log line to copy.',
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _autoScroll = true),
                          child: Text(
                            i18n.pick('恢复', 'Resume'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF1E1E1E),
                    padding: const EdgeInsets.all(16),
                    child: displayLogs.isEmpty
                        ? Center(
                            child: Text(
                              query.isNotEmpty
                                  ? i18n.pick(
                                      '未匹配到包含 "$query" 的日志条目',
                                      'No log entries match "$query"',
                                    )
                                  : i18n.pick('暂无日志输出...', 'No logs yet...'),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontFamily: 'Consolas',
                                fontFamilyFallback: ['Courier New', 'monospace'],
                                fontSize: 13,
                              ),
                            ),
                          )
                        : RepaintBoundary(
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              itemCount: displayLogs.length,
                              itemBuilder: (context, index) {
                                final line = displayLogs[index];
                                var textColor = const Color(0xFFCCCCCC);
                                if (line.contains('[ERR]') ||
                                    line.contains('ERROR') ||
                                    line.contains('Error') ||
                                    line.contains('error')) {
                                  textColor = const Color(0xFFF87171);
                                } else if (line.contains('[WRN]') ||
                                    line.contains('WARN') ||
                                    line.contains('warning')) {
                                  textColor = const Color(0xFFFBBF24);
                                } else if (line.contains('[INF]') ||
                                    line.contains('listening') ||
                                    line.contains('ready')) {
                                  textColor = const Color(0xFF34D399);
                                } else if (line.contains('[DBG]')) {
                                  textColor = const Color(0xFF60A5FA);
                                }

                                return InkWell(
                                  onTap: () {
                                    unawaited(
                                      Clipboard.setData(
                                        ClipboardData(text: line),
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          i18n.pick('已复制该行日志', 'Copied log line'),
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2.0,
                                    ),
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        fontFamily: 'Consolas',
                                        fontFamilyFallback: const [
                                          'Cascadia Mono',
                                          'Courier New',
                                          'monospace',
                                        ],
                                        fontSize: 12,
                                        color: textColor,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
