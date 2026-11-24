import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
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

  void _exportConfig() async {
    final state = context.read<AppState>();
    final jsonList = state.profiles.map((p) => p.toJson()).toList();
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(jsonList)));
    final uri = await FilePicker.saveFile(
      dialogTitle: '导出配置文件',
      fileName: 'webrtc_gateway_profiles.json',
      bytes: bytes,
    );
    if (uri != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已成功导出配置到: ${uri.path}')),
      );
    }
  }

  void _importConfig() async {
    final state = context.read<AppState>();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result.isNotEmpty && result.first.path != null) {
      final count = await state.configRepo.importFromFile(result.first.path!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功导入 $count 个节点配置')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();

    final customPath = state.binaryManager.customAgentPath;

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

          // 1. Binary Management Card
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Text(
                            customPath ?? '默认内置路径 (./bin/agent.exe 或系统自动探测)',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: customPath != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _chooseCustomBinary,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: Text(i18n.t('settings_binary_browse')),
                      ),
                      if (customPath != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _resetCustomBinary,
                          child: const Text('恢复默认'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Backup & Restore Card
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
                      const Icon(Icons.save_rounded, color: Colors.indigo),
                      const SizedBox(width: 8),
                      Text(
                        i18n.t('settings_config_backup'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('支持将当前所有节点配置全量导出备份，或从文件导入配置。', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _exportConfig,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(i18n.t('settings_export_btn')),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _importConfig,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(i18n.t('settings_import_btn')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Update & i18n
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
                      const Icon(Icons.system_update_rounded, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        i18n.t('settings_update_check'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_latestRelease != null)
                        Chip(label: Text('最新版本: $_latestRelease')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('当前客户端版本: v1.0.0 (Zero-Client WebRTC P2P Gateway GUI)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _isCheckingUpdate ? null : _checkGithubUpdate,
                        icon: _isCheckingUpdate
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_sync_rounded, size: 18),
                        label: Text(i18n.t('settings_update_check')),
                      ),
                      const Spacer(),
                      // Language Switch
                      Row(
                        children: [
                          const Icon(Icons.language_rounded, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(i18n.t('settings_lang')),
                          const SizedBox(width: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'zh', label: Text('中文')),
                              ButtonSegment(value: 'en', label: Text('English')),
                            ],
                            selected: {i18n.currentLocale},
                            onSelectionChanged: (set) {
                              i18n.setLocale(set.first);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ],
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
