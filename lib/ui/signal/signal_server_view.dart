import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../models/runtime_state.dart';
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
  late TextEditingController _tlsCertCtrl;
  late TextEditingController _tlsKeyCtrl;
  late TextEditingController _allowedOriginsCtrl;
  late TextEditingController _portalDomainCtrl;
  late TextEditingController _signalSecretCtrl;
  late TextEditingController _trustedProxiesCtrl;
  late int _maxIpConns;

  bool _isProbingHealth = false;
  String? _healthResult;

  final ScrollController _signalLogScrollCtrl = ScrollController();
  bool _signalLogsAutoScroll = true;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<AppState>().signalConfig;
    _addrCtrl = TextEditingController(text: cfg.addr);
    _staticCtrl = TextEditingController(text: cfg.staticDir);
    _metricsCtrl = TextEditingController(text: cfg.metricsAddr);
    _tlsAuto = cfg.tlsAuto;
    _tlsCertCtrl = TextEditingController(text: cfg.tlsCert);
    _tlsKeyCtrl = TextEditingController(text: cfg.tlsKey);
    _allowedOriginsCtrl = TextEditingController(text: cfg.allowedOrigins);
    _portalDomainCtrl = TextEditingController(text: cfg.portalDomain);
    _signalSecretCtrl = TextEditingController(text: cfg.signalSecret);
    _trustedProxiesCtrl = TextEditingController(text: cfg.trustedProxies);
    _maxIpConns = cfg.maxIpConns;
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
    _signalLogScrollCtrl.dispose();
    super.dispose();
  }

  void _syncConfig(AppState state) {
    state.signalConfig.addr = _addrCtrl.text.trim();
    state.signalConfig.staticDir = _staticCtrl.text.trim();
    state.signalConfig.metricsAddr = _metricsCtrl.text.trim();
    state.signalConfig.tlsAuto = _tlsAuto;
    state.signalConfig.tlsCert = _tlsCertCtrl.text.trim();
    state.signalConfig.tlsKey = _tlsKeyCtrl.text.trim();
    state.signalConfig.allowedOrigins = _allowedOriginsCtrl.text.trim();
    state.signalConfig.portalDomain = _portalDomainCtrl.text.trim();
    state.signalConfig.signalSecret = _signalSecretCtrl.text.trim();
    state.signalConfig.trustedProxies = _trustedProxiesCtrl.text.trim();
    state.signalConfig.maxIpConns = _maxIpConns;
  }

  void _pickStaticDir() async {
    final uri = await FilePicker.pickDirectory();
    if (uri != null) {
      setState(() => _staticCtrl.text = uri.toFilePath());
    }
  }

  void _pickCert() async {
    final res = await FilePicker.pickFiles();
    if (res.isNotEmpty && res.first.path != null) {
      setState(() => _tlsCertCtrl.text = res.first.path!);
    }
  }

  void _pickKey() async {
    final res = await FilePicker.pickFiles();
    if (res.isNotEmpty && res.first.path != null) {
      setState(() => _tlsKeyCtrl.text = res.first.path!);
    }
  }

  void _runHealthCheck(AppState state) async {
    setState(() {
      _isProbingHealth = true;
      _healthResult = null;
    });

    final healthy = await state.probeSignalHealth();

    if (mounted) {
      setState(() {
        _isProbingHealth = false;
        _healthResult = healthy ? '健康检查通过 (HTTP 200 OK /healthz)' : '探针未响应或服务未就绪';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_healthResult!),
          backgroundColor: healthy ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  void _exportConfig(AppState state) async {
    _syncConfig(state);
    final yamlStr = state.signalConfig.toYamlString();
    final bytes = Uint8List.fromList(utf8.encode(yamlStr));
    final uri = await FilePicker.saveFile(
      dialogTitle: '导出源项目标准 server.yaml 配置文件',
      fileName: 'server.yaml',
      bytes: bytes,
    );
    if (uri != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已成功导出 server.yaml 到: ${uri.path}')),
      );
    }
  }

  void _importConfig(AppState state) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml', 'json'],
    );
    if (result.isNotEmpty && result.first.path != null) {
      final summary = await state.importConfigFile(result.first.path!);
      final cfg = state.signalConfig;
      setState(() {
        _addrCtrl.text = cfg.addr;
        _staticCtrl.text = cfg.staticDir;
        _metricsCtrl.text = cfg.metricsAddr;
        _tlsAuto = cfg.tlsAuto;
        _tlsCertCtrl.text = cfg.tlsCert;
        _tlsKeyCtrl.text = cfg.tlsKey;
        _allowedOriginsCtrl.text = cfg.allowedOrigins;
        _portalDomainCtrl.text = cfg.portalDomain;
        _signalSecretCtrl.text = cfg.signalSecret;
        _trustedProxiesCtrl.text = cfg.trustedProxies;
        _maxIpConns = cfg.maxIpConns;
      });
      if (mounted) {
        final signalUpdated = summary['signal'] as bool? ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(signalUpdated ? '已成功导入并加载源项目 server.yaml 信令配置' : '未在文件中检测到信令配置')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isRunning = state.isSignalRunning();
    final runtime = state.signalState;

    Color statusColor = isRunning ? Colors.green : Colors.grey;
    String statusText = isRunning ? '运行中 (Running)' : '已停止 (Stopped)';
    if (runtime.status == ProcessStatus.starting) {
      statusColor = Colors.orange;
      statusText = '启动中...';
    } else if (runtime.status == ProcessStatus.error) {
      statusColor = Colors.red;
      statusText = '运行异常';
    }

    final webUrl = state.signalConfig.portalWebUrl;

    if (_signalLogsAutoScroll && _signalLogScrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_signalLogsAutoScroll && _signalLogScrollCtrl.hasClients) {
          _signalLogScrollCtrl.jumpTo(_signalLogScrollCtrl.position.maxScrollExtent);
        }
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '信令与 Web 门户服务 (Signal Server)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'WebRTC 拓扑撮合、DTLS/ICE 候选协商及免客户端 Web Portal',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _exportConfig(state),
                    icon: const Icon(Icons.save_alt_rounded, size: 16),
                    label: const Text('导出配置'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _importConfig(state),
                    icon: const Icon(Icons.file_open_rounded, size: 16),
                    label: const Text('导入配置'),
                  ),
                  if (isRunning)
                    OutlinedButton.icon(
                      onPressed: () => _runHealthCheck(state),
                      icon: _isProbingHealth
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.health_and_safety_outlined, size: 18),
                      label: const Text('健康检查'),
                    ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isRunning ? Colors.redAccent : Colors.purpleAccent,
                    ),
                    onPressed: () {
                      _syncConfig(state);
                      if (isRunning) {
                        state.stopSignalServer();
                      } else {
                        state.startSignalServer();
                      }
                    },
                    icon: Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(isRunning ? '停止信令服务' : '启动信令服务'),
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
              side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1.5),
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
                          ? [BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 3)]
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: statusColor),
                            ),
                            const SizedBox(width: 12),
                            if (isRunning && runtime.pid != null) ...[
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('PID: ${runtime.pid} | 端口: ${state.signalConfig.addr}'),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (isRunning) ...[
                          Row(
                            children: [
                              const Text('Web 控制台访问入口: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              SelectableText(
                                webUrl,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            runtime.lastError ?? '信令服务负责管理整个集群的 WebRTC 拓扑撮合、DTLS/ICE 候选协商并提供免客户端 Web Portal。',
                            style: TextStyle(color: runtime.lastError != null ? Colors.redAccent : Colors.grey, fontSize: 13),
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
                          title: '信令服务实时日志',
                          profileId: '__signal__',
                          isSignal: true,
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('查看日志'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Open in external browser
                        Process.run('cmd', ['/c', 'start', webUrl]);
                      },
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('打开 Web 门户'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Full CLI Options Configuration
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: Colors.purpleAccent),
                        SizedBox(width: 8),
                        Text(
                          '信令服务所有命令行全量配置项 (CLI Options)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section A: Server & Network
                    const Text('A. 服务与监听配置 (Server & Network)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _addrCtrl,
                            enabled: !isRunning,
                            decoration: const InputDecoration(
                              labelText: 'HTTP/WS 监听地址 (-addr)',
                              hintText: ':8888 或 0.0.0.0:8888',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.settings_input_component_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _metricsCtrl,
                            enabled: !isRunning,
                            decoration: const InputDecoration(
                              labelText: 'Prometheus 指标监听地址 (-metrics-addr)',
                              hintText: ':9090',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.analytics_outlined),
                            ),
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
                            decoration: const InputDecoration(
                              labelText: '外部 Web 静态资产目录路径 (-static)',
                              hintText: '留空使用内置嵌入式 Web 门户控制台',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.folder_copy_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: isRunning ? null : _pickStaticDir,
                          child: const Text('浏览...'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Section B: TLS & HTTPS
                    const Text('B. TLS / HTTPS 安全凭据配置 (TLS & HTTPS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('内存自签 ECDSA 证书开启 (-tls-auto)'),
                      subtitle: const Text('自动生成覆盖 localhost 和局域网 IP 的内存证书，为浏览器 Service Worker 激活安全上下文 (HTTPS)'),
                      value: _tlsAuto,
                      onChanged: isRunning ? null : (v) => setState(() => _tlsAuto = v ?? true),
                    ),
                    if (!_tlsAuto) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tlsCertCtrl,
                              enabled: !isRunning,
                              decoration: const InputDecoration(
                                labelText: '正式 TLS 证书 PEM 路径 (-tls-cert)',
                                hintText: 'C:\\certs\\fullchain.pem',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(onPressed: isRunning ? null : _pickCert, child: const Text('浏览...')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tlsKeyCtrl,
                              enabled: !isRunning,
                              decoration: const InputDecoration(
                                labelText: '正式 TLS 私钥 PEM 路径 (-tls-key)',
                                hintText: 'C:\\certs\\privkey.pem',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(onPressed: isRunning ? null : _pickKey, child: const Text('浏览...')),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Section C: Security & Origins
                    const Text('C. 安全鉴权、防劫持与跨域 (Security & Origins)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _signalSecretCtrl,
                      enabled: !isRunning,
                      decoration: const InputDecoration(
                        labelText: '集群统一准入预共享密钥 (-signal-secret)',
                        helperText: '控制面鉴权：连接到此信令服务的 Agent 必须提供相同的 signal_secret 才能注册节点',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _allowedOriginsCtrl,
                      enabled: !isRunning,
                      decoration: const InputDecoration(
                        labelText: 'WebSocket 允许接入 Origin 跨域白名单 (-allowed-origins)',
                        hintText: '* 或 https://*.pages.dev,http://localhost:*',
                        helperText: '支持通配符，防 CSWSH 劫持攻击。输入 * 允许所有跨域浏览器连接',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.security_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        const Text('快捷填充: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ActionChip(
                          label: const Text('* (允许所有)', style: TextStyle(fontSize: 11)),
                          onPressed: isRunning ? null : () => setState(() => _allowedOriginsCtrl.text = '*'),
                        ),
                        ActionChip(
                          label: const Text('http://localhost:*', style: TextStyle(fontSize: 11)),
                          onPressed: isRunning ? null : () => setState(() => _allowedOriginsCtrl.text = 'http://localhost:*'),
                        ),
                        ActionChip(
                          label: const Text('https://*.pages.dev', style: TextStyle(fontSize: 11)),
                          onPressed: isRunning ? null : () => setState(() => _allowedOriginsCtrl.text = 'https://*.pages.dev'),
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
                            decoration: const InputDecoration(
                              labelText: 'Web 门户根域名 (-portal-domain)',
                              hintText: '例如: portal.example.com',
                              helperText: '配置后开启零配置子域名确定性路由',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _maxIpConns.toString(),
                            enabled: !isRunning,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '单 IP 最大并发 WS (-max-ip-conns)',
                              helperText: '默认 64，防 DDoS 耗尽',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => _maxIpConns = int.tryParse(v) ?? 64,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _trustedProxiesCtrl,
                      enabled: !isRunning,
                      decoration: const InputDecoration(
                        labelText: '受信任的反代 CIDR 网段 (-trusted-proxies)',
                        hintText: '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128',
                        helperText: '用于提取真实客户端 IP，直接暴露公网时填 none',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Embedded Live Signal Logs
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
                      const Icon(Icons.receipt_long_rounded, color: Colors.purpleAccent),
                      const SizedBox(width: 8),
                      const Text(
                        '信令服务实时日志输出 (Signal Live Logs)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _signalLogsAutoScroll ? '暂停自动滚动' : '恢复自动滚动',
                        icon: Icon(
                          _signalLogsAutoScroll ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                          color: _signalLogsAutoScroll ? null : Colors.orangeAccent,
                        ),
                        onPressed: () => setState(() => _signalLogsAutoScroll = !_signalLogsAutoScroll),
                      ),
                      IconButton(
                        tooltip: '复制信令日志',
                        icon: const Icon(Icons.copy_all_rounded),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: runtime.recentLogs.join('\n')));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制信令日志到剪贴板'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: '弹窗查看日志',
                        icon: const Icon(Icons.open_in_new_rounded),
                        onPressed: () {
                          LiveLogDialog.show(
                            context,
                            title: '信令服务实时日志',
                            profileId: '__signal__',
                            isSignal: true,
                          );
                        },
                      ),
                      IconButton(
                        tooltip: '清空信令日志',
                        icon: const Icon(Icons.delete_sweep_outlined),
                        onPressed: () {
                          state.clearLogs('__signal__');
                        },
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
                    child: runtime.recentLogs.isEmpty
                        ? const Center(
                            child: Text(
                              '信令服务启动后，此处将实时流式输出调度日志...',
                              style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 12),
                            ),
                          )
                        : SelectionArea(
                            child: ListView.builder(
                              controller: _signalLogScrollCtrl,
                              itemCount: runtime.recentLogs.length,
                              itemBuilder: (ctx, idx) {
                                final line = runtime.recentLogs[idx];
                                return Text(
                                  line,
                                  style: const TextStyle(
                                    fontFamily: 'Consolas, monospace',
                                    fontSize: 12,
                                    color: Color(0xFFE2E8F0),
                                    height: 1.3,
                                  ),
                                );
                              },
                            ),
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
