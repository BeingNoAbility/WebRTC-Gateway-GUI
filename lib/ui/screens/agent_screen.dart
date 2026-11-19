import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/agent_config.dart';
import '../../core/models/agent_instance.dart';
import '../../core/models/agent_metrics.dart';
import '../../providers/agent_provider.dart';
import '../widgets/metric_card.dart';
import '../widgets/quick_mode_selector.dart';
import '../widgets/share_link_dialog.dart';
import '../widgets/status_indicator_badge.dart';

class AgentScreen extends StatefulWidget {
  final VoidCallback onNavigateToLogs;

  const AgentScreen({super.key, required this.onNavigateToLogs});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  // If null, displays the multi-agent cluster overview; otherwise focuses on a specific agent
  String? _selectedAgentId;

  void _showAgentEditDialog(BuildContext context, {AgentInstance? existing}) {
    final provider = context.read<AgentProvider>();
    final isEditing = existing != null;

    final nameCtrl = TextEditingController(text: existing?.name ?? '新穿透服务');
    final nodeIdCtrl = TextEditingController(text: existing?.config.nodeId ?? 'node-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final targetCtrl = TextEditingController(text: existing?.config.target ?? 'http://127.0.0.1:8080');
    final dirCtrl = TextEditingController(text: existing?.config.dir ?? '');
    final fileCtrl = TextEditingController(text: existing?.config.file ?? '');
    final signalCtrl = TextEditingController(text: existing?.config.signal ?? 'ws://127.0.0.1:8888/ws');
    final signalSecretCtrl = TextEditingController(text: existing?.config.signalSecret ?? '');
    final accessSecretCtrl = TextEditingController(text: existing?.config.accessSecret ?? '');
    final portalUrlCtrl = TextEditingController(text: existing?.config.portalUrl ?? 'http://127.0.0.1:8888');

    AgentMode selectedMode = existing?.config.mode ?? AgentMode.reverseProxy;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              title: Text(isEditing ? '编辑 Agent [${existing.name}]' : '创建新 Agent 实例'),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Agent 描述别名',
                                hintText: '如: 家庭 NAS, 开发服务, 共享照片',
                                prefixIcon: Icon(Icons.label_rounded, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: nodeIdCtrl,
                              decoration: InputDecoration(
                                labelText: '唯一 Node ID',
                                prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.shuffle_rounded, size: 16),
                                  tooltip: '随机 ID',
                                  onPressed: () {
                                    setDialogState(() {
                                      nodeIdCtrl.text = 'node-${DateTime.now().millisecondsSinceEpoch % 10000}';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Mode selection
                      Text(
                        '运行模式 (三大模式三选一)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      QuickModeSelector(
                        selectedMode: selectedMode,
                        onModeChanged: (newMode) {
                          setDialogState(() => selectedMode = newMode);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Mode inputs
                      if (selectedMode == AgentMode.reverseProxy) ...[
                        TextField(
                          controller: targetCtrl,
                          decoration: const InputDecoration(
                            labelText: '本地反向代理目标 URL (-target)',
                            hintText: '如: http://127.0.0.1:8080',
                            prefixIcon: Icon(Icons.lan_rounded, size: 18),
                          ),
                        ),
                      ] else if (selectedMode == AgentMode.directory) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: dirCtrl,
                                decoration: const InputDecoration(
                                  labelText: '本地共享目录 (-dir)',
                                  prefixIcon: Icon(Icons.folder_open_rounded, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.folder_rounded, size: 16),
                              label: const Text('浏览'),
                              onPressed: () async {
                                await provider.pickDirectory();
                                setDialogState(() {
                                  dirCtrl.text = provider.focusedAgent.config.dir;
                                });
                              },
                            ),
                          ],
                        ),
                      ] else if (selectedMode == AgentMode.singleFile) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: fileCtrl,
                                decoration: const InputDecoration(
                                  labelText: '本地单文件路径 (-file)',
                                  prefixIcon: Icon(Icons.insert_drive_file_rounded, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.file_open_rounded, size: 16),
                              label: const Text('选择'),
                              onPressed: () async {
                                await provider.pickFile();
                                setDialogState(() {
                                  fileCtrl.text = provider.focusedAgent.config.file;
                                });
                              },
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Signaling & Secrets
                      TextField(
                        controller: signalCtrl,
                        decoration: const InputDecoration(
                          labelText: '信令服务器 WebSocket 地址 (-signal)',
                          hintText: '如: ws://127.0.0.1:8888/ws',
                          prefixIcon: Icon(Icons.cloud_sync_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: accessSecretCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: '访客密码 (-access-secret)',
                                hintText: '留空表示完全公开',
                                prefixIcon: Icon(Icons.key_rounded, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: signalSecretCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: '信令秘钥 (-signal-secret)',
                                hintText: '集群入网令牌',
                                prefixIcon: Icon(Icons.security_rounded, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newCfg = (existing?.config ?? AgentConfig()).copyWith(
                      nodeId: nodeIdCtrl.text.trim(),
                      mode: selectedMode,
                      target: targetCtrl.text.trim(),
                      dir: dirCtrl.text.trim(),
                      file: fileCtrl.text.trim(),
                      signal: signalCtrl.text.trim(),
                      signalSecret: signalSecretCtrl.text.trim(),
                      accessSecret: accessSecretCtrl.text.trim(),
                      portalUrl: portalUrlCtrl.text.trim(),
                    );

                    if (isEditing) {
                      existing.name = nameCtrl.text.trim().isEmpty ? existing.name : nameCtrl.text.trim();
                      existing.config = newCfg;
                      provider.updateAgent(existing);
                    } else {
                      provider.addAgent(
                        name: nameCtrl.text.trim(),
                        config: newCfg,
                      );
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: Text(isEditing ? '保存修改' : '立即创建'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final agents = provider.agents;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Cluster Overview Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFF1F5F9), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 680;

                    final infoWidget = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: provider.hasRunningAgents
                                ? AppColors.successGreen.withValues(alpha: 0.15)
                                : AppColors.primaryCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            provider.hasRunningAgents ? Icons.hub_rounded : Icons.sensors_off_rounded,
                            color: provider.hasRunningAgents ? AppColors.successGreen : AppColors.primaryCyan,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Agent 多节点并发管理中心',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: provider.hasRunningAgents
                                          ? AppColors.successGreen.withValues(alpha: 0.12)
                                          : AppColors.darkTextMuted.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: provider.hasRunningAgents
                                            ? AppColors.successGreen.withValues(alpha: 0.3)
                                            : AppColors.darkTextMuted.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${provider.runningAgents} / ${provider.totalAgents} 运行中',
                                      style: TextStyle(
                                        color: provider.hasRunningAgents ? AppColors.successGreen : AppColors.darkTextMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '支持同时运行多个 Web 反向代理、静态目录托管与 P2P 单文件直传进程，端口智能动态分流',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final actionButtons = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryCyan,
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('新建 Agent'),
                          onPressed: () => _showAgentEditDialog(context),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.successGreen),
                          label: const Text('全部启动'),
                          onPressed: () async => await provider.startAll(),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.stop_rounded, size: 18, color: AppColors.errorRed),
                          label: const Text('全部停止'),
                          onPressed: () async => await provider.stopAll(),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          infoWidget,
                          const SizedBox(height: 14),
                          actionButtons,
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(child: infoWidget),
                          const SizedBox(width: 14),
                          actionButtons,
                        ],
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Aggregated Cluster Metrics HUD
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;

                  final cards = [
                    MetricCard(
                      icon: Icons.device_hub_rounded,
                      title: '全网活跃 P2P 对等连接',
                      value: '${provider.totalActivePeers} 个',
                      subtitle: '${provider.runningAgents} 个在线 Agent',
                      accentColor: AppColors.primaryCyan,
                    ),
                    MetricCard(
                      icon: Icons.layers_rounded,
                      title: 'Agent 实例总数',
                      value: '${provider.totalAgents} 个',
                      subtitle: '${provider.runningAgents} 在线 / ${provider.totalAgents - provider.runningAgents} 待命',
                      accentColor: AppColors.accentIndigo,
                    ),
                    MetricCard(
                      icon: Icons.arrow_downward_rounded,
                      title: '集群总下行吞吐',
                      value: AgentMetrics.formatSpeed(provider.totalRxSpeed),
                      subtitle: '累计: ${AgentMetrics.formatBytes(provider.totalRxBytes)}',
                      accentColor: AppColors.successGreen,
                    ),
                    MetricCard(
                      icon: Icons.arrow_upward_rounded,
                      title: '集群总上行吞吐',
                      value: AgentMetrics.formatSpeed(provider.totalTxSpeed),
                      subtitle: '累计: ${AgentMetrics.formatBytes(provider.totalTxBytes)}',
                      accentColor: AppColors.warningAmber,
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      children: cards
                          .map((c) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: c,
                                ),
                              ))
                          .toList(),
                    );
                  } else {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 10),
                            Expanded(child: cards[1]),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: cards[2]),
                            const SizedBox(width: 10),
                            Expanded(child: cards[3]),
                          ],
                        ),
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 20),

              // Agent List Title
              Row(
                children: [
                  Text(
                    'Agent 穿透实例列表 (${agents.length})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedAgentId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('返回所有 Agent 列表'),
                      onPressed: () => setState(() => _selectedAgentId = null),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Detail View for a single focused Agent OR Multi-Agent Grid View
              if (_selectedAgentId != null) ...[
                _buildAgentDetailView(context, agents.firstWhere((a) => a.id == _selectedAgentId, orElse: () => agents.first)),
              ] else ...[
                if (agents.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.router_outlined, size: 40, color: AppColors.darkTextMuted),
                            const SizedBox(height: 10),
                            const Text('暂无 Agent 实例，点击上方“新建 Agent”添加'),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: agents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final agent = agents[idx];
                      return _buildAgentCard(context, agent, provider, isDark);
                    },
                  ),
              ],

              const SizedBox(height: 20),

              // Recent Logs Preview Banner
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal_rounded, size: 20, color: AppColors.primaryCyan),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.allAgentLogs.isNotEmpty
                              ? '最新集群日志: [${provider.allAgentLogs.last.source.displayName}] ${provider.allAgentLogs.last.message}'
                              : '所有 Agent 实例待命就绪',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('查看完整控制台'),
                        onPressed: widget.onNavigateToLogs,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentCard(
    BuildContext context,
    AgentInstance agent,
    AgentProvider provider,
    bool isDark,
  ) {
    final isRunning = agent.isRunning;
    final config = agent.config;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;

            final headerInfo = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? AppColors.successGreen.withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getModeIcon(config.mode),
                    color: isRunning ? AppColors.successGreen : AppColors.primaryCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Mode
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            agent.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${config.nodeId}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                            ),
                          ),
                          StatusIndicatorBadge(status: agent.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getModeTargetSummary(config),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isNarrow)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    onSelected: (val) async {
                      if (val == 'edit') {
                        _showAgentEditDialog(context, existing: agent);
                      } else if (val == 'detail') {
                        setState(() => _selectedAgentId = agent.id);
                      } else if (val == 'delete') {
                        await provider.deleteAgent(agent.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'detail', child: Text('查看详情监控与控制')),
                      const PopupMenuItem(value: 'edit', child: Text('修改配置')),
                      const PopupMenuItem(value: 'delete', child: Text('删除此 Agent', style: TextStyle(color: AppColors.errorRed))),
                    ],
                  ),
              ],
            );

            final actionButtons = Row(
              mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (isNarrow) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_rounded, size: 16),
                      label: const Text('分享直连'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => ShareLinkDialog(
                            portalUrl: config.portalUrl,
                            nodeId: config.nodeId,
                            accessSecret: config.accessSecret,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning ? AppColors.errorRed : AppColors.primaryCyan,
                        foregroundColor: isRunning ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 18),
                      label: Text(isRunning ? '停止' : '启动'),
                      onPressed: () async {
                        if (isRunning) {
                          await agent.stop();
                        } else {
                          await agent.start(customBinaryPath: provider.customBinaryPath);
                        }
                      },
                    ),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_rounded, size: 16),
                    label: const Text('分享直连'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ShareLinkDialog(
                          portalUrl: config.portalUrl,
                          nodeId: config.nodeId,
                          accessSecret: config.accessSecret,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRunning ? AppColors.errorRed : AppColors.primaryCyan,
                      foregroundColor: isRunning ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 18),
                    label: Text(isRunning ? '停止' : '启动'),
                    onPressed: () async {
                      if (isRunning) {
                        await agent.stop();
                      } else {
                        await agent.start(customBinaryPath: provider.customBinaryPath);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    onSelected: (val) async {
                      if (val == 'edit') {
                        _showAgentEditDialog(context, existing: agent);
                      } else if (val == 'detail') {
                        setState(() => _selectedAgentId = agent.id);
                      } else if (val == 'delete') {
                        await provider.deleteAgent(agent.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'detail', child: Text('查看详情监控与控制')),
                      const PopupMenuItem(value: 'edit', child: Text('修改配置')),
                      const PopupMenuItem(value: 'delete', child: Text('删除此 Agent', style: TextStyle(color: AppColors.errorRed))),
                    ],
                  ),
                ],
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNarrow) ...[
                  headerInfo,
                  const SizedBox(height: 12),
                  actionButtons,
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: headerInfo),
                      const SizedBox(width: 14),
                      actionButtons,
                    ],
                  ),
                ],

            if (isRunning) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'P2P 对等节点: ${agent.metrics.activePeers} 个',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '数据流: ${agent.metrics.activeStreams} / ${agent.metrics.maxStreams}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      '下行: ${AgentMetrics.formatSpeed(agent.metrics.rxSpeedBytesPerSec)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.successGreen),
                    ),
                    Text(
                      '上行: ${AgentMetrics.formatSpeed(agent.metrics.txSpeedBytesPerSec)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.warningAmber),
                    ),
                    Text(
                      'Prometheus: ${config.metricsAddr}',
                      style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  ],
                ),
              ),
            ],

            if (agent.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                '异常: ${agent.errorMessage}',
                style: const TextStyle(color: AppColors.errorRed, fontSize: 11),
              ),
            ],
          ],
        );
      },
    ),
  ),
);
  }

  Widget _buildAgentDetailView(BuildContext context, AgentInstance agent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = agent.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    StatusIndicatorBadge(status: agent.status),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: agent.isRunning ? AppColors.errorRed : AppColors.primaryCyan,
                        foregroundColor: agent.isRunning ? Colors.white : Colors.black,
                      ),
                      icon: Icon(agent.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 18),
                      label: Text(agent.isRunning ? '停止' : '启动'),
                      onPressed: () async {
                        if (agent.isRunning) {
                          await agent.stop();
                        } else {
                          await agent.start(customBinaryPath: context.read<AgentProvider>().customBinaryPath);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('编辑参数'),
                      onPressed: () => _showAgentEditDialog(context, existing: agent),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('运行模式: ${config.mode.displayName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('目标地址: ${_getModeTargetSummary(config)}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                Text('信令服务器: ${config.signal}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                Text('Prometheus 监控端口: ${config.metricsAddr}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getModeIcon(AgentMode mode) {
    switch (mode) {
      case AgentMode.reverseProxy:
        return Icons.alt_route_rounded;
      case AgentMode.directory:
        return Icons.folder_shared_rounded;
      case AgentMode.singleFile:
        return Icons.file_download_rounded;
    }
  }

  String _getModeTargetSummary(AgentConfig config) {
    switch (config.mode) {
      case AgentMode.reverseProxy:
        return 'HTTP/WS 反代: ${config.target}';
      case AgentMode.directory:
        return '本地静态目录: ${config.dir.isEmpty ? "(未选择目录)" : config.dir}';
      case AgentMode.singleFile:
        return '单文件直传: ${config.file.isEmpty ? "(未选择文件)" : config.file}';
    }
  }
}
