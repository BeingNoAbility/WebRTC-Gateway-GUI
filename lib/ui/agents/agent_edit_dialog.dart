import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../models/agent_profile.dart';

class AgentEditDialog extends StatefulWidget {
  final AgentProfile? initialProfile;
  final Function(AgentProfile) onSave;

  const AgentEditDialog({
    super.key,
    this.initialProfile,
    required this.onSave,
  });

  static void show(BuildContext context, {AgentProfile? profile, required Function(AgentProfile) onSave}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AgentEditDialog(
        initialProfile: profile,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AgentEditDialog> createState() => _AgentEditDialogState();
}

class _AgentEditDialogState extends State<AgentEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _id;
  late TextEditingController _nameCtrl;
  late TextEditingController _nodeIdCtrl;
  late TunnelMode _mode;
  late TextEditingController _targetCtrl;
  late TextEditingController _dirPathCtrl;
  late TextEditingController _filePathCtrl;
  late TextEditingController _signalUrlCtrl;
  late TextEditingController _signalSecretCtrl;
  late TextEditingController _accessSecretCtrl;
  late TextEditingController _allowedProxyDomainsCtrl;
  late TextEditingController _portalUrlCtrl;
  late TextEditingController _signLinkCtrl;
  late int _maxTrunks;
  late int _maxStreams;
  late TextEditingController _stunServersCtrl;
  late TextEditingController _turnUrlCtrl;
  late TextEditingController _turnUserCtrl;
  late TextEditingController _turnPassCtrl;
  late bool _insecure;
  late bool _insecureTarget;
  late TextEditingController _proxyCtrl;
  late TextEditingController _sniCtrl;
  late TextEditingController _customBinaryCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _id = p?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _nameCtrl = TextEditingController(text: p?.name ?? '新穿透节点');
    _nodeIdCtrl = TextEditingController(text: p?.nodeId ?? 'node-${DateTime.now().millisecondsSinceEpoch % 10000}');
    _mode = p?.mode ?? TunnelMode.target;
    _targetCtrl = TextEditingController(text: p?.target ?? 'http://127.0.0.1:8080');
    _dirPathCtrl = TextEditingController(text: p?.dirPath ?? '');
    _filePathCtrl = TextEditingController(text: p?.filePath ?? '');
    _signalUrlCtrl = TextEditingController(text: p?.signalUrl ?? 'ws://127.0.0.1:8888/ws');
    _signalSecretCtrl = TextEditingController(text: p?.signalSecret ?? '');
    _accessSecretCtrl = TextEditingController(text: p?.accessSecret ?? '');
    _allowedProxyDomainsCtrl = TextEditingController(text: p?.allowedProxyDomains ?? '');
    _portalUrlCtrl = TextEditingController(text: p?.portalUrl ?? '');
    _signLinkCtrl = TextEditingController(text: p?.signLink ?? '');
    _maxTrunks = p?.maxTrunks ?? 4;
    _maxStreams = p?.maxStreams ?? 512;
    _stunServersCtrl = TextEditingController(text: p?.stunServers.join(',') ?? 'stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302');
    _turnUrlCtrl = TextEditingController(text: p?.turnUrl ?? '');
    _turnUserCtrl = TextEditingController(text: p?.turnUser ?? '');
    _turnPassCtrl = TextEditingController(text: p?.turnPass ?? '');
    _insecure = p?.insecure ?? false;
    _insecureTarget = p?.insecureTarget ?? false;
    _proxyCtrl = TextEditingController(text: p?.proxy ?? '');
    _sniCtrl = TextEditingController(text: p?.sni ?? '');
    _customBinaryCtrl = TextEditingController(text: p?.customBinaryPath ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nodeIdCtrl.dispose();
    _targetCtrl.dispose();
    _dirPathCtrl.dispose();
    _filePathCtrl.dispose();
    _signalUrlCtrl.dispose();
    _signalSecretCtrl.dispose();
    _accessSecretCtrl.dispose();
    _allowedProxyDomainsCtrl.dispose();
    _portalUrlCtrl.dispose();
    _signLinkCtrl.dispose();
    _stunServersCtrl.dispose();
    _turnUrlCtrl.dispose();
    _turnUserCtrl.dispose();
    _turnPassCtrl.dispose();
    _proxyCtrl.dispose();
    _sniCtrl.dispose();
    _customBinaryCtrl.dispose();
    super.dispose();
  }

  void _pickDirectory() async {
    final uri = await FilePicker.pickDirectory();
    if (uri != null) {
      setState(() => _dirPathCtrl.text = uri.toFilePath());
    }
  }

  void _pickFile() async {
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      setState(() => _filePathCtrl.text = result.first.path!);
    }
  }

  void _pickCustomBinary() async {
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null) {
      setState(() => _customBinaryCtrl.text = result.first.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        children: [
          Icon(
            widget.initialProfile == null ? Icons.add_circle_outline : Icons.edit_note_rounded,
            color: Colors.blueAccent,
          ),
          const SizedBox(width: 8),
          Text(widget.initialProfile == null ? '添加新穿透节点' : '编辑穿透节点全量配置'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: screenHeight * 0.8, // Explicitly constrain height to enable smooth scrolling!
        ),
        child: Form(
          key: _formKey,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Basic Information
                  const Text('1. 基础标识 (Core Info)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '节点友好名称 (Display Name)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? '请输入名称' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _nodeIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Node ID (节点唯一标识 -node-id)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.fingerprint),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return '请输入 Node ID';
                            if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(v)) {
                              return '仅限字母、数字、点(.)、下划线(_)或横杠(-)';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Operational Mode
                  const Text('2. 穿透工作模式 (Operational Mode)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  SegmentedButton<TunnelMode>(
                    segments: const [
                      ButtonSegment(
                        value: TunnelMode.target,
                        label: Text('本地服务反代 (-target)'),
                        icon: Icon(Icons.http_rounded),
                      ),
                      ButtonSegment(
                        value: TunnelMode.dir,
                        label: Text('静态目录托管 (-dir)'),
                        icon: Icon(Icons.folder_outlined),
                      ),
                      ButtonSegment(
                        value: TunnelMode.file,
                        label: Text('单文件直传 (-file)'),
                        icon: Icon(Icons.insert_drive_file_outlined),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (set) => setState(() => _mode = set.first),
                  ),
                  const SizedBox(height: 12),

                  if (_mode == TunnelMode.target) ...[
                    TextFormField(
                      controller: _targetCtrl,
                      decoration: const InputDecoration(
                        labelText: '本地目标 URL (-target)',
                        hintText: 'http://127.0.0.1:8080',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? '请输入目标 URL' : null,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const Text('常用预设: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ActionChip(
                          label: const Text('Ollama (11434)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(() => _targetCtrl.text = 'http://127.0.0.1:11434'),
                        ),
                        ActionChip(
                          label: const Text('ComfyUI (8188)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(() => _targetCtrl.text = 'http://127.0.0.1:8188'),
                        ),
                        ActionChip(
                          label: const Text('Jellyfin (8096)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(() => _targetCtrl.text = 'http://127.0.0.1:8096'),
                        ),
                        ActionChip(
                          label: const Text('群晖 NAS (5000)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(() => _targetCtrl.text = 'http://127.0.0.1:5000'),
                        ),
                        ActionChip(
                          label: const Text('前端 Dev (3000)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(() => _targetCtrl.text = 'http://127.0.0.1:3000'),
                        ),
                      ],
                    ),
                  ] else if (_mode == TunnelMode.dir) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dirPathCtrl,
                            decoration: const InputDecoration(
                              labelText: '静态目录路径 (-dir)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.folder_shared_outlined),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? '请选择目录' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _pickDirectory,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('浏览...'),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _filePathCtrl,
                            decoration: const InputDecoration(
                              labelText: '单文件路径 (-file)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.file_present_outlined),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? '请选择文件' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.file_open),
                          label: const Text('选择...'),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 3. Signaling & Auth
                  const Text('3. 信令连接与安全鉴权 (Signaling & Auth)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _signalUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: '信令服务地址 (-signal)',
                      hintText: 'wss://signal.example.com/ws 或 ws://127.0.0.1:8888/ws',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.hub_outlined),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '请输入信令 URL' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _signalSecretCtrl,
                          decoration: const InputDecoration(
                            labelText: '集群准入密钥 (-signal-secret)',
                            helperText: '控制面鉴权，防未授权节点入群',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _accessSecretCtrl,
                          decoration: const InputDecoration(
                            labelText: '访客访问密码 (-access-secret)',
                            helperText: '数据面鉴权，空代表公开免密',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_person_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _allowedProxyDomainsCtrl,
                    decoration: const InputDecoration(
                      labelText: '跨域代理白名单 (-allowed-proxy-domains)',
                      hintText: '*.hdslb.com,*.bilivideo.com,*.qpic.cn',
                      helperText: '逗号分隔的合法第三方公网域名后缀，支持通配符',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 4. Performance & Trunking
                  const Text('4. 性能调优与多链路聚合 (Performance & Trunking)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Multi-PC 物理链路聚合 (-max-trunks): $_maxTrunks 路', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('并发协商多个独立 PeerConnection 突破 Chromium 单核算力瓶颈', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: Slider(
                          value: _maxTrunks.toDouble(),
                          min: 1,
                          max: 8,
                          divisions: 7,
                          label: '$_maxTrunks Trunks',
                          onChanged: (val) => setState(() => _maxTrunks = val.round()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _maxStreams.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '最大并发多路复用流 (-max-streams)',
                            helperText: '默认 512，超过触发背压阻断',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _maxStreams = int.tryParse(v) ?? 512,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _signLinkCtrl,
                          decoration: const InputDecoration(
                            labelText: '生成带签名临时有效分享 (-sign-link)',
                            hintText: '例如: 1h, 24h, 7d',
                            helperText: '生成 HMAC-SHA256 时效安全访问链接',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 5. Network & ICE Traversal
                  const Text('5. 网络穿越与 STUN/TURN (Network & Traversal)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _stunServersCtrl,
                    decoration: const InputDecoration(
                      labelText: '自定义 STUN 服务器列表 (-stun-servers)',
                      hintText: 'stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302',
                      helperText: '逗号分隔的 STUN 探测地址',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _turnUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'TURN 中继 URL (-turn-url)',
                            hintText: 'turn:relay.example.com:3478',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _turnUserCtrl,
                          decoration: const InputDecoration(
                            labelText: 'TURN 用户名 (-turn-user)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _turnPassCtrl,
                          decoration: const InputDecoration(
                            labelText: 'TURN 凭证 (-turn-pass)',
                            border: OutlineInputBorder(),
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
                          controller: _proxyCtrl,
                          decoration: const InputDecoration(
                            labelText: '出站代理 (-proxy)',
                            hintText: 'socks5://127.0.0.1:1080',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sniCtrl,
                          decoration: const InputDecoration(
                            labelText: 'TLS SNI 混淆域名 (-sni)',
                            hintText: 'cdn.example.com',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('信任自签信令证书 (-insecure)'),
                          subtitle: const Text('连接私有自签信令服务时开启'),
                          value: _insecure,
                          onChanged: (v) => setState(() => _insecure = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('信任目标服务证书 (-insecure-target)'),
                          subtitle: const Text('反代私有自签 HTTPS 服务时开启'),
                          value: _insecureTarget,
                          onChanged: (v) => setState(() => _insecureTarget = v ?? false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 6. Advanced Custom Binary
                  const Text('6. 高级与专属核心二进制覆盖 (Custom Core Override)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customBinaryCtrl,
                          decoration: const InputDecoration(
                            labelText: '为该节点指定专属 agent.exe (留空使用全局)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.terminal_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _pickCustomBinary,
                        child: const Text('浏览...'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final stunList = _stunServersCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              final newProfile = AgentProfile(
                id: _id,
                name: _nameCtrl.text.trim(),
                nodeId: _nodeIdCtrl.text.trim(),
                mode: _mode,
                target: _targetCtrl.text.trim(),
                dirPath: _dirPathCtrl.text.trim(),
                filePath: _filePathCtrl.text.trim(),
                signalUrl: _signalUrlCtrl.text.trim(),
                signalSecret: _signalSecretCtrl.text.trim(),
                accessSecret: _accessSecretCtrl.text.trim(),
                allowPublic: _accessSecretCtrl.text.trim().isEmpty,
                allowedProxyDomains: _allowedProxyDomainsCtrl.text.trim(),
                portalUrl: _portalUrlCtrl.text.trim(),
                signLink: _signLinkCtrl.text.trim(),
                maxTrunks: _maxTrunks,
                maxStreams: _maxStreams,
                stunServers: stunList.isEmpty ? null : stunList,
                turnUrl: _turnUrlCtrl.text.trim(),
                turnUser: _turnUserCtrl.text.trim(),
                turnPass: _turnPassCtrl.text.trim(),
                insecure: _insecure,
                insecureTarget: _insecureTarget,
                customBinaryPath: _customBinaryCtrl.text.trim().isEmpty ? null : _customBinaryCtrl.text.trim(),
                proxy: _proxyCtrl.text.trim(),
                sni: _sniCtrl.text.trim(),
              );
              widget.onSave(newProfile);
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('保存配置'),
        ),
      ],
    );
  }
}
