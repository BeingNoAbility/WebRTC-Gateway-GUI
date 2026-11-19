import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/log_entry.dart';

class TerminalLogView extends StatefulWidget {
  final List<LogEntry> logs;
  final VoidCallback? onClear;

  const TerminalLogView({
    super.key,
    required this.logs,
    this.onClear,
  });

  @override
  State<TerminalLogView> createState() => _TerminalLogViewState();
}

class _TerminalLogViewState extends State<TerminalLogView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  LogLevel? _selectedLevel;
  String _searchQuery = '';

  @override
  void didUpdateWidget(TerminalLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return AppColors.terminalInfo;
      case LogLevel.warning:
        return AppColors.terminalWarning;
      case LogLevel.error:
        return AppColors.terminalError;
      case LogLevel.success:
        return AppColors.terminalSuccess;
      case LogLevel.debug:
        return AppColors.darkTextMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = widget.logs.where((log) {
      if (_selectedLevel != null && log.level != _selectedLevel) return false;
      if (_searchQuery.isNotEmpty &&
          !log.message.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.terminalBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkCardBorder),
      ),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 560;

                final trafficLights = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    const Text(
                      '实时终端控制台',
                      style: TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                );

                final searchBox = SizedBox(
                  width: isNarrow ? double.infinity : 130,
                  height: 28,
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: '搜索日志...',
                      hintStyle: const TextStyle(color: AppColors.darkTextMuted, fontSize: 11),
                      prefixIcon: const Icon(Icons.search, size: 14, color: AppColors.darkTextMuted),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                );

                final toolButtons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _autoScroll ? '已启用自动滚动' : '自动滚动已暂停',
                      icon: Icon(
                        _autoScroll ? Icons.arrow_circle_down_rounded : Icons.pause_circle_outline_rounded,
                        size: 18,
                        color: _autoScroll ? AppColors.primaryCyan : AppColors.darkTextMuted,
                      ),
                      onPressed: () => setState(() => _autoScroll = !_autoScroll),
                    ),
                    IconButton(
                      tooltip: '复制所有日志',
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.darkTextSecondary),
                      onPressed: () {
                        final allText = widget.logs.map((l) => '[${l.formattedTime}] [${l.source.displayName}] ${l.message}').join('\n');
                        Clipboard.setData(ClipboardData(text: allText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制所有日志到剪贴板'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    if (widget.onClear != null)
                      IconButton(
                        tooltip: '清空日志',
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.darkTextSecondary),
                        onPressed: widget.onClear,
                      ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          trafficLights,
                          const Spacer(),
                          toolButtons,
                        ],
                      ),
                      const SizedBox(height: 6),
                      searchBox,
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      trafficLights,
                      const Spacer(),
                      searchBox,
                      const SizedBox(width: 8),
                      toolButtons,
                    ],
                  );
                }
              },
            ),
          ),

          // Log list
          Expanded(
            child: filteredLogs.isEmpty
                ? const Center(
                    child: Text(
                      '暂无运行日志...',
                      style: TextStyle(color: AppColors.darkTextMuted, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final item = filteredLogs[index];
                      final color = _getLevelColor(item.level);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: SelectableText.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${item.formattedTime} ',
                                style: const TextStyle(
                                  color: AppColors.terminalTimestamp,
                                  fontSize: 11,
                                  fontFamily: 'Consolas, monospace',
                                ),
                              ),
                              TextSpan(
                                text: '[${item.source.displayName}] ',
                                style: const TextStyle(
                                  color: Color(0xFF818CF8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Consolas, monospace',
                                ),
                              ),
                              TextSpan(
                                text: '${item.message}\n',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontFamily: 'Consolas, monospace',
                                  height: 1.3,
                                ),
                              ),
                            ],
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
}
