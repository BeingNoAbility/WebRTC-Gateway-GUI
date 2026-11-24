import 'dart:async';
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

  int _lastCompositeSignature = -1;
  String? _lastSelectedId;
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
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final selectedId = state.selectedLogProfileId;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          i18n.t('nav_logs'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: selectedId,
                            underline: const SizedBox(),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(
                                  i18n.t('logs_all_nodes'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: '__signal__',
                                child: Text(
                                  i18n.t('logs_signal_node'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...state.profiles.map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    '${p.name} (${p.nodeId})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: state.setSelectedLogProfileId,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: i18n.t('logs_filter_hint'),
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: _autoScroll
                          ? i18n.t('logs_pause_scroll')
                          : i18n.t('logs_resume_scroll'),
                      icon: Icon(
                        _autoScroll
                            ? Icons.vertical_align_bottom
                            : Icons.pause,
                      ),
                      onPressed: () =>
                          setState(() => _autoScroll = !_autoScroll),
                    ),
                    IconButton(
                      tooltip: i18n.pick('复制当前显示日志', 'Copy Displayed Logs'),
                      icon: const Icon(Icons.copy_all_rounded),
                      onPressed: () {
                        final logs = _collectFilteredLogs(state, selectedId);
                        unawaited(
                          Clipboard.setData(
                            ClipboardData(text: logs.join('\n')),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              i18n.pick(
                                '已复制 ${logs.length} 条日志到剪贴板',
                                'Copied ${logs.length} log line(s)',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: i18n.pick('清空显示', 'Clear Logs'),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      onPressed: () {
                        state.clearLogs(selectedId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(i18n.pick('已清空日志输出', 'Logs cleared')),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: AnimatedBuilder(
              animation: state.logNotifier,
              builder: (context, _) {
                final logs = _collectFilteredLogs(state, selectedId);
                final signature = _computeLogSignature(state, selectedId);
                final query = _searchCtrl.text.trim().toLowerCase();

                if (signature != _lastCompositeSignature ||
                    selectedId != _lastSelectedId ||
                    query != _lastQuery) {
                  _lastCompositeSignature = signature;
                  _lastSelectedId = selectedId;
                  _lastQuery = query;
                  if (_autoScroll) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());
                  }
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: logs.isEmpty
                      ? Center(
                          child: Text(
                            i18n.t('logs_empty'),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontFamily: 'Consolas',
                              fontFamilyFallback: ['Courier New', 'monospace'],
                            ),
                          ),
                        )
                      : RepaintBoundary(
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final line = logs[index];
                              var textColor = const Color(0xFFE2E8F0);
                              if (line.contains('ERROR') ||
                                  line.contains('panic') ||
                                  line.contains('failed')) {
                                textColor = const Color(0xFFF87171);
                              } else if (line.contains('WARN')) {
                                textColor = const Color(0xFFFBBF24);
                              } else if (line.contains('P2P') ||
                                  line.contains('connected') ||
                                  line.contains('registered')) {
                                textColor = const Color(0xFF38BDF8);
                              }

                              return InkWell(
                                onTap: () {
                                  unawaited(
                                    Clipboard.setData(ClipboardData(text: line)),
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontFamily: 'Consolas',
                                      fontFamilyFallback: const [
                                        'Cascadia Mono',
                                        'Courier New',
                                        'monospace',
                                      ],
                                      fontSize: 12.5,
                                      color: textColor,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _computeLogSignature(AppState state, String? selectedId) {
    if (selectedId == null) {
      var sum = state.supervisor.getSignalState().logVersion;
      for (final p in state.profiles) {
        sum = sum * 31 + state.getRuntimeState(p.id).logVersion;
      }
      return sum;
    } else if (selectedId == '__signal__') {
      return state.supervisor.getSignalState().logVersion;
    } else {
      return state.getRuntimeState(selectedId).logVersion;
    }
  }

  List<String> _collectFilteredLogs(AppState state, String? selectedId) {
    final logs = <String>[];
    if (selectedId == null) {
      for (final p in state.profiles) {
        final runtime = state.getRuntimeState(p.id);
        logs.addAll(runtime.recentLogs.map((l) => '[${p.nodeId}] $l'));
      }
      final signal = state.supervisor.getSignalState();
      logs.addAll(signal.recentLogs.map((l) => '[SIGNAL] $l'));
    } else if (selectedId == '__signal__') {
      logs.addAll(state.supervisor.getSignalState().recentLogs);
    } else {
      logs.addAll(state.getRuntimeState(selectedId).recentLogs);
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return logs;
    return logs.where((l) => l.toLowerCase().contains(query)).toList();
  }
}
