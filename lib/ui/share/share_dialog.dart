import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/i18n.dart';
import '../../models/agent_profile.dart';

class ShareDialog extends StatefulWidget {
  final AgentProfile profile;

  const ShareDialog({super.key, required this.profile});

  static void show(BuildContext context, AgentProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => ShareDialog(profile: profile),
    );
  }

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final int _expireHours = 24;
  bool _copiedLink = false;
  bool _copiedCard = false;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n();
    final url = widget.profile.directPortalUrl;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Text(i18n.t('share_dialog_title')),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
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
                    const Icon(Icons.info_outline, size: 20, color: Colors.blueAccent),
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
              const SizedBox(height: 16),
              // QR Code Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Node name & URL
              Text(
                '${widget.profile.name} (${widget.profile.nodeId})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: const TextStyle(color: Colors.blueAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (widget.profile.accessSecret.isNotEmpty) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.lock_rounded, size: 16),
                  label: Text('访问密码: ${widget.profile.accessSecret}'),
                ),
              ],
              const SizedBox(height: 16),
              // Copy buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      setState(() => _copiedLink = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制直连 URL 到剪贴板')),
                      );
                    },
                    icon: Icon(_copiedLink ? Icons.check : Icons.link),
                    label: Text(i18n.t('share_link_btn')),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      final cardText = widget.profile.formatShareCard(expireHours: _expireHours);
                      Clipboard.setData(ClipboardData(text: cardText));
                      setState(() => _copiedCard = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制完整格式化分享卡片到剪贴板')),
                      );
                    },
                    icon: Icon(_copiedCard ? Icons.check : Icons.copy_all_rounded),
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
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
