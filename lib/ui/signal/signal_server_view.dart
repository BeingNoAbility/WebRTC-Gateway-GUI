import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/i18n.dart';
import '../../models/runtime_state.dart';
import '../../services/desktop_service.dart';
import '../../state/app_state.dart';
import '../logs/live_log_dialog.dart';

class SignalServerView extends StatefulWidget {
  const SignalServerView({super.key});

  @override
  State<SignalServerView> createState() => _SignalServerViewState();
}

class _SignalServerViewState extends State<SignalServerView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _addrCtrl;
  late TextEditingController _staticCtrl;
  late TextEditingController _metricsCtrl;
  late bool _tlsAuto;
  late bool _autoStart;
  late TextEditingController _tlsCertCtrl;
  late TextEditingController _tlsKeyCtrl;
  late TextEditingController _allowedOriginsCtrl;
  late TextEditingController _portalDomainCtrl;
  late TextEditingController _signalSecretCtrl;
  late TextEditingController _trustedProxiesCtrl;
  late TextEditingController _maxIpConnsCtrl;

  bool _showSignalSecret = false;
  bool _isProbingHealth = false;
  String? _healthResult;

  final ScrollController _signalLogScrollCtrl = ScrollController();
  bool _signalLogsAutoScroll = true;
  int _lastSignalLogVersion = -1;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<AppState>().signalConfig;
    _addrCtrl = TextEditingController(text: cfg.addr);
    _staticCtrl = TextEditingController(text: cfg.staticDir);
    _metricsCtrl = TextEditingController(text: cfg.metricsAddr);
    _tlsAuto = cfg.tlsAuto;
    _autoStart = cfg.autoStart;
    _tlsCertCtrl = TextEditingController(text: cfg.tlsCert);
    _tlsKeyCtrl = TextEditingController(text: cfg.tlsKey);
    _allowedOriginsCtrl = TextEditingController(text: cfg.allowedOrigins);
    _portalDomainCtrl = TextEditingController(text: cfg.portalDomain);
    _signalSecretCtrl = TextEditingController(text: cfg.signalSecret);
    _trustedProxiesCtrl = TextEditingController(text: cfg.trustedProxies);
    _maxIpConnsCtrl = TextEditingController(text: cfg.maxIpConns.toString());
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _staticCtrl.dispose();
    _metricsCtrl.dispose();
    _tlsCertCtrl.dispose();
    _tlsKeyCtrl.dispose();
    _allowedOriginsCtrl.dispose();
    _portalDomainCtrl.dispose();
    _signalSecretCtrl.dispose();
    _trustedProxiesCtrl.dispose();
    _maxIpConnsCtrl.dispose();
    _signalLogScrollCtrl.dispose();
    super.dispose();
  }

  String _generateSecret([int length = 20]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final rand = Random.secure();
    return List<String>.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  void _syncConfig(AppState state) {
    state.signalConfig.addr = _addrCtrl.text.trim();
    state.signalConfig.staticDir = _staticCtrl.text.trim();
    state.signalConfig.metricsAddr = _metricsCtrl.text.trim();
    state.signalConfig.tlsAuto = _tlsAuto;
    state.signalConfig.autoStart = _autoStart;
    state.signalConfig.tlsCert = _tlsCertCtrl.text.trim();
    state.signalConfig.tlsKey = _tlsKeyCtrl.text.trim();
    state.signalConfig.allowedOrigins = _allowedOriginsCtrl.text.trim();
    state.signalConfig.portalDomain = _portalDomainCtrl.text.trim();
    state.signalConfig.signalSecret = _signalSecretCtrl.text.trim();
    state.signalConfig.trustedProxies = _trustedProxiesCtrl.text.trim();
    state.signalConfig.maxIpConns =
        (int.tryParse(_maxIpConnsCtrl.text.trim()) ?? 64).clamp(1, 65535);
    state.syncSignalConfig();
  }

  Future<void> _pickStaticDir() async {
    final uri = await FilePicker.pickDirectory();
    if (uri != null && mounted) {
      setState(() => _staticCtrl.text = uri.toFilePath());
    }
  }

  Future<void> _pickCert() async {
    final res = await FilePicker.pickFiles();
    if (res.isNotEmpty && res.first.path != null && mounted) {
      setState(() => _tlsCertCtrl.text = res.first.path!);
    }
  }

  Future<void> _pickKey() async {
    final res = await FilePicker.pickFiles();
    if (res.isNotEmpty && res.first.path != null && mounted) {
      setState(() => _tlsKeyCtrl.text = res.first.path!);
    }
  }

  Future<void> _runHealthCheck(AppState state) async {
    final i18n = AppI18n();
    setState(() {
      _isProbingHealth = true;
      _healthResult = null;
    });

    final healthy = await state.probeSignalHealth();

    if (mounted) {
      setState(() {
        _isProbingHealth = false;
        _healthResult = healthy
            ? i18n.pick('健康检查通过 (HTTP 200 OK /healthz)', 'Health check OK (200 /healthz)')
            : i18n.pick('探针未响应或服务未就绪', 'Probe failed or service not ready');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_healthResult!),
          backgroundColor: healthy ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _exportConfig(AppState state) async {
    final i18n = AppI18n();
    _syncConfig(state);
    final yamlStr = state.signalConfig.toYamlString();
    final bytes = Uint8List.fromList(utf8.encode(yamlStr));
    final uri = await FilePicker.saveFile(
      dialogTitle: i18n.pick('导出源项目标准 server.yaml 配置文件', 'Export server.yaml'),
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

  Future<void> _importConfig(AppState state) async {
    final i18n = AppI18n();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml', 'json'],
    );
    if (result.isEmpty || result.first.path == null) return;

    try {
      final summary = await state.importConfigFile(result.first.path!);
      final cfg = state.signalConfig;
      setState(() {
        _addrCtrl.text = cfg.addr;
        _staticCtrl.text = cfg.staticDir;
        _metricsCtrl.text = cfg.metricsAddr;
        _tlsAuto = cfg.tlsAuto;
        _autoStart = cfg.autoStart;
        _tlsCertCtrl.text = cfg.tlsCert;
        _tlsKeyCtrl.text = cfg.tlsKey;
        _allowedOriginsCtrl.text = cfg.allowedOrigins;
        _portalDomainCtrl.text = cfg.portalDomain;
        _signalSecretCtrl.text = cfg.signalSecret;
        _trustedProxiesCtrl.text = cfg.trustedProxies;
        _maxIpConnsCtrl.text = cfg.maxIpConns.toString();
      });
      if (mounted) {
        final signalUpdated = summary['signal'] as bool? ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              signalUpdated
                  ? i18n.pick('已成功导入并加载 server.yaml 信令配置', 'Signal config imported')
                  : i18n.pick('未在文件中检测到信令配置', 'No signal config found in file'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(i18n.pick('导入失败: $e', 'Import failed: $e')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n();
    final isRunning = state.isSignalRunning();
    final runtime = state.signalState;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    var statusColor = isRunning ? Colors.green : muted;
    var statusText = isRunning
        ? '${i18n.t("agent_status_running")} (Running)'
        : '${i18n.t("agent_status_stopped")} (Stopped)';
    if (runtime.status == ProcessStatus.starting) {
      statusColor = Colors.orange;
      statusText = i18n.t('agent_status_starting');
    } else if (runtime.status == ProcessStatus.stopping) {
      statusColor = Colors.orangeAccent;
      statusText = i18n.t('agent_status_stopping');
    } else if (runtime.status == ProcessStatus.error) {
      statusColor = Colors.redAccent;
      statusText = i18n.t('agent_status_error');
    }

    final webUrl = state.signalConfig.portalWebUrl;
    final noSecret = _signalSecretCtrl.text.trim().isEmpty;
    final wildcardOrigin = _allowedOriginsCtrl.text.trim() == '*';
    final plainHttp = !_tlsAuto && _tlsCertCtrl.text.trim().isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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
                    i18n.t('signal_server_title'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    i18n.t('signal_server_desc'),
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_exportConfig(state)),
                    icon: const Icon(Icons.save_alt_rounded, size: 16),
                    label: Text(i18n.pick('导出配置', 'Export')),
                  ),
                  OutlinedButton.icon(
                    onPressed: isRunning
                        ? null
                        : () => unawaited(_importConfig(state)),
                    icon: const Icon(Icons.file_open_rounded, size: 16),
                    label: Text(i18n.pick('导入配置', 'Import')),
                  ),
                  if (isRunning)
                    OutlinedButton.icon(
                      onPressed: () => unawaited(_runHealthCheck(state)),
                      icon: _isProbingHealth
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.health_and_safety_outlined,
                              size: 18,
                            ),
                      label: Text(i18n.t('signal_health_btn')),
                    ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isRunning ? Colors.redAccent : Colors.purpleAccent,
                    ),
                    onPressed: () {
                      if (isRunning) {
                        unawaited(state.stopSignalServer());
                      } else {
                        if (_formKey.currentState?.validate() ?? true) {
                          _syncConfig(state);
                          unawaited(state.startSignalServer());
                        }
                      }
                    },
                    icon: Icon(
                      isRunning
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      isRunning
                          ? i18n.t('signal_stop_btn')
                          : i18n.t('signal_start_btn'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Status Banner Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: statusColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: isRunning
                          ? [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              statusText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isRunning && runtime.pid != null)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  'PID: ${runtime.pid} | ${state.signalConfig.addr}',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (isRunning) ...[
                          Row(
                            children: [
                              Text(
                                '${i18n.pick("Web 控制台入口:", "Portal URL:")} ',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                              SelectableText(
                                webUrl,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            runtime.lastError ??
                                i18n.pick(
                                  '信令服务负责管理集群内节点发现与 WebRTC ICE/SDP 撮合，并内置免客户端 Web Portal。',
                                  'Coordinates WebRTC SDP/ICE signaling and hosts the built-in zero-client Web Portal.',
                                ),
                            style: TextStyle(
                              color: runtime.lastError != null
                                  ? Colors.redAccent
                                  : muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isRunning) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        LiveLogDialog.show(
                          context,
                          title: i18n.t('logs_signal_node'),
                          profileId: '__signal__',
                          isSignal: true,
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: Text(i18n.pick('查看日志', 'Logs')),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          unawaited(DesktopService.openExternalUrl(webUrl)),
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: Text(i18n.t('signal_open_portal')),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (noSecret || wildcardOrigin || plainHttp) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.shade700.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        color: Colors.amber.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        i18n.pick('信令服务安全提醒', 'Signal Server Security Advisories'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (noSecret)
                    Text(
                      i18n.pick(
                        '• 未设置集群准入密钥 (-signal-secret)：任意知道此端口的节点均可注册任意 Node ID，公网/多人网络下存在节点劫持风险。',
                        '• No cluster secret (-signal-secret): Any external agent can register and claim Node IDs.',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (wildcardOrigin)
                    Text(
                      i18n.pick(
                        '• 跨域白名单为通配符 "*"：允许任意第三方网页发起 WebSocket 握手 (CSWSH 风险)。同域部署建议留空。',
                        '• Wildcard "*" allowed origins permits cross-site WebSockets. Leave empty for strict same-origin.',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (plainHttp)
                    Text(
                      i18n.pick(
                        '• 未开启 HTTPS (-tls-auto 且未配置证书)：除 localhost 外，远程浏览器会禁用 Service Worker，建议开启自签 TLS 或配置域名证书。',
                        '• Plain HTTP active: Remote browsers require HTTPS to register Service Workers.',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // 2. CLI Options Configuration
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Colors.purpleAccent),
                        const SizedBox(width: 8),
                        Text(
                          i18n.pick('信令服务参数配置 (CLI Options)', 'Signal Server Options'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        i18n.pick('随软件启动自动拉起本地信令服务', 'Auto-start local signal server on launch'),
                      ),
                      value: _autoStart,
                      onChanged: isRunning
                          ? null
                          : (v) {
                              setState(() => _autoStart = v ?? false);
                              _syncConfig(state);
                            },
                    ),
                    const SizedBox(height: 12),

                    // Section A
                    Text(
                      i18n.pick('A. 服务与监听配置 (Server & Network)', 'A. Server & Network'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _addrCtrl,
                            enabled: !isRunning,
                            decoration: InputDecoration(
                              labelText: i18n.pick('HTTP/WS 监听地址 (-addr)', 'Listen Address (-addr)'),
                              hintText: ':8888 或 0.0.0.0:8888',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(
                                Icons.settings_input_component_rounded,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? i18n.pick('监听地址不能为空', 'Required')
                                : null,
                            onChanged: (_) => _syncConfig(state),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _metricsCtrl,
                            enabled: !isRunning,
                            decoration: InputDecoration(
                              labelText: i18n.pick('Prometheus 指标地址 (-metrics-addr)', 'Metrics Addr (-metrics-addr)'),
                              hintText: ':9090',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.analytics_outlined),
                            ),
                            onChanged: (_) => _syncConfig(state),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _staticCtrl,
                            enabled: !isRunning,
                            decoration: InputDecoration(
                              labelText: i18n.pick('外部 Web 静态目录 (-static)', 'Static Portal Dir (-static)'),
                              hintText: i18n.pick('留空使用内置嵌入式 Web 门户控制台', 'Empty uses built-in Web Portal'),
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.folder_copy_outlined),
                            ),
                            onChanged: (_) => _syncConfig(state),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed:
                              isRunning ? null : () => unawaited(_pickStaticDir()),
                          child: Text(i18n.t('common_browse')),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Section B
                    Text(
                      i18n.pick('B. TLS / HTTPS 安全凭据 (TLS & HTTPS)', 'B. TLS & HTTPS'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        i18n.pick('内存自签 ECDSA 证书开启 (-tls-auto)', 'Auto In-Memory Self-Signed TLS (-tls-auto)'),
                      ),
                      subtitle: Text(
                        i18n.pick(
                          '自动生成覆盖 localhost 与局域网 IP 的证书以激活浏览器 Service Worker 安全上下文',
                          'Generates self-signed HTTPS certificate for localhost and LAN IPs',
                        ),
                      ),
                      value: _tlsAuto,
                      onChanged: isRunning
                          ? null
                          : (v) {
                              setState(() => _tlsAuto = v ?? true);
                              _syncConfig(state);
                            },
                    ),
                    if (!_tlsAuto) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tlsCertCtrl,
                              enabled: !isRunning,
                              decoration: InputDecoration(
                                labelText: i18n.pick('TLS 证书 PEM 路径 (-tls-cert)', 'TLS Cert PEM (-tls-cert)'),
                                hintText: r'C:\certs\fullchain.pem',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                                _syncConfig(state);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed:
                                isRunning ? null : () => unawaited(_pickCert()),
                            child: Text(i18n.t('common_browse')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tlsKeyCtrl,
                              enabled: !isRunning,
                              decoration: InputDecoration(
                                labelText: i18n.pick('TLS 私钥 PEM 路径 (-tls-key)', 'TLS Key PEM (-tls-key)'),
                                hintText: r'C:\certs\privkey.pem',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                                _syncConfig(state);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed:
                                isRunning ? null : () => unawaited(_pickKey()),
                            child: Text(i18n.t('common_browse')),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Section C
                    Text(
                      i18n.pick('C. 安全鉴权与防劫持 (Security & Origins)', 'C. Security & Origins'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _signalSecretCtrl,
                      enabled: !isRunning,
                      obscureText: !_showSignalSecret,
                      onChanged: (_) {
                        setState(() {});
                        _syncConfig(state);
                      },
                      decoration: InputDecoration(
                        labelText: i18n.pick('集群准入预共享密钥 (-signal-secret)', 'Cluster Pre-Shared Secret (-signal-secret)'),
                        helperText: i18n.pick('连接的 Agent 必须匹配此密钥才允许注册节点', 'Agents must match this secret to register'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isRunning)
                              IconButton(
                                tooltip: i18n.pick('生成随机集群密钥', 'Generate Random Secret'),
                                icon: const Icon(Icons.casino_outlined, size: 19),
                                onPressed: () {
                                  setState(() {
                                    _signalSecretCtrl.text = _generateSecret();
                                    _showSignalSecret = true;
                                  });
                                  _syncConfig(state);
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                _showSignalSecret
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _showSignalSecret = !_showSignalSecret,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _allowedOriginsCtrl,
                      enabled: !isRunning,
                      onChanged: (_) {
                        setState(() {});
                        _syncConfig(state);
                      },
                      decoration: InputDecoration(
                        labelText: i18n.pick('WebSocket 允许跨域白名单 (-allowed-origins)', 'Allowed Origins (-allowed-origins)'),
                        hintText: i18n.pick('推荐留空（仅同源），或填写 https://*.pages.dev', 'Empty = strict same-origin'),
                        helperText: i18n.pick(
                          '留空最安全（严格同源）；若外部独立域名托管 Portal 再填写白名单，非调试不建议填 *',
                          'Empty enforces strict same-origin (safest). Avoid "*" outside local debug.',
                        ),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.security_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          i18n.pick('快捷填充: ', 'Quick fill: '),
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        ActionChip(
                          label: Text(
                            i18n.pick('严格同源 (推荐/留空)', 'Strict Same-Origin (Empty)'),
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: isRunning
                              ? null
                              : () {
                                  setState(() => _allowedOriginsCtrl.clear());
                                  _syncConfig(state);
                                },
                        ),
                        ActionChip(
                          label: const Text('http://localhost:*', style: TextStyle(fontSize: 11)),
                          onPressed: isRunning
                              ? null
                              : () {
                                  setState(
                                    () => _allowedOriginsCtrl.text =
                                        'http://localhost:*',
                                  );
                                  _syncConfig(state);
                                },
                        ),
                        ActionChip(
                          label: const Text('https://*.pages.dev', style: TextStyle(fontSize: 11)),
                          onPressed: isRunning
                              ? null
                              : () {
                                  setState(
                                    () => _allowedOriginsCtrl.text =
                                        'https://*.pages.dev',
                                  );
                                  _syncConfig(state);
                                },
                        ),
                        ActionChip(
                          label: Text(
                            i18n.pick('* (仅限调试)', '* (Debug Only)'),
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: isRunning
                              ? null
                              : () {
                                  setState(() => _allowedOriginsCtrl.text = '*');
                                  _syncConfig(state);
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _portalDomainCtrl,
                            enabled: !isRunning,
                            decoration: InputDecoration(
                              labelText: i18n.pick('Web 门户根域名 (-portal-domain)', 'Portal Root Domain (-portal-domain)'),
                              hintText: 'portal.example.com',
                              helperText: i18n.pick('配置后开启零配置子域名确定性路由与自动 CORS 放行', 'Enables deterministic subdomain routing'),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => _syncConfig(state),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _maxIpConnsCtrl,
                            enabled: !isRunning,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: i18n.pick('单 IP 最大并发 WS (-max-ip-conns)', 'Max Conns/IP (-max-ip-conns)'),
                              helperText: i18n.pick('默认 64，防 DDoS 耗尽', 'Default 64'),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final parsed = int.tryParse(v?.trim() ?? '');
                              if (parsed == null || parsed < 1 || parsed > 65535) {
                                return i18n.pick('请输入 1~65535', '1-65535');
                              }
                              return null;
                            },
                            onChanged: (_) => _syncConfig(state),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _trustedProxiesCtrl,
                      enabled: !isRunning,
                      decoration: InputDecoration(
                        labelText: i18n.pick('受信任的反代 CIDR 网段 (-trusted-proxies)', 'Trusted Proxies (-trusted-proxies)'),
                        hintText:
                            '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128',
                        helperText: i18n.pick('用于提取真实客户端 IP，直接暴露公网时填 none', 'CIDRs trusted for X-Forwarded-For, or "none"'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => _syncConfig(state),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Embedded Live Signal Logs
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: AnimatedBuilder(
                animation: state.logNotifier,
                builder: (context, _) {
                  final logs = runtime.recentLogs;
                  if (_signalLogsAutoScroll &&
                      runtime.logVersion != _lastSignalLogVersion) {
                    _lastSignalLogVersion = runtime.logVersion;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          _signalLogsAutoScroll &&
                          _signalLogScrollCtrl.hasClients) {
                        _signalLogScrollCtrl.jumpTo(
                          _signalLogScrollCtrl.position.maxScrollExtent,
                        );
                      }
                    });
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.purpleAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            i18n.pick('信令服务实时日志 (Signal Logs)', 'Signal Live Logs'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: _signalLogsAutoScroll
                                ? i18n.t('logs_pause_scroll')
                                : i18n.t('logs_resume_scroll'),
                            icon: Icon(
                              _signalLogsAutoScroll
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                              color: _signalLogsAutoScroll
                                  ? null
                                  : Colors.orangeAccent,
                            ),
                            onPressed: () => setState(
                              () => _signalLogsAutoScroll =
                                  !_signalLogsAutoScroll,
                            ),
                          ),
                          IconButton(
                            tooltip: i18n.pick('复制信令日志', 'Copy Signal Logs'),
                            icon: const Icon(Icons.copy_all_rounded),
                            onPressed: () {
                              unawaited(
                                Clipboard.setData(
                                  ClipboardData(text: logs.join('\n')),
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    i18n.pick('已复制信令日志到剪贴板', 'Copied to clipboard'),
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: i18n.pick('弹窗查看日志', 'Pop out Log Dialog'),
                            icon: const Icon(Icons.open_in_new_rounded),
                            onPressed: () {
                              LiveLogDialog.show(
                                context,
                                title: i18n.t('logs_signal_node'),
                                profileId: '__signal__',
                                isSignal: true,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: i18n.pick('清空信令日志', 'Clear Signal Logs'),
                            icon: const Icon(Icons.delete_sweep_outlined),
                            onPressed: () => state.clearLogs('__signal__'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 220,
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: logs.isEmpty
                            ? Center(
                                child: Text(
                                  i18n.pick(
                                    '信令服务启动后，此处将实时流式输出调度日志...',
                                    'Logs will stream here once Signal Server starts...',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontFamily: 'Consolas',
                                    fontFamilyFallback: [
                                      'Courier New',
                                      'monospace',
                                    ],
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : RepaintBoundary(
                                child: ListView.builder(
                                  controller: _signalLogScrollCtrl,
                                  itemCount: logs.length,
                                  itemBuilder: (ctx, idx) {
                                    final line = logs[idx];
                                    return InkWell(
                                      onTap: () {
                                        unawaited(
                                          Clipboard.setData(
                                            ClipboardData(text: line),
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              i18n.pick('已复制该行日志', 'Copied log line'),
                                            ),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 1.5,
                                        ),
                                        child: Text(
                                          line,
                                          style: const TextStyle(
                                            fontFamily: 'Consolas',
                                            fontFamilyFallback: [
                                              'Cascadia Mono',
                                              'Courier New',
                                              'monospace',
                                            ],
                                            fontSize: 12,
                                            color: Color(0xFFE2E8F0),
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
