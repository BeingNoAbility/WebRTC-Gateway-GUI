import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../models/app_settings.dart';
import '../../services/update_service.dart';
import '../../state/app_state.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String? _detectedAgentVersion;
  String? _detectedSignalVersion;

  bool _isTogglingAutostart = false;

  // Updates state
  late TextEditingController _mirrorCtrl;
  bool _isCheckingGui = false;
  bool _isCheckingCore = false;
  ReleaseInfo? _guiRelease;
  ReleaseInfo? _coreRelease;

  double? _coreDownloadProgress;
  String? _coreDownloadStatus;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _mirrorCtrl = TextEditingController(text: state.githubMirror);
    _inspectBinaries();
  }

  @override
  void dispose() {
    _mirrorCtrl.dispose();
    super.dispose();
  }

  void _inspectBinaries() async {
    final state = context.read<AppState>();
    
    // Agent
    final agentPath = await state.binaryManager.resolveAgentPath();
    final agentInfo = await state.binaryManager.inspectBinary(agentPath);

    // Signal
    final signalPath = await state.binaryManager.resolveSignalPath();
    final signalInfo = await state.binaryManager.inspectBinary(signalPath);

    if (mounted) {
      setState(() {
        _detectedAgentVersion = agentInfo.version ?? agentInfo.error ?? '未检测到可用程序';
        _detectedSignalVersion = signalInfo.version ?? signalInfo.error ?? '未检测到可用程序';
      });
    }
  }

  void _chooseCustomAgentBinary() async {
    final state = context.read<AppState>();
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      await state.binaryManager.setCustomAgentPath(result.first.path);
      _inspectBinaries();
      setState(() {});
    }
  }

  void _resetCustomAgentBinary() async {
    final state = context.read<AppState>();
    await state.binaryManager.setCustomAgentPath(null);
    _inspectBinaries();
    setState(() {});
  }

  void _chooseCustomSignalBinary() async {
    final state = context.read<AppState>();
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      await state.binaryManager.setCustomSignalPath(result.first.path);
      _inspectBinaries();
      setState(() {});
    }
  }

  void _resetCustomSignalBinary() async {
    final state = context.read<AppState>();
    await state.binaryManager.setCustomSignalPath(null);
    _inspectBinaries();
    setState(() {});
  }

  void _checkGuiUpdate() async {
    setState(() => _isCheckingGui = true);
    final mirror = _mirrorCtrl.text.trim();
    final info = await UpdateService.fetchLatestRelease(UpdateService.repoGui, mirrorPrefix: mirror);
    if (mounted) {
      setState(() {
        _isCheckingGui = false;
        _guiRelease = info;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(info != null ? '已获取 GUI 最新版本: ${info.tagName}' : '检查 GUI 更新失败，请检查网络或更换代理地址'),
        ),
      );
    }
  }

  void _checkCoreUpdate() async {
    setState(() => _isCheckingCore = true);
    final mirror = _mirrorCtrl.text.trim();
    final info = await UpdateService.fetchLatestRelease(UpdateService.repoCore, mirrorPrefix: mirror);
    if (mounted) {
      setState(() {
        _isCheckingCore = false;
        _coreRelease = info;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(info != null ? '已获取 Go 核心最新版本: ${info.tagName}' : '检查 Go 核心更新失败，请检查网络或更换代理地址'),
        ),
      );
    }
  }

  void _downloadCoreAsset(ReleaseAsset asset) async {
    setState(() {
      _coreDownloadProgress = 0.01;
      _coreDownloadStatus = '准备下载 ${asset.name}...';
    });

    final mirror = _mirrorCtrl.text.trim();
    final msg = await UpdateService.downloadAndInstallCoreAsset(
      asset: asset,
      mirrorPrefix: mirror,
      onProgress: (p, status) {
        if (mounted) {
          setState(() {
            _coreDownloadProgress = p;
            _coreDownloadStatus = status;
          });
        }
      },
    );

    if (mounted) {
      _inspectBinaries();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
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
    final customAgent = state.binaryManager.customAgentPath;
    final customSignal = state.binaryManager.customSignalPath;
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

          // 2. Display & Font Scaling Card
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
                      const Icon(Icons.format_size_rounded, color: Colors.indigoAccent),
                      const SizedBox(width: 8),
                      const Text(
                        '界面缩放与字体显示 (Display & Scaling)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => state.resetDisplayScaling(),
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text('恢复默认比例'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Font Size Scaling
                  Row(
                    children: [
                      const SizedBox(
                        width: 160,
                        child: Text('全局字体大小缩放:', style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        child: Slider(
                          value: state.fontScale,
                          min: 0.85,
                          max: 1.30,
                          divisions: 9,
                          label: '${(state.fontScale * 100).toInt()}%',
                          onChanged: (val) => state.setFontScale(val),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${(state.fontScale * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Auto DPI Follow System
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自动跟随系统 DPI 缩放 (Auto-detect DPI)'),
                    subtitle: const Text('开启后自动适配 Windows 系统显示缩放比率，在高分屏上保持清晰锐利'),
                    trailing: Switch(
                      value: state.autoDpi,
                      activeThumbColor: Colors.indigoAccent,
                      onChanged: (val) => state.setAutoDpi(val),
                    ),
                  ),

                  // Custom DPI Scale (active when autoDpi is false)
                  if (!state.autoDpi) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(
                          width: 160,
                          child: Text('自定义 DPI 缩放比例:', style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          child: Slider(
                            value: state.customDpiScale,
                            min: 0.80,
                            max: 1.50,
                            divisions: 14,
                            label: '${(state.customDpiScale * 100).toInt()}%',
                            onChanged: (val) => state.setCustomDpiScale(val),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${(state.customDpiScale * 100).toInt()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        const Text('快捷档位: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ActionChip(
                          label: const Text('100%'),
                          onPressed: () => state.setCustomDpiScale(1.0),
                        ),
                        ActionChip(
                          label: const Text('125%'),
                          onPressed: () => state.setCustomDpiScale(1.25),
                        ),
                        ActionChip(
                          label: const Text('150%'),
                          onPressed: () => state.setCustomDpiScale(1.50),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Binary Management Cards (Split into Agent & Signal)
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
                      Icon(Icons.terminal_rounded, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        '底层核心可执行程序设置 (Core Binaries)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('穿透节点核心与信令服务端核心已分别独立支持自定义路径及版本自省：', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),

                  // A: Agent Binary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hub_outlined, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            const Text('Agent 穿透节点核心 (agent.exe)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const Spacer(),
                            if (_detectedAgentVersion != null)
                              Chip(
                                avatar: const Icon(Icons.verified_rounded, size: 14, color: Colors.green),
                                label: Text(_detectedAgentVersion!, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.withValues(alpha: 0.05),
                                ),
                                child: Text(
                                  customAgent ?? '默认使用内置核心程序 (bin/agent.exe)',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: customAgent != null ? Colors.blueAccent : Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _chooseCustomAgentBinary,
                              icon: const Icon(Icons.folder_open_rounded, size: 16),
                              label: const Text('浏览选择'),
                            ),
                            if (customAgent != null) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: '恢复内置 agent',
                                icon: const Icon(Icons.restore_rounded, color: Colors.orangeAccent),
                                onPressed: _resetCustomAgentBinary,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // B: Signal Binary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.dns_outlined, color: Colors.purpleAccent, size: 18),
                            const SizedBox(width: 8),
                            const Text('Signal 信令服务核心 (signal.exe)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const Spacer(),
                            if (_detectedSignalVersion != null)
                              Chip(
                                avatar: const Icon(Icons.verified_rounded, size: 14, color: Colors.green),
                                label: Text(_detectedSignalVersion!, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.withValues(alpha: 0.05),
                                ),
                                child: Text(
                                  customSignal ?? '默认使用内置信令程序 (bin/signal.exe)',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: customSignal != null ? Colors.purpleAccent : Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _chooseCustomSignalBinary,
                              icon: const Icon(Icons.folder_open_rounded, size: 16),
                              label: const Text('浏览选择'),
                            ),
                            if (customSignal != null) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: '恢复内置 signal',
                                icon: const Icon(Icons.restore_rounded, color: Colors.orangeAccent),
                                onPressed: _resetCustomSignalBinary,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Profiles & Signal Config Backup/Restore Card
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
                        icon: const Icon(Icons.save_alt_rounded, size: 16),
                        label: const Text('全量打包导出 (.json)'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _exportUpstreamAgentYaml,
                        icon: const Icon(Icons.save_alt_rounded, size: 16),
                        label: const Text('导出源项目 agent.yaml'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _exportUpstreamSignalYaml,
                        icon: const Icon(Icons.save_alt_rounded, size: 16),
                        label: const Text('导出源项目 server.yaml'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importAnyConfig,
                        icon: const Icon(Icons.file_open_rounded, size: 16),
                        label: const Text('导入配置 (支持 .yaml / .yml / .json)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Updates & Mirror Accelerator Card (Dual updates: GUI and Core separate)
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
                      Icon(Icons.system_update_rounded, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        '检查更新与在线升级 (GUI & Core Updates)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('GUI 客户端更新与底层 Go 核心版本更新独立解耦，并支持配置 GitHub 公共代理节点加速下载：', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 14),

                  // Mirror Proxy Input Bar
                  Row(
                    children: [
                      const Text('更新下载加速代理: ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: UpdateService.presetMirrors.contains(_mirrorCtrl.text) ? _mirrorCtrl.text : null,
                        hint: const Text('选择公共代理预设'),
                        underline: const SizedBox(),
                        items: UpdateService.presetMirrors.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _mirrorCtrl.text = val);
                            state.setGithubMirror(val);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _mirrorCtrl,
                          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '填入自定义 GitHub 代理节点前缀，如 https://ghproxy.net/',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onSubmitted: (val) => state.setGithubMirror(val),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // A: GUI Update Section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GUI 客户端版本 (WebRTC-Gateway-GUI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(height: 4),
                            Text('当前运行: v1.0.0 | 基于 Flutter 3.50 + Dart 3.10', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        if (_guiRelease != null) ...[
                          Text(
                            '最新版本: ${_guiRelease!.tagName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: () {
                              final targetUrl = UpdateService.formatUrlWithMirror(_guiRelease!.htmlUrl, _mirrorCtrl.text);
                              if (Platform.isWindows) {
                                Process.run('cmd', ['/c', 'start', targetUrl]);
                              }
                            },
                            child: const Text('前往发布页下载'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: _isCheckingGui ? null : _checkGuiUpdate,
                          icon: _isCheckingGui
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('检查 GUI 更新'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // B: Core Update Section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('底层 Go 核心版本 (WebRTC-Gateway Core)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('当前检测到核心: ${_detectedAgentVersion ?? "v3.1.11"}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            const Spacer(),
                            if (_coreRelease != null) ...[
                              Text(
                                '上游最新: ${_coreRelease!.tagName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              const SizedBox(width: 12),
                            ],
                            OutlinedButton.icon(
                              onPressed: _isCheckingCore ? null : _checkCoreUpdate,
                              icon: _isCheckingCore
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('检查底层核心更新'),
                            ),
                          ],
                        ),

                        // Download progress if active
                        if (_coreDownloadProgress != null) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: _coreDownloadProgress),
                          const SizedBox(height: 4),
                          Text(_coreDownloadStatus ?? '', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
                        ],

                        // List Core Release Assets if available
                        if (_coreRelease != null && _coreRelease!.assets.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('可供在线更新的核心安装包 (点击直接下载并更新):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _coreRelease!.assets.map((asset) {
                              final isWindows = asset.name.toLowerCase().contains('windows') || asset.name.endsWith('.exe');
                              return ActionChip(
                                avatar: Icon(
                                  isWindows ? Icons.window_rounded : Icons.file_present_rounded,
                                  size: 14,
                                  color: isWindows ? Colors.blueAccent : Colors.grey,
                                ),
                                label: Text(
                                  '${asset.name} (${(asset.size / (1024 * 1024)).toStringAsFixed(1)} MB)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: _coreDownloadProgress != null && _coreDownloadProgress! < 1.0
                                    ? null
                                    : () => _downloadCoreAsset(asset),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
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
