import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../models/agent_profile.dart';
import '../../models/runtime_state.dart';
import '../../state/app_state.dart';
import '../logs/live_log_dialog.dart';
import '../share/share_dialog.dart';
import 'agent_edit_dialog.dart';

class AgentListView extends StatelessWidget {
  const AgentListView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.t('agent_list_title'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已配置 ${state.profiles.length} 个节点，当前运行中: ${state.runningCount} 个',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['yaml', 'yml', 'json'],
                  );
                  if (result.isNotEmpty && result.first.path != null) {
                    final summary = await state.importConfigFile(result.first.path!);
                    if (context.mounted) {
                      final count = summary['agents'] as int? ?? 0;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已成功导入 $count 个源项目 Agent 穿透节点配置')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.file_open_rounded, size: 16),
                label: const Text('导入 agent.yaml'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.runningCount < state.profiles.length ? () => state.startAllAgents() : null,
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.green),
                label: Text(i18n.t('agent_start_all')),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.runningCount > 0 ? () => state.stopAllAgents() : null,
                icon: const Icon(Icons.stop_rounded, color: Colors.redAccent),
                label: Text(i18n.t('agent_stop_all')),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  AgentEditDialog.show(
                    context,
                    onSave: (newProfile) => state.addProfile(newProfile),
                  );
                },
                icon: const Icon(Icons.add),
                label: Text(i18n.t('agent_add_btn')),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cards List
          Expanded(
            child: state.profiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hub_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('暂无穿透节点，点击右上角“添加节点”开始', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            AgentEditDialog.show(
                              context,
                              onSave: (newProfile) => state.addProfile(newProfile),
                            );
                          },
                          child: Text(i18n.t('agent_add_btn')),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: state.profiles.length,
                    itemBuilder: (context, index) {
                      final profile = state.profiles[index];
                      return _AgentCard(profile: profile);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final AgentProfile profile;

  const _AgentCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final runtime = state.getRuntimeState(profile.id);
    final isRunning = runtime.status == ProcessStatus.running;
    final isStarting = runtime.status == ProcessStatus.starting;
    final isError = runtime.status == ProcessStatus.error;

    Color statusColor = Colors.grey;
    String statusText = '已停止';
    if (isRunning) {
      statusColor = Colors.green;
      statusText = '运行中';
    } else if (isStarting) {
      statusColor = Colors.orange;
      statusText = '启动中...';
    } else if (isError) {
      statusColor = Colors.red;
      statusText = '启动异常';
    }

    IconData modeIcon = Icons.http_rounded;
    String modeDesc = profile.target;
    if (profile.mode == TunnelMode.dir) {
      modeIcon = Icons.folder_outlined;
      modeDesc = profile.dirPath;
    } else if (profile.mode == TunnelMode.file) {
      modeIcon = Icons.insert_drive_file_outlined;
      modeDesc = profile.filePath;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRunning ? Colors.green.withValues(alpha: 0.4) : Colors.black12,
          width: isRunning ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Status Indicator Circle
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: isRunning
                    ? [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 16),

            // Profile info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          profile.nodeId,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(modeIcon, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          modeDesc,
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Runtime metadata
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('状态: $statusText', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  if (isRunning && runtime.metricsPort != null) ...[
                    Text(
                      '端口: :${runtime.metricsPort} | PID: ${runtime.pid ?? "-"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ] else if (isError && runtime.lastError != null) ...[
                    Text(
                      runtime.lastError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Quick Actions
            IconButton(
              tooltip: '快速分享',
              icon: const Icon(Icons.qr_code_2_rounded, color: Colors.blueAccent),
              onPressed: () => ShareDialog.show(context, profile),
            ),
            IconButton(
              tooltip: '导出源项目 agent.yaml',
              icon: const Icon(Icons.save_alt_rounded, color: Colors.teal),
              onPressed: () async {
                final yamlStr = profile.toYamlString();
                final bytes = Uint8List.fromList(utf8.encode(yamlStr));
                final uri = await FilePicker.saveFile(
                  dialogTitle: '导出标准 agent.yaml 配置文件',
                  fileName: 'agent.${profile.nodeId}.yaml',
                  bytes: bytes,
                );
                if (uri != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已导出源项目 agent.yaml 到: ${uri.path}')),
                  );
                }
              },
            ),
            IconButton(
              tooltip: '查看日志 (弹窗)',
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.indigo),
              onPressed: () {
                LiveLogDialog.show(
                  context,
                  title: '节点 ${profile.name} (${profile.nodeId}) 实时运行日志',
                  profileId: profile.id,
                );
              },
            ),
            IconButton(
              tooltip: '编辑配置',
              icon: const Icon(Icons.edit_outlined),
              onPressed: isRunning
                  ? null
                  : () {
                      AgentEditDialog.show(
                        context,
                        profile: profile,
                        onSave: (updated) => state.updateProfile(updated),
                      );
                    },
            ),
            IconButton(
              tooltip: '删除节点',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: isRunning
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认删除节点'),
                          content: Text('确定要删除 "${profile.name}" 吗？此操作无法撤销。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: () {
                                state.deleteProfile(profile.id);
                                Navigator.of(ctx).pop();
                              },
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                    },
            ),

            const SizedBox(width: 8),
            // Start/Stop Switch
            Switch(
              value: isRunning,
              activeThumbColor: Colors.green,
              onChanged: (val) {
                if (val) {
                  state.startAgent(profile);
                } else {
                  state.stopAgent(profile.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
