import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/hmac_signer.dart';

class ShareLinkDialog extends StatefulWidget {
  final String portalUrl;
  final String nodeId;
  final String accessSecret;

  const ShareLinkDialog({
    super.key,
    required this.portalUrl,
    required this.nodeId,
    required this.accessSecret,
  });

  @override
  State<ShareLinkDialog> createState() => _ShareLinkDialogState();
}

class _ShareLinkDialogState extends State<ShareLinkDialog> {
  Duration _selectedDuration = const Duration(hours: 24);
  late String _generatedLink;

  final List<Map<String, dynamic>> _durationOptions = [
    {'label': '1 小时', 'duration': const Duration(hours: 1)},
    {'label': '24 小时 (推荐)', 'duration': const Duration(days: 1)},
    {'label': '7 天', 'duration': const Duration(days: 7)},
    {'label': '30 天', 'duration': const Duration(days: 30)},
  ];

  @override
  void initState() {
    super.initState();
    _recomputeLink();
  }

  void _recomputeLink() {
    _generatedLink = HmacSigner.generateShareLink(
      portalUrl: widget.portalUrl,
      nodeId: widget.nodeId,
      accessSecret: widget.accessSecret,
      duration: _selectedDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'P2P 访客直连分享',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '节点: ${widget.nodeId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Duration selector
              if (widget.accessSecret.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      '时效安全签名有效期:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<Duration>(
                        initialValue: _selectedDuration,
                        isDense: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: _durationOptions.map((opt) {
                          return DropdownMenuItem<Duration>(
                            value: opt['duration'] as Duration,
                            child: Text(opt['label'] as String, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (newDur) {
                          if (newDur != null) {
                            setState(() {
                              _selectedDuration = newDur;
                              _recomputeLink();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // QR Code Card
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: QrImageView(
                    data: _generatedLink,
                    version: QrVersions.auto,
                    size: 190.0,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F172A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Link box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: SelectableText(
                  _generatedLink,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('复制链接'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatedLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制分享链接到剪贴板！'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                      label: const Text('浏览器打开'),
                      onPressed: () async {
                        final uri = Uri.parse(_generatedLink);
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
