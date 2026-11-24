import 'dart:async';
import 'dart:convert';
import 'dart:math';
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

  String _generateRandomPassword([int length = 14]) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%*';
    final rand = Random.secure();
    return List<String>.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<void> _startAgentWithSecurityCheck(
    BuildContext context,
    AppState state,
    AgentProfile profile,
  ) async {
    if (profile.accessSecret.isNotEmpty || profile.allowPublic) {
      await state.startAgent(profile);
      return;
    }

    final i18n = AppI18n();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber.shade800,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                i18n.pick(
                  '安全确认：未设置访客访问密码',
                  'Security Confirmation: No Visitor Password',
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            i18n.pick(
              '节点 "${profile.name}" (${profile.nodeId}) 当前未设置访问密码 (-access-secret)。\n\n'
              '若以公开免密模式启动，任何知道访问链接或 Node ID 的人都可直接访问暴露的资源。建议一键生成强密码后再通过“分享”生成免密限时链接。',
              'Agent "${profile.name}" (${profile.nodeId}) has no visitor password.\n\n'
              'Running in public mode allows anyone with the link or Node ID to access the target directly.',
            ),
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: Text(i18n.t('common_cancel')),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('public'),
            child: Text(
              i18n.pick('确认公开免密启动', 'Allow Public & Start'),
              style: const TextStyle(color: Colors.orange),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop('protect'),
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: Text(
              i18n.pick('自动生成密码并启动', 'Generate Password & Start'),
            ),
          ),
        ],
      ),
    );

    if (choice == 'protect') {
      final pwd = _generateRandomPassword();
      final updated = profile.copyWith(accessSecret: pwd, allowPublic: false);
      state.updateProfile(updated);
      await state.startAgent(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              i18n.pick(
                '已为 ${updated.nodeId} 生成强密码并启动（可在分享弹窗生成免输密码时效链接）',
                'Generated password and started ${updated.nodeId}.',
              ),
            ),
          ),
        );
      }
    } else if (choice == 'public') {
      final updated = profile.copyWith(allowPublic: true);
      state.updateProfile(updated);
      await state.startAgent(updated);
    }
  }

  Future<void> _importConfig(BuildContext context, AppState state) async {
    final i18n = AppI18n();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml', 'json'],
    );
    if (result.isEmpty || result.first.path == null) return;

    try {
      final summary = await state.importConfigFile(result.first.path!);
      if (context.mounted) {
        final count = summary['agents'] as int? ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              i18n.pick(
                '已成功导入 $count 个穿透节点配置',
                'Imported $count agent profile(s)',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              i18n.pick('导入配置文件失败: $e', 'Failed to import config: $e'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.t('agent_list_title'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i18n.pick(
                      '已配置 ${state.profiles.length} 个节点，当前运行中: ${state.runningCount} 个',
                      '${state.profiles.length} configured, ${state.runningCount} running',
                    ),
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_importConfig(context, state)),
                    icon: const Icon(Icons.file_open_rounded, size: 16),
                    label: Text(i18n.t('agent_import_yaml')),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.runningCount < state.profiles.length
                        ? () async {
                            final unconfirmed = state.profiles.where(
                              (p) =>
                                  !state.isRunning(p.id) &&
                                  p.accessSecret.isEmpty &&
                                  !p.allowPublic,
                            );
                            if (unconfirmed.isNotEmpty) {
                              for (final p in List<AgentProfile>.from(state.profiles)) {
                                if (!state.isRunning(p.id)) {
                                  if (!context.mounted) break;
                                  await _startAgentWithSecurityCheck(
                                    context,
                                    state,
                                    p,
                                  );
                                }
                              }
                            } else {
                              await state.startAllAgents();
                            }
                          }
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.green),
                    label: Text(i18n.t('agent_start_all')),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.runningCount > 0
                        ? () => unawaited(state.stopAllAgents())
                        : null,
                    icon: const Icon(Icons.stop_rounded, color: Colors.redAccent),
                    label: Text(i18n.t('agent_stop_all')),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      AgentEditDialog.show(
                        context,
                        existingProfiles: state.profiles,
                        onSave: state.addProfile,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(i18n.t('agent_add_btn')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: state.profiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hub_outlined, size: 64, color: muted),
                        const SizedBox(height: 16),
                        Text(
                          i18n.pick(
                            '暂无穿透节点，点击右上角“添加节点”开始',
                            'No tunnel agents yet. Click "Add Node" to start.',
                          ),
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            AgentEditDialog.show(
                              context,
                              existingProfiles: state.profiles,
                              onSave: state.addProfile,
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
                      return _AgentCard(
                        profile: profile,
                        onToggleStart: (start) async {
                          if (start) {
                            await _startAgentWithSecurityCheck(
                              context,
                              state,
                              profile,
                            );
                          } else {
                            await state.stopAgent(profile.id);
                          }
                        },
                      );
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
  final Future<void> Function(bool start) onToggleStart;

  const _AgentCard({
    required this.profile,
    required this.onToggleStart,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurfaceVariant;
    final runtime = state.getRuntimeState(profile.id);

    final isRunning = runtime.status == ProcessStatus.running;
    final isStarting = runtime.status == ProcessStatus.starting;
    final isStopping = runtime.status == ProcessStatus.stopping;
    final isError = runtime.status == ProcessStatus.error;
    final isBusy = isRunning || isStarting || isStopping;

    var statusColor = muted;
    var statusText = i18n.t('agent_status_stopped');
    if (isRunning) {
      statusColor = Colors.green;
      statusText = i18n.t('agent_status_running');
    } else if (isStarting) {
      statusColor = Colors.orange;
      statusText = i18n.t('agent_status_starting');
    } else if (isStopping) {
      statusColor = Colors.orangeAccent;
      statusText = i18n.t('agent_status_stopping');
    } else if (isError) {
      statusColor = Colors.redAccent;
      statusText = i18n.t('agent_status_error');
    }

    var modeIcon = Icons.http_rounded;
    var modeDesc = profile.target;
    if (profile.mode == TunnelMode.dir) {
      modeIcon = Icons.folder_outlined;
      modeDesc = profile.dirPath;
    } else if (profile.mode == TunnelMode.file) {
      modeIcon = Icons.insert_drive_file_outlined;
      modeDesc = profile.filePath;
    }

    final isPublic = profile.accessSecret.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRunning
              ? Colors.green.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
          width: isRunning ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.12),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isPublic ? Colors.amber : Colors.green)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPublic
                              ? i18n.t('agent_public_badge')
                              : i18n.t('agent_protected_badge'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPublic
                                ? Colors.amber.shade800
                                : Colors.green,
                          ),
                        ),
                      ),
                      if (profile.autoStart)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            i18n.t('agent_autostart_badge'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(modeIcon, size: 16, color: muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          modeDesc,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 13,
                          ),
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
                  Text(
                    '${i18n.pick("状态", "Status")}: $statusText',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isRunning && runtime.metricsPort != null) ...[
                    Text(
                      '${i18n.pick("监控端口", "Metrics")}: :${runtime.metricsPort} | PID: ${runtime.pid ?? "-"}',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ] else if (isError && runtime.lastError != null) ...[
                    Tooltip(
                      message: runtime.lastError!,
                      child: InkWell(
                        onTap: () {
                          unawaited(
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(i18n.pick('启动错误详情', 'Error Details')),
                                content: SelectableText(runtime.lastError!),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: Text(i18n.t('common_close')),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Text(
                          runtime.lastError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11.5,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            IconButton(
              tooltip: i18n.pick('快速分享', 'Quick Share'),
              icon: const Icon(Icons.qr_code_2_rounded, color: Colors.blueAccent),
              onPressed: () => ShareDialog.show(context, profile),
            ),
            IconButton(
              tooltip: i18n.pick('导出源项目 agent.yaml', 'Export agent.yaml'),
              icon: const Icon(Icons.save_alt_rounded, color: Colors.teal),
              onPressed: () async {
                final yamlStr = profile.toYamlString();
                final bytes = Uint8List.fromList(utf8.encode(yamlStr));
                final uri = await FilePicker.saveFile(
                  dialogTitle: i18n.pick('导出标准 agent.yaml 配置文件', 'Export agent.yaml'),
                  fileName: 'agent.${profile.nodeId}.yaml',
                  bytes: bytes,
                );
                if (uri != null && context.mounted) {
                  final displayPath =
                      uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        i18n.pick('已导出到: $displayPath', 'Exported to: $displayPath'),
                      ),
                    ),
                  );
                }
              },
            ),
            IconButton(
              tooltip: i18n.pick('查看实时日志', 'Live Logs'),
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.indigo),
              onPressed: () {
                LiveLogDialog.show(
                  context,
                  title: '${profile.name} (${profile.nodeId})',
                  profileId: profile.id,
                );
              },
            ),
            IconButton(
              tooltip: isBusy
                  ? i18n.pick('运行中无法编辑，请先停止节点', 'Stop node before editing')
                  : i18n.pick('编辑配置', 'Edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: isBusy
                  ? null
                  : () {
                      AgentEditDialog.show(
                        context,
                        profile: profile,
                        existingProfiles: state.profiles,
                        onSave: state.updateProfile,
                      );
                    },
            ),
            IconButton(
              tooltip: isBusy
                  ? i18n.pick('运行中无法删除，请先停止节点', 'Stop node before deleting')
                  : i18n.pick('删除节点', 'Delete'),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: isBusy
                  ? null
                  : () {
                      unawaited(
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(i18n.pick('确认删除节点', 'Confirm Deletion')),
                            content: Text(
                              i18n.pick(
                                '确定要删除 "${profile.name}" 吗？此操作无法撤销。',
                                'Delete "${profile.name}"? This cannot be undone.',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: Text(i18n.t('common_cancel')),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                onPressed: () {
                                  unawaited(state.deleteProfile(profile.id));
                                  Navigator.of(ctx).pop();
                                },
                                child: Text(i18n.t('common_delete')),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
            ),

            const SizedBox(width: 8),
            Switch(
              value: isRunning,
              activeThumbColor: Colors.green,
              onChanged: (isStarting || isStopping)
                  ? null
                  : (val) => unawaited(onToggleStart(val)),
            ),
          ],
        ),
      ),
    );
  }
}
