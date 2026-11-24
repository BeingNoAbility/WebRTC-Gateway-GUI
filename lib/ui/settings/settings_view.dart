import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../models/agent_profile.dart';
import '../../models/app_settings.dart';
import '../../services/desktop_service.dart';
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
  bool _agentValid = false;
  bool _signalValid = false;

  bool _isTogglingAutostart = false;

  late TextEditingController _mirrorCtrl;
  bool _isCheckingGui = false;
  bool _isCheckingCore = false;
  ReleaseInfo? _guiRelease;
  ReleaseInfo? _coreRelease;
  Map<String, String> _coreChecksums = const {};

  double? _coreDownloadProgress;
  String? _coreDownloadStatus;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _mirrorCtrl = TextEditingController(text: state.githubMirror);
    unawaited(_inspectBinaries());
  }

  @override
  void dispose() {
    _mirrorCtrl.dispose();
    super.dispose();
  }

  Future<void> _inspectBinaries() async {
    final state = context.read<AppState>();

    final agentPath = await state.binaryManager.resolveAgentPath();
    final agentInfo = await state.binaryManager.inspectBinary(agentPath);

    final signalPath = await state.binaryManager.resolveSignalPath();
    final signalInfo = await state.binaryManager.inspectBinary(signalPath);

    if (mounted) {
      setState(() {
        _agentValid = agentInfo.isValid;
        _signalValid = signalInfo.isValid;
        _detectedAgentVersion =
            agentInfo.version ?? agentInfo.error ?? '未检测到可用程序';
        _detectedSignalVersion =
            signalInfo.version ?? signalInfo.error ?? '未检测到可用程序';
      });
    }
  }

  Future<void> _chooseCustomAgentBinary() async {
    final state = context.read<AppState>();
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      await state.binaryManager.setCustomAgentPath(result.first.path);
      await _inspectBinaries();
      if (mounted) setState(() {});
    }
  }

  Future<void> _resetCustomAgentBinary() async {
    final state = context.read<AppState>();
    await state.binaryManager.setCustomAgentPath(null);
    await _inspectBinaries();
    if (mounted) setState(() {});
  }

  Future<void> _chooseCustomSignalBinary() async {
    final state = context.read<AppState>();
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      await state.binaryManager.setCustomSignalPath(result.first.path);
      await _inspectBinaries();
      if (mounted) setState(() {});
    }
  }

  Future<void> _resetCustomSignalBinary() async {
    final state = context.read<AppState>();
    await state.binaryManager.setCustomSignalPath(null);
    await _inspectBinaries();
    if (mounted) setState(() {});
  }

  Future<void> _checkGuiUpdate() async {
    final i18n = AppI18n();
    setState(() => _isCheckingGui = true);
    final mirror = _mirrorCtrl.text.trim();
    final info = await UpdateService.fetchLatestRelease(
      UpdateService.repoGui,
      mirrorPrefix: mirror,
    );
    if (mounted) {
      setState(() {
        _isCheckingGui = false;
        _guiRelease = info;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            info != null
                ? i18n.pick('已获取 GUI 最新版本: ${info.tagName}', 'Latest GUI: ${info.tagName}')
                : i18n.pick('检查 GUI 更新失败，请检查网络或更换代理', 'Failed to check GUI updates'),
          ),
        ),
      );
    }
  }

  Future<void> _checkCoreUpdate() async {
    final i18n = AppI18n();
    setState(() => _isCheckingCore = true);
    final mirror = _mirrorCtrl.text.trim();
    final info = await UpdateService.fetchLatestRelease(
      UpdateService.repoCore,
      mirrorPrefix: mirror,
    );
    Map<String, String> sums = const {};
    if (info != null) {
      sums = await UpdateService.fetchChecksums(info, mirrorPrefix: mirror);
    }
    if (mounted) {
      setState(() {
        _isCheckingCore = false;
        _coreRelease = info;
        _coreChecksums = sums;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            info != null
                ? i18n.pick('已获取 Go 核心最新版本: ${info.tagName}', 'Latest Core: ${info.tagName}')
                : i18n.pick('检查 Go 核心更新失败，请检查网络或更换代理', 'Failed to check Core updates'),
          ),
        ),
      );
    }
  }

  Future<void> _downloadCoreAsset(ReleaseAsset asset) async {
    final state = context.read<AppState>();
    final hasRunningCore = state.runningCount > 0 || state.isSignalRunning();

    setState(() {
      _coreDownloadProgress = 0.01;
      _coreDownloadStatus = '准备下载 ${asset.name}...';
    });

    final mirror = _mirrorCtrl.text.trim();
    final msg = await UpdateService.downloadAndInstallCoreAsset(
      asset: asset,
      mirrorPrefix: mirror,
      expectedSha256: _coreChecksums[asset.name],
      hasRunningCore: hasRunningCore,
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
      state.binaryManager.clearInspectCache();
      await _inspectBinaries();
      if (!mounted) return;
      if (hasRunningCore) {
        setState(() {
          _coreDownloadProgress = null;
          _coreDownloadStatus = null;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
      );
    }
  }

  Future<void> _exportAllConfig() async {
    final state = context.read<AppState>();
    final i18n = AppI18n();
    final bundle = {
      'version': 1,
      'settings': state.appSettings.toJson(),
      'signal': state.signalConfig.toJson(),
      'agents': state.profiles.map((p) => p.toJson()).toList(),
    };
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(bundle)),
    );
    final uri = await FilePicker.saveFile(
      dialogTitle: i18n.pick('导出全量配置文件', 'Export Full Config Bundle'),
      fileName: 'webrtc_gateway_full_config.json',
      bytes: bytes,
    );
    if (uri != null && mounted) {
      final pathText =
          uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.pick('已成功导出到: $pathText', 'Exported to: $pathText'))),
      );
    }
  }

  Future<void> _exportUpstreamAgentYaml() async {
    final state = context.read<AppState>();
    final i18n = AppI18n();
    if (state.profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.pick('当前暂无穿透节点，请先添加节点', 'No agents to export'))),
      );
      return;
    }

    AgentProfile? chosen = state.profiles.first;
    if (state.profiles.length > 1) {
      chosen = await showDialog<AgentProfile>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(i18n.pick('选择要导出的穿透节点', 'Select Agent to Export')),
          children: state.profiles
              .map(
                (p) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(p),
                  child: Text('${p.name} (${p.nodeId})'),
                ),
              )
              .toList(),
        ),
      );
      if (chosen == null || !mounted) return;
    }

    final yamlStr = chosen.toYamlString();
    final bytes = Uint8List.fromList(utf8.encode(yamlStr));
    final uri = await FilePicker.saveFile(
      dialogTitle: i18n.pick('导出源项目标准 agent.yaml', 'Export agent.yaml'),
      fileName: 'agent.${chosen.nodeId}.yaml',
      bytes: bytes,
    );
    if (uri != null && mounted) {
      final pathText =
          uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.pick('已成功导出 agent.yaml 到: $pathText', 'Exported agent.yaml to: $pathText'),
          ),
        ),
      );
    }
  }

  Future<void> _exportUpstreamSignalYaml() async {
    final state = context.read<AppState>();
    final i18n = AppI18n();
    final yamlStr = state.signalConfig.toYamlString();
    final bytes = Uint8List.fromList(utf8.encode(yamlStr));
    final uri = await FilePicker.saveFile(
      dialogTitle: i18n.pick('导出源项目标准 server.yaml', 'Export server.yaml'),
      fileName: 'server.yaml',
      bytes: bytes,
    );
    if (uri != null && mounted) {
      final pathText =
          uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.pick('已成功导出 server.yaml 到: $pathText', 'Exported server.yaml to: $pathText'),
          ),
        ),
      );
    }
  }

  Future<void> _importAnyConfig() async {
    final state = context.read<AppState>();
    final i18n = AppI18n();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml', 'json'],
    );
    if (result.isEmpty || result.first.path == null) return;

    try {
      final summary = await state.importConfigFile(result.first.path!);
      if (!mounted) return;
      final agentsCount = summary['agents'] as int? ?? 0;
      final signalUpdated = summary['signal'] as bool? ?? false;
      final settingsUpdated = summary['settings'] as bool? ?? false;

      if (settingsUpdated) {
        _mirrorCtrl.text = state.githubMirror;
      }

      final parts = <String>[];
      if (agentsCount > 0) parts.add('$agentsCount ${i18n.pick("个节点", "agent(s)")}');
      if (signalUpdated) parts.add(i18n.pick('信令服务配置', 'signal config'));
      if (settingsUpdated) parts.add(i18n.pick('全局偏好设置', 'app settings'));

      final msg = parts.isNotEmpty
          ? '${i18n.pick("已成功导入:", "Imported:")} ${parts.join(", ")}'
          : i18n.pick('未在配置文件中识别到可导入项', 'No importable items found');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(i18n.pick('导入配置文件失败: $e', 'Import failed: $e')),
          ),
        );
      }
    }
  }

  bool _isRecommendedForHostPlatform(String assetName) {
    final lower = assetName.toLowerCase();
    if (Platform.isWindows) {
      return lower.contains('windows') && lower.contains('amd64');
    } else if (Platform.isLinux) {
      return lower.contains('linux') && lower.contains('amd64');
    } else if (Platform.isMacOS) {
      return lower.contains('darwin');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final customAgent = state.binaryManager.customAgentPath;
    final customSignal = state.binaryManager.customSignalPath;
    final isPortable = state.configRepo.isPortable;
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurfaceVariant;

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.desktop_windows_rounded,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        i18n.pick('桌面与系统行为 (System & Behavior)', 'System & Desktop Behavior'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.power_settings_new_rounded,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      i18n.pick('开机静默自启动 (Launch at Startup)', 'Launch Minimized at Startup'),
                    ),
                    subtitle: Text(
                      i18n.pick(
                        '系统登录时自动启动并缩入托盘，配合节点的“随软件启动”即可实现后台无感穿透',
                        'Starts minimized in tray on login (enable node auto-start in Agent settings)',
                      ),
                    ),
                    trailing: _isTogglingAutostart
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: state.startOnBoot,
                            activeThumbColor: Colors.blueAccent,
                            onChanged: (val) async {
                              setState(() => _isTogglingAutostart = true);
                              await state.setStartOnBoot(val);
                              if (mounted) {
                                setState(() => _isTogglingAutostart = false);
                              }
                            },
                          ),
                  ),
                  const Divider(height: 20),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.close_fullscreen_rounded,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      i18n.pick('点击主窗口关闭按钮时 (On Window Close)', 'On Window Close'),
                    ),
                    subtitle: Text(
                      i18n.pick('配置点击右上角 "X" 按钮时的默认行为', 'Action when clicking the close button'),
                    ),
                    trailing: DropdownButton<CloseAction>(
                      value: state.closeAction,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: CloseAction.prompt,
                          child: Text(i18n.pick('每次询问确认 (Prompt)', 'Ask every time')),
                        ),
                        DropdownMenuItem(
                          value: CloseAction.minimizeToTray,
                          child: Text(i18n.pick('最小化到托盘 (Minimize to Tray)', 'Minimize to Tray')),
                        ),
                        DropdownMenuItem(
                          value: CloseAction.exitApp,
                          child: Text(i18n.pick('直接退出程序 (Exit)', 'Exit Application')),
                        ),
                      ],
                      onChanged: (action) {
                        if (action != null) state.setCloseAction(action);
                      },
                    ),
                  ),
                  const Divider(height: 20),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined, color: Colors.blueAccent),
                    title: Text(i18n.t('settings_theme_label')),
                    subtitle: Text(
                      i18n.pick('支持浅色、深色模式或跟随系统外观', 'Choose Light, Dark, or System appearance'),
                    ),
                    trailing: DropdownButton<AppThemePreference>(
                      value: state.themePreference,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: AppThemePreference.system,
                          child: Text(i18n.t('settings_theme_system')),
                        ),
                        DropdownMenuItem(
                          value: AppThemePreference.light,
                          child: Text(i18n.t('settings_theme_light')),
                        ),
                        DropdownMenuItem(
                          value: AppThemePreference.dark,
                          child: Text(i18n.t('settings_theme_dark')),
                        ),
                      ],
                      onChanged: (pref) {
                        if (pref != null) state.setThemePreference(pref);
                      },
                    ),
                  ),
                  const Divider(height: 20),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.folder_special_rounded,
                      color: Colors.green,
                    ),
                    title: Text(
                      i18n.pick('存储模式 (Storage Mode)', 'Storage Mode'),
                    ),
                    subtitle: Text(
                      isPortable
                          ? i18n.pick(
                              '当前启用绿色便携模式：配置文件保存在程序目录下的 "data/webrtc_gateway_config.json"。',
                              'Portable Mode: config stored in local "data/webrtc_gateway_config.json".',
                            )
                          : i18n.pick(
                              '当前运行在受保护目录，配置文件存储在系统应用数据目录中。',
                              'Standard Mode: config stored in OS application support directory.',
                            ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Chip(
                      backgroundColor:
                          (isPortable ? Colors.green : muted).withValues(alpha: 0.12),
                      label: Text(
                        isPortable
                            ? i18n.pick('便携免安装 (Portable)', 'Portable')
                            : i18n.pick('标准目录', 'Standard'),
                        style: TextStyle(
                          color: isPortable ? Colors.green : muted,
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.format_size_rounded,
                        color: Colors.indigoAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        i18n.pick('界面缩放与字体显示 (Display & MiSans)', 'Display & Font Scaling'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: state.resetDisplayScaling,
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: Text(i18n.pick('恢复默认比例', 'Reset')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      SizedBox(
                        width: 170,
                        child: Text(
                          i18n.pick('全局字体大小缩放:', 'Font Scale:'),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: state.fontScale,
                          min: 0.80,
                          max: 1.40,
                          divisions: 12,
                          label: '${(state.fontScale * 100).toInt()}%',
                          onChanged: state.setFontScale,
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${(state.fontScale * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      i18n.pick('自动跟随系统 DPI 缩放 (Auto-detect DPI)', 'Follow OS DPI Scaling'),
                    ),
                    subtitle: Text(
                      i18n.pick(
                        '开启后由系统原生 Per-Monitor DPI 负责清晰渲染，推荐保持开启',
                        'Uses native OS Per-Monitor DPI scaling (recommended)',
                      ),
                    ),
                    trailing: Switch(
                      value: state.autoDpi,
                      activeThumbColor: Colors.indigoAccent,
                      onChanged: state.setAutoDpi,
                    ),
                  ),

                  if (!state.autoDpi) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 170,
                          child: Text(
                            i18n.pick('自定义界面缩放倍率:', 'Custom UI Scale:'),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: state.customDpiScale,
                            min: 0.75,
                            max: 2.00,
                            divisions: 25,
                            label: '${(state.customDpiScale * 100).toInt()}%',
                            onChanged: state.setCustomDpiScale,
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${(state.customDpiScale * 100).toInt()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigoAccent,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          i18n.pick('快捷档位: ', 'Quick presets: '),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
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

          // 3. Binary Management Card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.terminal_rounded,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        i18n.pick('底层核心可执行程序管理 (Core Binaries)', 'Core Binary Management'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.pick(
                      '穿透节点核心与信令服务核心分别支持自定义路径及 -help 版本自省：',
                      'Agent & Signal core binaries support custom overrides and version detection:',
                    ),
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Agent Binary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.hub_outlined,
                              color: Colors.blueAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              i18n.pick('Agent 穿透节点核心', 'Agent Core Binary'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            if (_detectedAgentVersion != null)
                              Chip(
                                avatar: Icon(
                                  _agentValid
                                      ? Icons.verified_rounded
                                      : Icons.error_outline_rounded,
                                  size: 14,
                                  color: _agentValid
                                      ? Colors.green
                                      : Colors.redAccent,
                                ),
                                label: Text(
                                  _detectedAgentVersion!,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                ),
                                child: Text(
                                  customAgent ??
                                      i18n.pick('默认使用内置核心 (bin/agent)', 'Built-in binary (bin/agent)'),
                                  style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontFamilyFallback: const [
                                      'Courier New',
                                      'monospace',
                                    ],
                                    fontSize: 12,
                                    color: customAgent != null
                                        ? Colors.blueAccent
                                        : muted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  unawaited(_chooseCustomAgentBinary()),
                              icon: const Icon(Icons.folder_open_rounded, size: 16),
                              label: Text(i18n.t('common_browse')),
                            ),
                            if (customAgent != null) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: i18n.pick('恢复内置 agent', 'Reset to built-in'),
                                icon: const Icon(
                                  Icons.restore_rounded,
                                  color: Colors.orangeAccent,
                                ),
                                onPressed: () =>
                                    unawaited(_resetCustomAgentBinary()),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Signal Binary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.purpleAccent.withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.dns_outlined,
                              color: Colors.purpleAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              i18n.pick('Signal 信令服务核心', 'Signal Server Core Binary'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            if (_detectedSignalVersion != null)
                              Chip(
                                avatar: Icon(
                                  _signalValid
                                      ? Icons.verified_rounded
                                      : Icons.error_outline_rounded,
                                  size: 14,
                                  color: _signalValid
                                      ? Colors.green
                                      : Colors.redAccent,
                                ),
                                label: Text(
                                  _detectedSignalVersion!,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                ),
                                child: Text(
                                  customSignal ??
                                      i18n.pick('默认使用内置信令 (bin/signal)', 'Built-in binary (bin/signal)'),
                                  style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontFamilyFallback: const [
                                      'Courier New',
                                      'monospace',
                                    ],
                                    fontSize: 12,
                                    color: customSignal != null
                                        ? Colors.purpleAccent
                                        : muted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  unawaited(_chooseCustomSignalBinary()),
                              icon: const Icon(Icons.folder_open_rounded, size: 16),
                              label: Text(i18n.t('common_browse')),
                            ),
                            if (customSignal != null) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: i18n.pick('恢复内置 signal', 'Reset to built-in'),
                                icon: const Icon(
                                  Icons.restore_rounded,
                                  color: Colors.orangeAccent,
                                ),
                                onPressed: () =>
                                    unawaited(_resetCustomSignalBinary()),
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

          // 4. Backup / Restore Card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.backup_rounded, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        i18n.pick('配置导入与导出备份 (Config Management)', 'Config Backup & Restore'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.pick(
                      '支持全量打包备份为 JSON，或分项导出上游兼容的 agent.yaml / server.yaml 并智能导入还原。',
                      'Export full JSON bundles or upstream-compatible agent.yaml / server.yaml files.',
                    ),
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => unawaited(_exportAllConfig()),
                        icon: const Icon(Icons.save_alt_rounded, size: 16),
                        label: Text(i18n.pick('全量打包导出 (.json)', 'Export Bundle (.json)')),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => unawaited(_exportUpstreamAgentYaml()),
                        icon: const Icon(Icons.save_alt_rounded, size: 16),
                        label: Text(i18n.pick('导出源项目 agent.yaml', 'Export agent.yaml')),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => unawaited(_exportUpstreamSignalYaml()),
                        icon: const Icon(Icons.save_alt_rounded, size: 16),
                        label: Text(i18n.pick('导出源项目 server.yaml', 'Export server.yaml')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => unawaited(_importAnyConfig()),
                        icon: const Icon(Icons.file_open_rounded, size: 16),
                        label: Text(i18n.pick('导入配置 (.yaml / .yml / .json)', 'Import (.yaml / .json)')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Updates & Mirror Card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.system_update_rounded,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        i18n.pick('检查更新与在线升级 (GUI & Core Updates)', 'Software & Core Updates'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.pick(
                      'GUI 客户端更新与底层 Go 核心更新相互独立，支持 GitHub 公共加速代理及 SHA256 自动校验解压安装：',
                      'Decoupled GUI & Go Core updates with GitHub proxy mirror and automatic SHA256 verification:',
                    ),
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Text(
                        i18n.pick('更新下载加速代理: ', 'GitHub Mirror: '),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: UpdateService.presetMirrors
                                .contains(_mirrorCtrl.text)
                            ? _mirrorCtrl.text
                            : null,
                        hint: Text(i18n.pick('选择公共代理预设', 'Mirror preset')),
                        underline: const SizedBox(),
                        items: UpdateService.presetMirrors
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m, style: const TextStyle(fontSize: 13)),
                              ),
                            )
                            .toList(),
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Consolas',
                            fontFamilyFallback: ['Courier New', 'monospace'],
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'https://ghproxy.net/',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: state.setGithubMirror,
                          onSubmitted: state.setGithubMirror,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // GUI Update
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i18n.pick('GUI 客户端版本 (WebRTC-Gateway-GUI)', 'GUI Client (WebRTC-Gateway-GUI)'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'v1.0.0 | Flutter 3.50 / Dart 3.14',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (_guiRelease != null) ...[
                          Text(
                            '${i18n.pick("最新", "Latest")}: ${_guiRelease!.tagName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: () {
                              final targetUrl =
                                  UpdateService.formatUrlWithMirror(
                                _guiRelease!.htmlUrl,
                                _mirrorCtrl.text,
                              );
                              unawaited(
                                DesktopService.openExternalUrl(targetUrl),
                              );
                            },
                            child: Text(i18n.pick('前往发布页下载', 'Open Release Page')),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: _isCheckingGui
                              ? null
                              : () => unawaited(_checkGuiUpdate()),
                          icon: _isCheckingGui
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded, size: 16),
                          label: Text(i18n.pick('检查 GUI 更新', 'Check GUI')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Core Update
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.05),
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
                                Text(
                                  i18n.pick('底层 Go 核心版本 (WebRTC-Gateway Core)', 'Go Core (WebRTC-Gateway)'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${i18n.pick("当前核心", "Detected")}: ${_detectedAgentVersion ?? i18n.pick("检测中...", "Inspecting...")}',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (_coreRelease != null) ...[
                              Text(
                                '${i18n.pick("上游最新", "Upstream")}: ${_coreRelease!.tagName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            OutlinedButton.icon(
                              onPressed: _isCheckingCore
                                  ? null
                                  : () => unawaited(_checkCoreUpdate()),
                              icon: _isCheckingCore
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync_rounded, size: 16),
                              label: Text(i18n.pick('检查底层核心更新', 'Check Core')),
                            ),
                          ],
                        ),

                        if (_coreDownloadProgress != null) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: _coreDownloadProgress),
                          const SizedBox(height: 4),
                          Text(
                            _coreDownloadStatus ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],

                        if (_coreRelease != null &&
                            _coreRelease!.assets.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            i18n.pick(
                              '可供一键更新的发布包（将自动解压安装 agent 与 signal）：',
                              'Available packages (auto-extracts & installs agent and signal):',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _coreRelease!.assets
                                .where(
                                  (a) => !a.name.toUpperCase().contains('SHA256SUMS'),
                                )
                                .map((asset) {
                              final isRecommended =
                                  _isRecommendedForHostPlatform(asset.name);
                              return ActionChip(
                                avatar: Icon(
                                  isRecommended
                                      ? Icons.star_rounded
                                      : Icons.archive_outlined,
                                  size: 14,
                                  color: isRecommended
                                      ? Colors.blueAccent
                                      : muted,
                                ),
                                label: Text(
                                  '${asset.name} (${(asset.size / (1024 * 1024)).toStringAsFixed(1)} MB)'
                                  '${isRecommended ? i18n.pick(" [本机推荐]", " [Recommended]") : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isRecommended
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                onPressed: _coreDownloadProgress != null &&
                                        _coreDownloadProgress! < 1.0
                                    ? null
                                    : () => unawaited(_downloadCoreAsset(asset)),
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
