import 'dart:async';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/i18n.dart';
import '../../models/agent_profile.dart';

class AgentEditDialog extends StatefulWidget {
  final AgentProfile? initialProfile;
  final List<AgentProfile> existingProfiles;
  final void Function(AgentProfile) onSave;

  const AgentEditDialog({
    super.key,
    this.initialProfile,
    this.existingProfiles = const [],
    required this.onSave,
  });

  static void show(
    BuildContext context, {
    AgentProfile? profile,
    List<AgentProfile> existingProfiles = const [],
    required void Function(AgentProfile) onSave,
  }) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AgentEditDialog(
          initialProfile: profile,
          existingProfiles: existingProfiles,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<AgentEditDialog> createState() => _AgentEditDialogState();
}

class _AgentEditDialogState extends State<AgentEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollCtrl = ScrollController();

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
  late bool _allowPublic;
  late bool _autoStart;
  late TextEditingController _allowedProxyDomainsCtrl;
  late TextEditingController _portalUrlCtrl;
  late TextEditingController _signLinkCtrl;
  late int _maxTrunks;
  late TextEditingController _maxStreamsCtrl;
  late TextEditingController _stunServersCtrl;
  late TextEditingController _turnUrlCtrl;
  late TextEditingController _turnUserCtrl;
  late TextEditingController _turnPassCtrl;
  late bool _insecure;
  late bool _insecureTarget;
  late TextEditingController _proxyCtrl;
  late TextEditingController _sniCtrl;
  late TextEditingController _customBinaryCtrl;

  bool _showSignalSecret = false;
  bool _showAccessSecret = false;
  bool _showTurnPass = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _id = p?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _nameCtrl = TextEditingController(text: p?.name ?? '新穿透节点');
    _nodeIdCtrl = TextEditingController(
      text: p?.nodeId ?? 'node-${DateTime.now().millisecondsSinceEpoch % 10000}',
    );
    _mode = p?.mode ?? TunnelMode.target;
    _targetCtrl =
        TextEditingController(text: p?.target ?? 'http://127.0.0.1:8080');
    _dirPathCtrl = TextEditingController(text: p?.dirPath ?? '');
    _filePathCtrl = TextEditingController(text: p?.filePath ?? '');
    _signalUrlCtrl =
        TextEditingController(text: p?.signalUrl ?? 'ws://127.0.0.1:8888/ws');
    _signalSecretCtrl = TextEditingController(text: p?.signalSecret ?? '');
    _accessSecretCtrl = TextEditingController(text: p?.accessSecret ?? '');
    _allowPublic = p?.allowPublic ?? false;
    _autoStart = p?.autoStart ?? false;
    _allowedProxyDomainsCtrl =
        TextEditingController(text: p?.allowedProxyDomains ?? '');
    _portalUrlCtrl = TextEditingController(text: p?.portalUrl ?? '');
    _signLinkCtrl = TextEditingController(text: p?.signLink ?? '');
    _maxTrunks = p?.maxTrunks ?? 4;
    _maxStreamsCtrl =
        TextEditingController(text: (p?.maxStreams ?? 512).toString());
    _stunServersCtrl = TextEditingController(
      text: p?.stunServers.join(',') ??
          'stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302',
    );
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
    _maxStreamsCtrl.dispose();
    _stunServersCtrl.dispose();
    _turnUrlCtrl.dispose();
    _turnUserCtrl.dispose();
    _turnPassCtrl.dispose();
    _proxyCtrl.dispose();
    _sniCtrl.dispose();
    _customBinaryCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _generateRandomSecret([int length = 16]) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%*';
    final rand = Random.secure();
    return List<String>.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<void> _pickDirectory() async {
    final uri = await FilePicker.pickDirectory();
    if (uri != null && mounted) {
      setState(() => _dirPathCtrl.text = uri.toFilePath());
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null && mounted) {
      setState(() => _filePathCtrl.text = result.first.path!);
    }
  }

  Future<void> _pickCustomBinary() async {
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && result.first.path != null && mounted) {
      setState(() => _customBinaryCtrl.text = result.first.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final hasEphemeralSignLink = _signLinkCtrl.text.trim().isNotEmpty;
    final isPublicNoPassword =
        _accessSecretCtrl.text.trim().isEmpty && !hasEphemeralSignLink;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        children: [
          Icon(
            widget.initialProfile == null
                ? Icons.add_circle_outline
                : Icons.edit_note_rounded,
            color: Colors.blueAccent,
          ),
          const SizedBox(width: 8),
          Text(
            widget.initialProfile == null
                ? i18n.pick('添加新穿透节点', 'Add Tunnel Agent')
                : i18n.pick('编辑穿透节点配置', 'Edit Tunnel Agent'),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 740,
          maxHeight: screenHeight * 0.82,
        ),
        child: Form(
          key: _formKey,
          child: Scrollbar(
            controller: _scrollCtrl,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Basic Information
                  Text(
                    i18n.pick('1. 基础标识 (Core Info)', '1. Basic Identity'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.pick('节点友好名称', 'Display Name'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.label_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? i18n.pick('请输入名称', 'Please enter a name')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _nodeIdCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.pick(
                              'Node ID (唯一标识 -node-id)',
                              'Node ID (-node-id)',
                            ),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.fingerprint),
                          ),
                          validator: (v) {
                            final trimmed = v?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return i18n.pick('请输入 Node ID', 'Node ID is required');
                            }
                            if (!RegExp(r'^[a-zA-Z0-9._-]{1,64}$')
                                .hasMatch(trimmed)) {
                              return i18n.pick(
                                '仅限 1~64 位字母、数字、点(.)、下划线(_)或横杠(-)',
                                '1-64 chars: letters, digits, ., _, -',
                              );
                            }
                            final duplicate = widget.existingProfiles.any(
                              (other) =>
                                  other.id != _id && other.nodeId == trimmed,
                            );
                            if (duplicate) {
                              return i18n.pick(
                                '该 Node ID 已被其他节点占用，请更换',
                                'Duplicate Node ID already exists',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      i18n.pick('随软件启动自动运行该节点', 'Auto-start this node on app launch'),
                    ),
                    value: _autoStart,
                    onChanged: (v) => setState(() => _autoStart = v ?? false),
                  ),
                  const SizedBox(height: 12),

                  // 2. Operational Mode
                  Text(
                    i18n.pick('2. 穿透工作模式 (Operational Mode)', '2. Tunnel Mode'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TunnelMode>(
                    segments: [
                      ButtonSegment(
                        value: TunnelMode.target,
                        label: Text(i18n.pick('本地服务反代 (-target)', 'Reverse Proxy (-target)')),
                        icon: const Icon(Icons.http_rounded),
                      ),
                      ButtonSegment(
                        value: TunnelMode.dir,
                        label: Text(i18n.pick('静态目录托管 (-dir)', 'Static Dir (-dir)')),
                        icon: const Icon(Icons.folder_outlined),
                      ),
                      ButtonSegment(
                        value: TunnelMode.file,
                        label: Text(i18n.pick('单文件直传 (-file)', 'Single File (-file)')),
                        icon: const Icon(Icons.insert_drive_file_outlined),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (set) =>
                        setState(() => _mode = set.first),
                  ),
                  const SizedBox(height: 12),

                  if (_mode == TunnelMode.target) ...[
                    TextFormField(
                      controller: _targetCtrl,
                      decoration: InputDecoration(
                        labelText: i18n.pick('本地目标 URL (-target)', 'Target URL (-target)'),
                        hintText: 'http://127.0.0.1:8080',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link_rounded),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) {
                          return i18n.pick('请输入目标 URL', 'Target URL is required');
                        }
                        final uri = Uri.tryParse(text);
                        if (uri == null ||
                            (uri.scheme != 'http' && uri.scheme != 'https') ||
                            uri.host.isEmpty) {
                          return i18n.pick(
                            '请输入合法的 http:// 或 https:// 地址',
                            'Enter a valid http:// or https:// URL',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          i18n.pick('常用预设: ', 'Presets: '),
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        ActionChip(
                          label: const Text('Ollama (11434)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(
                            () => _targetCtrl.text = 'http://127.0.0.1:11434',
                          ),
                        ),
                        ActionChip(
                          label: const Text('ComfyUI (8188)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(
                            () => _targetCtrl.text = 'http://127.0.0.1:8188',
                          ),
                        ),
                        ActionChip(
                          label: const Text('Jellyfin (8096)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(
                            () => _targetCtrl.text = 'http://127.0.0.1:8096',
                          ),
                        ),
                        ActionChip(
                          label: const Text('群晖 NAS (5000)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(
                            () => _targetCtrl.text = 'http://127.0.0.1:5000',
                          ),
                        ),
                        ActionChip(
                          label: const Text('前端 Dev (3000)', style: TextStyle(fontSize: 11)),
                          onPressed: () => setState(
                            () => _targetCtrl.text = 'http://127.0.0.1:3000',
                          ),
                        ),
                      ],
                    ),
                  ] else if (_mode == TunnelMode.dir) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dirPathCtrl,
                            decoration: InputDecoration(
                              labelText: i18n.pick('静态目录路径 (-dir)', 'Directory Path (-dir)'),
                              border: const OutlineInputBorder(),
                              prefixIcon:
                                  const Icon(Icons.folder_shared_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? i18n.pick('请选择目录', 'Please select a directory')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => unawaited(_pickDirectory()),
                          icon: const Icon(Icons.folder_open),
                          label: Text(i18n.t('common_browse')),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _filePathCtrl,
                            decoration: InputDecoration(
                              labelText: i18n.pick('单文件路径 (-file)', 'File Path (-file)'),
                              border: const OutlineInputBorder(),
                              prefixIcon:
                                  const Icon(Icons.file_present_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? i18n.pick('请选择文件', 'Please select a file')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => unawaited(_pickFile()),
                          icon: const Icon(Icons.file_open),
                          label: Text(i18n.t('common_select')),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 3. Signaling & Auth
                  Text(
                    i18n.pick('3. 信令连接与安全鉴权 (Signaling & Auth)', '3. Signaling & Security'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _signalUrlCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.pick('信令服务地址 (-signal)', 'Signaling URL (-signal)'),
                            hintText: 'wss://signal.example.com/ws',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.hub_outlined),
                          ),
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (text.isEmpty) {
                              return i18n.pick('请输入信令 URL', 'Signaling URL is required');
                            }
                            final uri = Uri.tryParse(text);
                            if (uri == null ||
                                (uri.scheme != 'ws' && uri.scheme != 'wss') ||
                                uri.host.isEmpty) {
                              return i18n.pick(
                                '信令地址必须以 ws:// 或 wss:// 开头',
                                'Must start with ws:// or wss://',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _portalUrlCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.pick('Web 门户基础地址 (-portal-url)', 'Portal Base URL (-portal-url)'),
                            hintText: 'https://portal.example.com',
                            helperText: i18n.pick('可选，留空自动从信令地址推导', 'Optional, inferred from signal URL'),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final uri = Uri.tryParse(text);
                            if (uri == null ||
                                (uri.scheme != 'http' && uri.scheme != 'https') ||
                                uri.host.isEmpty) {
                              return i18n.pick('需为 http(s):// 地址', 'Must be http(s):// URL');
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _signalSecretCtrl,
                          obscureText: !_showSignalSecret,
                          decoration: InputDecoration(
                            labelText: i18n.pick('集群准入密钥 (-signal-secret)', 'Cluster Secret (-signal-secret)'),
                            helperText: i18n.pick('控制面鉴权，防未授权节点入群', 'Control-plane cluster auth'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                            suffixIcon: IconButton(
                              tooltip: i18n.pick('显示/隐藏', 'Show/Hide'),
                              icon: Icon(
                                _showSignalSecret
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _showSignalSecret = !_showSignalSecret,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _accessSecretCtrl,
                              obscureText: !_showAccessSecret,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: i18n.pick('访客访问密码 (-access-secret)', 'Visitor Password (-access-secret)'),
                                helperText: i18n.pick('强烈建议设置，可配合分享弹窗生成免密签名链接', 'Strongly recommended for safety'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock_person_outlined),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: i18n.pick('生成随机强密码', 'Generate Random Password'),
                                      icon: const Icon(Icons.casino_outlined, size: 19),
                                      onPressed: () => setState(() {
                                        _accessSecretCtrl.text =
                                            _generateRandomSecret();
                                        _allowPublic = false;
                                        _showAccessSecret = true;
                                      }),
                                    ),
                                    IconButton(
                                      tooltip: i18n.pick('显示/隐藏', 'Show/Hide'),
                                      icon: Icon(
                                        _showAccessSecret
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _showAccessSecret =
                                            !_showAccessSecret,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (isPublicNoPassword) ...[
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.amber.withValues(alpha: 0.14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Colors.amber.shade700.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.amber.shade800,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    i18n.pick(
                                      '安全警告：当前未设置访客访问密码 (-access-secret)',
                                      'Security Warning: No Visitor Password Set',
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => setState(() {
                                    _accessSecretCtrl.text =
                                        _generateRandomSecret();
                                    _allowPublic = false;
                                    _showAccessSecret = true;
                                  }),
                                  icon: const Icon(Icons.lock_rounded, size: 15),
                                  label: Text(i18n.pick('一键设密码', 'Set Password')),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              i18n.pick(
                                '公开免密模式下，任何获取链接或猜出 Node ID 的访客均可直接访问该节点暴露的服务/文件。普通用户建议点击上方“一键设密码”，然后通过“分享”生成免输密码的限时链接。',
                                'In public mode, anyone knowing the link or Node ID can access your exposed service/files directly.',
                              ),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                i18n.pick(
                                  '我已了解安全风险，确认允许公开免密访问 (-allow-public)',
                                  'I understand the risks and allow public unauthenticated access (-allow-public)',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              value: _allowPublic,
                              onChanged: (v) =>
                                  setState(() => _allowPublic = v ?? false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _allowedProxyDomainsCtrl,
                    decoration: InputDecoration(
                      labelText: i18n.pick(
                        '跨域代理白名单 (-allowed-proxy-domains)',
                        'Allowed Proxy Domains (-allowed-proxy-domains)',
                      ),
                      hintText: '*.hdslb.com,*.bilivideo.com,*.qpic.cn',
                      helperText: i18n.pick(
                        '逗号分隔的合法第三方公网域名后缀，支持通配符（受零信任 SSRF 引擎限制，私网 IP 恒拒绝）',
                        'Comma-separated public domain suffixes (private IPs blocked by SSRF guard)',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 4. Performance & Trunking
                  Text(
                    i18n.pick(
                      '4. 性能调优与多链路聚合 (Performance & Trunking)',
                      '4. Performance & Trunking',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Multi-PC 物理链路聚合 (-max-trunks): $_maxTrunks ${i18n.pick("路", "trunks")}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              i18n.pick(
                                '并发协商多个独立 PeerConnection 突破浏览器单核吞吐瓶颈（日常建议 4 路）',
                                'Multiple parallel PeerConnections to scale throughput (recommended: 4)',
                              ),
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
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
                          onChanged: (val) =>
                              setState(() => _maxTrunks = val.round()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _maxStreamsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: i18n.pick(
                              '最大并发多路复用流 (-max-streams)',
                              'Max Concurrent Streams (-max-streams)',
                            ),
                            helperText: i18n.pick('默认 512，范围 1~65535', 'Default 512 (1-65535)'),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final parsed = int.tryParse(v?.trim() ?? '');
                            if (parsed == null || parsed < 1 || parsed > 65535) {
                              return i18n.pick('请输入 1~65535 整数', 'Enter 1-65535');
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _signLinkCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.pick(
                              '启动时输出 CLI 临时签名链接 (-sign-link)',
                              'CLI Signed Link Duration (-sign-link)',
                            ),
                            hintText: '例如: 1h, 24h, 168h',
                            helperText: i18n.pick(
                              '需使用 h/m/s（如 7 天请填 168h，不支持 d）',
                              'Use Go duration h/m/s (e.g. 168h for 7 days)',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (!AgentProfile.isValidGoDuration(v ?? '')) {
                              return i18n.pick(
                                '格式无效：请使用如 1h、24h、168h（不支持 d）',
                                'Invalid Go duration (use e.g. 24h or 168h)',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 5. Network & ICE Traversal
                  Text(
                    i18n.pick(
                      '5. 网络穿越与 STUN/TURN (Network & Traversal)',
                      '5. Network & ICE Traversal',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _stunServersCtrl,
                    decoration: InputDecoration(
                      labelText: i18n.pick(
                        '自定义 STUN 服务器列表 (-stun-servers)',
                        'STUN Servers (-stun-servers)',
                      ),
                      hintText:
                          'stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302',
                      helperText: i18n.pick(
                        '逗号分隔的 STUN 地址（可在“网络诊断”测速后一键应用）',
                        'Comma-separated STUN URLs (can be auto-filled from Diagnostics)',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _turnUrlCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.pick('TURN 中继 URL (-turn-url)', 'TURN URL (-turn-url)'),
                            hintText: 'turn:relay.example.com:3478',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _turnUserCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.pick('TURN 用户名 (-turn-user)', 'TURN User'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _turnPassCtrl,
                          obscureText: !_showTurnPass,
                          decoration: InputDecoration(
                            labelText: i18n.pick('TURN 凭证 (-turn-pass)', 'TURN Pass'),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showTurnPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                () => _showTurnPass = !_showTurnPass,
                              ),
                            ),
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
                          decoration: InputDecoration(
                            labelText: i18n.pick('出站代理 (-proxy)', 'Outbound Proxy (-proxy)'),
                            hintText: 'socks5://127.0.0.1:1080',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sniCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.pick('TLS SNI 混淆域名 (-sni)', 'TLS SNI (-sni)'),
                            hintText: 'cdn.example.com',
                            border: const OutlineInputBorder(),
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
                          title: Text(i18n.pick('信任自签信令证书 (-insecure)', 'Skip Signal TLS Verify (-insecure)')),
                          subtitle: Text(i18n.pick('连接私有自签信令服务时开启', 'For self-signed signal servers only')),
                          value: _insecure,
                          onChanged: (v) =>
                              setState(() => _insecure = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(i18n.pick('信任目标服务证书 (-insecure-target)', 'Skip Target TLS Verify (-insecure-target)')),
                          subtitle: Text(i18n.pick('反代私有自签 HTTPS 服务时开启', 'For self-signed HTTPS backends')),
                          value: _insecureTarget,
                          onChanged: (v) =>
                              setState(() => _insecureTarget = v ?? false),
                        ),
                      ),
                    ],
                  ),
                  if (_insecure || _insecureTarget) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.gpp_maybe_outlined,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              i18n.pick(
                                '注意：跳过 TLS 证书校验仅限受信任的本地/局域网自签环境；在公网开启可能带来中间人劫持风险。',
                                'Warning: Skipping TLS verification weakens MITM protection; use only for trusted self-signed servers.',
                              ),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // 6. Advanced Custom Binary
                  Text(
                    i18n.pick('6. 高级与专属核心覆盖 (Custom Binary Override)', '6. Custom Binary Override'),
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
                          controller: _customBinaryCtrl,
                          decoration: InputDecoration(
                            labelText: i18n.pick(
                              '为该节点指定专属 agent 可执行文件 (留空使用全局)',
                              'Custom agent binary path for this node (optional)',
                            ),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.terminal_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => unawaited(_pickCustomBinary()),
                        child: Text(i18n.t('common_browse')),
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
          child: Text(i18n.t('common_cancel')),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;

            if (_accessSecretCtrl.text.trim().isEmpty &&
                _signLinkCtrl.text.trim().isEmpty &&
                !_allowPublic) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    i18n.pick(
                      '请设置访客密码，或勾选“确认允许公开免密访问”后再保存',
                      'Please set a visitor password or confirm public mode before saving.',
                    ),
                  ),
                ),
              );
              return;
            }

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
              allowPublic:
                  _accessSecretCtrl.text.trim().isEmpty ? _allowPublic : false,
              allowedProxyDomains: _allowedProxyDomainsCtrl.text.trim(),
              portalUrl: _portalUrlCtrl.text.trim(),
              signLink: _signLinkCtrl.text.trim(),
              maxTrunks: _maxTrunks,
              maxStreams: int.tryParse(_maxStreamsCtrl.text.trim()) ?? 512,
              stunServers: stunList.isEmpty ? null : stunList,
              turnUrl: _turnUrlCtrl.text.trim(),
              turnUser: _turnUserCtrl.text.trim(),
              turnPass: _turnPassCtrl.text.trim(),
              insecure: _insecure,
              insecureTarget: _insecureTarget,
              customBinaryPath: _customBinaryCtrl.text.trim().isEmpty
                  ? null
                  : _customBinaryCtrl.text.trim(),
              proxy: _proxyCtrl.text.trim(),
              sni: _sniCtrl.text.trim(),
              autoStart: _autoStart,
            );
            widget.onSave(newProfile);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.check),
          label: Text(i18n.t('common_save')),
        ),
      ],
    );
  }
}
