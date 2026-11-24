import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/i18n.dart';
import '../../models/agent_profile.dart';
import '../../state/app_state.dart';

class ShareDialog extends StatefulWidget {
  final AgentProfile profile;

  const ShareDialog({super.key, required this.profile});

  static void show(BuildContext context, AgentProfile profile) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => ShareDialog(profile: profile),
      ),
    );
  }

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final ScrollController _scrollCtrl = ScrollController();
  int _expireHours = 24;
  bool _useSignedLink = true;
  bool _includePasswordInCard = false;
  bool _copiedLink = false;
  bool _copiedCard = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _computeActiveShareUrl(String? cliGeneratedLink) {
    if (widget.profile.accessSecret.isNotEmpty) {
      if (_useSignedLink) {
        return widget.profile.generateSignedShareUrl(
          duration: Duration(hours: _expireHours),
        );
      }
      return widget.profile.directPortalUrl;
    }
    if (cliGeneratedLink != null && cliGeneratedLink.isNotEmpty) {
      return cliGeneratedLink;
    }
    return widget.profile.directPortalUrl;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n();
    final runtime = context.select<AppState, String?>(
      (s) => s.getRuntimeState(widget.profile.id).generatedShareLink,
    );

    final hasPassword = widget.profile.accessSecret.isNotEmpty;
    final url = _computeActiveShareUrl(runtime);
    final isPlainHttpNonLocal = url.startsWith('http://') &&
        !url.contains('127.0.0.1') &&
        !url.contains('localhost');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(i18n.t('share_dialog_title'))),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Scrollbar(
          controller: _scrollCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          i18n.t('share_tip'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                if (!hasPassword && runtime == null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amber.shade700.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            i18n.pick(
                              '安全提示：此节点未设置访问密码，任何扫码或打开链接的人都可直接访问您的本地服务。建议为节点设置密码以启用时效数字签名分享。',
                              'Security Warning: No visitor password is set. Anyone with this link can access your local service directly.',
                            ),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (isPlainHttpNonLocal) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.https_outlined,
                          size: 18,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            i18n.pick(
                              '浏览器提示：跨设备打开 Web 门户需使用 HTTPS（如开启信令 -tls-auto 或填写公网 HTTPS 门户地址），否则浏览器会禁用 Service Worker。',
                              'Browser Note: Remote devices require HTTPS to register the Service Worker.',
                            ),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // QR Code Card (always white background so scanners read reliably in Dark Mode)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox.square(
                    dimension: 156.0,
                    child: QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: 156.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  '${widget.profile.name} (${widget.profile.nodeId})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  url,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 12.5,
                    fontFamily: 'Consolas',
                    fontFamilyFallback: ['Courier New', 'monospace'],
                  ),
                  textAlign: TextAlign.center,
                ),

                if (hasPassword) ...[
                  const SizedBox(height: 14),
                  Material(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            i18n.pick(
                              '生成免密时效签名链接 (HMAC-SHA256)',
                              'Generate Signed Temporary Link (HMAC-SHA256)',
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            i18n.pick(
                              '访客无需手动输入密码，链接到期后自动失效',
                              'Visitors connect without typing password; expires automatically.',
                            ),
                            style: const TextStyle(fontSize: 11),
                          ),
                          value: _useSignedLink,
                          onChanged: (v) => setState(() {
                            _useSignedLink = v;
                            _copiedLink = false;
                            _copiedCard = false;
                          }),
                        ),
                        if (_useSignedLink) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                i18n.pick('有效时长:', 'Expires in:'),
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  children: [1, 12, 24, 168].map((hours) {
                                    final label = hours == 168
                                        ? i18n.pick('7 天', '7d')
                                        : '$hours ${i18n.pick("小时", "h")}';
                                    return ChoiceChip(
                                      label: Text(
                                        label,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      selected: _expireHours == hours,
                                      visualDensity: VisualDensity.compact,
                                      onSelected: (_) => setState(() {
                                        _expireHours = hours;
                                        _copiedLink = false;
                                        _copiedCard = false;
                                      }),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            i18n.pick(
                              '在复制的分享卡片中附带明文密码',
                              'Include plaintext password in share card',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: _includePasswordInCard,
                          onChanged: (v) => setState(() {
                            _includePasswordInCard = v ?? false;
                            _copiedCard = false;
                          }),
                        ),
                      ],
                    ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        unawaited(Clipboard.setData(ClipboardData(text: url)));
                        setState(() => _copiedLink = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              i18n.pick(
                                '已复制访问链接到剪贴板',
                                'Access URL copied to clipboard',
                              ),
                            ),
                          ),
                        );
                      },
                      icon: Icon(_copiedLink ? Icons.check : Icons.link),
                      label: Text(i18n.t('share_link_btn')),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final cardText = widget.profile.formatShareCard(
                          expireHours:
                              (hasPassword && _useSignedLink) ? _expireHours : null,
                          shareUrl: url,
                          includePassword: _includePasswordInCard,
                          isEnglish: i18n.isEnglish,
                        );
                        unawaited(
                          Clipboard.setData(ClipboardData(text: cardText)),
                        );
                        setState(() => _copiedCard = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              i18n.pick(
                                '已复制完整分享卡片到剪贴板',
                                'Formatted share card copied to clipboard',
                              ),
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        _copiedCard ? Icons.check : Icons.copy_all_rounded,
                      ),
                      label: Text(i18n.t('share_card_btn')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.t('common_close')),
        ),
      ],
    );
  }
}
