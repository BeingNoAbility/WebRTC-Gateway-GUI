import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/remote_node.dart';
import '../../providers/visitor_provider.dart';

class VisitorScreen extends StatefulWidget {
  const VisitorScreen({super.key});

  @override
  State<VisitorScreen> createState() => _VisitorScreenState();
}

class _VisitorScreenState extends State<VisitorScreen> {
  final _quickConnectCtrl = TextEditingController();
  final _manualNodeIdCtrl = TextEditingController();
  final _manualPortalCtrl = TextEditingController(text: 'http://127.0.0.1:8888');
  final _manualSecretCtrl = TextEditingController();

  @override
  void dispose() {
    _quickConnectCtrl.dispose();
    _manualNodeIdCtrl.dispose();
    _manualPortalCtrl.dispose();
    _manualSecretCtrl.dispose();
    super.dispose();
  }

  void _showAddNodeDialog(BuildContext context, {RemoteNode? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final nodeIdCtrl = TextEditingController(text: existing?.nodeId ?? '');
    final portalCtrl = TextEditingController(text: existing?.portalUrl ?? 'http://127.0.0.1:8888');
    final secretCtrl = TextEditingController(text: existing?.accessSecret ?? '');
    final tagCtrl = TextEditingController(text: existing?.tags.join(', ') ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          title: Text(existing == null ? '添加常用穿透节点' : '编辑节点'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: '节点别名 (如: 家庭 NAS)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nodeIdCtrl,
                    decoration: const InputDecoration(labelText: '目标 Node ID (如: myhome)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: portalCtrl,
                    decoration: const InputDecoration(labelText: '信令/门户 URL (如: http://127.0.0.1:8888)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: secretCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '访客访问口令 (可选)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagCtrl,
                    decoration: const InputDecoration(labelText: '标签 (以逗号分隔，如: NAS, 媒体)'),
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
                final nodeId = nodeIdCtrl.text.trim();
                if (nodeId.isEmpty) return;

                final tags = tagCtrl.text
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();

                final provider = context.read<VisitorProvider>();
                if (existing == null) {
                  provider.addNode(RemoteNode(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleCtrl.text.trim().isEmpty ? nodeId : titleCtrl.text.trim(),
                    nodeId: nodeId,
                    portalUrl: portalCtrl.text.trim().isEmpty ? 'http://127.0.0.1:8888' : portalCtrl.text.trim(),
                    accessSecret: secretCtrl.text.trim(),
                    lastConnected: DateTime.now(),
                    tags: tags,
                  ));
                } else {
                  existing.title = titleCtrl.text.trim().isEmpty ? nodeId : titleCtrl.text.trim();
                  existing.nodeId = nodeId;
                  existing.portalUrl = portalCtrl.text.trim();
                  existing.accessSecret = secretCtrl.text.trim();
                  existing.tags = tags;
                  provider.updateNode(existing);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitorProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nodes = provider.nodes;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header description
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 620;

                  final infoWidget = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.travel_explore_rounded, color: AppColors.primaryCyan, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '访客远程直连中心 (Visitor & Connection Hub)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '输入远程 Node ID 或分享链接，一键穿透连接目标 Web 服务或 P2P 分享',
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

                  final addBtn = ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('添加常用节点'),
                    onPressed: () => _showAddNodeDialog(context),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        infoWidget,
                        const SizedBox(height: 12),
                        addBtn,
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(child: infoWidget),
                        const SizedBox(width: 14),
                        addBtn,
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 18),

              // Quick Paste & Connect Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '快速解析或输入分享链接',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quickConnectCtrl,
                              decoration: InputDecoration(
                                hintText: '粘贴完整的分享链接 (如: http://127.0.0.1:8888/#myhome?exp=...&sign=...)',
                                prefixIcon: const Icon(Icons.link_rounded, size: 18),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                                  tooltip: '从剪贴板粘贴',
                                  onPressed: () async {
                                    final data = await Clipboard.getData('text/plain');
                                    if (data?.text != null) {
                                      _quickConnectCtrl.text = data!.text!;
                                      provider.parseLink(data.text!);
                                    }
                                  },
                                ),
                              ),
                              onSubmitted: (url) {
                                if (url.trim().isNotEmpty) {
                                  provider.launchCustomUrl(url.trim());
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.launch_rounded, size: 18),
                            label: const Text('直达访问'),
                            onPressed: () {
                              final text = _quickConnectCtrl.text.trim();
                              if (text.isNotEmpty) {
                                provider.launchCustomUrl(text);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Manual Node ID Connect Row
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 620;

                          final inputs = Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _manualNodeIdCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '目标 Node ID',
                                    hintText: '如: myhome',
                                    prefixIcon: Icon(Icons.badge_rounded, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _manualPortalCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '信令/门户 URL',
                                    hintText: '如: http://127.0.0.1:8888',
                                    prefixIcon: Icon(Icons.cloud_queue_rounded, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          );

                          final connectBtn = ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentIndigo,
                              foregroundColor: Colors.white,
                              padding: isNarrow ? const EdgeInsets.symmetric(vertical: 12) : null,
                            ),
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text('连接节点'),
                            onPressed: () {
                              final nodeId = _manualNodeIdCtrl.text.trim();
                              final portal = _manualPortalCtrl.text.trim();
                              if (nodeId.isNotEmpty) {
                                final base = portal.endsWith('/') ? portal.substring(0, portal.length - 1) : portal;
                                final fullUrl = '$base/#$nodeId';
                                provider.launchCustomUrl(fullUrl);
                              }
                            },
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                inputs,
                                const SizedBox(height: 10),
                                connectBtn,
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(child: inputs),
                                const SizedBox(width: 10),
                                connectBtn,
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Saved Bookmark Nodes List
              Text(
                '常用穿透节点 (${nodes.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),

              if (nodes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.bookmark_border_rounded, size: 40, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          const SizedBox(height: 10),
                          const Text('暂无保存的节点，点击右上角“添加常用节点”'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: nodes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final node = nodes[idx];
                    final dateStr = DateFormat('MM-dd HH:mm').format(node.lastConnected);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 600;

                            final nodeInfo = Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentIndigo.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.dns_rounded, color: AppColors.accentIndigo, size: 22),
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
                                          Text(
                                            node.title,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '#${node.nodeId}',
                                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          if (!isNarrow) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '最近访问: $dateStr',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        node.accessUrl,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          fontFamily: 'monospace',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (node.tags.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          children: node.tags.map((tag) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryCyan.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                tag,
                                                style: const TextStyle(color: AppColors.primaryCyan, fontSize: 10),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );

                            final actionButtons = Row(
                              mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                              children: [
                                if (isNarrow)
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                  ),
                                if (isNarrow) const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: '编辑',
                                  onPressed: () => _showAddNodeDialog(context, existing: node),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.errorRed),
                                  tooltip: '删除',
                                  onPressed: () => provider.deleteNode(node.id),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryCyan,
                                    foregroundColor: Colors.black,
                                  ),
                                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                                  label: const Text('打开'),
                                  onPressed: () => provider.openNode(node),
                                ),
                              ],
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  nodeInfo,
                                  const SizedBox(height: 8),
                                  actionButtons,
                                ],
                              );
                            } else {
                              return Row(
                                children: [
                                  Expanded(child: nodeInfo),
                                  const SizedBox(width: 14),
                                  actionButtons,
                                ],
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
