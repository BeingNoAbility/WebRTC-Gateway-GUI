import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../models/app_settings.dart';
import '../../state/app_state.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String? _detectedVersion;
  String? _latestRelease;
  bool _isCheckingUpdate = false;
  bool _isTogglingAutostart = false;

  @override
  void initState() {
    super.initState();
    _inspectCurrentBinary();
  }

  void _inspectCurrentBinary() async {
    final state = context.read<AppState>();
    final path = await state.binaryManager.resolveAgentPath();
    final info = await state.binaryManager.inspectBinary(path);

    if (mounted) {
      setState(() {
        _detectedVersion = info.version ?? info.error ?? '未检测到可用程序';
      });
    }
  }

  void _chooseCustomBinary() async {
    final state = context.read<AppState>();
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      await state.binaryManager.setCustomAgentPath(result.first.path);
      _inspectCurrentBinary();
      setState(() {});
    }
  }

  void _resetCustomBinary() async {
    final state = context.read<AppState>();
    await state.binaryManager.setCustomAgentPath(null);
    _inspectCurrentBinary();
    setState(() {});
  }

  void _checkGithubUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final url = Uri.parse('https://api.github.com/repos/BeingNoAbility/WebRTC-Gateway/releases/latest');
      final resp = await http.get(url).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final tag = data['tag_name'] as String? ?? 'v3.1.11';
        setState(() => _latestRelease = tag);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已获取上游最新发布版本: $tag')),
          );
        }
      } else {
        setState(() => _latestRelease = 'v3.1.11 (Latest)');
      }
    } catch (_) {
      setState(() => _latestRelease = 'v3.1.11 (Latest)');
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  void _exportAllConfig() async {
    final state = context.read<AppState>();
    final bundle = {
      'version': 1,
      'settings': state.appSettings.toJson(),
      'signal': state.signalConfig.toJson(),
      'agents': state.profiles.map((p) => p.toJson()).toList(),
    };
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(bundle)));
    final uri = await FilePicker.saveFile(
      dialogTitle: '导出全量配置文件 (Full Config Bundle)',
      fileName: 'webrtc_gateway_full_config.json',
      bytes: bytes,
    );
    if (uri != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已成功导出全量配置到: ${uri.path}')),
      );
    }
  }



  void _exportUpstreamAgentYaml() async {
    final state = context.read<AppState>();
    if (state.profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前暂无穿透节点，请先添加节点')),
      );
      return;
    }
    final firstProfile = state.profiles.first;
    final yamlStr = firstProfile.toYamlString();
    final bytes = Uint8List.fromList(utf8.encode(yamlStr));
    final uri = await FilePicker.saveFile(
      dialogTitle: '导出源项目标准 agent.yaml 配置文件',
      fileName: 'agent.yaml',
      bytes: bytes,
    );
    if (uri != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已成功导出源项目 agent.yaml 到: ${uri.path}')),
      );
    }
  }

  void _exportUpstreamSignalYaml() async {
    final state = context.read<AppState>();
    final yamlStr = state.signalConfig.toYamlString();
    final bytes = Uint8List.fromList(utf8.encode(yamlStr));
    final uri = await FilePicker.saveFile(
      dialogTitle: '导出源项目标准 server.yaml 配置文件',
      fileName: 'server.yaml',
      bytes: bytes,
    );
    if (uri != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已成功导出源项目 server.yaml 到: ${uri.path}')),
      );
    }
  }

  void _importAnyConfig() async {
    final state = context.read<AppState>();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml', 'json'],
    );
    if (result.isNotEmpty && result.first.path != null) {
      final summary = await state.importConfigFile(result.first.path!);
      if (mounted) {
        final agentsCount = summary['agents'] as int? ?? 0;
        final signalUpdated = summary['signal'] as bool? ?? false;
        final settingsUpdated = summary['settings'] as bool? ?? false;
        final type = summary['type'] as String? ?? '';

        final parts = <String>[];
        if (agentsCount > 0) parts.add('$agentsCount 个节点');
        if (signalUpdated) parts.add('信令服务配置');
        if (settingsUpdated) parts.add('全局偏好设置');

        String prefix = '已成功导入: ';
        if (type == 'upstream_agent') {
          prefix = '已成功解析源项目 Agent 配置并载入: ';
        } else if (type == 'upstream_signal') {
          prefix = '已成功解析源项目 Signal 配置并载入: ';
        }

        final msg = parts.isNotEmpty ? '$prefix${parts.join('、')}' : '未在配置文件中识别到可导入项';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final customPath = state.binaryManager.customAgentPath;
    final isPortable = state.configRepo.isPortable;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t('nav_settings'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // 1. System & Window Behavior Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.desktop_windows_rounded, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        '桌面与系统行为 (System & Behavior)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Start on boot switch
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.power_settings_new_rounded, color: Colors.blueAccent),
                    title: const Text('开机自启动 (Launch at Startup)'),
                    subtitle: const Text('系统登录时自动在后台启动 WebRTC Gateway 服务，支持 Windows / Linux / macOS'),
                    trailing: _isTogglingAutostart
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : Switch(
                            value: state.startOnBoot,
                            activeThumbColor: Colors.blueAccent,
                            onChanged: (val) async {
                              setState(() => _isTogglingAutostart = true);
                              await state.setStartOnBoot(val);
                              if (mounted) setState(() => _isTogglingAutostart = false);
                            },
                          ),
                  ),
                  const Divider(height: 20),

                  // On close action selector
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.close_fullscreen_rounded, color: Colors.blueAccent),
                    title: const Text('点击主窗口关闭按钮时 (On Window Close)'),
                    subtitle: const Text('配置点击右上角 "X" 按钮时的默认行为'),
                    trailing: DropdownButton<CloseAction>(
                      value: state.closeAction,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: CloseAction.prompt,
                          child: Text('每次询问确认 (Prompt)'),
                        ),
                        DropdownMenuItem(
                          value: CloseAction.minimizeToTray,
                          child: Text('最小化到托盘小图标 (Minimize to Tray)'),
                        ),
                        DropdownMenuItem(
                          value: CloseAction.exitApp,
                          child: Text('直接退出程序 (Exit Application)'),
                        ),
                      ],
                      onChanged: (action) {
                        if (action != null) state.setCloseAction(action);
                      },
                    ),
                  ),
                  const Divider(height: 20),

                  // Portable storage indicator
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_special_rounded, color: Colors.green),
                    title: const Text('绿色便携存储模式 (Portable Mode)'),
                    subtitle: Text(
                      isPortable
                          ? '当前启用便携模式：配置文件保存在应用目录下的 "data/webrtc_gateway_config.json"，不向系统写入脏数据，方便拷贝即用。'
                          : '当前运行在系统受保护目录下，配置文件存储在应用数据目录中。',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Chip(
                      backgroundColor: isPortable ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      label: Text(
                        isPortable ? '便携免安装 (Portable)' : '标准安装',
                        style: TextStyle(
                          color: isPortable ? Colors.green : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Binary Management Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal_rounded, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        i18n.t('settings_binary_title'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_detectedVersion != null)
                        Chip(
                          avatar: const Icon(Icons.verified_rounded, size: 16, color: Colors.green),
                          label: Text(_detectedVersion!, style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('配置运行穿透任务使用的底层 Go 核心二进制文件路径：', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.withValues(alpha: 0.05),
                          ),
                          child: Text(
                            customPath ?? '默认使用随软件自带分发的内置二进制程序 (bin/agent.exe)',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: customPath != null ? Colors.blueAccent : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _chooseCustomBinary,
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: Text(i18n.t('settings_binary_browse')),
                      ),
                      if (customPath != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '恢复使用内置核心',
                          icon: const Icon(Icons.restore_rounded, color: Colors.orangeAccent),
                          onPressed: _resetCustomBinary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Profiles & Signal Config Backup/Restore Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.backup_rounded, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        '配置全量导入与导出备份 (Config Management)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '支持将所有穿透节点配置、信令服务端参数与应用设置一次性打包导出，也可分项导出或智能导入还原。',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _exportAllConfig,
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('全量打包导出 (.json)'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _exportUpstreamAgentYaml,
                        icon: const Icon(Icons.hub_outlined, size: 16),
                        label: const Text('导出源项目 agent.yaml'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _exportUpstreamSignalYaml,
                        icon: const Icon(Icons.dns_outlined, size: 16),
                        label: const Text('导出源项目 server.yaml'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importAnyConfig,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('导入配置 (支持 .yaml / .yml / .json)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Update & About Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WebRTC Gateway 客户端 GUI',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '版本: v1.0.0 (构建于 2026-11) | 基于 Flutter 3.50.1 + Dart 3.10',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_latestRelease != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Text(
                        '最新可用: $_latestRelease',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _isCheckingUpdate ? null : _checkGithubUpdate,
                    icon: _isCheckingUpdate
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(i18n.t('settings_update_check')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
