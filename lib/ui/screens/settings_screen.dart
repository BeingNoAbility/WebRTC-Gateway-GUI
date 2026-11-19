import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/agent_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _agentPathCtrl;
  late TextEditingController _signalPathCtrl;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _agentPathCtrl = TextEditingController(
      text: settings.customAgentPath ?? '',
    );
    _signalPathCtrl = TextEditingController(
      text: settings.customSignalPath ?? '',
    );
  }

  @override
  void dispose() {
    _agentPathCtrl.dispose();
    _signalPathCtrl.dispose();
    super.dispose();
  }

  void _showYamlDialog(
    BuildContext context,
    String title,
    String yamlContent, {
    bool isImport = false,
  }) {
    final ctrl = TextEditingController(text: yamlContent);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          title: Text(title),
          content: SizedBox(
            width: 550,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  maxLines: 14,
                  readOnly: !isImport,
                  style: const TextStyle(
                    fontFamily: 'Consolas, monospace',
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!isImport)
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('复制配置'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ctrl.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制 YAML 配置到剪贴板')),
                  );
                },
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
            if (isImport)
              ElevatedButton(
                onPressed: () {
                  final agentProvider = context.read<AgentProvider>();
                  final settingsProvider = context.read<SettingsProvider>();
                  final importedConfig = settingsProvider.importAgentYaml(
                    ctrl.text,
                  );
                  if (importedConfig != null) {
                    agentProvider.updateConfig(importedConfig);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('成功导入 Agent 配置！')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('YAML 格式解析失败，请检查语法')),
                    );
                  }
                },
                child: const Text('应用配置'),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final agentProvider = context.watch<AgentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primaryCyan,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '系统设置与高级配置 (Settings & Preferences)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '跨平台统一样式外观、二进制路径覆盖与官方 YAML 配置文件双向互通',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Appearance Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '界面与视觉主题风格 (Unified Material 3)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('赛博暗黑 (Dark)'),
                            icon: Icon(Icons.dark_mode_rounded, size: 16),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('纯粹明亮 (Light)'),
                            icon: Icon(Icons.light_mode_rounded, size: 16),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('跟随系统 (System)'),
                            icon: Icon(
                              Icons.settings_suggest_rounded,
                              size: 16,
                            ),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (set) {
                          settings.setThemeMode(set.first);
                        },
                      ),
                      if (!kIsWeb && Platform.isWindows) ...[
                        const SizedBox(height: 14),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('关闭主窗口时最小化到系统托盘 (任务栏小图标)'),
                          subtitle: const Text(
                            '点击右上角关闭按钮时保持后台运行，可在任务栏右下角小图标随时唤醒或右键退出',
                          ),
                          value: settings.closeToTray,
                          activeThumbColor: AppColors.primaryCyan,
                          onChanged: (val) => settings.setCloseToTray(val),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Binary Paths Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Go 核心二进制程序路径 (Windows 桌面端)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '默认自动搜索 assets/bin 及系统 PATH。若要覆盖指定版本，可在下方设置绝对路径',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Agent binary
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _agentPathCtrl,
                              decoration: const InputDecoration(
                                labelText: '自定义 agent.exe 路径',
                                hintText: '默认: assets/bin/agent.exe',
                                prefixIcon: Icon(
                                  Icons.folder_special_rounded,
                                  size: 18,
                                ),
                              ),
                              onChanged: (val) =>
                                  settings.setCustomAgentPath(val),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.file_open_rounded, size: 16),
                            label: const Text('选择文件'),
                            onPressed: () async {
                              final file = await FilePicker.pickFile();
                              if (file != null && file.path != null) {
                                _agentPathCtrl.text = file.path!;
                                settings.setCustomAgentPath(
                                  _agentPathCtrl.text,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Signal binary
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _signalPathCtrl,
                              decoration: const InputDecoration(
                                labelText: '自定义 signal.exe 路径',
                                hintText: '默认: assets/bin/signal.exe',
                                prefixIcon: Icon(
                                  Icons.folder_special_rounded,
                                  size: 18,
                                ),
                              ),
                              onChanged: (val) =>
                                  settings.setCustomSignalPath(val),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.file_open_rounded, size: 16),
                            label: const Text('选择文件'),
                            onPressed: () async {
                              final file = await FilePicker.pickFile();
                              if (file != null && file.path != null) {
                                _signalPathCtrl.text = file.path!;
                                settings.setCustomSignalPath(
                                  _signalPathCtrl.text,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // YAML Profile Import / Export Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YAML 配置文件双向互通 (agent.yaml)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '与官方 WebRTC-Gateway CLI 命令行参数、Docker Compose 及 agent.yaml 完全兼容',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentIndigo,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.file_upload_rounded,
                              size: 16,
                            ),
                            label: const Text('查看与导出 agent.yaml'),
                            onPressed: () {
                              final yamlStr = agentProvider.config
                                  .toYamlString();
                              _showYamlDialog(
                                context,
                                '当前 Agent 配置 (YAML)',
                                yamlStr,
                                isImport: false,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.file_download_rounded,
                              size: 16,
                            ),
                            label: const Text('导入 agent.yaml 文本'),
                            onPressed: () {
                              _showYamlDialog(
                                context,
                                '导入 Agent 配置 (YAML)',
                                '',
                                isImport: true,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Project About & Links Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryCyan.withValues(
                                  alpha: 0.3,
                                ),
                                width: 1.2,
                              ),
                            ),
                            child: SvgPicture.asset('assets/images/logo.svg'),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WebRTC Gateway & GUI',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Zero-Client WebRTC P2P Penetration',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCyan.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              AppConstants.appVersion,
                              style: TextStyle(
                                color: AppColors.primaryCyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Zero-Client WebRTC P2P Intranet Penetration & Reverse Proxy GUI\n'
                        '支持 Windows 桌面与 Android 移动端统一风格界面，基于 WebRTC RTCDataChannel (SCTP) 双通道架构与 DTLS 1.2 / SRTP 端到端加密直连。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.code_rounded, size: 16),
                            label: const Text('开源代码仓库 (GitHub)'),
                            onPressed: () {
                              launchUrl(
                                Uri.parse(AppConstants.githubRepo),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          TextButton.icon(
                            icon: const Icon(Icons.menu_book_rounded, size: 16),
                            label: const Text('官方 VitePress 文档站'),
                            onPressed: () {
                              launchUrl(
                                Uri.parse(AppConstants.docsUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                        ],
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
}
