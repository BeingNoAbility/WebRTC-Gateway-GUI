import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/log_entry.dart';
import '../../providers/agent_provider.dart';
import '../../providers/signal_provider.dart';
import '../widgets/terminal_log_view.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _selectedSource = 'all'; // 'all', 'signal', or specific agent ID

  @override
  Widget build(BuildContext context) {
    final agentProvider = context.watch<AgentProvider>();
    final signalProvider = context.watch<SignalProvider>();

    List<LogEntry> logsToDisplay;
    if (_selectedSource == 'signal') {
      logsToDisplay = signalProvider.logs;
    } else if (_selectedSource == 'all') {
      logsToDisplay = [...agentProvider.allAgentLogs, ...signalProvider.logs]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } else {
      // Find specific agent instance
      final agent = agentProvider.agents.firstWhere(
        (a) => a.id == _selectedSource,
        orElse: () => agentProvider.focusedAgent,
      );
      logsToDisplay = agent.logs;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('日志源筛选: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedSource,
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('全部集群与信令日志 (${agentProvider.allAgentLogs.length + signalProvider.logs.length})', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'signal',
                      child: Text('Signal 信令服务端日志 (${signalProvider.logs.length})', overflow: TextOverflow.ellipsis),
                    ),
                    ...agentProvider.agents.map((agent) {
                      return DropdownMenuItem(
                        value: agent.id,
                        child: Text('Agent: ${agent.name} (#${agent.config.nodeId}) [${agent.logs.length}]', overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSource = val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TerminalLogView(
              logs: logsToDisplay,
              onClear: () {
                if (_selectedSource == 'signal') {
                  signalProvider.clearLogs();
                } else if (_selectedSource == 'all') {
                  agentProvider.clearLogs();
                  signalProvider.clearLogs();
                } else {
                  final agent = agentProvider.agents.firstWhere((a) => a.id == _selectedSource);
                  agent.clearLogs();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
